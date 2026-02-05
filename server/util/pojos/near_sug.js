class NearSug {
    constructor(id, lat, long) {
        this._id = id;
        this._lat = lat;
        this._long = long;
        this._distance = 999999;
    }

    get id() { return this._id; }
    get lat() { return this._lat; }
    get long() { return this._long; }
    get distance() { return this._distance; }

    setDistance(latP, lngP) {
        //Aplico la expresión del semiverso: https://en.wikipedia.org/wiki/Haversine_formula
        //Radio medio de la Tierra https://es.wikipedia.org/wiki/Tierra (considerando la aproximación de esfera)
        const R = 6371;
        const mFi = ((latP - this.lat) / 2) * Math.PI / 180;
        const mLambda = ((lngP - this.long) / 2) * Math.PI / 180;
        this._distance = 2 * R * Math.asin(
            Math.sqrt(
                Math.pow(
                    Math.sin(mFi),
                    2) +
                Math.cos(
                    this.lat *
                    Math.PI /
                    180) *
                Math.cos(
                    latP *
                    Math.PI /
                    180) *
                Math.pow(
                    Math.sin(mLambda),
                    2)
            )
        );
        return this.distance;
    }
}

module.exports = {
    NearSug,
}