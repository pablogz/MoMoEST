const path = require('path');
const fs = require('fs');
const { Buffer } = require('buffer');
const multer = require('multer');
const short = require('short-uuid');
const FirebaseAdmin = require('firebase-admin');
const Mustache = require('mustache');

const winston = require('../../util/winston');
const { getTokenAuth, logHttp, shortId2Id } = require('../../util/auxiliar');
const {
    getPhotoVotePlace, addPhotoVoteEntry, votePhotoVoteDB, saveAnswer,
    deletePhotoVoteEntryDB, getAnswerByEntry, hideAnswerDB,
} = require('../../util/bd');
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

// Borra del disco la fotografía de una entrada
function _deleteFile(fileName) {
    try {
        if (typeof fileName !== 'string') return;
        const safeFileId = path.basename(fileName);
        if (!FILE_ID_REGEX.test(safeFileId)) return;
        const filePath = path.join(UPLOAD_DIR, safeFileId);
        if (fs.existsSync(filePath)) {
            fs.unlinkSync(filePath);
        }
    } catch (error) {
        winston.error('photoVoteDeleteFile:', error);
    }
}

// Las tareas llegan unas veces con el identificador corto ('md:…') y otras con
// el IRI completo, según la pantalla desde la que se pida
function _fullId(value) {
    if (typeof value !== 'string' || value.trim() === '') return null;
    const id = value.trim();
    return shortId2Id(id) ?? id;
}

/**
 * Retira una fotografía de la votación pública: borra la entrada (con lo que
 * desaparecen todos sus votos) y el fichero del disco. Con [uid] se comprueba
 * además que quien borra es su autor. Se usa tanto al borrar la foto desde la
 * votación como al borrar la respuesta desde "Mis respuestas", para que no
 * queden fotografías sin respuesta ni respuestas apuntando a ficheros que ya
 * no existen. Solo toca MongoDB y el disco: nada llega al triple-store LOD.
 */
async function removeEntry(idFeature, entryId, uid) {
    const doc = await getPhotoVotePlace(idFeature);
    const entry = doc !== null && Array.isArray(doc.entries)
        ? doc.entries.find(e => e.entryId === entryId)
        : undefined;
    if (entry === undefined) {
        winston.info(Mustache.render('removeEntry || notFound || {{{feature}}} || {{{entry}}}', {
            feature: idFeature,
            entry: entryId,
        }));
        return 'notFound';
    }
    if (uid !== undefined && entry.uid !== uid) {
        winston.info(Mustache.render('removeEntry || forbidden || {{{entry}}}', { entry: entryId }));
        return 'forbidden';
    }
    if (!await deletePhotoVoteEntryDB(idFeature, entryId)) {
        winston.error(Mustache.render('removeEntry || error || {{{entry}}}', { entry: entryId }));
        return 'error';
    }
    _deleteFile(entry.file);
    // La respuesta privada de quien la subió deja de mostrarse, para que el
    // borrado sea simétrico también cuando lo hace otra persona (por ejemplo
    // al borrar el profesorado la tarea)
    await _hideLinkedAnswer(entry.uid, entryId);
    winston.info(Mustache.render('removeEntry || ok || {{{entry}}} || {{{file}}}', {
        entry: entryId,
        file: entry.file,
    }));
    return 'ok';
}

/** Oculta la respuesta privada enlazada con una entrada de la votación. */
async function _hideLinkedAnswer(uid, entryId) {
    if (typeof uid !== 'string' || uid === '') return;
    try {
        const answer = await getAnswerByEntry(uid, entryId);
        if (answer !== null) {
            await hideAnswerDB(uid, answer.id);
        }
    } catch (error) {
        winston.error('photoVoteHideLinkedAnswer:', error);
    }
}

/**
 * Retira todas las fotografías de una tarea de votación. Se usa cuando el
 * profesorado borra la tarea: sin esto quedarían fotografías públicas de una
 * tarea que ya no existe y a las que nadie podría llegar para borrarlas.
 */
