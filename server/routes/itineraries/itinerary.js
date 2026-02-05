const Mustache = require('mustache');
const fetch = require('node-fetch');
const FirebaseAdmin = require('firebase-admin');

const { options4Request, sparqlResponse2Json, getTokenAuth, logHttp, mergeResults } = require('../../util/auxiliar');
const { getInfoItinerary, isAuthor, deleteItinerarySparql } = require('../../util/queries');
const { getInfoUser } = require('../../util/bd');
const SPARQLQuery = require('../../util/sparqlQuery');
const Config = require('../../util/config');

const winston = require('../../util/winston');

async function getItineraryServer(req, res) {
    const start = Date.now();
    try {
        const idIt = Mustache.render(
            'http://moult.gsic.uva.es/data/{{{it}}}',
            { it: req.params.itinerary });
        const query = getInfoItinerary(idIt);
        const sparqlQuery = new SPARQLQuery(Config.localSPARQL);
        const data = await sparqlQuery.query(query);
        const dataServer = mergeResults(sparqlResponse2Json(data)).pop();

        if(dataServer === undefined) {
            logHttp(req, 404, 'getItinerary', start);
            res.sendStatus(404);
        } else {
        winston.info(Mustache.render(
            'getItinerary || {{{uid}}} || {{{body}}} || {{{time}}}',
            {
                uid: idIt,
                body: JSON.stringify(dataServer),
                time: Date.now() - start
            }
        ));
        logHttp(req, 200, 'getItinerary', start);
        res.send(JSON.stringify(dataServer));
        }
    } catch (error) {
        winston.error(Mustache.render(
            'getItinerary || {{{error}}} || {{{time}}}',
            {
                error: error,
                time: Date.now() - start
            }
        ));
        logHttp(req, 500, 'getItinerary', start);
        res.sendStatus(500);
    }
}

function updateItineraryServer(req, res) {
    res.sendStatus(418);
}

// curl -X DELETE -H "Authorization: Bearer fdas" "localhost:11110/itineraries/rkoxEMyKgT4BaB3xUofRPp" -v
function deleteItineraryServer(req, res) {
    const start = Date.now();

    try {
        const idIt = Mustache.render(
            'http://moult.gsic.uva.es/data/{{{it}}}',
            { it: req.params.itinerary });
        FirebaseAdmin.auth().verifyIdToken(getTokenAuth(req.headers.authorization))
            .then(async dToken => {
                const { uid } = dToken;
                if ( uid !== '') {
                    getInfoUser(uid).then(async infoUser => {
                        if (infoUser !== null && infoUser.rol.includes('TEACHER')) {
                            let options = options4Request(isAuthor(idIt, `http://moult.gsic.uva.es/data/${infoUser.id}`));
                            fetch(options.url, options.init)
                                .then((r) => r.json())
                                .then((json) => {
                                    if (json.boolean === true || infoUser.rol.includes('ADMIN')) {
                                        options = options4Request(deleteItinerarySparql(idIt), true);
                                        fetch(options.url, options.init)
                                            .then(r => {
                                                winston.info(Mustache.render(
                                                    'deleteItinerary || {{{error}}} || {{{time}}}',
                                                    {
                                                        error: r.status,
                                                        time: Date.now() - start
                                                    }
                                                ));
                                                logHttp(req, r.status, 'deleteItinerary', start);
                                                res.sendStatus(r.status);
                                            })
                                            .catch(error => {
                                                winston.error(Mustache.render(
                                                    'deleteItinerary || {{{error}}} || {{{time}}}',
                                                    {
                                                        error: error,
                                                        time: Date.now() - start
                                                    }
                                                ));
                                                logHttp(req, 500, 'deleteItinerary', start);
                                                res.sendStatus(500);
                                            });
                                    } else {
                                        winston.error(Mustache.render(
                                            'deleteItinerary || {{{error}}} || {{{time}}}',
                                            {
                                                error: "401",
                                                time: Date.now() - start
                                            }
                                        ));
                                        logHttp(req, 401, 'deleteItinerary', start);
                                        res.sendStatus(401);
                                    }
                                })
                                .catch((error) => {
                                    winston.error(Mustache.render(
                                        'deleteItinerary || {{{error}}} || {{{time}}}',
                                        {
                                            error: error,
                                            time: Date.now() - start
                                        }
                                    ));
                                    logHttp(req, 500, 'deleteItinerary', start);
                                    res.sendStatus(500);
                                });
                        } else {
                            winston.info(Mustache.render(
                                'deleteItinerary || {{{error}}} || {{{time}}}',
                                {
                                    error: "401",
                                    time: Date.now() - start
                                }
                            ));
                            logHttp(req, 401, 'deleteItinerary', start);
                            res.sendStatus(401);
                        }
                    });
                } else {
                    winston.info(Mustache.render(
                        'deleteItinerary || {{{error}}} || {{{time}}}',
                        {
                            error: "403",
                            time: Date.now() - start
                        }
                    ));
                    logHttp(req, 403, 'deleteItinerary', start);
                    res.status(403).send('You have to verify your email!');
                }
            }).catch(error => {
                winston.info(Mustache.render(
                    'deleteItinerary || {{{error}}} || {{{time}}}',
                    {
                        error: "401",
                        time: Date.now() - start
                    }
                ));
                logHttp(req, 401, 'deleteItinerary', start);
                res.sendStatus(401);
            });
    } catch (error) {
        winston.error(Mustache.render(
            'deleteItinerary || {{{error}}} || {{{time}}}',
            {
                error: error,
                time: Date.now() - start
            }
        ));
        logHttp(req, 500, 'deleteItinerary', start);
        res.sendStatus(500);
    }
}

module.exports = {
    getItineraryServer,
    updateItineraryServer,
    deleteItineraryServer,
}