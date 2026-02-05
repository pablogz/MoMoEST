const Mustache = require('mustache');
const FirebaseAdmin = require('firebase-admin');

const { logHttp, getTokenAuth, shortId2Id } = require('../../util/auxiliar');
const winston = require('../../util/winston');
const { InfoUser, FeedsUser } = require('../../util/pojos/user');
const { getInfoUser, getFeedsUser, getFeed, deleteFeedOwner, deleteFeedSubscriber, updateFeedDB } = require('../../util/bd');
const { Feed, FeedSubscriber } = require('../../util/pojos/feed');


async function objFeed(req, res) {
    const start = Date.now();
    try {
        // Recupero el identificador del usuario
        FirebaseAdmin.auth().verifyIdToken(getTokenAuth(req.headers.authorization))
            .then(async dToken => {
                const { uid } = dToken;
                if (uid !== '') {
                    const user = new InfoUser(await getInfoUser(uid));
                    // Recupero la lista de canales a los que está subscrito o es propietario
                    const feedsUser = new FeedsUser(await getFeedsUser(user.id));
                    // Compruebo si el cliente ha enviado un identificador como parámetro de la consulta
                    const shortIdFeed = req.params.feed;
                    const idFeed = shortId2Id(shortIdFeed);
                    if (idFeed !== null) {
                        // Compruebo si el id del canal solicitado por el usuario está entre los suyos
                        let out = null;
                        feedsUser.owner.forEach(feed => {
                            feed = new Feed(feed);
                            if (feed.id === idFeed) {
                                out = feed.toMap();
                            }
                        });
                        if (out !== null) {
                            winston.info(Mustache.render('objFeed || idUser: {{{idUser}}} - feed: {{{feed}}} || {{{time}}}', {
                                idUser: user.id,
                                feed: out.id,
                                time: Date.now() - start
                            }));
                            logHttp(req, 200, 'objFeed', start);
                            res.send(JSON.stringify(out));
                        } else {
                            // Compruebo si es uno en los que está subscrito
                            feedsUser.subscribed.forEach(feedSubscriber => {
                                feedSubscriber = new FeedSubscriber(feedSubscriber);
                                if (feedSubscriber.idFeed === idFeed) {
                                    out = feedSubscriber;
                                }
                            });
                            if (out !== null) {
                                // Me falta recuperar el resto de información del canal
                                const feed = await getFeed(out.idOwner, out.idFeed);
                                if (typeof feed === Feed) {
                                    Object.assign(
                                        { id: out.idFeed, date: out.date, owner: out.idOwner },
                                        feed.toSubscriber());
                                    winston.info(Mustache.render('objFeed || idUser: {{{idUser}}} - feed: {{{feed}}} || {{{time}}}', {
                                        idUser: user.id,
                                        feed: out.id,
                                        time: Date.now() - start
                                    }));
                                    logHttp(req, 200, 'objFeed', start);
                                    res.send(JSON.stringify(out));
                                } else {
                                    logHttp(req, 400, 'objFeed', start);
                                    res.sendStatus(400);
                                }
                            } else {
                                logHttp(req, 400, 'objFeed', start);
                                res.sendStatus(400);
                            }
                        }
                    } else {
                        logHttp(req, 400, 'objFeed', start);
                        res.sendStatus(400);
                    }
                } else {
                    logHttp(req, 401, 'objFeed', start);
                    res.sendStatus(401);
                }
            });
    } catch (error) {
        winston.error(Mustache.render(
            'objFeed || {{{error}}} || {{{time}}}',
            {
                error: error,
                time: Date.now() - start
            }
        ));
        logHttp(req, 500, 'objFeed', start);
        res.sendStatus(500);
    }
}