async function removeEntriesOfTask(idFeature, idTask) {
    let removed = 0;
    try {
        const task = _fullId(idTask);
        const doc = await getPhotoVotePlace(idFeature);
        const entries = doc !== null && Array.isArray(doc.entries)
            ? doc.entries.filter(e => e.idTask === task)
            : [];
        for (const entry of entries) {
            if (await removeEntry(idFeature, entry.entryId) === 'ok') {
                removed += 1;
            }
        }
        if (entries.length > 0) {
            winston.info(Mustache.render('removeEntriesOfTask || {{{task}}} || {{{removed}}}/{{{total}}}', {
                task: task,
                removed: removed,
                total: entries.length,
            }));
        }
    } catch (error) {
        winston.error('removeEntriesOfTask:', error);
    }
    return removed;
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
// Con ?task=<idTarea> se devuelven solo las fotografías de esa tarea, ya que
// un mismo lugar puede tener varias tareas de votación.
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
                const idTask = _fullId(req.query.task);
                const doc = await getPhotoVotePlace(idFeature);
                const all = doc !== null && Array.isArray(doc.entries) ? doc.entries : [];
                const entries = idTask === null
                    ? all
                    : all.filter(entry => entry.idTask === idTask);
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
                // Sin cabeceras de caché el navegador puede seguir enseñando
                // una fotografía ya retirada de la votación
                res.setHeader('Cache-Control', 'no-store, no-cache, must-revalidate');
                res.setHeader('Pragma', 'no-cache');
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

                // Una fotografía por persona y tarea. Sin esta comprobación una
                // segunda subida dejaría la anterior pública y sin forma de
                // llegar a ella para retirarla, porque "Mis respuestas" agrupa
                // por lugar y tarea y solo enseña la más reciente.
                const task = _fullId(idTask);
                const doc = await getPhotoVotePlace(idFeature);
                const yaParticipa = doc !== null && Array.isArray(doc.entries)
                    && doc.entries.some(e => e.uid === uid && e.idTask === task);
                if (yaParticipa) {
                    _cleanFile(req);
                    winston.info(Mustache.render('photoVoteUpload || yaParticipa || {{{task}}}', { task: task }));
                    logHttp(req, 409, 'photoVoteUpload', start);
                    return res.status(409).json({ error: 'alreadyParticipated' });
                }

                const fileName = path.basename(req.file.path);
                const entryId = short.generate();

                // (1) Entrada pública anónima; el uid solo queda en MongoDB
                // para moderación/propiedad y nunca se expone
                const entryOk = await addPhotoVoteEntry(idFeature, {
                    entryId: entryId,
                    uid: uid,
                    // La tarea a la que pertenece la foto: un lugar puede tener
                    // varias votaciones y cada una es independiente
                    ...(task !== null && { idTask: task }),
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
                    // Fallo al guardar la respuesta, no un conflicto: el 409 se
                    // reserva para quien ya participó en esta votación
                    _cleanFile(req);
                    logHttp(req, 500, 'photoVoteUpload', start);
                    res.sendStatus(500);
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
// voto por usuario autenticado y tarea, validado en servidor. La tarea se
// toma de la propia entrada, no de la petición.
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
                const entry = doc !== null && Array.isArray(doc.entries)
                    ? doc.entries.find(e => e.entryId === entryId)
                    : undefined;
                if (entry === undefined) {
                    logHttp(req, 404, 'photoVoteVote', start);
                    return res.sendStatus(404);
                }
                const ok = await votePhotoVoteDB(idFeature, entry.idTask, entryId, uid, vote);
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

// DELETE: retira de la votación una fotografía propia. Se borra la entrada
// (con todos sus votos), el fichero y se oculta la respuesta asociada, para
// que el borrado sea simétrico y no queden recursos ni respuestas sueltas.
async function deleteEntry(req, res) {
    const start = Date.now();
    // La autenticación se resuelve aparte del resto: si no, cualquier error del
    // borrado acabaría contestando un 401 y ocultando la causa real
    let uid;
    try {
        ({ uid } = await FirebaseAdmin.auth().verifyIdToken(getTokenAuth(req.headers.authorization)));
    } catch {
        logHttp(req, 401, 'photoVoteDelete', start);
        return res.sendStatus(401);
    }
    try {
        const idFeature = shortId2Id(req.params.feature);
        const entryId = req.params.entry;
        if (idFeature === null || typeof entryId !== 'string' || entryId === '') {
            logHttp(req, 400, 'photoVoteDelete', start);
            return res.sendStatus(400);
        }
        // removeEntry se encarga de la entrada, del fichero y de ocultar la
        // respuesta privada enlazada
        const result = await removeEntry(idFeature, entryId, uid);
        if (result !== 'ok') {
            const status = result === 'notFound' ? 404 : result === 'forbidden' ? 403 : 500;
            logHttp(req, status, 'photoVoteDelete', start);
            return res.sendStatus(status);
        }
        winston.info(Mustache.render('photoVoteDelete || {{{entry}}} || {{{time}}}', {
            entry: entryId,
            time: Date.now() - start,
        }));
        logHttp(req, 204, 'photoVoteDelete', start);
        res.sendStatus(204);
    } catch (error) {
        winston.error(Mustache.render('photoVoteDelete || {{{error}}} || {{{stack}}} || {{{time}}}', {
            error: String(error),
            stack: error?.stack ?? '',
            time: Date.now() - start,
        }));
        logHttp(req, 500, 'photoVoteDelete', start);
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
    deleteEntry,
    serveFile,
    removeEntry,
    removeEntriesOfTask,
};
