const Mustache = require('mustache');
const FirebaseAdmin = require('firebase-admin');

const winston = require('../../../../util/winston');
const { logHttp, shortId2Id, getTokenAuth } = require('../../../../util/auxiliar');
const { InfoUser, FeedsUser } = require('../../../../util/pojos/user');
const {
    getInfoUser, getFeedsUser, getInfoSubscriber, getAnswersDB, deleteAnswerFeedDB,
    updateFeedbackAnswer,
    addAnswerFeedDB } = require('../../../../util/bd');
const { FeedSubscriber } = require('../../../../util/pojos/feed');

async function objAnswer(req, res) {
    const start = Date.now();
    try {
        FirebaseAdmin.auth().verifyIdToken(getTokenAuth(req.headers.authorization))
            .then(async dToken => {
                const { uid } = dToken;
                if (uid !== '') {
                    // Comparo el uid con el identificador del usuario del canal
                    let { feed, subscriber, answer } = req.params;
                    feed = shortId2Id(feed);
                    if (feed !== null) {
                        if (uid === subscriber) {
                            // Si es el mismo es el propio usuario que está solicitando su respuesta
                            const feeds = new FeedsUser(await getFeedsUser(uid));
                            const index = feeds.subscribed.findIndex(f => {
                                return f.idFeed === feed;
                            });
                            if (index > -1) {
                                const feedSubscriber = new FeedSubscriber(feeds.subscribed.at(index));
                                if (feedSubscriber.answers === undefined || feedSubscriber.answers.length === 0) {
                                    logHttp(req, 404, 'objAnswer', start);
                                    res.sendStatus(404);
                                } else {
                                    const answers = await getAnswersDB(uid);
                                    if (answers !== null && answers !== undefined && Array.isArray(answers) && answers.length > 0) {
                                        let out = null;
                                        answers.forEach(a => {
                                            if (feedSubscriber.answers.includes(a.id) && a.id === answer) {
                                                out = a;
                                            }
                                        });
                                        if (out !== null) {
                                            winston.info(Mustache.render('objAnswer || uid: {{{uid}}} feedId: {{{feedId}}} - answer: {{{answer}}} || {{{time}}}',
                                                {
                                                    uid: uid,
                                                    feedId: feed,
                                                    answer: answer,
                                                    time: Date.now() - start
                                                }));
                                            logHttp(req, 200, 'objAnswer', start);
                                            res.send(JSON.stringify(out));
                                        } else {
                                            logHttp(req, 404, 'objAnswer', start);
                                            res.sendStatus(404);
                                        }
                                    } else {
                                        logHttp(req, 404, 'objAnswer', start);
                                        res.sendStatus(404);
                                    }
                                }
                            } else {
                                logHttp(req, 404, 'objAnswer', start);
                                res.sendStatus(404);
                            }
                        } else {
                            // También puede pasar que su profesor esté solicitando la respuesta
                            const teacher = new InfoUser(await getInfoUser(uid));
                            if (teacher.isTeacher) {
                                const feedsUser = new FeedsUser(await getFeedsUser(uid));
                                const indexFeed = feedsUser.owner.findIndex(f => {
                                    return f.id === feed;
                                });
                                if (indexFeed > -1) {
                                    if (feedsUser.owner.at(indexFeed).subscribers.includes(subscriber)) {
                                        const promesas = [];
                                        promesas.push(getAnswersDB(subscriber));
                                        promesas.push(getInfoSubscriber(subscriber, feed, false));
                                        const arrayDatos = await Promise.all(promesas);
                                        if (arrayDatos.at(0) !== null && arrayDatos.at(0) !== undefined && Array.isArray(arrayDatos.at(0)) && arrayDatos.at(0).length > 0) {
                                            let out = null;
                                            arrayDatos.at(0).forEach(a => {
                                                if (arrayDatos.at(1).answers.includes(a.id) && a.id === answer) {
                                                    out = a;
                                                }
                                            });
                                            if (out !== null) {
                                                winston.info(Mustache.render('objAnswer || uid: {{{uid}}} subscriber: {{{subscriber}}} feedId: {{{feedId}}} - answer: {{{answer}}} || {{{time}}}',
                                                    {
                                                        uid: uid,
                                                        subscriber: subscriber,
                                                        feedId: feed,
                                                        answer: answer,
                                                        time: Date.now() - start
                                                    }));
                                                logHttp(req, 200, 'objAnswer', start);
                                                res.send(JSON.stringify(out));
                                            } else {
                                                logHttp(req, 404, 'objAnswer', start);
                                                res.sendStatus(404);
                                            }
                                        } else {
                                            logHttp(req, 404, 'objAnswer', start);
                                            res.sendStatus(404);
                                        }
                                    } else {
                                        logHttp(req, 400, 'objAnswer', start);
                                        res.sendStatus(400);
                                    }
                                } else {
                                    logHttp(req, 401, 'objAnswer', start);
                                    res.sendStatus(401);
                                }
                            } else {
                                logHttp(req, 401, 'objAnswer', start);
                                res.sendStatus(401);
                            }
                        }
                    } else {
                        logHttp(req, 400, 'objAnswer', start);
                        res.sendStatus(400);
                    }
                } else {
                    logHttp(req, 401, 'objAnswer', start);
                    res.sendStatus(401);
                }
            });
    } catch (error) {
        winston.error(Mustache.render(
            'objAnswer || {{{error}}} || {{{time}}}',
            {
                error: error,
                time: Date.now() - start
            }
        ));
        logHttp(req, 500, 'objAnswer', start);
        res.sendStatus(500);
    }
}

