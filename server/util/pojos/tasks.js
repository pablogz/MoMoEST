class Task {
    constructor(dataTask) {
        if (dataTask.id !== undefined && typeof dataTask.id === 'string') {
            this._id = dataTask.id;
        } else {
            Error('Task id');
        }
        if (dataTask.author !== undefined && typeof dataTask.author === 'string') {
            this._author = dataTask.author;
        } else {
            Error('Task author');
        }
        if (dataTask.idContainer !== undefined) {
            this._idContainer = dataTask.idContainer;
        } else {
            Error('Task idContainer');
        }
        if (dataTask.label !== undefined) {
            this._label = dataTask.label;
        } else {
            Error('Task label');
        }
        if (dataTask.comment !== undefined) {
            this._comment = dataTask.comment;
        } else {
            Error('Task comment');
        }
        if (dataTask.typeContainer !== undefined) {
            this._typeContainer = dataTask.typeContainer;
        } else {
            Error('Task typeContainer');
        }
        if (dataTask.aT !== undefined) {
            this._aT = dataTask.aT;
        } else {
            Error('Task aT');
        }
        if (dataTask.inSpace !== undefined) {
            this._inSpace = dataTask.inSpace;
        } else {
            Error('Task inSpace');
        }
        switch (dataTask.aT) {
            case 'mcq':
                if (dataTask.correct) {
                    this._correct = dataTask.correct;
                }
                if (dataTask.distractors) {
                    this._distractors = dataTask.distractors;
                }
                if (dataTask.singleSelection) {
                    this._singleSelection = dataTask.singleSelection;
                }
                break;
            case 'tf':
                if (dataTask.correct) {
                    this._correct = dataTask.correct;
                }
                this._distractors = [];
                this._singleSelection = null;
                break;
            default:
                this._correct = [];
                this._distractors = [];
                this._singleSelection = null;
                break;
        }
        if (dataTask.image !== undefined) {
            this._image = dataTask.image;
        } else {
            this._image = null;
        }
    }
    get id() { return this._id; }
    set id(id) {
        if (id !== undefined && typeof id === 'string') {
            this._id = id;
        } else {
            Error('Task id');
        }
    }
    get author() { return this._author; }
    set author(author) {
        if (author !== undefined && typeof author === 'string') {
            this._author = author;
        } else {
            Error('Task author');
        }
    }
    get idContainer() { return this._idContainer; }
    set idContainer(idContainer) {
        if (idContainer !== undefined) {
            this._idContainer = idContainer;
        } else {
            Error('Task idContainer');
        }
    }
    get label() { return this._label; }
    set label(label) {
        if (label !== undefined) {
            this._label = label;
        } else {
            Error('Task label');
        }
    }
    get comment() { return this._comment; }
    set comment(comment) {
        if (comment !== undefined) {
            this._comment = comment;
        } else {
            Error('Task comment');
        }
    }
    get typeContainer() { return this._typeContainer; }
    set typeContainer(typeContainer) {
        if (typeContainer !== undefined) {
            this._typeContainer = typeContainer;
        } else {
            Error('Task typeContainer');
        }
    }
    get type() { return this._aT; }
    set type(type) {
        if (type !== undefined) {
            this._aT = type;
        } else {
            Error('Task type');
        }
    }
    get inSpace() { return this._inSpace; }
    set inSpace(inSpace) {
        if (inSpace !== undefined) {
            this._inSpace = inSpace;
        } else {
            Error('Task inSpace');
        }
    }
    get correct() { return this._correct.length > 0 ? this._correct : null; }
    set correct(correct) {
        this._correct = correct;
    }
    get distractors() { return this._distractors.length > 0 ? this.distractors : null; }
    set distractors(distractors) {
        this._distractors = distractors;
    }
    get singleSelection() { return this._singleSelection; }
    set singleSelection(singleSelection) {
        this._singleSelection = singleSelection;
    }
    get image() { return this._image; }
    set image(image) {
        this._image = image;
    }


    static toMap(task) {
        const out = {};
        out.id = task.id;
        out.author = task.author;
        out.idContainer = task.idContainer;
        out.label = task.label;
        out.comment = task.comment;
        out.typeContainer = task.typeContainer;
        out.aT = task.type;
        out.inSpace = task.inSpace;
        if (task.correct !== null && (task.correct.length > 0 || typeof correct === 'boolean')) {
            out.correct = task.correct;
        }
        if (task.distractors !== null && task.distractors.length > 0) {
            out.distractors = task.distractors;
        }
        if (task.singleSelection !== null) {
            out.singleSelection = task.singleSelection;
        }
        if (task.image !== null) {
            out.image = task.image;
        }
        return out;
    }
}

module.exports = {
    Task,
}