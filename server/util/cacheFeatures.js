const short = require('short-uuid');

class Zone {
    constructor(north, east, south, west) {
        this._id = short.generate();
        this._north = north;
        this._east = east;
        this._south = south;
        this._west = west;
        this._timestampCache = Date.now();
        this._features = [];
    }

    get north() { return this.north; }
    get west() { return this.west; }
    get south() { return this.south; }
    get east() { return this.east; }

    validZone() {
        return this.north > this.south && this.north - this.south <= 0.5 && this.north <= 90 && this.south >= -90 &&
            this.west > this.east && Math.abs(this.west - this.east) <= 0.5 && this.west <= 180 && this.east <= 180 &&
            this.north % 0.5 == 0 && this.south % 0.5 == 0 && this.west % 0.5 == 0 && this.east % 0.5 == 0;
    }

    addFeature(featureCache) {
        removeFeatureCache(featureCache);
        this._features.push(featureCache);
    }

    removeFeature(featureCache) {
        const featureId = featureCache.id;
        this._features = this._features.filter(element => featureId != featureCache.id && !element.ids.contains(featureId));
    }

    insideZone(latitude, longitude) {
        return this._north >= latitude && this._south <= latitude && this._east >= longitude && this._west <= longitude;
    }
}

class FeatureCache {
    constructor(id) {
        this._id = id;
        this._ids = [];
        this._lastEdit = Date.now();
        this._infoFeature = [];
        this._providers = [];
    }
    get id() { return this._id; }
    get ids() { return this._ids; }
    get lastEdit() { return this._lastEdit; }
    get infoFeature() { return this._infoFeature; }
    get providers() { return this._providers; }

    updateLastEdit() { this._lastEdit = Date.now(); }

    addInfoFeatureCache(infoFeatureCache) {
        let _find = false;
        const provider = infoFeatureCache.provider;
        this.infoFeature.forEach((element, index, arra) => {
            if (element.provider == provider) {
                arra[index] = infoFeatureCache;
                _find = true;
            }
        });
        if (!_find) {
            this._ids.push(infoFeatureCache.id);
            this.infoFeature.push(infoFeatureCache);
            this._providers.push(provider);
        }
        this.updateLastEdit();
    }

    removeInfoFeatureCache(idInfoFeatureCache) {
        this._ids = this._ids.filter(element => element.id != idInfoFeatureCache);
        this._data = this._data.filter(element => element.id != idInfoFeatureCache);
        this.updateLastEdit();
    }
}

class InfoFeatureCache {
    constructor(provider, id, dataProvider) {
        this._provider = provider;
        this._id = id;
        this._dataProvider = dataProvider;
        this._timestampCache = Date.now();
    }

    get provider() { return this._provider; }
    get id() { return this._id; }
    get timestampCache() { return this._timestampCache; }
    get dataProvider() { return this._dataProvider; }

    updateTimestampCache() { this._timestampCache = Date.now(); }

    updateData(newData) {
        this._dataProvider = newData;
        this.updateTimestampCache();
    }
}

/**
 * [
 * ...,
 *  {
 *      {
 *      north: ,
 *      south: ,
 *      east: ,
 *      west: ,
 *      features: [
 *          {
 *              id: ,
 *              ids: [],
 *              lastEdit: ,
 *              infoFeature: [
 *                  {
 *                      type: 'OSM'
 *                      timestampCache: ,
 *                      dataProvider: ,
 *                  }, 
 *                  {
 *                      type: 'sparqlCHEST'
 *                      timestampCache: ,
 *                      dataProvider: ,
 *                  },
 *          }
 * 
 *      ]},
 *  },
 * ...
 * ]
 */
let _cacheZones = [];
//let _zoneFeatures = [];

function getAllCache() {
    _checkCache();
    return _cacheZones;
}

function getFeatureCache(idFeature) {
    _checkCache();
    const i = _cacheZones.findIndex((element) => element.id == idFeature || element.ids.includes(idFeature));
    return (i > -1) ? _cacheZones[i] : null;
}

function updateFeatureCache(feature) {
    const idFeature = feature.id;
    // _cacheZones = _cacheZones.filter((element) => element.id != idFeature && !element.ids.includes(idFeature));
    _cacheZones = _cacheZones.filter((element) => element.id != idFeature);
    _cacheZones.push(feature);
    _checkCache();
}

function removeFeatureCache(idFeature) {
    _cacheZones = _cacheZones.filter((element) => element.id != idFeature && !element.ids.includes(idFeature));
    _checkCache();
}

function _checkCache() {
    const limit = Date.now() - 60 * 60 * 24 * 1000;
    _cacheZones = _cacheZones.filter((element) => element.lastEdit >= limit);
}

module.exports = {
    getAllCache,
    getFeatureCache,
    updateFeatureCache,
    removeFeatureCache,
    FeatureCache,
    InfoFeatureCache,
    Zone,
};