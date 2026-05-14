const path = require('path');
const fs = require('fs');
const { Buffer } = require('buffer');
const multer = require('multer');
const short = require('short-uuid');
const FirebaseAdmin = require('firebase-admin');
const Mustache = require('mustache');

const winston = require('../../../util/winston');
const { getTokenAuth, logHttp, shortId2Id } = require('../../../util/auxiliar');
const { saveAnswer, getAnswerByFile, getInfoUser, getFeedsUser, getInfoSubscriber } = require('../../../util/bd');
const { InfoUser, FeedsUser } = require('../../../util/pojos/user');
const { FeedSubscriber } = require('../../../util/pojos/feed');
const { urlServer, tamaMaxFile } = require('../../../util/config');

const UPLOAD_DIR = path.join(__dirname, '../../../uploads/pdfs');
if (!fs.existsSync(UPLOAD_DIR)) {
    fs.mkdirSync(UPLOAD_DIR, { recursive: true });
}

// IP-based rate limiter: max 5 uploads per minute per IP
const _rateLimitMap = new Map();
const _RL_WINDOW_MS = 60 * 1000;
const _RL_MAX = 5;

function rateLimit(req, res, next) {
    const ip = req.ip || req.socket?.remoteAddress || 'unknown';
    const now = Date.now();
    const entry = _rateLimitMap.get(ip);
    if (!entry || now > entry.resetTime) {
        _rateLimitMap.set(ip, { count: 1, resetTime: now + _RL_WINDOW_MS });
        return next();
    }
    if (entry.count >= _RL_MAX) {
        return res.sendStatus(429);
    }
    entry.count++;
    next();
}

const _storage = multer.diskStorage({
    destination: (req, file, cb) => cb(null, UPLOAD_DIR),
    filename: (req, file, cb) => cb(null, `${short.generate()}.pdf`),
});

// Only check extension here; magic bytes are checked in the handler
const _upload = multer({
    storage: _storage,
    limits: { fileSize: tamaMaxFile * 1024 * 1024 },
    fileFilter: (req, file, cb) => {
        if (path.extname(file.originalname).toLowerCase() === '.pdf') {
            cb(null, true);
        } else {
            cb(new Error('Only PDF files are allowed'));
        }
    },
});

