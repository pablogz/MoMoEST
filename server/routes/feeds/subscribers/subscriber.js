const Mustache = require('mustache');
const FirebaseAdmin = require('firebase-admin');

const winston = require('../../../util/winston');
const { logHttp, getTokenAuth, shortId2Id } = require('../../../util/auxiliar');
const { InfoUser, FeedsUser } = require('../../../util/pojos/user');
const {
    getInfoUser, getFeedsUser, getInfoSubscriber,
    findCollectionAndFeed, updateFeedDB, updateSubscribedFeedBD,
    deleteFeedSubscriber, deleteSubscriber } = require('../../../util/bd');
const { Feed } = require('../../../util/pojos/feed');

async function subscriber(req, res) {
    const start = Date.now();
    try {
        FirebaseAdmin.auth().verifyIdToken(getTokenAuth(req.headers.authorization))
            .then(async dToken => {
                const { uid } = dToken;
                if (uid !== '') {
                    const user = new InfoUser(await getInfoUser(uid));
                    const subscriberId = req.params.subscriber;
                    const feedId = shortId2Id(req.params.feed);
                    if (feedId !== null) {
                        if (user.id === subscriberId) {
                            // El usuario está solicitando su propia información. Tengo que comprobar si está subscripto al canal. Si es así le envío su información.
                            const infoSubscriber = await getInfoSubscriber(subscriberId, feedId);
                            if (infoSubscriber !== null) {
                                winston.info(Mustache.render('subscriber || uid: {{{uid}}} feedId: {{{feedId}}} || {{{time}}}',
                                    {
                                        uid: uid,
                                        feedId: feedId,
                                        time: Date.now() - start
                                    }));
                                logHttp(req, 200, 'subscriber', start);
                                res.send(JSON.stringify(infoSubscriber));
                            } else {
                                winston.info(Mustache.render('subscriber || uid: {{{uid}}} feedId: {{{feedId}}} - no subscrito || {{{time}}}',
                                    {
                                        uid: uid,
                                        feedId: feedId,
                                        time: Date.now() - start
                                    }));
                                logHttp(req, 404, 'subscriber', start);
                                res.sendStatus(404);
                            }
                        } else {
                            if (user.isTeacher) {
                                // Es posible que el profesor esté solicitando información sobre uno de sus estudiantes. Voy a ver si el feed es de los que ha creado él y si uno de los estudiantes tiene el id subscriberId. Si es así le envío la información del estudiante.
                                const feedsUser = new FeedsUser(await getFeedsUser(user.id));
                                let index = feedsUser.owner.findIndex(f => {
                                    return f.id === feedId;
                                });
                                if (index > - 1) {
                                    const feed = new Feed(feedsUser.owner.at(index));
                                    if (feed.subscribers.includes(subscriberId)) {
                                        // El profesor puede solicitar la información
                                        const infoSubscriber = await getInfoSubscriber(subscriberId, feedId);
                                        if (infoSubscriber !== null) {
                                            winston.info(Mustache.render('subscriber || uid: {{{uid}}} feedId: {{{feedId}}} || {{{time}}}',
                                                {
                                                    uid: uid,
                                                    feedId: feedId,
                                                    time: Date.now() - start
                                                }));
                                            logHttp(req, 200, 'subscriber', start);
                                            res.send(JSON.stringify(infoSubscriber));
                                        } else {
                                            winston.info(Mustache.render('subscriber || Profe: {{{profe}}} estudiante: {{{uid}}} feedId: {{{feedId}}} - no subscrito || {{{time}}}',
                                                {
                                                    profe: user.id,
                                                    uid: subscriberId,
                                                    feedId: feedId,
                                                    time: Date.now() - start
                                                }));
                                            logHttp(req, 404, 'subscriber', start);
                                            res.sendStatus(404);
                                        }
                                    } else {
                                        winston.info(Mustache.render('subscriber || Profesor {{{uid}}} solicita {{{subscriberId}}} en {{{feed}}} - el estudiante no está subscrito || {{{time}}}',
                                            {
                                                uid: uid,
                                                subscriberId: subscriberId,
                                                feed: feedId,
                                                time: Date.now() - start
                                            }));
                                        logHttp(req, 404, 'subscriber', start);
                                        res.sendStatus(404);
                                    }
                                } else {
                                    // El profe está intentando acceder a un estudiante de un canal que no ha creado él
                                    winston.info(Mustache.render('subscriber || Profesor {{{uid}}} solicita {{{subscriberId}}} en {{{feed}}} || {{{time}}}',
                                        {
                                            uid: uid,
                                            subscriberId: subscriberId,
                                            feed: feedId,
                                            time: Date.now() - start
                                        }));
                                    logHttp(req, 401, 'subscriber', start);
                                    res.sendStatus(401);
                                }
                            } else {
                                // Un usuario sin privilegios está pidiendo la información de otro
                                winston.info(Mustache.render('subscriber || {{{uid}}} solicita {{{subscriberId}}} sin tener privilegios || {{{time}}}',
                                    {
                                        uid: uid,
                                        subscriberId: subscriberId,
                                        time: Date.now() - start
                                    }));
                                logHttp(req, 401, 'subscriber', start);
                                res.sendStatus(401);
                            }
                        }
                    } else {
                        logHttp(req, 400, 'subscriber', start);
                        res.sendStatus(400);
                    }
                } else {
                    logHttp(req, 401, 'subscriber', start);
                    res.sendStatus(401);
                }
            });
    } catch (error) {
        winston.error(Mustache.render(
            'subscriber || {{{error}}} || {{{time}}}',
            {
                error: error,
                time: Date.now() - start
            }
        ));
        logHttp(req, 500, 'subscriber', start);
        res.sendStatus(500);
    }
}