async function updateFeed(req, res) {
    const start = Date.now();
    try {
        // Recupero el identificador del usuario
        FirebaseAdmin.auth().verifyIdToken(getTokenAuth(req.headers.authorization))
            .then(async dToken => {
                const { uid } = dToken;
                if (uid !== null) {
                    // Recupero los datos del usuario
                    const infoUser = new InfoUser(await getInfoUser(uid));
                    if (infoUser.isTeacher) {
                        const feedsUser = new FeedsUser(await getFeedsUser(uid));
                        const shortIdFeed = req.params.feed;
                        const idFeed = shortId2Id(shortIdFeed);
                        if (idFeed !== null) {
                            // Compruebo que el feed a modificar sea de los suyos
                            const index = feedsUser.owner.findIndex(feed => {
                                feed = new Feed(feed);
                                return feed.id === idFeed;
                            });
                            if (index > -1) {
                                const feedData = feedsUser.owner.at(index);
                                const newData = {};
                                // Compruebo los datos enviados por el cliente
                                if (req.body) {
                                    let { labels, comments, password } = req.body;
                                    let update = true;
                                    if (!Array.isArray(labels)) {
                                        labels = [labels];
                                    }
                                    labels.forEach(label => {
                                        if (!(typeof label === 'object' &&
                                            label.value !== undefined && typeof label.value === 'string' &&
                                            label.lang !== undefined && typeof label.lang === 'string')) {
                                            update = false;
                                        }
                                    });
                                    if (update) {
                                        if (!Array.isArray(comments)) {
                                            comments = [comments];
                                        }

                                        comments.forEach(label => {
                                            if (!(typeof label === 'object' &&
                                                label.value !== undefined && typeof label.value === 'string' &&
                                                label.lang !== undefined && typeof label.lang === 'string')) {
                                                update = false;
                                            }
                                        });
                                        if (update) {
                                            if (password === undefined) {
                                                password = null;
                                            } else {
                                                if (password.trim() === '') {
                                                    password = null;
                                                }
                                            }
                                            // Actualizo la información
                                            newData.labels = labels;
                                            newData.comments = comments;
                                            newData.password = password;
                                            newData.updated = (new Date(Date.now())).toISOString();
                                            Object.assign(feedData, newData);
                                            Object.keys(feedData).forEach(key => {
                                                if (feedData[key] === undefined) {
                                                    delete feedData[key];
                                                }
                                            });
                                            const actualizado = await updateFeedDB(uid, feedData);
                                            // Respondo al cliente
                                            winston.info(Mustache.render('updateFeed || idUser: {{{idUser}}} - idFeed: {{{feed}}} - updated: {{{updated}}} || {{{time}}}', {
                                                idUser: uid,
                                                feed: feedData.id,
                                                updated: actualizado,
                                                time: Date.now() - start
                                            }));
                                            if (actualizado) {
                                                logHttp(req, 204, 'updateFeed', start);
                                                res.sendStatus(204);
                                            } else {
                                                logHttp(req, 406, 'updateFeed', start);
                                                res.sendStatus(406);
                                            }
                                        } else {
                                            logHttp(req, 400, 'updateFeed', start);
                                            res.sendStatus(400);
                                        }
                                    } else {
                                        logHttp(req, 400, 'updateFeed', start);
                                        res.sendStatus(400);
                                    }
                                } else {
                                    logHttp(req, 400, 'updateFeed', start);
                                    res.sendStatus(400);
                                }
                            } else {
                                logHttp(req, 404, 'updateFeed', start);
                                res.sendStatus(404);
                            }
                        } else {
                            logHttp(req, 400, 'updateFeed', start);
                            res.sendStatus(400);
                        }
                    } else {
                        logHttp(req, 401, 'updateFeed', start);
                        res.sendStatus(401);
                    }
                } else {
                    logHttp(req, 401, 'updateFeed', start);
                    res.sendStatus(401);
                }
            });
    } catch (error) {
        winston.error(Mustache.render(
            'updateFeed || {{{error}}} || {{{time}}}',
            {
                error: error,
                time: Date.now() - start
            }
        ));
        logHttp(req, 500, 'updateFeed', start);
        res.sendStatus(500);
    }
}

async function byeFeed(req, res) {
    // Recupero la lista de canales que son propiedad del cliente
    // Si es suyo lo elimino
    const start = Date.now();
    try {
        // Recupero el identificador del usuario
        FirebaseAdmin.auth().verifyIdToken(getTokenAuth(req.headers.authorization))
            .then(async dToken => {
                const { uid } = dToken;
                if (uid !== '') {
                    const feedsUser = new FeedsUser(await getFeedsUser(uid));
                    // Compruebo si el cliente ha enviado un identificador como parámetro de la consulta
                    const shortIdFeed = req.params.feed;
                    const idFeed = shortId2Id(shortIdFeed);
                    if (idFeed !== null) {
                        // Compruebo si el id del canal solicitado por el usuario está entre los suyos
                        if (feedsUser.owner !== undefined) {
                            const index = feedsUser.owner.findIndex(f => {
                                f = new Feed(f);
                                return f.id === idFeed;
                            });
                            if (index > -1) {
                                // Sí que es de los suyos por lo que puede borrarlo
                                // Tengo que ir a cada subscriber y borrarle el canal
                                const promesas = [];
                                const feed = new Feed(feedsUser.owner.at(index));
                                for (let index = 0, tama = feed.subscribers.length; index < tama; index++) {
                                    const subscriberId = feed.subscribers[index];
                                    promesas.push(deleteFeedSubscriber(subscriberId, feed.id));
                                }
                                // Tengo que borrar el canal del propietario
                                promesas.push(deleteFeedOwner(uid, feed.id));
                                const arrayBorrados = await Promise.all(promesas);
                                // Envío código de estado aceptado
                                let todoBien = arrayBorrados.every(Boolean);
                                winston.info(Mustache.render('byeFeed || idUser: {{{idUser}}} - idFeed: {{{feed}}} - allDelete: {{{allDelete}}} || {{{time}}}', {
                                    idUser: uid,
                                    feed: feed.id,
                                    allDelete: todoBien,
                                    time: Date.now() - start
                                }));
                                if (todoBien) {
                                    logHttp(req, 204, 'byeFeed', start);
                                    res.sendStatus(204);
                                } else {
                                    logHttp(req, 406, 'byeFeed', start);
                                    res.sendStatus(406);
                                }
                            } else {
                                logHttp(req, 404, 'byeFeed', start);
                                res.sendStatus(401);
                            }
                        } else {
                            logHttp(req, 401, 'byeFeed', start);
                            res.sendStatus(401);
                        }
                    } else {
                        logHttp(req, 400, 'byeFeed', start);
                        res.sendStatus(400);
                    }
                } else {
                    logHttp(req, 401, 'byeFeed', start);
                    res.sendStatus(401);
                }
            });
    } catch (error) {
        winston.error(Mustache.render(
            'byeFeed || {{{error}}} || {{{time}}}',
            {
                error: error,
                time: Date.now() - start
            }
        ));
        logHttp(req, 500, 'byeFeed', start);
        res.sendStatus(500);
    }
}

module.exports = { objFeed, updateFeed, byeFeed }