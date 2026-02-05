class FeatureDBpedia {
    constructor(id, data) {
        this._id = id;
        this._shortId = id.includes('http://es') ? `esdbpedia:${id.split('/').pop()}` : `dbpedia:${id.split('/').pop()}`;
        this._type = Array.isArray(data.type) ? data.type : [data.type];
        this._comment = Array.isArray(data.comment) ? data.comment : [data.comment];
        if (data.label !== undefined) {
            this._label = Array.isArray(data.label) ? data.label : [data.label];
        }
    }

    get id() { return this._id; }
    get shortId() { return this._shortId; }
    get type() { return this._type; }
    get comment() { return this._comment; }
    get label() { return this._label; }

    toCHESTFeature() {
        return {
            id: this.id,
            shortId: this.shortId,
            type: this.type,
            comment: this.comment,
            label: this.label,
        };
    }
}

module.exports = { FeatureDBpedia, };