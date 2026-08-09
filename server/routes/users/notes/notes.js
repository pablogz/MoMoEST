const path = require('path');
const fs = require('fs');
const short = require('short-uuid');
const FirebaseAdmin = require('firebase-admin');
const Mustache = require('mustache');

const winston = require('../../../util/winston');
const { getTokenAuth, logHttp } = require('../../../util/auxiliar');
const { getNotesDB, addNoteDB, updateNoteDB, deleteNoteDB } = require('../../../util/bd');
const { Note, notesSize } = require('../../../util/pojos/note');
const { urlServer, mbNotes } = require('../../../util/config');
const {
    UPLOAD_DIR, MAX_DRAWING_MB, FILE_ID_REGEX,
    isValidPng, cleanUploaded, deleteDrawingFile,
} = require('./files');

// Espacio total que puede ocupar un usuario con sus notas
const NOTES_QUOTA = mbNotes * 1024 * 1024;

/**
 * Construye la nota a partir del cuerpo de la petición. Admite JSON y
 * multipart: si viene un fichero pasa a ser el dibujo de la nota; si no, el
 * campo `drawing` indica si se conserva ('keep') o se quita ('remove') el que
 * ya tuviera. [current] es la nota tal y como está guardada, al editar.
 */
function _parseNoteBody(req, id, current) {
    const body = req.body || {};
    const now = Date.now();
    const data = {
        id: id,
        title: body.title,
        text: body.text,
        idPlace: body.idPlace,
        labelPlace: body.labelPlace,
        creation: current !== undefined ? current.creation : now,
        lastUpdate: now,
    };
    if (req.file) {
        data.drawingFile = path.basename(req.file.path);
        data.drawingSize = req.file.size;
    } else if (current !== undefined && body.drawing !== 'remove') {
        // Sin fichero nuevo se mantiene el dibujo anterior, sea fichero o el
        // base64 heredado de las notas creadas antes de este cambio
        data.drawingFile = current.drawingFile;
        data.drawingSize = current.drawingSize;
        data.drawing = current.drawing;
    }
    const note = new Note(data);
    if (note.isEmpty) {
        throw new Error('Empty note');
    }
    return note;
}

/** Fichero de dibujo que deja de usarse tras guardar la nota, si lo hay. */
function _obsoleteFile(current, note) {
    if (current === undefined || typeof current.drawingFile !== 'string') {
        return undefined;
    }
    return current.drawingFile !== note.drawingFile ? current.drawingFile : undefined;
}

async function getNotes(req, res) {
    const start = Date.now();
    try {
        FirebaseAdmin.auth().verifyIdToken(getTokenAuth(req.headers.authorization))
            .then(async (dToken) => {
                const { uid } = dToken;
                const notes = await getNotesDB(uid);
                if (notes === null) {
                    logHttp(req, 500, 'getNotes', start);
                    return res.sendStatus(500);
                }
                winston.info(Mustache.render('getNotes || {{{n}}} || {{{time}}}', {
                    n: notes.length,
                    time: Date.now() - start,
                }));
                logHttp(req, 200, 'getNotes', start);
                // Sin cabeceras de caché el navegador aplica caché heurística
                // (no hay ETag, está desactivado en app.js) y la recarga tras
                // crear o borrar una nota devolvería la lista anterior.
                res.setHeader('Cache-Control', 'no-store, no-cache, must-revalidate');
                res.setHeader('Pragma', 'no-cache');
                res.send(JSON.stringify({
                    notes: notes,
                    usage: {
                        used: notesSize(notes),
                        quota: NOTES_QUOTA,
                        maxDrawing: MAX_DRAWING_MB * 1024 * 1024,
                    },
                }));
            })
            .catch(() => {
                logHttp(req, 401, 'getNotes', start);
                res.sendStatus(401);
            });
    } catch (error) {
        winston.error(Mustache.render('getNotes || {{{error}}} || {{{time}}}', {
            error: String(error),
            time: Date.now() - start,
        }));
        logHttp(req, 500, 'getNotes', start);
        res.sendStatus(500);
    }
}

