const path = require('path');
const fs = require('fs');
const { Buffer } = require('buffer');
const multer = require('multer');
const short = require('short-uuid');
const FirebaseAdmin = require('firebase-admin');
const Mustache = require('mustache');

const winston = require('../../util/winston');
const { getTokenAuth, logHttp, shortId2Id } = require('../../util/auxiliar');
const { getPhotoVotePlace, addPhotoVoteEntry, votePhotoVoteDB, saveAnswer } = require('../../util/bd');
const { urlServer, tamaMaxFile } = require('../../util/config');

// Las fotografías de la votación pública se guardan aparte de los ficheros de
// respuestas privadas
const UPLOAD_DIR = path.join(__dirname, '../../uploads/photoVote');
if (!fs.existsSync(UPLOAD_DIR)) {
    fs.mkdirSync(UPLOAD_DIR, { recursive: true });
}

const ALLOWED_EXTENSIONS = ['.jpg', '.jpeg', '.png'];
const FILE_ID_REGEX = /^[A-Za-z0-9_-]+\.(jpg|jpeg|png)$/;

const _storage = multer.diskStorage({
    destination: (req, file, cb) => cb(null, UPLOAD_DIR),
    filename: (req, file, cb) => {
        const ext = path.extname(file.originalname).toLowerCase();
        cb(null, `${short.generate()}${ALLOWED_EXTENSIONS.includes(ext) ? ext : '.jpg'}`);
    },
});

const _upload = multer({
    storage: _storage,
    limits: { fileSize: tamaMaxFile * 1024 * 1024 },
    fileFilter: (req, file, cb) => {
        if (ALLOWED_EXTENSIONS.includes(path.extname(file.originalname).toLowerCase())) {
            cb(null, true);
        } else {
            cb(new Error('Only JPG or PNG files are allowed'));
        }
    },
});

function multerMiddleware(req, res, next) {
    _upload.single('file')(req, res, (err) => {
        if (err instanceof multer.MulterError) {
            if (err.code === 'LIMIT_FILE_SIZE') return res.sendStatus(413);
            return res.sendStatus(400);
        } else if (err) {
            return res.sendStatus(415);
        }
        next();
    });
}

function _cleanFile(req) {
    if (req.file?.path && fs.existsSync(req.file.path)) {
        fs.unlinkSync(req.file.path);
    }
}

