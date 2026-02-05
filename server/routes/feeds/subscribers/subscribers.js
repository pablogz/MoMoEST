const Mustache = require('mustache');
const FirebaseAdmin = require('firebase-admin');

const winston = require('../../../util/winston');
const { logHttp, getTokenAuth, shortId2Id } = require('../../../util/auxiliar');
const { InfoUser, FeedsUser } = require('../../../util/pojos/user');
const { getInfoUser, getFeedsUser, getInfoSubscriber } = require('../../../util/bd');
const { Feed } = require('../../../util/pojos/feed');


async function listSubscribers(req, res) {
    const start = Date.now();
    try {
        // Recupero el identificador del usuario
        FirebaseAdmin.auth().verifyIdToken(getTokenAuth(req.headers.authorization))
            .then(async dToken => {
                const { uid } = dToken;
                if (uid !== '') {
                    // Recupero la información del usuario para conocer si es profesor
                    const infoUser = new InfoUser(await getInfoUser(uid));
                    if (infoUser.isTeacher) {
                        // Recupero el identificador del canal y compruebo si está entre los suyos
                        const feedsUser = new FeedsUser(await getFeedsUser(uid));
                        const shortIdFeed = req.params.feed;
                        const idFeed = shortId2Id(shortIdFeed);
                        if (idFeed !== null) {
                            const index = feedsUser.owner.findIndex(feed => {
                                feed = new Feed(feed);
                                return feed.id === idFeed;
                            });
                            if (index > -1) {
                                const feed = new Feed(feedsUser.owner.at(index));
                                // Al cliente le envío una lista de objetos que contrendrá: el identificador del subscriber, la fecha de subscripción, su alias (si lo tuviera), el número de respuestas que tiene hasta ese momento
                                const out = [];
                                const promesas = [];
                                for (let i = 0, tama = feed.subscribers.length; i < tama; i++) {
                                    promesas.push(getInfoSubscriber(feed.subscribers.at(i), feed.id));
                                }
                                const arrayObjetos = await Promise.all(promesas);
                                arrayObjetos.forEach(obj => {
                                    if (obj !== null) {
                                        out.push(obj);
                                    }
                                });
                                // Envío al cliente la respuesta
                                winston.info(Mustache.render('listSubscribers || idUser: {{{idUser}}} - subscribers: {{{ns}}} || {{{time}}}', {
                                    idUser: uid,
                                    ns: out.length,
                                    time: Date.now() - start
                                }));
                                if (out.length > 0) {
                                    logHttp(req, 200, 'listSubscribers', start);
                                    res.send(JSON.stringify(out));
                                } else {
                                    logHttp(req, 204, 'listSubscribers', start);
                                    res.sendStatus(204);
                                }
                            } else {
                                logHttp(req, 404, 'listSubscribers', start);
                                res.sendStatus(404);
                            }
                        } else {
                            logHttp(req, 400, 'listSubscribers', start);
                            res.sendStatus(400);
                        }
                    } else {
                        logHttp(req, 401, 'listSubscribers', start);
                        res.sendStatus(401);
                    }
                } else {
                    logHttp(req, 401, 'listSubscribers', start);
                    res.sendStatus(401);
                }
            });
    } catch (error) {
        winston.error(Mustache.render(
            'listSubscribers || {{{error}}} || {{{time}}}',
            {
                error: error,
                time: Date.now() - start
            }
        ));
        logHttp(req, 500, 'listSubscribers', start);
        res.sendStatus(500);
    }
}

module.exports = { listSubscribers }