async function newSubscriber(req, res) {
    // Identifico al usuario
    const start = Date.now();
    try {
        FirebaseAdmin.auth().verifyIdToken(getTokenAuth(req.headers.authorization))
            .then(async dToken => {
                const { uid } = dToken;
                if (uid !== '') {
                    // Obtengo la contraseña del cuerpo de la petición
                    const { password } = req.body;
                    // Traigo el canal al que se quiere subscribir. Tengo que buscar en todas la colecciones para encontrarlo
                    const feedId = shortId2Id(req.params.feed);
                    const objCollFeed = await findCollectionAndFeed(feedId);
                    if (objCollFeed !== null) {
                        const ownerId = objCollFeed.userId;
                        const feed = new Feed(objCollFeed.dataFeed);
                        // Compruebo si no está ya subscrito.
                        let puede = !feed.subscribers.includes(uid);
                        if (puede && feed.password !== undefined && feed.password !== null) {
                            puede = password === feed.password;
                        }
                        if (puede) {
                            // Almaceno en el objeto del creador el id del nuevo usuario
                            const feedObj = objCollFeed.dataFeed;
                            feedObj.subscribers.push(uid)
                            const promesas = [];
                            promesas.push(updateFeedDB(ownerId, feedObj));
                            // Almaceno en el documento del usuario su subscripción al canal
                            const feedSubscriberObj = {
                                idFeed: feedId,
                                idOwner: ownerId,
                                date: (new Date(Date.now()).toISOString()),
                                answers: []
                            };
                            promesas.push(updateSubscribedFeedBD(uid, feedSubscriberObj));
                            const arrayConsultas = await Promise.all(promesas);
                            // Envío código de estado aceptado
                            let todoBien = arrayConsultas.every(Boolean);
                            winston.info(Mustache.render('newSubscriber || idUser: {{{idUser}}} - idFeed: {{{feed}}} - allOk: {{{allOk}}} || {{{time}}}', {
                                idUser: uid,
                                feed: feed.id,
                                allOk: todoBien,
                                time: Date.now() - start
                            }));
                            if (todoBien) {
                                logHttp(req, 204, 'newSubscriber', start);
                                res.sendStatus(204);
                            } else {
                                logHttp(req, 406, 'newSubscriber', start);
                                res.sendStatus(406);
                            }
                        } else {
                            logHttp(req, 400, 'newSubscriber', start);
                            res.sendStatus(400);
                        }

                    } else {
                        logHttp(req, 404, 'newSubscriber', start);
                        res.sendStatus(404);
                    }
                } else {
                    logHttp(req, 401, 'newSubscriber', start);
                    res.sendStatus(401);
                }
            });
    } catch (error) {
        winston.error(Mustache.render(
            'newSubscriber || {{{error}}} || {{{time}}}',
            {
                error: error,
                time: Date.now() - start
            }
        ));
        logHttp(req, 500, 'newSubscriber', start);
        res.sendStatus(500);
    }
}

