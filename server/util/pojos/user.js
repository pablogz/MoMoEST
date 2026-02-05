const { Feed, FeedSubscriber } = require("./feed");

class InfoUser {
    constructor(data) {
        if (data == null || typeof data !== 'object') {
            Error('No valid data for create InfoUser')
        }

        if (data.id !== undefined && typeof data.id === 'string') {
            this._id = data.id;
        } else { Error('InfoUser id'); }

        if (data.rol !== undefined) {
            if (typeof data.rol === 'string') { data.rol = [data.rol]; }
            if (Array.isArray(data.rol)) {
                this._rol = data.rol;
                if (this._rol.includes('TEACHER')) {
                    if (data.confTeacherLOD !== undefined && typeof data.confTeacherLOD === 'string') {
                        this._confTeacherLOD = data.confTeacherLOD;
                    } else {
                        Error('Confirmation Teacher LOD date');
                    }
                    if (data.code !== undefined && typeof data.code === 'string') {
                        this._code = data.code;
                    } else {
                        Error('Teacher code');
                    }
                }
            } else { Error('InfoUser rol'); }
        } else { Error('InfoUser rol'); }

        if (data.alias !== undefined && typeof data.alias === 'string') {
            this._alias = data.alias;
            if (data.confAliasLOD !== undefined && typeof data.confAliasLOD === 'string') {
                this._confAliasLOD = data.confAliasLOD;
            } else { Error('Confirmation Alias LOD date'); }
        }

        if (data.creation !== undefined && typeof data.creation === 'string') {
            this._creation = data.creation;
        } else { Error('InfoUser creation date'); }

        if (data.lastUpdate !== undefined && typeof data.lastUpdate === 'string') {
            this._lastUpdate = data.lastUpdate;
        }

        if (data.lpv !== undefined && typeof data.lpv === 'object' && data.lpv.lat !== undefined && typeof data.lpv.lat === 'number' && data.lpv.long !== undefined && typeof data.lpv.long === 'number' && data.lpv.zoom !== undefined && typeof data.lpv.zoom === 'number') {
            this._lpv = data.lpv;
        }

        if (data.defaultMap !== undefined && typeof data.defaultMap === 'string') {
            this._defaultMap = data.defaultMap;
        }

        // if (data.feeder !== undefined && Array.isArray(data.feeder)) {
        //     this._feeder = data.feeder;
        // }

        // if (data.subscriptor !== undefined && Array.isArray(data.subscriptor)) {
        //     this._subscriptor = data.subscriptor;
        // }
    }

    get id() { return this._id; }
    set id(id) {
        if (id !== undefined && typeof id === 'string') {
            this._id = id;
        } else { Error('InfoUser id'); }
    }

    get roles() { return this._rol; }
    set roles(roles) {
        if (roles !== undefined && Array.isArray(roles)) {
            this._rol = roles;
        } else { Error('InfoUser rol'); }
    }

    addRol(rol) {
        if (!this._rol.includes(rol)) {
            this._rol.push(rol);
        }
    }

    removeRol(rol) {
        const index = this._rol.indexOf(rol);
        if (index > -1) {
            this._rol.splice(index, 1);
        }
    }

    get confTeacherLOD() {
        return this._rol.contains('TEACHER') ? this._confTeacherLOD : undefined;
    }
    set confTeacherLOD(confTeacherLOD) {
        if (confTeacherLOD !== undefined && typeof confTeacherLOD === 'string') {
            this._confTeacherLOD = confTeacherLOD;
        } else { Error('Confirmation Teacher LOD date'); }
    }

    get code() {
        return this._rol.contains('TEACHER') ? this._code : undefined;
    }
    set code(code) {
        if (code !== undefined && typeof code === 'string') {
            this._code = code;
        } else { Error('Teacher code'); }
    }

    get alias() { return this._alias; }
    set alias(alias) {
        if (alias !== undefined && typeof alias === 'string') {
            this._alias = alias;
        } else { Error('User alias'); }
    }

    get confAliasLOD() {
        return this._alias !== undefined ? this._confAliasLOD : undefined;
    }
    set confAliasLOD(date) {
        if (date !== undefined && typeof date === 'string') {
            this._confAliasLOD = date;
        } else { Error('Confirmation alias LOD date'); }
    }

    get lpv() { return this._lpv; }
    set lpv(lpv) {
        if (lpv !== undefined && typeof lpv === 'object' && lpv.lat !== undefined && typeof lpv.lat === 'number' && lpv.long !== undefined && typeof lpv.long === 'number' && lpv.zoom !== undefined && typeof lpv.zoom === 'number') {
            this._lpv = lpv;
        } else { Error('InfoUser lpv'); }
    }

    get defaultMap() { return this._defaultMap; }
    set defaultMap(defaultMap) {
        if (defaultMap !== undefined && typeof defaultMap === 'string') {
            this._defaultMap = defaultMap;
        }
    }

    get isTeacher() {return this._rol.includes('TEACHER'); }

    // get feeder() { return this._feeder; }
    // set feeder(feeder) {
    //     if (feeder !== undefined && Array.isArray(feeder)) {
    //         this._feeder = feeder;
    //     }
    // }

    // get subscriptor() { return this._subscriptor; }
    // set subscriptor(subscriptor) {
    //     if (subscriptor !== undefined && Array.isArray(subscriptor)) {
    //         this._subscriptor = subscriptor;
    //     }
    // }
}

class FeedsUser {
    constructor(data) {
        if (data === null || typeof data !== 'object') {
            this._subcribed = [];
            this._owner = [];
        } else {
            this._subcribed = data.subscribed !== undefined && Array.isArray(data.subscribed) ? data.subscribed : [];
            this._owner = data.owner !== undefined && Array.isArray(data.owner) ? data.owner : [];
        }
    }

    get owner() { return this._owner; }
    get subscribed() { return this._subcribed; }

    addOwnFeed(feed) {
        if(typeof feed === Feed) {
            this._owner.push(feed);
        }
    }
    
    removeOwnFeed(idFeed) {
        const index = this._owner.findIndex((feed) => {
            feed.id == idFeed;
        });
        if(index > -1) {
            this._owner.splice(index, 1);
        }
    }

    addSubcription(feedSubscriber) {
        if(typeof feedSubscriber === FeedSubscriber) {
            this._subcribed = feedSubscriber;
        }
    }
}

module.exports = { InfoUser, FeedsUser, }