async function updateAnswer(req, res) {
    const start = Date.now();
    try {
        FirebaseAdmin.auth().verifyIdToken(getTokenAuth(req.headers.authorization))
            .then(async dToken => {
                const { uid } = dToken;
                if (uid !== '') {
                    let { feed, subscriber, answer } = req.params;
                    feed = shortId2Id(feed);
                    if (feed !== null) {
                        if (uid === subscriber) {
                            // El usuario puede asociar una respuesta al canal
                            // Compruebo que el usuario esté subscrito al canal
                            const feedsUser = new FeedsUser(await getFeedsUser(uid));
                            const indexFeed = feedsUser.subscribed.findIndex(f => {
                                return f.idFeed === feed;
                            });
                            if (indexFeed > -1) {
                                // El usuario está subscrito al canal, pero tengo que comprobar que la tarea es de las suyas
                                const answers = await getAnswersDB(subscriber);
                                if (Array.isArray(answers) && answers.length > 0) {
                                    const indexAnswer = answers.findIndex(a => { return a.id === answer; });
                                    if (indexAnswer > -1) {
                                        // Si lo está relaciono la tarea con el canal
                                        const todoBien = await addAnswerFeedDB(uid, feed, answer);
                                        if (todoBien) {
                                            winston.info(Mustache.render('updateAnswer || uid: {{{uid}}} feedId: {{{feedId}}} - answer: {{{answer}}} || {{{time}}}',
                                                {
                                                    uid: uid,
                                                    feedId: feed,
                                                    answer: answer,
                                                    time: Date.now() - start
                                                }));
                                            logHttp(req, 204, 'updateAnswer', start);
                                            res.sendStatus(204);
                                        } else {
                                            logHttp(req, 405, 'updateAnswer - noAnswer', start);
                                            res.sendStatus(405);
                                        }
                                    } else {
                                        logHttp(req, 401, 'updateAnswer - noAnswerArray', start);
                                        res.sendStatus(401);
                                    }
                                } else {
                                    logHttp(req, 401, 'updateAnswer - noFeed', start);
                                    res.sendStatus(401);
                                }
                            } else {
                                logHttp(req, 401, 'updateAnswer', start);
                                res.sendStatus(401);
                            }
                        } else {
                            const user = new InfoUser(await getInfoUser(uid));
                            if (user.isTeacher) {
                                // El profesor puede cambiar el feedback
                                const { feedback } = req.body;
                                if (feedback !== undefined && typeof feedback === 'string') {
                                    const feedsUser = new FeedsUser(await getFeedsUser(uid));
                                    const indexFeed = feedsUser.owner.findIndex(f => {
                                        return f.id === feed;
                                    });
                                    if (indexFeed > -1) {
                                        if (feedsUser.owner.at(indexFeed).subscribers.includes(subscriber)) {
                                            const promesas = [];
                                            promesas.push(getAnswersDB(subscriber));
                                            promesas.push(getInfoSubscriber(subscriber, feed, false));
                                            const arrayDatos = await Promise.all(promesas);
                                            if (arrayDatos.at(0) !== null && arrayDatos.at(0) !== undefined && Array.isArray(arrayDatos.at(0)) && arrayDatos.at(0).length > 0) {
                                                let respuesta = null;
                                                arrayDatos.at(0).forEach(a => {
                                                    if (arrayDatos.at(1).answers.includes(a.id) && a.id === answer) {
                                                        respuesta = a;
                                                    }
                                                });
                                                if (respuesta !== null) {
                                                    respuesta.feedback = feedback;
                                                    // Tengo que actualizar el valor de esa respuesta
                                                    const todoBien = await updateFeedbackAnswer(subscriber, respuesta);
                                                    if (todoBien) {
                                                        winston.info(Mustache.render('updateAnswer || uid: {{{uid}}} subscriber: {{{subscriber}}} feedId: {{{feedId}}} - answer: {{{answer}}} || {{{time}}}',
                                                            {
                                                                uid: uid,
                                                                subscriber: subscriber,
                                                                feedId: feed,
                                                                answer: answer,
                                                                time: Date.now() - start
                                                            }));
                                                        logHttp(req, 204, 'updateAnswer', start);
                                                        res.sendStatus(204);
                                                    } else {
                                                        logHttp(req, 405, 'updateAnswer', start);
                                                        res.sendStatus(405);
                                                    }
                                                } else {
                                                    logHttp(req, 404, 'updateAnswer', start);
                                                    res.sendStatus(404);
                                                }
                                            } else {
                                                logHttp(req, 404, 'updateAnswer', start);
                                                res.sendStatus(404);
                                            }
                                        } else {
                                            logHttp(req, 401, 'updateAnswer', start);
                                            res.sendStatus(401);
                                        }
                                    } else {
                                        logHttp(req, 401, 'updateAnswer', start);
                                        res.sendStatus(401);
                                    }
                                } else {
                                    logHttp(req, 400, 'updateAnswer', start);
                                    res.sendStatus(400);
                                }
                            } else {
                                logHttp(req, 401, 'updateAnswer', start);
                                res.sendStatus(401);
                            }
                        }
                    } else {
                        logHttp(req, 400, 'updateAnswer', start);
                        res.sendStatus(400);
                    }
                } else {
                    logHttp(req, 401, 'updateAnswer', start);
                    res.sendStatus(401);
                }
            });
    } catch (error) {
        winston.error(Mustache.render(
            'updateAnswer || {{{error}}} || {{{time}}}',
            {
                error: error,
                time: Date.now() - start
            }
        ));
        logHttp(req, 500, 'updateAnswer', start);
        res.sendStatus(500);
    }
}