async function byeSubscriber(req, res) {
    // Identifico al usuario
    const start = Date.now();
    try {
        FirebaseAdmin.auth().verifyIdToken(getTokenAuth(req.headers.authorization))
            .then(async dToken => {
                const { uid } = dToken;
                if (uid !== '') {
                    // Construyo el identificador del canal
                    const feedId = shortId2Id(req.params.feed);
                    const reqSubscriberId = req.params.subscriber;
                    // Si uid y reqSubscriberId son iguales => el propio usuario quiere darse de baja
                    if (reqSubscriberId === uid) {
                        // Traigo los canales del usuario
                        const feeds = await getFeedsUser(uid);
                        if (feeds !== undefined && feeds.subscribed !== undefined && Array.isArray(feeds.subscribed) && feeds.subscribed.length > 0) {
                            const index = feeds.subscribed.findIndex(f => {
                                return f.idFeed === feedId;
                            });
                            if (index > -1) {
                                // Tengo que borrar la subscripción en el documento del usuario y quitarle de subscriber donde el profe
                                const feedBorrar = feeds.subscribed.at(index);
                                const promesas = [];
                                promesas.push(deleteFeedSubscriber(uid, feedId));
                                promesas.push(deleteSubscriber(feedBorrar.idOwner, feedId, uid));
                                const arrayPromesas = await Promise.all(promesas);
                                const todoBien = arrayPromesas.every(Boolean);
                                winston.info(Mustache.render('byeSubscriber || idUser: {{{idUser}}} - idFeed: {{{feed}}} - allOk: {{{allOk}}} || {{{time}}}', {
                                    idUser: uid,
                                    feed: feedId,
                                    allOk: todoBien,
                                    time: Date.now() - start
                                }));
                                if (todoBien) {
                                    logHttp(req, 200, 'byeSubscriber', start);
                                    res.sendStatus(200);
                                } else {
                                    logHttp(req, 406, 'byeSubscriber', start);
                                    res.sendStatus(406);
                                }
                            } else {
                                logHttp(req, 404, 'byeSubscriber', start);
                                res.sendStatus(404);
                            }
                        } else {
                            logHttp(req, 404, 'byeSubscriber', start);
                            res.sendStatus(404);
                        }
                    } else {
                        // Este tipo de operaciones solo las puede hacer un profesor
                        const user = new InfoUser(await getInfoUser(uid));
                        if (user.isTeacher) {
                            // Es posible que el profesor quiera dar de baja al estudiante. Lo compruebo y actuo
                            const feedsTeacher = new FeedsUser(await getFeedsUser(uid));
                            const index = feedsTeacher.owner.findIndex(f => {
                                return f.id === feedId;
                            });
                            if (index > -1) {
                                if (feedsTeacher.owner.at(index).subscribers.includes(reqSubscriberId)) {
                                    // Borro al estudiante de subscritores de su canal y borro también el objeto del canal del documento del estudiante
                                    const promesas = [];
                                    promesas.push(deleteSubscriber(uid, feedId, reqSubscriberId));
                                    promesas.push(deleteFeedSubscriber(reqSubscriberId, feedId));
                                    const arrayPromesas = await Promise.all(promesas);
                                    const todoBien = arrayPromesas.every(Boolean);
                                    winston.info(Mustache.render('byeSubscriber || idUser: {{{idUser}}} - idFeed: {{{feed}}} - allOk: {{{allOk}}} || {{{time}}}', {
                                        idUser: uid,
                                        feed: feedId,
                                        allOk: todoBien,
                                        time: Date.now() - start
                                    }));
                                    if (todoBien) {
                                        logHttp(req, 200, 'byeSubscriber', start);
                                        res.sendStatus(200);
                                    } else {
                                        logHttp(req, 406, 'byeSubscriber', start);
                                        res.sendStatus(406);
                                    }
                                } else {
                                    // El estudiante no está en su canal
                                    logHttp(req, 404, 'byeSubscriber', start);
                                    res.sendStatus(404);
                                }
                            } else {
                                // El canal no se encuentra entre los de su propiedad por lo que no puede gestionar estudiantes
                                logHttp(req, 401, 'byeSubscriber', start);
                                res.sendStatus(401);
                            }
                        } else {
                            logHttp(req, 401, 'byeSubscriber', start);
                            res.sendStatus(401);
                        }
                    }
                } else {
                    logHttp(req, 401, 'byeSubscriber', start);
                    res.sendStatus(401);
                }
            });
    } catch (error) {
        winston.error(Mustache.render(
            'byeSubscriber || {{{error}}} || {{{time}}}',
            {
                error: error,
                time: Date.now() - start
            }
        ));
        logHttp(req, 500, 'byeSubscriber', start);
        res.sendStatus(500);
    }
}

module.exports = { subscriber, newSubscriber, byeSubscriber }