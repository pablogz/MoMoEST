class City {
    constructor(id, lat, long, population = -1) {
        this._id = id;
        this._lat = lat;
        this._long = long;
        this._population = population;
    }

    get id() { return this._id; }
    get latitude() { return this._lat; }
    get longitude() { return this._long; }
    get population() { return this._population; }
    get hasPopulation() { return this._population > -1; }

    distance(latP, lngP) {
        //Aplico la expresión del semiverso: https://en.wikipedia.org/wiki/Haversine_formula
        //Radio medio de la Tierra https://es.wikipedia.org/wiki/Tierra (considerando la aproximación de esfera)
        const R = 6371;
        const mFi = ((latP - this.latitude) / 2) * Math.PI / 180;
        const mLambda = ((lngP - this.longitude) / 2) * Math.PI / 180;
        return 2 * R * Math.asin(
            Math.sqrt(
                Math.pow(
                    Math.sin(mFi),
                    2) +
                Math.cos(
                    this.latitude *
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
    }

    inside(bounds) {
        return bounds.north >= this.latitude &&
            bounds.south <= this.latitude &&
            bounds.east >= this.longitude &&
            bounds.west <= this.longitude;
    }
}

module.exports = {
    City
}