async function byeAnswer(req, res) {
    // Solo voy a eliminar la respuesta del feed
    const start = Date.now();
    try {
        FirebaseAdmin.auth().verifyIdToken(getTokenAuth(req.headers.authorization))
            .then(async dToken => {
                const { uid } = dToken;
                if (uid !== '') {
                    // Comparo el uid con el identificador del usuario del canal
                    let { feed, subscriber, answer } = req.params;
                    feed = shortId2Id(feed);
                    if (feed !== null) {
                        if (uid === subscriber) {
                            // Si es el mismo es el propio usuario que quiere eliminar su respuesta del canal
                            const feeds = new FeedsUser(await getFeedsUser(uid));
                            const index = feeds.subscribed.findIndex(f => {
                                return f.idFeed === feed;
                            });
                            if (index > -1) {
                                const feedSubscriber = new FeedSubscriber(feeds.subscribed.at(index));
                                if (feedSubscriber.answers === undefined || feedSubscriber.answers.length === 0 || !feedSubscriber.answers.includes(answer)) {
                                    logHttp(req, 404, 'byeAnswer', start);
                                    res.sendStatus(404);
                                } else {
                                    const eliminada = await deleteAnswerFeedDB(uid, feed, answer);
                                    if (eliminada) {
                                        winston.info(Mustache.render('byeAnswer || uid: {{{uid}}} feedId: {{{feedId}}} - answer: {{{answer}}} || {{{time}}}',
                                            {
                                                uid: uid,
                                                feedId: feed,
                                                answer: answer,
                                                time: Date.now() - start
                                            }));
                                        logHttp(req, 204, 'byeAnswer', start);
                                        res.sendStatus(204);
                                    } else {
                                        logHttp(req, 404, 'byeAnswer', start);
                                        res.sendStatus(404);
                                    }
                                }
                            } else {
                                logHttp(req, 404, 'byeAnswer', start);
                                res.sendStatus(404);
                            }
                        } else {
                            // También puede pasar que su profesor esté solicitando la respuesta
                            const teacher = new InfoUser(await getInfoUser(uid));
                            if (teacher.isTeacher) {
                                const feedsUser = new FeedsUser(await getFeedsUser(uid));
                                const indexFeed = feedsUser.owner.findIndex(f => {
                                    return f.id === feed;
                                });
                                if (indexFeed > -1) {
                                    if (feedsUser.owner.at(indexFeed).subscribers.includes(subscriber)) {
                                        const infoSubscriber = await getInfoSubscriber(subscriber, feed, false);
                                        if (infoSubscriber !== null && infoSubscriber.answers !== undefined && Array.isArray(infoSubscriber.answers) && infoSubscriber.answers.includes(answer)) {
                                            const eliminada = await deleteAnswerFeedDB(subscriber, feed, answer);
                                            if (eliminada) {
                                                winston.info(Mustache.render('byeAnswer || uid: {{{uid}}} subscriber: {{{subscriber}}} feedId: {{{feedId}}} - answer: {{{answer}}} || {{{time}}}',
                                                    {
                                                        uid: uid,
                                                        subscriber: subscriber,
                                                        feedId: feed,
                                                        answer: answer,
                                                        time: Date.now() - start
                                                    }));
                                                logHttp(req, 204, 'byeAnswer', start);
                                                res.sendStatus(204);
                                            } else {
                                                logHttp(req, 404, 'byeAnswer', start);
                                                res.sendStatus(404);
                                            }
                                        } else {
                                            logHttp(req, 404, 'byeAnswer', start);
                                            res.sendStatus(404);
                                        }
                                    } else {
                                        logHttp(req, 400, 'byeAnswer', start);
                                        res.sendStatus(400);
                                    }
                                } else {
                                    logHttp(req, 401, 'byeAnswer', start);
                                    res.sendStatus(401);
                                }
                            } else {
                                logHttp(req, 401, 'byeAnswer', start);
                                res.sendStatus(401);
                            }
                        }
                    } else {
                        logHttp(req, 400, 'byeAnswer', start);
                        res.sendStatus(400);
                    }
                } else {
                    logHttp(req, 401, 'byeAnswer', start);
                    res.sendStatus(401);
                }
            });
    } catch (error) {
        winston.error(Mustache.render(
            'objAnswer || {{{error}}} || {{{time}}}',
            {
                error: error,
                time: Date.now() - start
            }
        ));
        logHttp(req, 500, 'objAnswer', start);
        res.sendStatus(500);
    }
}

module.exports = { objAnswer, updateAnswer, byeAnswer }