async function newNote(req, res) {
    const start = Date.now();
    try {
        FirebaseAdmin.auth().verifyIdToken(getTokenAuth(req.headers.authorization))
            .then(async (dToken) => {
                const { uid } = dToken;
                if (req.file && !isValidPng(req.file.path)) {
                    cleanUploaded(req);
                    logHttp(req, 415, 'newNote', start);
                    return res.sendStatus(415);
                }
                let note;
                try {
                    note = _parseNoteBody(req, short.generate());
                } catch {
                    cleanUploaded(req);
                    logHttp(req, 400, 'newNote', start);
                    return res.sendStatus(400);
                }
                // Cuota: lo que ya ocupa el usuario más lo que añade esta nota
                const notes = await getNotesDB(uid);
                const used = notesSize(notes);
                if (used + note.size > NOTES_QUOTA) {
                    cleanUploaded(req);
                    logHttp(req, 413, 'newNote', start);
                    return res.status(413).json({
                        error: 'quotaExceeded',
                        used: used,
                        quota: NOTES_QUOTA,
                        size: note.size,
                    });
                }
                const ok = await addNoteDB(uid, note.toMap());
                if (ok) {
                    winston.info(Mustache.render('newNote || {{{id}}} || {{{time}}}', {
                        id: note.id,
                        time: Date.now() - start,
                    }));
                    logHttp(req, 201, 'newNote', start);
                    res.location(`${urlServer}/users/user/notes/${note.id}`).sendStatus(201);
                } else {
                    cleanUploaded(req);
                    logHttp(req, 500, 'newNote', start);
                    res.sendStatus(500);
                }
            })
            .catch(() => {
                cleanUploaded(req);
                logHttp(req, 401, 'newNote', start);
                res.sendStatus(401);
            });
    } catch (error) {
        cleanUploaded(req);
        winston.error(Mustache.render('newNote || {{{error}}} || {{{time}}}', {
            error: String(error),
            time: Date.now() - start,
        }));
        logHttp(req, 500, 'newNote', start);
        res.sendStatus(500);
    }
}

async function editNote(req, res) {
    const start = Date.now();
    try {
        FirebaseAdmin.auth().verifyIdToken(getTokenAuth(req.headers.authorization))
            .then(async (dToken) => {
                const { uid } = dToken;
                const noteId = req.params.note;
                const notes = await getNotesDB(uid);
                const current = Array.isArray(notes) ? notes.find(n => n.id === noteId) : undefined;
                if (current === undefined) {
                    cleanUploaded(req);
                    logHttp(req, 404, 'editNote', start);
                    return res.sendStatus(404);
                }
                if (req.file && !isValidPng(req.file.path)) {
                    cleanUploaded(req);
                    logHttp(req, 415, 'editNote', start);
                    return res.sendStatus(415);
                }
                let note;
                try {
                    note = _parseNoteBody(req, noteId, current);
                } catch {
                    cleanUploaded(req);
                    logHttp(req, 400, 'editNote', start);
                    return res.sendStatus(400);
                }
                // Cuota: se descuenta lo que ocupaba la nota antes de editarla
                const used = notesSize(notes);
                const previous = new Note(current).size;
                if (used - previous + note.size > NOTES_QUOTA) {
                    cleanUploaded(req);
                    logHttp(req, 413, 'editNote', start);
                    return res.status(413).json({
                        error: 'quotaExceeded',
                        used: used - previous,
                        quota: NOTES_QUOTA,
                        size: note.size,
                    });
                }
                const ok = await updateNoteDB(uid, note.toMap());
                if (ok) {
                    // El dibujo anterior ya no se referencia desde ninguna nota
                    deleteDrawingFile(_obsoleteFile(current, note));
                } else {
                    cleanUploaded(req);
                }
                winston.info(Mustache.render('editNote || {{{id}}} || {{{time}}}', {
                    id: noteId,
                    time: Date.now() - start,
                }));
                logHttp(req, ok ? 204 : 500, 'editNote', start);
                res.sendStatus(ok ? 204 : 500);
            })
            .catch(() => {
                cleanUploaded(req);
                logHttp(req, 401, 'editNote', start);
                res.sendStatus(401);
            });
    } catch (error) {
        cleanUploaded(req);
        winston.error(Mustache.render('editNote || {{{error}}} || {{{time}}}', {
            error: String(error),
            time: Date.now() - start,
        }));
        logHttp(req, 500, 'editNote', start);
        res.sendStatus(500);
    }
}

