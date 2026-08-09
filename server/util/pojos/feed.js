class Feed {
    constructor(data) {
        if (data !== null && typeof data === 'object') {
            this._id = data.id !== undefined && typeof data.id === 'string' ? data.id : null;
            // this._feeder = data.feeder !== undefined && Array.isArray(data.feeder) ? data.feeder : null;
            this._labels = data.labels !== undefined && Array.isArray(data.labels) ? data.labels : [];
            this._comments = data.comments !== undefined && Array.isArray(data.comments) ? data.comments : [];
            this._subscribers = data.subscribers !== undefined && Array.isArray(data.subscribers) ? data.subscribers : [];
            this._teachers = data.teachers !== undefined && Array.isArray(data.teachers)
                ? data.teachers.map(t => typeof t === 'string' ? { uid: t, alias: t } : t)
                : [];
            this._password = data.password !== undefined && typeof data.password === 'string' ? data.password : null;
            this._date = data.date !== undefined && typeof data.date === 'string' ? data.date : null;
            this._owner = data.owner !== undefined && typeof data.owner === 'string' ? data.owner : null;
            // Si es verdadero, el nombre y los apellidos son obligatorios al
            // apuntarse al canal. Solo los ve el profesorado (MongoDB).
            this._requireFullName = data.requireFullName === true;
        } else {
            throw new Error("Data is not an object");
        }
    }

    get id() { return this._id; }
    get labels() { return this._labels; }
    get comments() { return this._comments; }
    get subscribers() { return this._subscribers; }
    get teachers() { return this._teachers; }
    get password() { return this._password; }
    get date() { return this._date; }
    get owner() { return this._owner; }
    get requireFullName() { return this._requireFullName; }
    set requireFullName(v) { this._requireFullName = v === true; }

    setLabels(labels) {
        this._labels = Array.isArray(labels) ? labels : null;
    }

    addLabel(label) {
        this._labels.push(label);
    }

    setComments(comments) {
        this._comments = Array.isArray(comments) ? comments : null;
    }

    addComment(comment) {
        this._comments.push(comment);
    }

    addSubscriber(subscriber) {
        if (typeof subscriber === 'string') {
            const index = this._subscribers.indexOf(subscriber);
            if (index == -1) {
                this._subscribers.push(subscriber);
            }
        }
    }

    removeSubscriber(subscriber) {
        if (typeof subscriber === 'string') {
            this._subscribers = this._subscribers.filter(ele => ele.id != subscriber);
        }
    }

    addTeacher(uid, alias) {
        if (typeof uid === 'string' && !this._teachers.some(t => t.uid === uid)) {
            this._teachers.push({ uid, alias: alias || uid });
        }
    }

    removeTeacher(uid) {
        if (typeof uid === 'string') {
            this._teachers = this._teachers.filter(t => t.uid !== uid);
        }
    }

    setPassword(password) {
        this._password = typeof password === 'string' ? password : null;
    }

    setOwnwer(owner) {
        this._owner = typeof owner === 'string' ? owner : null;
    }

    toMap() {
        return {
            id: this._id,
            labels: this._labels,
            comments: this._comments,
            owner: this._owner,
            password: this._password === null ? undefined : this._password,
            subscribers: this._subscribers,
            teachers: this._teachers,
            date: this._date,
            requireFullName: this._requireFullName,
        }
    }

    toSubscriber() {
        return {
            id: this._id,
            labels: this._labels,
            comments: this._comments,
            requireFullName: this._requireFullName,
        }
    }
}

class FeedSubscriber {
    constructor(data) {
        if (data !== null && typeof data === 'object') {
            this._idFeed = data.idFeed !== undefined && typeof data.idFeed === 'string' ? data.idFeed : null;
            this._idOwner = data.idOwner !== undefined && typeof data.idOwner === 'string' ? data.idOwner : null;
            this._date = data.date !== undefined && typeof data.date === 'string' ? data.date : (new Date.now()).toISOString();
            this._answers = data.answers !== undefined && Array.isArray(data.answers) ? data.answers : [];
            // Nombre y apellidos que el estudiante da para este canal. Solo se
            // guardan en MongoDB y solo los ve el profesorado del canal.
            this._name = typeof data.name === 'string' && data.name.trim() !== '' ? data.name.trim() : undefined;
            this._surname = typeof data.surname === 'string' && data.surname.trim() !== '' ? data.surname.trim() : undefined;
        } else {
            Error('Data is not an object');
        }
    }

    get idFeed() { return this._idFeed }
    set idFeed(v) {
        this._idFeed = v !== undefined && typeof v === 'string' ? v : this._idFeed;
    }

    get idOwner() { return this._idOwner }
    set idOwner(v) {
        this._idOwner = v !== undefined && typeof v === 'string' ? v : this._idOwner;
    }

    get date() { return this._date }
    set date(v) {
        this._date = v !== undefined && typeof v === 'string' ? v : this._date;
    }

    get answers() { return this._answers }
    set answers(v) {
        this._answers = v !== undefined && Array.isArray(v) ? v : this._answers;
    }

    get name() { return this._name }
    set name(v) {
        this._name = typeof v === 'string' && v.trim() !== '' ? v.trim() : this._name;
    }

    get surname() { return this._surname }
    set surname(v) {
        this._surname = typeof v === 'string' && v.trim() !== '' ? v.trim() : this._surname;
    }
}

module.exports = {
    Feed,
    FeedSubscriber,
}