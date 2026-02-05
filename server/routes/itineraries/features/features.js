const Mustache = require('mustache');
const fetch = require('node-fetch');

const { logHttp, sparqlResponse2Json, id2ShortId } = require('../../../util/auxiliar');
const winston = require('../../../util/winston');
const Config = require('../../../util/config');
const SPARQLQuery = require('../../../util/sparqlQuery');
const { getFeaturesItinerary, getCommentFeatureIt } = require('../../../util/queries');



async function getAllFeaturesIt(req, res) {
    const start = Date.now();
    try {
        const idIt = Mustache.render(
            'http://moult.gsic.uva.es/data/{{{it}}}',
            { it: req.params.itinerary });
        const query = getFeaturesItinerary(idIt);
        const sparqlQuery = new SPARQLQuery(Config.localSPARQL);
        const data = await sparqlQuery.query(query);
        const itineraryJson = sparqlResponse2Json(data);
        if (!itineraryJson.length) {
            winston.info(Mustache.render(
                'getAllFeaturesIt || 404 - {{{uid}}} || {{{time}}}',
                {
                    uid: idIt,
                    time: Date.now() - start
                }
            ));
            logHttp(req, 404, 'getAllFeaturesIt', start);
            res.sendStatus(404);
        } else {
            let resultadosProcesados = _procesaResultado(itineraryJson);
            if (resultadosProcesados.feature !== undefined) {
                if (!Array.isArray(resultadosProcesados.feature)) {
                    resultadosProcesados.feature = [resultadosProcesados.feature]
                }
                const lstIdFeatures = resultadosProcesados.feature;
                let promises = [];
                for (const feature of lstIdFeatures) {
                    promises.push(fetch(`http://127.0.0.1:${Config.serverPort}/features/${id2ShortId(feature)}`));
                }
                let response = await Promise.all(promises);
                const features = [];
                for (const r of response) {
                    features.push(r.status == 200 ? await r.json() : undefined);
                }
                promises = [];
                for (const feature of lstIdFeatures) {
                    promises.push(sparqlQuery.query(getCommentFeatureIt(idIt, feature)));
                }
                response = await Promise.all(promises);
                const tama = lstIdFeatures.length;
                const comments = [];
                for (let index = 0; index < tama; index += 1) {
                    const r = sparqlResponse2Json(response[index]);
                    if (Array.isArray(r) && r.length === 1) {
                        const c = r.pop();
                        comments.push(c.comment);
                    } else {
                        comments.push(undefined);
                    }
                }
                resultadosProcesados.feature = [];
                for (let index = 0; index < tama; index += 1) {
                    const dataFeature = {
                        id: lstIdFeatures[index],
                        shortId: id2ShortId(lstIdFeatures[index]),
                        commentAlt: comments[index],
                    };

                    const providers = features[index];
                    for (const provider of providers) {
                        const idProvider = provider.provider;
                        const dataProvider = provider.data;
                        switch (idProvider) {
                            case 'localRepo':
                                dataFeature['lat'] = dataProvider.lat;
                                dataFeature['long'] = dataProvider.long;
                                dataFeature['comments'] = dataProvider.comments;
                                dataFeature['labels'] = dataProvider.labels;
                                dataFeature['author'] = dataProvider.author;
                                break;
                            case 'osm':
                                if (dataFeature.lat === undefined) {
                                    dataFeature['lat'] = dataProvider.lat;
                                }
                                if (dataFeature.long === undefined) {
                                    dataFeature['long'] = dataProvider.long;
                                }
                                if (dataFeature.comments === undefined) {
                                    dataFeature['comments'] = dataProvider.descriptions;
                                }
                                if (dataFeature.labels === undefined) {
                                    dataFeature['labels'] = dataProvider.labels;
                                }
                                if (dataFeature['author'] === undefined) {
                                    dataFeature['author'] = dataProvider.author;
                                }
                                break;
                            case 'wikidata':
                                if (dataFeature.comments === undefined) {
                                    dataFeature['comments'] = dataProvider.description;
                                }
                                if (dataFeature.labels === undefined) {
                                    dataFeature['labels'] = dataProvider.label;
                                }
                                break;
                            case 'dbpedia':
                                if (dataFeature.comments === undefined) {
                                    dataFeature['comments'] = dataProvider.comment;
                                }
                                if (dataFeature.labels === undefined) {
                                    dataFeature['labels'] = dataProvider.label;
                                }
                                break;
                            case 'esDBpedia':
                                if (dataFeature.comments === undefined) {
                                    dataFeature['comments'] = dataProvider.comment;
                                }
                                if (dataFeature.labels === undefined) {
                                    dataFeature['labels'] = dataProvider.label;
                                }
                                break;
                            default:
                                break;
                        }
                    }
                    dataFeature['providers'] = features[index];
                    resultadosProcesados.feature.push(dataFeature);
                }
                winston.info(Mustache.render(
                    'getAllFeaturesIt || {{{uid}}} || {{{time}}}',
                    {
                        uid: idIt,
                        time: Date.now() - start
                    }
                ));
                logHttp(req, 200, 'getAllFeaturesIt', start);
                res.send(JSON.stringify(resultadosProcesados))
            } else {
                winston.info(Mustache.render(
                    'getAllFeaturesIt || {{{uid}}} || {{{time}}}',
                    {
                        uid: idIt,
                        time: Date.now() - start
                    }
                ));
                logHttp(req, 204, 'getAllFeaturesIt', start);
                res.sendStatus(204);
            }

        }
    } catch (error) {
        console.error(error);
        winston.error(Mustache.render(
            'getAllFeaturesIt || {{{error}}} || {{{time}}}',
            {
                error: error,
                time: Date.now() - start
            }
        ));
        logHttp(req, 500, 'getAllFeaturesIt', start);
        res.status(500).send(error);
    }
}

