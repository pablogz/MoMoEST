const Mustache = require('mustache');

class ElementOSM {
    constructor(element) {
        this._type = element.type;
        this._id = `https://www.openstreetmap.org/${element.type}/${element.id}`;
        let bounds;
        switch (element.type) {
            case 'node':
                this._shortId = `osmn:${element.id}`;
                this._lat = element.lat;
                this._long = element.lon;
                break;
            case 'way':
                this._shortId = `osmw:${element.id}`;
                bounds = element.bounds;
                this._lat = (bounds.maxlat + bounds.minlat) / 2;
                this._long = (bounds.maxlon + bounds.minlon) / 2;
                this._geometry = element.geometry;
                break;
            case 'relation':
                this._shortId = `osmr:${element.id}`;
                bounds = element.bounds;
                this._lat = (bounds.maxlat + bounds.minlat) / 2;
                this._long = (bounds.maxlon + bounds.minlon) / 2;
                this._members = element.members;
                break;
            default:
                throw Error('Element\'s type undefined');
        }
        this._name = element.tags.name;

        this._author = element.user != undefined ? `OSM - ${element.user}` : 'OSM';

        const tags = element.tags;
        this._tags = tags;
        const labels = [];
        const descriptions = [];
        this._a = [];
        for (const key in tags) {
            switch (key) {
                case 'wikipedia':
                    if (tags.wikipedia.split(":").length > 1) {
                        this._wikipedia = Mustache.render(
                            'https://{{{lang}}}.wikipedia.org/wiki/{{{value}}}',
                            {
                                lang: tags.wikipedia.split(":")[0],
                                value: tags.wikipedia.split(":")[1].replace(/\s+/g, '_')
                            }
                        );
                    } else {
                        this._wikipedia = 'https://wikipedia.org/wiki/' + tags.wikipedia.replace(/\s+/g, '_');
                    }

                    if (this._wikipedia !== undefined) {
                        this._dbpedia = wikipedia2dbpedia(this._wikipedia);
                    }
                    break;
                case 'wikidata':
                    this._wikidata = "wd:" + tags.wikidata;
                    break;
                case 'image':
                    if (tags.image.includes('commons.wikimedia.org/wiki/File:')) {
                        tags.image = tags.image.replace('commons.wikimedia.org/wiki/File:', 'commons.wikimedia.org/wiki/Special:FilePath/');
                    }
                    break;
                case 'heritage':
                    if (tags.heritage === 'cathedral' && !this._a.includes('mo:Cathedral')) {
                        this._a.push('mo:Cathedral');
                    }
                    if (tags.heritage === 'castle' && !this._a.includes('mo:Castle')) {
                            this._a.push('mo:Castle');
                    }
                    if (tags.heritage === 'church' && !this._a.includes('mo:Church')) {
                        this._a.push('mo:Church');
                    }
                    if ((tags.heritage === 'chapel' || tags.heritage === 'mosque') && !this._a.includes('mo:PlaceOfWorship')) {
                        this._a.push('mo:PlaceOfWorship')
                    }
                    if (tags.heritage === 'palace' && !this._a.includes('mo:Palace')) {
                        this._a.push('mo:Palace');
                    }
                    if (tags.heritage === 'tower' && !this._a.includes('mo:Tower')) {
                        this._a.push('mo:Tower');
                    }
                    if (tags.heritage === 'museum' && !this._a.includes('mo:Museum')) {
                        this._a.push('mo:Museum');
                    }
                    if (tags.heritage === 'fountain' && !this._a.includes('mo:Fountain')) {
                        this._a.push('mo:Fountain');
                    }
                    if (tags.heritage === 'square' && !this._a.includes('mo:Square')) {
                            this._a.push('mo:Square');
                    }
                    break;
                case 'historic':
                    if (tags.historic === 'cathedral' && !this._a.includes('mo:Cathedral')) {
                        this._a.push('mo:Cathedral');
                    }
                    if (tags.historic === 'castle' && !this._a.includes('mo:Castle')) {
                            this._a.push('mo:Castle');
                    }
                    if (tags.historic === 'church' && !this._a.includes('mo:Church')) {
                        this._a.push('mo:Church');
                    }
                    if ((tags.historic === 'chapel' || tags.historic === 'mosque') && !this._a.includes('mo:PlaceOfWorship')) {
                        this._a.push('mo:PlaceOfWorship')
                    }
                    if (tags.historic === 'palace' && !this._a.includes('mo:Palace')) {
                        this._a.push('mo:Palace');
                    }
                    if (tags.historic === 'tower' && !this._a.includes('mo:Tower')) {
                        this._a.push('mo:Tower');
                    }
                    if (tags.historic === 'museum' && !this._a.includes('mo:Museum')) {
                        this._a.push('mo:Museum');
                    }
                    if (tags.historic === 'fountain' && !this._a.includes('mo:Fountain')) {
                        this._a.push('mo:Fountain');
                    }
                    if (tags.historic === 'square' && !this._a.includes('mo:Square')) {
                            this._a.push('mo:Square');
                    }
                    break;
                case 'building':
                    if (tags.building === 'cathedral' && !this._a.includes('mo:Cathedral')) {
                        this._a.push('mo:Cathedral');
                    }
                    if (tags.building === 'castle' && !this._a.includes('mo:Castle')) {
                            this._a.push('mo:Castle');
                    }
                    if (tags.building === 'church' && !this._a.includes('mo:Church')) {
                        this._a.push('mo:Church');
                    }
                    if ((tags.building === 'chapel' || tags.building === 'mosque') && !this._a.includes('mo:PlaceOfWorship')) {
                        this._a.push('mo:PlaceOfWorship')
                    }
                    if (tags.building === 'palace' && !this._a.includes('mo:Palace')) {
                        this._a.push('mo:Palace');
                    }
                    if (tags.building === 'tower' && !this._a.includes('mo:Tower')) {
                        this._a.push('mo:Tower');
                    }
                    if ((tags.building === 'museum' || tags.building === '2') && !this._a.includes('mo:Museum')) {
                        this._a.push('mo:Museum');
                    }
                    if (tags.building === 'fountain' && !this._a.includes('mo:Fountain')) {
                        this._a.push('mo:Fountain');
                    }
                    if (tags.building === 'square' && !this._a.includes('mo:Square')) {
                            this._a.push('mo:Square');
                    }
                    break;
                case 'museum':
                    if (!this._a.includes('mo:Museum')) {
                        this._a.push('mo:Museum');
                    }
                    break;
                case 'amenity':
                    if ((tags.amenity === 'place_of_worship' || tags.amenity === 'monastery') && !this._a.includes('mo:PlaceOfWorship')) {
                        this._a.push('mo:PlaceOfWorship');
                    }
                    if (tags.amenity === 'fountain' && !this._a.includes('mo:Fountain')) {
                        this._a.push('mo:Fountain');
                    }
                    break;
                case 'tourism':
                    if (tags.tourism === 'artwork' && !this._a.includes('mo:Artwork')) {
                        this._a.push('mo:Artwork');
                    }
                    if (tags.tourism === 'attraction' && !this._a.includes('mo:Attraction')) {
                        this._a.push('mo:Attraction');
                    }
                    if (tags.tourism === 'museum' && !this._a.includes('mo:Museum')) {
                        this._a.push('mo:Museum');
                    }
                    if (tags.tourism === 'tower' && !this._a.includes('mo:Tower')) {
                        this._a.push('mo:Tower');
                    }
                    if ((tags.amenity === 'place_of_worship') && !this._a.includes('mo:PlaceOfWorship')) {
                        this._a.push('mo:PlaceOfWorship');
                    }
                    break;
                case 'religion':
                    if (!this._a.includes('mo:PlaceOfWorship')) {
                        this._a.push('mo:PlaceOfWorship');
                    }
                    break;
                case 'place':
                    if (tags.place === 'square' && !this._a.includes('mo:Square')) {
                        this._a.push('mo:Square');
                    }
                    break;
                default:
                    if (key.includes('name')) {
                        if (key.includes(':')) {
                            const lang = key.split(':')[1];
                            if (lang.match(/^\D/) !== null && lang.length === 2) {
                                labels.push(
                                    {
                                        value: tags[key],
                                        lang: lang
                                    }
                                );
                            }
                        } else {
                            if (key === 'name') {
                                labels.push({ value: tags[key] });
                            }
                        }
                    } else {
                        if (key.includes('description')) {
                            if(key.includes(':')) {
                                const lang = key.split(':')[1];
                                if (lang.match(/^\D/) !== null && lang.length === 2) {
                                    descriptions.push(
                                        {
                                            value: tags[key],
                                            lang: lang
                                        }
                                    );
                                } 
                            } else {
                                descriptions.push({value: tags[key]});
                            }
                        }
                    }
                    break;
            }
        }

        this._a.push('mo:CulturalHeritage');
        
        if (labels.length > 0) {
            this._labels = labels;
        } else {
            this._labels = { value: this._tags.short_name == undefined ? this._name === undefined ? this._id : this._name : this._tags.short_name };
        }
        if (descriptions.length > 0) {
            this._descriptions = descriptions;
        }
    }