async function deleteNote(req, res) {
    const start = Date.now();
    try {
        FirebaseAdmin.auth().verifyIdToken(getTokenAuth(req.headers.authorization))
            .then(async (dToken) => {
                const { uid } = dToken;
                const noteId = req.params.note;
                const notes = await getNotesDB(uid);
                const current = Array.isArray(notes) ? notes.find(n => n.id === noteId) : undefined;
                const ok = await deleteNoteDB(uid, noteId);
                if (ok && current !== undefined) {
                    // Al borrar la nota se libera también su dibujo
                    deleteDrawingFile(current.drawingFile);
                }
                winston.info(Mustache.render('deleteNote || {{{id}}} || {{{time}}}', {
                    id: noteId,
                    time: Date.now() - start,
                }));
                logHttp(req, ok ? 204 : 404, 'deleteNote', start);
                res.sendStatus(ok ? 204 : 404);
            })
            .catch(() => {
                logHttp(req, 401, 'deleteNote', start);
                res.sendStatus(401);
            });
    } catch (error) {
        winston.error(Mustache.render('deleteNote || {{{error}}} || {{{time}}}', {
            error: String(error),
            time: Date.now() - start,
        }));
        logHttp(req, 500, 'deleteNote', start);
        res.sendStatus(500);
    }
}

/** Sirve el dibujo de una nota, solo a quien la tiene guardada. */
async function downloadNoteFile(req, res) {
    const start = Date.now();
    try {
        FirebaseAdmin.auth().verifyIdToken(getTokenAuth(req.headers.authorization))
            .then(async (dToken) => {
                const { uid } = dToken;
                const safeFileId = path.basename(req.params.fileId);
                if (!FILE_ID_REGEX.test(safeFileId)) {
                    logHttp(req, 400, 'downloadNoteFile', start);
                    return res.sendStatus(400);
                }
                const notes = await getNotesDB(uid);
                const owned = Array.isArray(notes)
                    && notes.some(n => n.drawingFile === safeFileId);
                if (!owned) {
                    logHttp(req, 403, 'downloadNoteFile', start);
                    return res.sendStatus(403);
                }
                const filePath = path.join(UPLOAD_DIR, safeFileId);
                if (!fs.existsSync(filePath)) {
                    logHttp(req, 404, 'downloadNoteFile', start);
                    return res.sendStatus(404);
                }
                res.setHeader('Cache-Control', 'no-store, no-cache, must-revalidate');
                res.setHeader('Pragma', 'no-cache');
                res.setHeader('Content-Type', 'image/png');
                logHttp(req, 200, 'downloadNoteFile', start);
                res.sendFile(filePath, { cacheControl: false, etag: false, lastModified: false });
            })
            .catch(() => {
                logHttp(req, 401, 'downloadNoteFile', start);
                res.sendStatus(401);
            });
    } catch (error) {
        winston.error(Mustache.render('downloadNoteFile || {{{error}}} || {{{time}}}', {
            error: String(error),
            time: Date.now() - start,
        }));
        logHttp(req, 500, 'downloadNoteFile', start);
        res.sendStatus(500);
    }
}

module.exports = {
    getNotes,
    newNote,
    editNote,
    deleteNote,
    downloadNoteFile,
    NOTES_QUOTA,
}