function multerMiddleware(req, res, next) {
    winston.info(`multer-in || content-type: ${req.headers['content-type']} || content-length: ${req.headers['content-length']}`);
    _upload.single('file')(req, res, (err) => {
        winston.info(`multer-out || file=${!!req.file} || err=${err ? String(err) : 'none'}`);
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

async function uploadFile(req, res) {
    const start = Date.now();
    if (!req.file) {
        logHttp(req, 400, 'uploadFile', start);
        return res.sendStatus(400);
    }
    try {
        const token = getTokenAuth(req.headers.authorization);
        if (!token) {
            _cleanFile(req);
            logHttp(req, 401, 'uploadFile', start);
            return res.sendStatus(401);
        }

        FirebaseAdmin.auth().verifyIdToken(token)
            .then(async dToken => {
                const { uid } = dToken;
                if (!uid) {
                    _cleanFile(req);
                    logHttp(req, 403, 'uploadFile', start);
                    return res.sendStatus(403);
                }

                // Validate magic bytes (%PDF) and EOF marker (%%EOF)
                const fileSize = fs.statSync(req.file.path).size;
                const fd = fs.openSync(req.file.path, 'r');
                const magic = Buffer.alloc(4);
                fs.readSync(fd, magic, 0, 4, 0);
                const eofBuf = Buffer.alloc(Math.min(64, fileSize));
                fs.readSync(fd, eofBuf, 0, eofBuf.length, fileSize - eofBuf.length);
                fs.closeSync(fd);
                if (magic.toString('ascii') !== '%PDF') {
                    _cleanFile(req);
                    logHttp(req, 415, 'uploadFile', start);
                    return res.sendStatus(415);
                }
                if (!eofBuf.toString('latin1').includes('%%EOF')) {
                    _cleanFile(req);
                    logHttp(req, 422, 'uploadFile', start);
                    return res.sendStatus(422);
                }

                const { idContainer, idTask, answerMetadata, labelContainer, commentTask } = req.body;
                winston.info(`uploadFile-fields || idContainer=${!!idContainer} idTask=${!!idTask} answerMetadata=${!!answerMetadata} labelContainer=${!!labelContainer} commentTask=${!!commentTask}`);
                if (!idContainer || !idTask || !answerMetadata || !labelContainer || !commentTask) {
                    _cleanFile(req);
                    logHttp(req, 400, 'uploadFile', start);
                    return res.sendStatus(400);
                }

                let meta;
                try {
                    meta = JSON.parse(answerMetadata);
                } catch {
                    _cleanFile(req);
                    logHttp(req, 400, 'uploadFile', start);
                    return res.sendStatus(400);
                }

                if (typeof meta.hasOptionalText !== 'boolean'
                    || typeof meta.finishClient !== 'number'
                    || typeof meta.time2Complete !== 'number') {
                    _cleanFile(req);
                    logHttp(req, 400, 'uploadFile', start);
                    return res.sendStatus(400);
                }

                const fileName = path.basename(req.file.path);
                const idAnswer = path.basename(fileName, '.pdf');
                const answer2Server = {
                    hasOptionalText: meta.hasOptionalText,
                    finishClient: meta.finishClient,
                    time2Complete: meta.time2Complete,
                    labelContainer,
                    commentTask,
                    answerType: 'uploadFile',
                    answer: {
                        file: fileName,
                        originalName: req.file.originalname,
                        timestamp: meta.finishClient,
                    },
                };
                const r = await saveAnswer(uid, idContainer, idTask, idAnswer, answer2Server);
                if (r != null && r.acknowledged) {
                    winston.info(Mustache.render(
                        'uploadFile || {{{id}}} || {{{time}}}',
                        { id: idAnswer, time: Date.now() - start }
                    ));
                    logHttp(req, 201, 'uploadFile', start);
                    res.location(`${urlServer}/users/user/answers/${idAnswer}`).sendStatus(201);
                } else {
                    _cleanFile(req);
                    logHttp(req, 409, 'uploadFile', start);
                    res.sendStatus(409);
                }
            })
            .catch(error => {
                _cleanFile(req);
                winston.info(Mustache.render(
                    'uploadFile-catch || {{{error}}} || {{{time}}}',
                    { error: String(error), time: Date.now() - start }
                ));
                logHttp(req, 400, 'uploadFile', start);
                res.sendStatus(400);
            });
    } catch (error) {
        _cleanFile(req);
        winston.error(Mustache.render(
            'uploadFile || {{{error}}} || {{{time}}}',
            { error: String(error), time: Date.now() - start }
        ));
        logHttp(req, 500, 'uploadFile', start);
        res.sendStatus(500);
    }
}

async function downloadFile(req, res) {
    const start = Date.now();
    try {
        const token = getTokenAuth(req.headers.authorization);
        if (!token) {
            logHttp(req, 401, 'downloadFile', start);
            return res.sendStatus(401);
        }

        FirebaseAdmin.auth().verifyIdToken(token)
            .then(async dToken => {
                const { uid } = dToken;
                if (!uid) {
                    logHttp(req, 403, 'downloadFile', start);
                    return res.sendStatus(403);
                }

                // Sanitize: only allow UUID.pdf pattern
                const safeFileId = path.basename(req.params.fileId);
                if (!/^[A-Za-z0-9_-]+\.pdf$/.test(safeFileId)) {
                    logHttp(req, 400, 'downloadFile', start);
                    return res.sendStatus(400);
                }

                // Verify ownership
                const answer = await getAnswerByFile(uid, safeFileId);
                if (!answer) {
                    logHttp(req, 403, 'downloadFile', start);
                    return res.sendStatus(403);
                }

                const filePath = path.join(UPLOAD_DIR, safeFileId);
                if (!fs.existsSync(filePath)) {
                    logHttp(req, 404, 'downloadFile', start);
                    return res.sendStatus(404);
                }

                const originalName = answer.answer?.originalName || safeFileId;
                res.setHeader('Cache-Control', 'no-store, no-cache, must-revalidate');
                res.setHeader('Pragma', 'no-cache');
                res.setHeader('Content-Disposition', `attachment; filename="${encodeURIComponent(originalName)}"`);
                res.setHeader('Content-Type', 'application/pdf');
                logHttp(req, 200, 'downloadFile', start);
                res.sendFile(filePath, { cacheControl: false, etag: false, lastModified: false });
            })
            .catch(error => {
                winston.info(Mustache.render(
                    'downloadFile || {{{error}}} || {{{time}}}',
                    { error: String(error), time: Date.now() - start }
                ));
                logHttp(req, 400, 'downloadFile', start);
                res.sendStatus(400);
            });
    } catch (error) {
        winston.error(Mustache.render(
            'downloadFile || {{{error}}} || {{{time}}}',
            { error: String(error), time: Date.now() - start }
        ));
        logHttp(req, 500, 'downloadFile', start);
        res.sendStatus(500);
    }
}

async function downloadFileTeacher(req, res) {
    const start = Date.now();
    try {
        const token = getTokenAuth(req.headers.authorization);
        if (!token) {
            logHttp(req, 401, 'downloadFileTeacher', start);
            return res.sendStatus(401);
        }

        FirebaseAdmin.auth().verifyIdToken(token)
            .then(async dToken => {
                const { uid } = dToken;
                if (!uid) {
                    logHttp(req, 403, 'downloadFileTeacher', start);
                    return res.sendStatus(403);
                }

                let { feed, subscriber, fileId } = req.params;
                feed = shortId2Id(feed);
                if (!feed) {
                    logHttp(req, 400, 'downloadFileTeacher', start);
                    return res.sendStatus(400);
                }

                const safeFileId = path.basename(fileId);
                if (!/^[A-Za-z0-9_-]+\.pdf$/.test(safeFileId)) {
                    logHttp(req, 400, 'downloadFileTeacher', start);
                    return res.sendStatus(400);
                }

                let verifiedAnswer;

                if (uid === subscriber) {
                    // Estudiante accediendo a su propio fichero en contexto de canal
                    const feeds = new FeedsUser(await getFeedsUser(uid));
                    const feedEntry = feeds.subscribed.find(f => f.idFeed === feed);
                    if (!feedEntry) {
                        logHttp(req, 403, 'downloadFileTeacher', start);
                        return res.sendStatus(403);
                    }
                    const feedSubscriber = new FeedSubscriber(feedEntry);
                    verifiedAnswer = await getAnswerByFile(uid, safeFileId);
                    if (!verifiedAnswer || !feedSubscriber.answers?.includes(verifiedAnswer.id)) {
                        logHttp(req, 403, 'downloadFileTeacher', start);
                        return res.sendStatus(403);
                    }
                } else {
                    // Profesor propietario del canal accediendo al fichero de un estudiante
                    const teacher = new InfoUser(await getInfoUser(uid));
                    if (!teacher.isTeacher) {
                        logHttp(req, 401, 'downloadFileTeacher', start);
                        return res.sendStatus(401);
                    }
                    const feedsUser = new FeedsUser(await getFeedsUser(uid));
                    const feedEntry = feedsUser.owner.find(f => f.id === feed);
                    if (!feedEntry || !feedEntry.subscribers.includes(subscriber)) {
                        logHttp(req, 401, 'downloadFileTeacher', start);
                        return res.sendStatus(401);
                    }
                    const infoSub = await getInfoSubscriber(subscriber, feed, false);
                    verifiedAnswer = await getAnswerByFile(subscriber, safeFileId);
                    if (!verifiedAnswer || !infoSub?.answers?.includes(verifiedAnswer.id)) {
                        logHttp(req, 403, 'downloadFileTeacher', start);
                        return res.sendStatus(403);
                    }
                }

                if (!verifiedAnswer) {
                    logHttp(req, 404, 'downloadFileTeacher', start);
                    return res.sendStatus(404);
                }

                const filePath = path.join(UPLOAD_DIR, safeFileId);
                if (!fs.existsSync(filePath)) {
                    logHttp(req, 404, 'downloadFileTeacher', start);
                    return res.sendStatus(404);
                }

                const originalName = verifiedAnswer.answer?.originalName || safeFileId;
                res.setHeader('Cache-Control', 'no-store, no-cache, must-revalidate');
                res.setHeader('Pragma', 'no-cache');
                res.setHeader('Content-Disposition', `attachment; filename="${encodeURIComponent(originalName)}"`);
                res.setHeader('Content-Type', 'application/pdf');
                winston.info(Mustache.render(
                    'downloadFileTeacher || {{{uid}}} -> {{{sub}}} || {{{time}}}',
                    { uid, sub: subscriber, time: Date.now() - start }
                ));
                logHttp(req, 200, 'downloadFileTeacher', start);
                res.sendFile(filePath, { cacheControl: false, etag: false, lastModified: false });
            })
            .catch(error => {
                winston.info(Mustache.render(
                    'downloadFileTeacher || {{{error}}} || {{{time}}}',
                    { error: String(error), time: Date.now() - start }
                ));
                logHttp(req, 400, 'downloadFileTeacher', start);
                res.sendStatus(400);
            });
    } catch (error) {
        winston.error(Mustache.render(
            'downloadFileTeacher || {{{error}}} || {{{time}}}',
            { error: String(error), time: Date.now() - start }
        ));
        logHttp(req, 500, 'downloadFileTeacher', start);
        res.sendStatus(500);
    }
}

module.exports = { multerMiddleware, rateLimit, uploadFile, downloadFile, downloadFileTeacher };