function _procesaResultado(itineraryJson) {
    const points = [];
    let first = null;
    itineraryJson.forEach((point) => {
        const findIndex = points.findIndex(p => {
            return p.poi === point.poi;
        });
        if (findIndex > -1) {
            const prev = points.splice(findIndex, 1).pop();
            // Agrego la información que no esté repetida
            const keys = Object.keys(point);
            for (let i = 0, tama = keys.length; i < tama; i++) {
                const prop = keys[i];
                if (prev[prop] === undefined) {
                    prev[prop] = point[prop];
                } else {
                    if (typeof prev[prop] === 'object') {
                        if (Array.isArray(prev[prop])) {
                            let encontrado = false;
                            if (prop === 'label' || prop === 'comment' || prop === 'altComment') {
                                //busco si está guardado el mismo idioma
                                prev[prop].forEach(ele => {
                                    if (ele.lang === point[prop].lang) {
                                        encontrado = true;
                                    }
                                });

                            } else {
                                prev[prop].forEach(ele => {
                                    if (ele === point[prop]) {
                                        encontrado = true;
                                    }
                                });
                            }
                            if (!encontrado) {
                                prev[prop].push(point[prop]);
                            }
                        } else {
                            let save = false;
                            for (let ele in prev[prop]) {
                                if (prev[prop][ele] !== point[prop][ele]) {
                                    save = true;
                                    break;
                                }
                            }
                            if (save) {
                                prev[prop] = [prev[prop], point[prop]];
                            }
                        }
                    } else {
                        if (prev[prop] !== point[prop]) {
                            prev[prop] = [prev[prop], point[prop]];
                        }
                    }
                }
            }
            points.push(prev);
        } else {
            if (first === null && point.first !== undefined) {
                first = point.first;
            }
            points.push(point);
        }
    }
    );
    return points.pop();
}

module.exports = {
    getAllFeaturesIt,
}