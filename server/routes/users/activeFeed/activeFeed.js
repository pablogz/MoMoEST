const FirebaseAdmin = require('firebase-admin');
const Mustache = require('mustache');

const { getTokenAuth, logHttp, shortId2Id } = require('../../../util/auxiliar');
const winston = require('../../../util/winston');
const { updateDocument, DOCUMENT_INFO, getInfoUser, getFeedsUser } = require('../../../util/bd');

// curl -X PUT -H "Authorization: Bearer 1" -H "Content-Type: application/json" -d '{"idFeed": "md:ABC123"}' "localhost:11110/users/user/activeFeed" -v
// Con idFeed a null (o ausente) se limpia el canal activo
async function putActiveFeed(req, res) {
    const start = Date.now();
    try {
        FirebaseAdmin.auth().verifyIdToken(getTokenAuth(req.headers.authorization))
            .then(async (dToken) => {
                const { uid } = dToken;
                const infoUser = await getInfoUser(uid);
                if (infoUser === null) {
                    logHttp(req, 404, 'putActiveFeed', start);
                    return res.sendStatus(404);
                }
                const { idFeed } = req.body;
                if (idFeed === undefined || idFeed === null || idFeed === '') {
                    // Limpiar el canal activo
                    const err = await updateDocument(uid, DOCUMENT_INFO, {
                        activeFeed: null,
                        lastUpdate: (new Date(Date.now())).toISOString(),
                    });
                    const ok = err !== null && typeof err.acknowledged !== 'undefined' && err.acknowledged;
                    logHttp(req, ok ? 204 : 500, 'putActiveFeed', start);
                    return res.sendStatus(ok ? 204 : 500);
                }
                if (typeof idFeed !== 'string') {
                    logHttp(req, 400, 'putActiveFeed', start);
                    return res.sendStatus(400);
                }
                const feedId = shortId2Id(idFeed.trim());
                if (feedId === null) {
                    logHttp(req, 400, 'putActiveFeed', start);
                    return res.sendStatus(400);
                }
                // El canal debe estar entre las subscripciones del usuario
                const feeds = await getFeedsUser(uid);
                const subscrito = feeds !== null
                    && Array.isArray(feeds.subscribed)
                    && feeds.subscribed.some(f => f.idFeed === feedId);
                if (!subscrito) {
                    logHttp(req, 403, 'putActiveFeed', start);
                    return res.sendStatus(403);
                }
                const err = await updateDocument(uid, DOCUMENT_INFO, {
                    activeFeed: feedId,
                    lastUpdate: (new Date(Date.now())).toISOString(),
                });
                const ok = err !== null && typeof err.acknowledged !== 'undefined' && err.acknowledged;
                winston.info(Mustache.render('putActiveFeed || {{{uid}}} -> {{{feed}}} || {{{time}}}', {
                    uid,
                    feed: feedId,
                    time: Date.now() - start,
                }));
                logHttp(req, ok ? 204 : 500, 'putActiveFeed', start);
                return res.sendStatus(ok ? 204 : 500);
            })
            .catch((error) => {
                winston.info(Mustache.render('putActiveFeed || {{{error}}} || {{{time}}}', {
                    error: String(error),
                    time: Date.now() - start,
                }));
                logHttp(req, 401, 'putActiveFeed', start);
                res.sendStatus(401);
            });
    } catch (error) {
        winston.error(Mustache.render('putActiveFeed || {{{error}}} || {{{time}}}', {
            error: String(error),
            time: Date.now() - start,
        }));
        logHttp(req, 500, 'putActiveFeed', start);
        res.status(500).send(error.message);
    }
}

// Limpia el canal activo del usuario si coincide con feedId. Pensada para el
// flujo de baja de un canal.
async function clearActiveFeedIfMatches(uid, feedId) {
    try {
        const infoUser = await getInfoUser(uid);
        if (infoUser !== null && infoUser.activeFeed === feedId) {
            await updateDocument(uid, DOCUMENT_INFO, {
                activeFeed: null,
                lastUpdate: (new Date(Date.now())).toISOString(),
            });
        }
    } catch (error) {
        winston.error(`clearActiveFeedIfMatches: ${error}`);
    }
}

module.exports = {
    putActiveFeed,
    clearActiveFeedIfMatches,
}
