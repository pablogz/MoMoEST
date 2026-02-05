const Mustache = require('mustache');

const { getLocationsTrackIt } = require('../../util/queries');
const Config = require('../../util/config');
const SPARQLQuery = require('../../util/sparqlQuery');
const { mergeResults, sparqlResponse2Json, logHttp } = require('../../util/auxiliar');

const winston = require('../../util/winston');


async function getTrackIt(req, res) {
    const start = Date.now();
    try {
        const idIt = `http://moult.gsic.uva.es/data/${req.params.itinerary}`;
        const query = getLocationsTrackIt(idIt);

        const sparqlQuery = new SPARQLQuery(Config.localSPARQL);
        const data = await sparqlQuery.query(query);
        const dataTrack = mergeResults(sparqlResponse2Json(data), 'pointTrack');
        const out = [];
        for (let d of dataTrack) {
            out[d.position] = {
                lat: d.lat,
                long: d.long,
            };
            if (d.alt !== undefined) {
                out[d.position]['alt'] = d.alt;
            }
            if (d.timestamp !== undefined) {
                out[d.position]['timestamp'] = d.timestamp;
            }
        }
        if (out.length > 0) {
            winston.info(Mustache.render(
                'getTrackIt || {{{uid}}} || {{{points}}} || {{{time}}}',
                {
                    uid: idIt,
                    points: out.length,
                    time: Date.now() - start
                }
            ));
            logHttp(req, 200, 'getTrackIt', start);
            res.send(JSON.stringify(out));
        } else {
            logHttp(req, 404, 'getTrackIt', start);
            res.sendStatus(404);
        }
    } catch (error) {
        winston.error(Mustache.render(
            'getTrackIt || 500 || {{{time}}}',
            {
                time: Date.now() - start
            }
        ));
        res.sendStatus(500);
    }
}

module.exports = {
    getTrackIt
}