// Valida los bytes mágicos (JPEG: FF D8 FF; PNG: firma de 8 bytes)
function _validateMagicBytes(filePath) {
    const ext = path.extname(filePath).toLowerCase();
    const fd = fs.openSync(filePath, 'r');
    try {
        if (ext === '.png') {
            const magic = Buffer.alloc(8);
            fs.readSync(fd, magic, 0, 8, 0);
            const pngSignature = Buffer.from([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
            return magic.equals(pngSignature);
        }
        const magic = Buffer.alloc(3);
        fs.readSync(fd, magic, 0, 3, 0);
        return magic[0] === 0xFF && magic[1] === 0xD8 && magic[2] === 0xFF;
    } finally {
        fs.closeSync(fd);
    }
}

// GET: listado anónimo de entradas para cualquier usuario autenticado.
// Nunca se expone el uid del autor; solo un indicador 'mine' para las
// entradas del propio solicitante y 'votedByMe' con su voto.
async function listEntries(req, res) {
    const start = Date.now();
    try {
        FirebaseAdmin.auth().verifyIdToken(getTokenAuth(req.headers.authorization))
            .then(async (dToken) => {
                const { uid } = dToken;
                const idFeature = shortId2Id(req.params.feature);
                if (idFeature === null) {
                    logHttp(req, 400, 'photoVoteList', start);
                    return res.sendStatus(400);
                }
                const doc = await getPhotoVotePlace(idFeature);
                const entries = doc !== null && Array.isArray(doc.entries) ? doc.entries : [];
                const out = entries.map((entry) => ({
                    entryId: entry.entryId,
                    file: entry.file,
                    creation: entry.creation,
                    votes: Array.isArray(entry.votes) ? entry.votes.length : 0,
                    votedByMe: Array.isArray(entry.votes) && entry.votes.includes(uid),
                    mine: entry.uid === uid,
                }));
                winston.info(Mustache.render('photoVoteList || {{{feature}}} - {{{n}}} || {{{time}}}', {
                    feature: idFeature,
                    n: out.length,
                    time: Date.now() - start,
                }));
                logHttp(req, 200, 'photoVoteList', start);
                res.send(JSON.stringify(out));
            })
            .catch(() => {
                logHttp(req, 401, 'photoVoteList', start);
                res.sendStatus(401);
            });
    } catch (error) {
        winston.error(Mustache.render('photoVoteList || {{{error}}} || {{{time}}}', {
            error: String(error),
            time: Date.now() - start,
        }));
        logHttp(req, 500, 'photoVoteList', start);
        res.sendStatus(500);
    }
}

// POST: sube una foto a la votación del lugar. Crea la entrada pública
// (anónima) y guarda además la respuesta privada del usuario con
// answerType 'photoVote', enlazadas mediante entryId.
async function uploadPhoto(req, res) {
    const start = Date.now();
    if (!req.file) {
        logHttp(req, 400, 'photoVoteUpload', start);
        return res.sendStatus(400);
    }
    try {
        FirebaseAdmin.auth().verifyIdToken(getTokenAuth(req.headers.authorization))
            .then(async (dToken) => {
                const { uid } = dToken;
                const idFeature = shortId2Id(req.params.feature);
                if (idFeature === null) {
                    _cleanFile(req);
                    logHttp(req, 400, 'photoVoteUpload', start);
                    return res.sendStatus(400);
                }
                if (!_validateMagicBytes(req.file.path)) {
                    _cleanFile(req);
                    logHttp(req, 415, 'photoVoteUpload', start);
                    return res.sendStatus(415);
                }
                const { idTask, answerMetadata, labelContainer, commentTask, idFeed } = req.body;
                if (!idTask || !answerMetadata || !labelContainer || !commentTask) {
                    _cleanFile(req);
                    logHttp(req, 400, 'photoVoteUpload', start);
                    return res.sendStatus(400);
                }
                let meta;
                try {
                    meta = JSON.parse(answerMetadata);
                } catch {
                    _cleanFile(req);
                    logHttp(req, 400, 'photoVoteUpload', start);
                    return res.sendStatus(400);
                }
                if (typeof meta.hasOptionalText !== 'boolean'
                    || typeof meta.finishClient !== 'number'
                    || typeof meta.time2Complete !== 'number') {
                    _cleanFile(req);
                    logHttp(req, 400, 'photoVoteUpload', start);
                    return res.sendStatus(400);
                }

                const fileName = path.basename(req.file.path);
                const entryId = short.generate();

                // (1) Entrada pública anónima; el uid solo queda en MongoDB
                // para moderación/propiedad y nunca se expone
                const entryOk = await addPhotoVoteEntry(idFeature, {
                    entryId: entryId,
                    uid: uid,
                    file: fileName,
                    creation: meta.finishClient,
                    votes: [],
                });
                if (!entryOk) {
                    _cleanFile(req);
                    logHttp(req, 500, 'photoVoteUpload', start);
                    return res.sendStatus(500);
                }

                // (2) Respuesta privada del usuario enlazada con la entrada
                const idAnswer = path.basename(fileName, path.extname(fileName));
                const answer2Server = {
                    hasOptionalText: meta.hasOptionalText,
                    finishClient: meta.finishClient,
                    time2Complete: meta.time2Complete,
                    labelContainer,
                    commentTask,
                    answerType: 'photoVote',
                    ...(typeof idFeed === 'string' && idFeed.trim() !== '' && { idFeed: idFeed.trim() }),
                    answer: {
                        entryId: entryId,
                        file: fileName,
                        originalName: req.file.originalname,
                        timestamp: meta.finishClient,
                    },
                };
                const r = await saveAnswer(uid, req.params.feature, idTask, idAnswer, answer2Server);
                if (r != null && r.acknowledged) {
                    winston.info(Mustache.render('photoVoteUpload || {{{entry}}} || {{{time}}}', {
                        entry: entryId,
                        time: Date.now() - start,
                    }));
                    logHttp(req, 201, 'photoVoteUpload', start);
                    res.location(`${urlServer}/users/user/answers/${idAnswer}`).sendStatus(201);
                } else {
                    _cleanFile(req);
                    logHttp(req, 409, 'photoVoteUpload', start);
                    res.sendStatus(409);
                }
            })
            .catch((error) => {
                _cleanFile(req);
                winston.info(Mustache.render('photoVoteUpload || {{{error}}} || {{{time}}}', {
                    error: String(error),
                    time: Date.now() - start,
                }));
                logHttp(req, 401, 'photoVoteUpload', start);
                res.sendStatus(401);
            });
    } catch (error) {
        _cleanFile(req);
        winston.error(Mustache.render('photoVoteUpload || {{{error}}} || {{{time}}}', {
            error: String(error),
            time: Date.now() - start,
        }));
        logHttp(req, 500, 'photoVoteUpload', start);
        res.sendStatus(500);
    }
}

// PUT: votar (vote=true) o retirar/cambiar el voto (vote=false). Un único
// voto por usuario autenticado y lugar, validado en servidor.
async function voteEntry(req, res) {
    const start = Date.now();
    try {
        FirebaseAdmin.auth().verifyIdToken(getTokenAuth(req.headers.authorization))
            .then(async (dToken) => {
                const { uid } = dToken;
                const idFeature = shortId2Id(req.params.feature);
                const entryId = req.params.entry;
                const { vote } = req.body;
                if (idFeature === null || typeof entryId !== 'string' || typeof vote !== 'boolean') {
                    logHttp(req, 400, 'photoVoteVote', start);
                    return res.sendStatus(400);
                }
                const doc = await getPhotoVotePlace(idFeature);
                const exists = doc !== null && Array.isArray(doc.entries)
                    && doc.entries.some(e => e.entryId === entryId);
                if (!exists) {
                    logHttp(req, 404, 'photoVoteVote', start);
                    return res.sendStatus(404);
                }
                const ok = await votePhotoVoteDB(idFeature, entryId, uid, vote);
                winston.info(Mustache.render('photoVoteVote || {{{entry}}} - {{{vote}}} || {{{time}}}', {
                    entry: entryId,
                    vote: vote,
                    time: Date.now() - start,
                }));
                logHttp(req, ok ? 204 : 500, 'photoVoteVote', start);
                res.sendStatus(ok ? 204 : 500);
            })
            .catch(() => {
                logHttp(req, 401, 'photoVoteVote', start);
                res.sendStatus(401);
            });
    } catch (error) {
        winston.error(Mustache.render('photoVoteVote || {{{error}}} || {{{time}}}', {
            error: String(error),
            time: Date.now() - start,
        }));
        logHttp(req, 500, 'photoVoteVote', start);
        res.sendStatus(500);
    }
}

// GET: sirve la imagen de una entrada a cualquier usuario autenticado
async function serveFile(req, res) {
    const start = Date.now();
    try {
        FirebaseAdmin.auth().verifyIdToken(getTokenAuth(req.headers.authorization))
            .then(async () => {
                const idFeature = shortId2Id(req.params.feature);
                const safeFileId = path.basename(req.params.fileId);
                if (idFeature === null || !FILE_ID_REGEX.test(safeFileId)) {
                    logHttp(req, 400, 'photoVoteFile', start);
                    return res.sendStatus(400);
                }
                // La imagen debe pertenecer a una entrada del lugar
                const doc = await getPhotoVotePlace(idFeature);
                const referenced = doc !== null && Array.isArray(doc.entries)
                    && doc.entries.some(e => e.file === safeFileId);
                if (!referenced) {
                    logHttp(req, 404, 'photoVoteFile', start);
                    return res.sendStatus(404);
                }
                const filePath = path.join(UPLOAD_DIR, safeFileId);
                if (!fs.existsSync(filePath)) {
                    logHttp(req, 404, 'photoVoteFile', start);
                    return res.sendStatus(404);
                }
                const ext = path.extname(safeFileId).toLowerCase();
                res.setHeader('Content-Type', ext === '.png' ? 'image/png' : 'image/jpeg');
                logHttp(req, 200, 'photoVoteFile', start);
                res.sendFile(filePath);
            })
            .catch(() => {
                logHttp(req, 401, 'photoVoteFile', start);
                res.sendStatus(401);
            });
    } catch (error) {
        winston.error(Mustache.render('photoVoteFile || {{{error}}} || {{{time}}}', {
            error: String(error),
            time: Date.now() - start,
        }));
        logHttp(req, 500, 'photoVoteFile', start);
        res.sendStatus(500);
    }
}

module.exports = {
    multerMiddleware,
    listEntries,
    uploadPhoto,
    voteEntry,
    serveFile,
};
