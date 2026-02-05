const FirebaseAdmin = require('firebase-admin');
const Mustache = require('mustache');

const { getTokenAuth, logHttp } = require('../../../util/auxiliar');
const winston = require('../../../util/winston');
const { updateDocument, DOCUMENT_INFO, getInfoUser } = require('../../../util/bd');


async function getPreferences(req, res) {
    const start = Date.now();
    try {
        FirebaseAdmin.auth().verifyIdToken(getTokenAuth(req.headers.authorization))
            .then(async (dToken) => {
                const { uid } = dToken;
                getInfoUser(uid).then(async (infoUser) => {
                    if (infoUser !== null) {
                        if (infoUser.lpv !== null && typeof infoUser.lpv !== 'undefined') {
                            logHttp(req, 200, 'getPreferences', start);
                            res.status(200).send(JSON.stringify({
                                lastMapView: {
                                    lat: infoUser.lpv.lat,
                                    long: infoUser.lpv.long,
                                    zoom: infoUser.lpv.zoom,
                                },
                                defaultMap: infoUser.defaultMap,
                            }));
                        } else {
                            logHttp(req, 404, 'getPreferences', start);
                            res.sendStatus(404);
                        }
                    } else {
                        logHttp(req, 404, 'getPreferences', start);
                        res.sendStatus(404);
                    }
                })
            });
    } catch (error) {
        winston.error(Mustache.render(
            'getPreferences || {{{error}}} || {{{time}}}',
            {
                error: error,
                time: Date.now() - start
            }
        ));
        logHttp(req, 500, 'getPreferences', start);
        res.status(500).send(error.message);
    }
}

async function putPreferences(req, res) {
    const start = Date.now();
    try {
        FirebaseAdmin.auth().verifyIdToken(getTokenAuth(req.headers.authorization))
            .then(async (dToken) => {
                const { uid } = dToken;
                const { lastPointView, defaultMap } = req.body;
                const doc = {};
                // Datos que pueden venir de los clientes
                if (lastPointView !== undefined && _checkLastPointView(lastPointView)) {
                    doc['lpv'] = {
                        lat: lastPointView['lat'],
                        long: lastPointView['long'],
                        zoom: lastPointView['zoom'],
                    };
                }
                if (defaultMap !== undefined && _checkDefaultMap(defaultMap)) {
                    doc['defaultMap'] = defaultMap;
                }

                // Actualizo si no está vacío
                if (Object.keys(doc).length > 0) {
                    doc['lastUpdate'] = (new Date(Date.now())).toISOString();
                    updateDocument(
                        uid,
                        DOCUMENT_INFO,
                        doc,
                    ).then(async (err) => {
                        if (err !== null && typeof err.acknowledged !== 'undefined' && err.acknowledged) {
                            logHttp(req, 204, 'putPreferences', start);
                            res.sendStatus(204);
                        } else {
                            logHttp(req, 403, 'putPreferences', start);
                            res.sendStatus(403);
                        }
                    });
                } else {
                    logHttp(req, 400, 'putPreferences', start);
                    res.sendStatus(400);
                }
            });
    } catch (error) {
        winston.error(Mustache.render(
            'putPreferences || {{{error}}} || {{{time}}}',
            {
                error: error,
                time: Date.now() - start
            }
        ));
        logHttp(req, 500, 'putPreferences', start);
        res.status(500).send(error.message);
    }
}


function _checkLastPointView(lpv) {
    return typeof lpv === 'object' && typeof lpv['lat'] === 'number' && lpv['lat'] <= 90 && lpv['lat'] >= -90 && typeof lpv['long'] === 'number' && lpv['long'] <= 180 && lpv['long'] >= -180 && typeof lpv['zoom'] === 'number' && lpv['zoom'] <= 23 && lpv['lat'] >= 12;
}

function _checkDefaultMap(defaultMap) {
    return typeof defaultMap === 'string' && (defaultMap === 'carto' || defaultMap === 'satellite');
}


module.exports = {
    getPreferences,
    putPreferences,
}