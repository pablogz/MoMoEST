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

module.exports = { FeatureLocalRepo, TaskLocalRepo };

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