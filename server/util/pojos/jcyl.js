class FeatureJCyL {
    constructor(shortId, jCyL) {
        this._shortId = shortId;
        this._id = `http://chest.gsic.uva.es/data/${shortId.split('chd:')[1]}`;
        this._url = jCyL.url;
        this._label = jCyL.label;
        this._altLabel = jCyL.altLabel;
        this._comment = jCyL.comment;
        this._category = jCyL.category;
        this._categoryLabel = jCyL.categoryLabel;
        this._lat = jCyL.lat;
        this._long = jCyL.long;
        this._license = jCyL.license;
    }

    get id() { return this._id; }
    get shortId() { return this._shortId; }
    get url() { return this._url; }
    get label() { return this._label; }
    get altLabel() { return this._altLabel; }
    get comment() { return this._comment; }
    get category() { return this._category; }
    get categoryLabel() { return this._categoryLabel; }
    get lat() { return this._lat; }
    get long() { return this._long; }
    get license() { return this._license; }

    toCHESTFeature() {
        return {
            id: this.id,
            shortId: this.shortId,
            url: this.url,
            label: this.label,
            altLabel: this.altLabel,
            comment: this.comment,
            category: this.category,
            categoryLabel: this.categoryLabel,
            lat: this.lat,
            long: this.long,
            license: this.license
        };
    }
}
module.exports = { FeatureJCyL, };