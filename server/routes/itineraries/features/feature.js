const Mustache = require('mustache');

const { logHttp, sparqlResponse2Json, mergeResults, shortId2Id } = require('../../../util/auxiliar');
const { getTasksFeatureIt } = require('../../../util/queries');
const winston = require('../../../util/winston');
const SPARQLQuery = require('../../../util/sparqlQuery');
const Config = require('../../../util/config');


async function getTasksPointItineraryServer(req, res) {
    const start = Date.now();
    try {
        const idIt = Mustache.render(
            'http://moult.gsic.uva.es/data/{{{it}}}',
            { it: req.params.itinerary });
        const idFeature = shortId2Id(req.params.feature);
        // const options = options4Request(getTasksFeatureIt(idIt, idFeature));
        const query = getTasksFeatureIt(idIt, idFeature);
        const sparqlQuery = new SPARQLQuery(Config.localSPARQL);
        const results = await sparqlQuery.query(query);
        if(results !== null) {
            const tasksFeature = mergeResults(sparqlResponse2Json(results), 'task');
            const out = JSON.stringify(tasksFeature);
            winston.info(Mustache.render(
                'getTasksFeatureIt || {{{time}}}',
                {
                    time: Date.now() - start
                }
            ));
            logHttp(req, 200, 'getTasksFeatureIt', start);
            res.send(out);
        } else {
            winston.info(Mustache.render(
                'getTasksFeatureIt || {{{time}}}',
                {
                    time: Date.now() - start
                }
            ));
            logHttp(req, 404, 'getTasksFeatureIt', start);
            res.sendStatus(404);
        }
        
    } catch (error) {
        winston.error(Mustache.render(
            'getTasksFeatureIt || {{{error}}} || {{{time}}}',
            {
                error: error,
                time: Date.now() - start
            }
        ));
        logHttp(req, 500, 'getTasksFeatureIt', start);
        res.sendStatus(500);
    }
}

module.exports = {
    getTasksPointItineraryServer,
}