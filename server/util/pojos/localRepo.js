const {id2ShortId} = require('../auxiliar');

/**
 * Represents a feature in the local repository.
 * @class
 */
class FeatureLocalRepo {
    /**
     * Creates a new FeatureLocalRepo instance.
     * @constructor
     * @param {Object} feature - The feature object.
     * @param {string} feature.feature - The feature ID.
     * @param {number} feature.lat - The feature latitude.
     * @param {number} feature.lng - The feature longitude.
     * @param {string[]} feature.label - The feature labels.
     * @param {string} feature.comment - The feature comments.
     * @param {string} feature.author - The feature author.
     */
    constructor(feature) {
        this._id = feature.feature;
        this._shortId = id2ShortId(feature.feature);
        this._lat = feature.lat;
        this._long = feature.lng;
        this._labels = feature.label;
        this._comments = feature.comment;
        this._author = feature.author;
        if (typeof feature.type === 'string') {
            feature.type = [feature.type];
        }
        this._type = [];
        if (Array.isArray(feature.type)){
            feature['type'].forEach((ele) => {
                if(typeof ele === 'string') {
                    this._type.push(id2ShortId(ele));
                }
            });
        }
    }

    /**
     * Gets the feature ID.
     * @type {string}
     */
    get id() { return this._id; }

    /**
     * Gets the feature ID.
     * @type {string}
     */
    get shortId() { return this._shortId; }

    /**
     * Gets the feature latitude.
     * @type {number}
     */
    get lat() { return this._lat; }

    /**
     * Gets the feature longitude.
     * @type {number}
     */
    get long() { return this._long; }

    /**
     * Gets the feature labels.
     * @type {Object[]}
     */
    get labels() { return this._labels; }

    /**
     * Gets the feature comments.
     * @type {Object[]}
     */
    get comments() { return this._comments; }

    /**
     * Gets the feature author.
     * @type {string}
     */
    get author() { return this._author; }

    get type() { return this._type; }

    /**
     * Converts the feature to a CHEST map object.
     * @returns {Object} The CHEST map object.
     */
    toChestMap() {
        return {
            id: this.id,
            shortId: this.shortId,
            type: this.type,
            lat: this.lat,
            long: this.long,
            provider: 'localRepo',
            labels: this.labels,
            comments: this.comments,
            author: this.author,
            license: 'CHEST contributors'
        };
    }

    toCHESTFeature() {
        return {
            id: this.id,
            shortId: this.shortId,
            type: this.type,
            lat: this.lat,
            long: this.long,
            provider: 'localRepo',
            labels: this.labels,
            comments: this.comments,
            author: this.author,
            license: 'CHEST contributors'
        };
    }
}

class TaskLocalRepo {
    constructor(task) {
        this._id = task.task;
        this._type = task.type;
        this._comments = task.comment;
        this._labels = task.label;
        this._author = task.author;
        switch (task.type) {
            case 'tf':
                // Get correct answer
                break;
            case 'mcq':
                // Get distractions and correct answer
                break;
            default:
                break;
        }
    }
}

class FeatureLocalDocomomo {
    constructor(feature) {
        this._id = feature.feature;
        this._shortId = id2ShortId(feature.feature);
        this._lat = feature.lat;
        this._long = feature.lng;
        this._labels = feature.label;
        if (typeof feature.type === 'string') {
            feature.type = [feature.type];
        }
        this._type = [];
        if (Array.isArray(feature.type)){
            feature['type'].forEach((ele) => {
                if(typeof ele === 'string') {
                    this._type.push(id2ShortId(ele));
                }
            });
        }
        if (typeof feature.links === 'string') {
            feature.links = [feature.links];
        }
        if (Array.isArray(feature.links)) {
            feature['links'].forEach((ele) => {
                if(typeof ele === 'string') {
                    const shortId = id2ShortId(ele);
                    if(shortId !== null) {
                        switch (shortId.split(':').at(0)) {
                            case 'wd':
                                this._wd = shortId;
                                break;
                            case 'osmn':
                            case 'osmr':
                            case 'osmw':
                                this._osm = shortId;
                                break;
                            default:
                                break;
                        }
                    }
                }
            });
        }
    }

    get id() { return this._id; }
    get shortId() { return this._shortId; }
    get lat() { return this._lat; }
    get long() { return this._long; }
    get labels() { return this._labels; }
    get type() { return this._type; }
    get wd() { return this._wd; }
    get osm() { return this._osm; }

    toChestMap() {
        return {
            id: this.id,
            shortId: this.shortId,
            type: this.type,
            lat: this.lat,
            long: this.long,
            provider: 'docomomo',
            labels: this.labels,
            license: 'Fundación Docomomo Ibérico',
        }
    }
}

class FeatureDocomomoFull {
    constructor(feature, media, architects) {
        this._id = feature.feature;
        this._shortId = id2ShortId(feature.feature);
        this._lat = feature.lat;
        this._long = feature.lng;
        this._labels = Array.isArray(feature.label) ? feature.label : (feature.label != null ? [feature.label] : []);
        this._comments = Array.isArray(feature.comment) ? feature.comment : (feature.comment != null ? [feature.comment] : []);
        this._startDate = feature.startDate;
        this._endDate = feature.endDate;
        this._seeAlso = Array.isArray(feature.seeAlso) ? feature.seeAlso : (feature.seeAlso != null ? [feature.seeAlso] : []);
        this._thumb = feature.thumb;
        if (typeof feature.type === 'string') {
            feature.type = [feature.type];
        }
        this._type = [];
        if (Array.isArray(feature.type)) {
            feature.type.forEach(ele => {
                if (typeof ele === 'string') {
                    this._type.push(id2ShortId(ele) || ele);
                }
            });
        }
        this._media = media || [];
        this._architects = architects || [];
    }

    get id() { return this._id; }
    get shortId() { return this._shortId; }
    get lat() { return this._lat; }
    get long() { return this._long; }
    get labels() { return this._labels; }
    get comments() { return this._comments; }
    get type() { return this._type; }
    get startDate() { return this._startDate; }
    get endDate() { return this._endDate; }
    get seeAlso() { return this._seeAlso; }
    get thumb() { return this._thumb; }
    get media() { return this._media; }
    get architects() { return this._architects; }

    toCHESTFeature() {
        return {
            id: this.id,
            shortId: this.shortId,
            type: this.type,
            lat: this.lat,
            long: this.long,
            provider: 'docomomo',
            labels: this.labels,
            comments: this.comments,
            startDate: this.startDate,
            endDate: this.endDate,
            seeAlso: this.seeAlso,
            thumb: this.thumb,
            media: this.media,
            architects: this.architects,
            license: 'Fundación Docomomo Ibérico',
        };
    }
}

module.exports = { FeatureLocalRepo, TaskLocalRepo, FeatureLocalDocomomo, FeatureDocomomoFull };

// delete data {
//     graph <http://chest.gsic.uva.es> {
//     <prueba>
//          a cho:Feature ;
//          geo:lat 41.652 ;
//          geo:long  -4.723;
//          rdfs:label "prueba"@es, "test"@en ;
//          rdfs:comment "comentario de prueba"@es, "test comment"@en ;
//          dc:creator <yo> .
//     }
//     }