    get license() { return 'The data included in this document is from www.openstreetmap.org. The data is made available under ODbL.'; }
    get id() { return this._id; }
    get shortId() { return this._shortId; }
    get type() { return this._type; }
    get lat() { return this._lat; }
    get long() { return this._long; }
    get geometry() { return this.type == 'way' ? this._geometry : [{ lat: this._lat, long: this._long }]; }
    get name() { return this._tags.short_name == undefined ? this._name === undefined ? this._id : this._name : this._tags.short_name; }
    get wikipedia() { return this._wikipedia; }
    get dbpedia() { return this._dbpedia; }
    get wikidata() { return this._wikidata; }
    get tags() { return this._tags; }
    get author() { return this._author; }
    get labels() { return this._labels; }
    get descriptions() { return this._descriptions; }
    get members() { return this._members; }
    get a() { return this._a; }

    toChestMap() {
        return {
            id: this.id,
            shortId: this.shortId,
            a: this.a,
            lat: this.lat,
            long: this.long,
            provider: 'osm',
            geometry: this.geometry,
            tags: this.tags,
            labels: this.labels,
            descriptions: this.descriptions,
            license: this.license,
            author: this.author,
            coments: this.comments,
        };
    }

    toCHESTFeature() {
        return {
            id: this.id,
            shortId: this.shortId,
            a: this.a,
            lat: this.lat,
            long: this.long,
            labels: this.labels,
            descriptions: this.descriptions,
            author: this.author,
            geometry: this.geometry,
            members: this.members,
            license: this.license,
            wikipedia: this.wikipedia,
            tags: this.tags,
        };
    }
}

function wikipedia2dbpedia(wikipediaURL) {
    return wikipediaURL
        .replace(/\s+/g, '_')
        .replace('https', 'http')
        .replace('wikipedia', 'dbpedia')
        .replace('wiki', 'resource');
}

module.exports = {
    ElementOSM
}