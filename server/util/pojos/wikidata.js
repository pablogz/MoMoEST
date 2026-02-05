const { getArcStyle4Wikidata } = require('../auxiliar.js');

class FeatureWikidata {
    constructor(shortId, wdR) {
        this._id = `http://www.wikidata.org/entity/${shortId.split('wd:')[1]}`;
        this._shortId = shortId;
        this._labels = [];
        if (wdR.label !== undefined) {
            if (!Array.isArray(wdR.label)) {
                wdR.label = [wdR.label];
            }
            wdR.label.forEach((pL) => {
                this._labels.push({
                    lang: pL.lang,
                    value: `${pL.value.charAt(0).toUpperCase()}${pL.value.slice(1)}`
                });
            });
        }
        this._descriptions = [];
        if (wdR.description !== undefined) {
            if (!Array.isArray(wdR.description)) {
                wdR.description = [wdR.description];
            }
            wdR.description.forEach((pL) => {
                try {
                    this._descriptions.push({
                        lang: pL.lang,
                        value: `${pL.value.charAt(0).toUpperCase()}${pL.value.slice(1)}`
                    });
                } catch (error) {
                    console.log(error);
                }
            });
        }
        this._images = [];
        if (wdR.image !== undefined) {
            if (typeof wdR.image === 'string') {
                wdR.image = [wdR.image];
            }
            wdR.image.forEach(i => {
                if (typeof i === 'string') {
                    if (i.includes("Special:FilePath/")) {
                        this._images.push({ f: i.replace('http://', 'https://'), l: i.replace("Special:FilePath/", "File:").replace('http://', 'https://') });
                    } else {
                        if(i.includes('commons.wikimedia.org/wiki/File:')) {
                            this._images.push( {f: i.replace('http://', 'https://').replace('commons.wikimedia.org/wiki/File:', 'commons.wikimedia.org/wiki/Special:FilePath/'), l: i.replace('http://', 'https://')} );
                        } else {
                            this._images.push({ f: i.replace('http://', 'https://'), });
                        }
                    }
                }
            });
        }
        if (wdR.arcStyle !== undefined) {
            this._arcStyle = wdR.arcStyle;
        }
        if (wdR.bicJCyL !== undefined) {
            this._bicJCyL = wdR.bicJCyL;
        }
        if (wdR.type !== undefined) {
            if (!Array.isArray(wdR.type)) {
                wdR.type = [wdR.type];
            }
            this._type = wdR.type;
        }
        if (wdR.inception !== undefined) {
            this._inception = wdR.inception;
        }
        if (wdR.osm !== undefined) {
            this._osm = wdR.osm;
        }
        if (wdR.point !== undefined) {
            if(Array.isArray(wdR.point)){
                wdR.point = wdR.point[0];
            }
            // this._point = wdR.point;
            this._lat = parseFloat(wdR.point.split(' ')[1].split(')')[0]);
            this._long = parseFloat(wdR.point.split(' ')[0].split('(')[1]);
        }
    }

    get id() { return this._id; }
    get shortId() { return this._shortId; }
    get labels() { return this._labels; }
    get descriptions() { return this._descriptions; }
    get images() { return this._images; }
    get arcStyle() { return this._arcStyle; }
    get bicJCyL() { return this._bicJCyL; }
    get type() { return this._type; }
    get inception() { return this._inception; }
    get osm() { return this._osm; }
    get lat() { return this._lat; }
    get long() { return this._long; }

    async initialize() {
        if (this.arcStyle !== undefined) {
            let arcStyleC = await getArcStyle4Wikidata();
            let listaActualizada = false;
            if (!Array.isArray(this.arcStyle)) {
                this._arcStyle = [this.arcStyle];
            }
            const styles = [];
            this._arcStyle.forEach(async (s) => {
                let style = arcStyleC.find((e) => e.id === s);
                if (style !== undefined) {
                    styles.push(style);
                } else {
                    if (!listaActualizada) {
                        arcStyleC = await getArcStyle4Wikidata();
                        listaActualizada = true;
                        style = arcStyleC.find((e) => e.id === s);
                        if (style !== undefined) {
                            styles.push(style);
                        } else {
                            styles.push({ id: s });
                        }
                    }
                }
            });
            this._arcStyle = styles;
        }
    }

    toCHESTFeature() {
        return {
            id: this.id,
            shortId: this.shortId,
            label: this.labels,
            description: this.descriptions,
            image: this.images,
            arcStyle: this.arcStyle,
            bicJCyL: this.bicJCyL,
            type: this.type,
            inception: this.inception,
            osm: this.osm,
            lat: this.lat,
            long: this.long,
        };
    }
}

module.exports = {
    FeatureWikidata,
}