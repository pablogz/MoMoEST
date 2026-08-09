// Nota privada de un usuario. Vive únicamente en MongoDB (documento 'notes'
// de la colección del usuario); nunca se envía al triple-store LOD.
//
// El dibujo se guarda como fichero en disco (drawingFile) y en el documento
// solo queda su nombre y su tamaño en bytes, para no agotar el límite de 16 MB
// por documento de MongoDB y poder calcular la cuota sin tocar el disco.
// El campo drawing (PNG en base64) se mantiene únicamente para poder seguir
// leyendo las notas creadas antes de este cambio.
class Note {
    constructor(data) {
        if (data === null || typeof data !== 'object') {
            throw new Error('No valid data for create Note');
        }

        if (data.id !== undefined && typeof data.id === 'string' && data.id.trim() !== '') {
            this._id = data.id.trim();
        } else {
            throw new Error('Note id');
        }

        this._title = typeof data.title === 'string' && data.title.trim() !== '' ? data.title.trim() : undefined;
        this._text = typeof data.text === 'string' && data.text.trim() !== '' ? data.text.trim() : undefined;
        // Dibujo guardado como fichero
        this._drawingFile = typeof data.drawingFile === 'string' && data.drawingFile.trim() !== '' ? data.drawingFile.trim() : undefined;
        this._drawingSize = typeof data.drawingSize === 'number' && data.drawingSize > 0 ? data.drawingSize : undefined;
        // Dibujo heredado: PNG en base64 dentro del propio documento
        this._drawing = typeof data.drawing === 'string' && data.drawing !== '' ? data.drawing : undefined;
        // Vínculo opcional con un lugar
        this._idPlace = typeof data.idPlace === 'string' && data.idPlace.trim() !== '' ? data.idPlace.trim() : undefined;
        this._labelPlace = typeof data.labelPlace === 'string' && data.labelPlace.trim() !== '' ? data.labelPlace.trim() : undefined;

        this._creation = typeof data.creation === 'number' ? data.creation : Date.now();
        this._lastUpdate = typeof data.lastUpdate === 'number' ? data.lastUpdate : this._creation;
    }

    get id() { return this._id; }
    get title() { return this._title; }
    get text() { return this._text; }
    get drawingFile() { return this._drawingFile; }
    get drawingSize() { return this._drawingSize; }
    get drawing() { return this._drawing; }
    get idPlace() { return this._idPlace; }
    get labelPlace() { return this._labelPlace; }
    get creation() { return this._creation; }
    get lastUpdate() { return this._lastUpdate; }

    get hasDrawing() {
        return this._drawingFile !== undefined || this._drawing !== undefined;
    }

    get isEmpty() {
        return this._title === undefined && this._text === undefined && !this.hasDrawing;
    }

    /**
     * Bytes que ocupa la nota de cara a la cuota del usuario: el fichero del
     * dibujo (o el base64 heredado) más el texto guardado en el documento.
     */
    get size() {
        let size = 0;
        if (this._drawingSize !== undefined) {
            size += this._drawingSize;
        } else if (this._drawing !== undefined) {
            size += Buffer.byteLength(this._drawing, 'utf8');
        }
        if (this._title !== undefined) {
            size += Buffer.byteLength(this._title, 'utf8');
        }
        if (this._text !== undefined) {
            size += Buffer.byteLength(this._text, 'utf8');
        }
        return size;
    }

    toMap() {
        return {
            id: this._id,
            ...(this._title !== undefined && { title: this._title }),
            ...(this._text !== undefined && { text: this._text }),
            ...(this._drawingFile !== undefined && { drawingFile: this._drawingFile }),
            ...(this._drawingSize !== undefined && { drawingSize: this._drawingSize }),
            ...(this._drawing !== undefined && { drawing: this._drawing }),
            ...(this._idPlace !== undefined && { idPlace: this._idPlace }),
            ...(this._labelPlace !== undefined && { labelPlace: this._labelPlace }),
            creation: this._creation,
            lastUpdate: this._lastUpdate,
        };
    }
}

/**
 * Tamaño total en bytes que ocupan las notas de un usuario.
 * @param {Array} notes documentos de nota tal y como están en MongoDB
 */
function notesSize(notes) {
    if (!Array.isArray(notes)) {
        return 0;
    }
    return notes.reduce((total, note) => {
        try {
            return total + new Note(note).size;
        } catch {
            return total;
        }
    }, 0);
}

module.exports = { Note, notesSize };
