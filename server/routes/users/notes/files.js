// Gestión de los ficheros de dibujo de las notas privadas. Sigue el mismo
// patrón que routes/users/answers/files.js: multer sobre disco, validación de
// bytes mágicos y servido autenticado comprobando la propiedad del fichero.
// Los dibujos ya no viajan en base64 dentro del documento de MongoDB, así que
// las notas dejan de estar limitadas por el máximo de 16 MB por documento.
const path = require('path');
const fs = require('fs');
const { Buffer } = require('buffer');
const multer = require('multer');
const short = require('short-uuid');

const winston = require('../../../util/winston');

const UPLOAD_DIR = path.join(__dirname, '../../../uploads/notes');
if (!fs.existsSync(UPLOAD_DIR)) {
    fs.mkdirSync(UPLOAD_DIR, { recursive: true });
}

// Tamaño máximo de un único dibujo (MB). Un dibujo sobre una fotografía del
// lugar ronda 1 MB; este techo deja margen sin permitir subidas desmedidas.
const MAX_DRAWING_MB = 5;

const ALLOWED_EXTENSIONS = ['.png'];
const FILE_ID_REGEX = /^[A-Za-z0-9_-]+\.png$/;

const _storage = multer.diskStorage({
    destination: (req, file, cb) => cb(null, UPLOAD_DIR),
    filename: (req, file, cb) => cb(null, `${short.generate()}.png`),
});

const _upload = multer({
    storage: _storage,
    limits: { fileSize: MAX_DRAWING_MB * 1024 * 1024 },
    fileFilter: (req, file, cb) => {
        if (ALLOWED_EXTENSIONS.includes(path.extname(file.originalname).toLowerCase())) {
            cb(null, true);
        } else {
            cb(new Error('Only PNG files are allowed'));
        }
    },
});

/**
 * Procesa el cuerpo de la petición. Si no es multipart multer llama a next()
 * sin tocar nada, así que la misma ruta admite JSON (nota sin dibujo nuevo) y
 * multipart (nota con dibujo).
 */
function multerMiddleware(req, res, next) {
    _upload.single('file')(req, res, (err) => {
        if (err instanceof multer.MulterError) {
            if (err.code === 'LIMIT_FILE_SIZE') {
                return res.status(413).json({ error: 'drawingTooBig', maxDrawing: MAX_DRAWING_MB * 1024 * 1024 });
            }
            return res.sendStatus(400);
        } else if (err) {
            return res.sendStatus(415);
        }
        next();
    });
}

/** Comprueba la firma PNG del fichero recibido. */
function isValidPng(filePath) {
    let fd;
    try {
        fd = fs.openSync(filePath, 'r');
        const magic = Buffer.alloc(8);
        fs.readSync(fd, magic, 0, 8, 0);
        return magic.equals(Buffer.from([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]));
    } catch (error) {
        winston.error('isValidPng:', error);
        return false;
    } finally {
        if (fd !== undefined) {
            fs.closeSync(fd);
        }
    }
}

/** Borra el fichero recién subido cuando la petición no puede completarse. */
function cleanUploaded(req) {
    if (req.file?.path && fs.existsSync(req.file.path)) {
        try {
            fs.unlinkSync(req.file.path);
        } catch (error) {
            winston.error('cleanUploaded:', error);
        }
    }
}

/** Borra el fichero de dibujo de una nota que ya no lo necesita. */
function deleteDrawingFile(fileName) {
    if (typeof fileName !== 'string' || !FILE_ID_REGEX.test(path.basename(fileName))) {
        return;
    }
    const filePath = path.join(UPLOAD_DIR, path.basename(fileName));
    try {
        if (fs.existsSync(filePath)) {
            fs.unlinkSync(filePath);
        }
    } catch (error) {
        winston.error('deleteDrawingFile:', error);
    }
}

function fileSize(fileName) {
    try {
        return fs.statSync(path.join(UPLOAD_DIR, path.basename(fileName))).size;
    } catch {
        return 0;
    }
}

module.exports = {
    UPLOAD_DIR,
    MAX_DRAWING_MB,
    FILE_ID_REGEX,
    multerMiddleware,
    isValidPng,
    cleanUploaded,
    deleteDrawingFile,
    fileSize,
};
