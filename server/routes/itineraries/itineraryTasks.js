const Mustache = require('mustache');

const { getItineraryTasks } = require('../../util/queries');
const Config = require('../../util/config');
const SPARQLQuery = require('../../util/sparqlQuery');
const { mergeResults, sparqlResponse2Json, logHttp } = require('../../util/auxiliar');

const winston = require('../../util/winston');

async function getTasksIt(req, res) {
    const start = Date.now();
    try {
        const idIt = `http://moult.gsic.uva.es/data/${req.params.itinerary}`;
        const query = getItineraryTasks(idIt);
        const sparqlQuery = new SPARQLQuery(Config.localSPARQL);
        const data = await sparqlQuery.query(query);
        const dataTasks = mergeResults(sparqlResponse2Json(data), 'task');
        if (dataTasks !== null && dataTasks.length > 0) {
            winston.info(Mustache.render(
                'getTasksIt || {{{uid}}} || {{{points}}} || {{{time}}}',
                {
                    uid: idIt,
                    points: dataTasks.length,
                    time: Date.now() - start
                }
            ));
            logHttp(req, 200, 'getTasksIt', start);
            res.send(JSON.stringify(dataTasks));
        } else {
            logHttp(req, 204, 'getTasksIt', start);
            res.sendStatus(204);
        }
    } catch (error) {
        winston.error(Mustache.render(
            'getTasksIt || 500 || {{{time}}}',
            {
                time: Date.now() - start
            }
        ));
        res.sendStatus(500);
    }
}

module.exports = {
    getTasksIt,
}