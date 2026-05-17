const Mustache = require('mustache');
const FirebaseAdmin = require('firebase-admin');

const winston = require('../../../../util/winston');
const { logHttp, shortId2Id, getTokenAuth } = require('../../../../util/auxiliar');
const { InfoUser, FeedsUser } = require('../../../../util/pojos/user');
const { getInfoUser, getFeedsUser, getInfoSubscriber, getAnswersDB, findCollectionAndFeed } = require('../../../../util/bd');
const { Feed, FeedSubscriber } = require('../../../../util/pojos/feed');


async function listAnswers(req, res) {
    const start = Date.now();
    try {
        FirebaseAdmin.auth().verifyIdToken(getTokenAuth(req.headers.authorization))
            .then(async dToken => {
                const { uid } = dToken;
                if (uid !== '') {
                    let { feed, subscriber } = req.params;
                    feed = shortId2Id(feed);
                    if (feed !== null) {
                        if (subscriber === uid) {
                            // Si coincide el uid con el id del estudiante es que es un estudiante queriendo ver sus respuestas
                            // Compruebo si el feed está entre sus suyos
                            const feeds = new FeedsUser(await getFeedsUser(uid));
                            const index = feeds.subscribed.findIndex(f => {
                                return f.idFeed === feed;
                            });
                            if (index > -1) {
                                const feedSubscriber = new FeedSubscriber(feeds.subscribed.at(index));
                                if (feedSubscriber.answers === undefined || feedSubscriber.answers.length === 0) {
                                    logHttp(req, 204, 'listAnswers', start);
                                    res.sendStatus(204);
                                } else {
                                    // Traigo el documento con las respuestas y realizo yo el filtrado
                                    const answers = await getAnswersDB(uid);
                                    if (answers !== null && answers !== undefined && Array.isArray(answers) && answers.length > 0) {
                                        const out = [];
                                        answers.forEach(answer => {
                                            if (feedSubscriber.answers.includes(answer.id) && !answer.hidden) {
                                                out.push(answer);
                                            }
                                        });
                                        if (out.length > 0) {
                                            winston.info(Mustache.render('listAnswers || uid: {{{uid}}} feedId: {{{feedId}}} - nAnswers: {{{nAnswers}}} || {{{time}}}',
                                                {
                                                    uid: uid,
                                                    feedId: feed,
                                                    nAnswers: out.length,
                                                    time: Date.now() - start
                                                }));
                                            logHttp(req, 200, 'listAnswers', start);
                                            res.send(JSON.stringify(out));
                                        } else {
                                            logHttp(req, 204, 'listAnswers', start);
                                            res.sendStatus(204);
                                        }
                                    } else {
                                        logHttp(req, 204, 'listAnswers', start);
                                        res.sendStatus(204);
                                    }
                                }
                            } else {
                                logHttp(req, 400, 'listAnswers', start);
                                res.sendStatus(400);
                            }
                        } else {
                            // Si no coincide comprobar si es un profesor o co-profesor
                            const user = new InfoUser(await getInfoUser(uid));
                            if (user.isTeacher) {
                                // Comprobar si es propietario del canal
                                const feedsUser = new FeedsUser(await getFeedsUser(uid));
                                const indexFeed = feedsUser.owner.findIndex(f => f.id === feed);
                                let subscriberList = null;
                                if (indexFeed > -1) {
                                    subscriberList = feedsUser.owner.at(indexFeed).subscribers;
                                } else {
                                    // No es propietario: comprobar si es co-profesor
                                    const objCollFeed = await findCollectionAndFeed(feed);
                                    if (objCollFeed !== null) {
                                        const feedData = new Feed(objCollFeed.dataFeed);
                                        if (feedData.teachers.some(t => t.uid === uid)) {
                                            subscriberList = objCollFeed.dataFeed.subscribers;
                                        }
                                    }
                                }
                                if (subscriberList === null) {
                                    logHttp(req, 401, 'listAnswers', start);
                                    return res.sendStatus(401);
                                }
                                if (!subscriberList.includes(subscriber)) {
                                    logHttp(req, 400, 'listAnswers', start);
                                    return res.sendStatus(400);
                                }
                                // El estudiante está en el canal solicitado
                                const promesas = [];
                                promesas.push(getAnswersDB(subscriber));
                                promesas.push(getInfoSubscriber(subscriber, feed, false));
                                const arrayDatos = await Promise.all(promesas);
                                if (arrayDatos.at(0) !== null && arrayDatos.at(0) !== undefined && Array.isArray(arrayDatos.at(0)) && arrayDatos.at(0).length > 0) {
                                    const out = [];
                                    arrayDatos.at(0).forEach(answer => {
                                        if (arrayDatos.at(1).answers.includes(answer.id) && !answer.hidden) {
                                            out.push(answer);
                                        }
                                    });
                                    if (out.length > 0) {
                                        winston.info(Mustache.render('listAnswers || uid: {{{uid}}} subscriber: {{{subscriber}}} feedId: {{{feedId}}} - nAnswers: {{{nAnswers}}} || {{{time}}}',
                                            {
                                                uid: uid,
                                                subscriber: subscriber,
                                                feedId: feed,
                                                nAnswers: out.length,
                                                time: Date.now() - start
                                            }));
                                        logHttp(req, 200, 'listAnswers', start);
                                        res.send(JSON.stringify(out));
                                    } else {
                                        logHttp(req, 204, 'listAnswers', start);
                                        res.sendStatus(204);
                                    }
                                } else {
                                    logHttp(req, 204, 'listAnswers', start);
                                    res.sendStatus(204);
                                }
                            } else {
                                logHttp(req, 401, 'listAnswers', start);
                                res.sendStatus(401);
                            }
                        }
                    } else {
                        logHttp(req, 400, 'listAnswers', start);
                        res.sendStatus(400);
                    }
                } else {
                    logHttp(req, 401, 'listAnswers', start);
                    res.sendStatus(401);
                }
            });
    } catch (error) {
        winston.error(Mustache.render(
            'listAnswers || {{{error}}} || {{{time}}}',
            {
                error: error,
                time: Date.now() - start
            }
        ));
        logHttp(req, 500, 'listAnswers', start);
        res.sendStatus(500);
    }
}


module.exports = { listAnswers }