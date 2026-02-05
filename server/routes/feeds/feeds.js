const Mustache = require('mustache');
const FirebaseAdmin = require('firebase-admin');

const { logHttp, getTokenAuth, generateUid } = require('../../util/auxiliar');
const winston = require('../../util/winston');
const { getInfoUser, getFeedsUser, getFeed, saveNewFeed } = require('../../util/bd');
const { Feed, FeedSubscriber } = require('../../util/pojos/feed');
const { InfoUser, FeedsUser } = require('../../util/pojos/user');

async function listFeeds(req, res) {
    const start = Date.now();
    try {
        FirebaseAdmin.auth().verifyIdToken(getTokenAuth(req.headers.authorization))
            .then(async dToken => {
                const { uid } = dToken;
                if (uid !== '') {
                    getInfoUser(uid).then(async infoUser => {
                        if (infoUser !== null) {
                            // Creo al usuario con sus datos
                            const user = new InfoUser(infoUser);
                            // Recupero la lista de feeds
                            getFeedsUser(user.id).then(async feedsUserDocument => {
                                const feedsToClient = {};
                                let nFeeds = 0;
                                const feedsUser = new FeedsUser(feedsUserDocument);
                                // Compruebo si ha creado algún canal. Si es así lo agrego para enviárselo al cliente
                                if (user.isTeacher) {
                                    feedsToClient.owner = feedsUser.owner;
                                    nFeeds += feedsToClient.owner.length;
                                }

                                // Compruebo si está subscrito a algún canal. 
                                if (feedsUser.subscribed.length > 0) {
                                    const promesas = [];
                                    const feedsSubscriptor = [];
                                    for (let i = 0, tama = feedsUser.subscribed.length; i < tama; i++) {
                                        const feedSubscriptor = new FeedSubscriber(feedsUser.subscribed.at(i));
                                        feedsSubscriptor.push(feedSubscriptor);
                                        promesas.push(getFeed(feedSubscriptor.idOwner, feedSubscriptor.idFeed));
                                    }
                                    // Recupero la información de cada canal para enviárselo al cliente
                                    const arrayFeeds = await Promise.all(promesas);
                                    if (feedsSubscriptor.length > 0) {
                                        feedsToClient.subscribed = [];
                                        // Preparo la información que le envío al usuario
                                        for (let i = 0, tama = arrayFeeds.length; i < tama; i++) {
                                            const feed = arrayFeeds.at(i);
                                            const feedSubscriptor = feedsSubscriptor.at(i);
                                            const f = feed.toSubscriber();
                                            f.date = feedSubscriptor.date;
                                            f.owner = feedSubscriptor.idOwner;
                                            f.answers = feedSubscriptor.answers;
                                            feedsToClient.subscribed.push(f);
                                            nFeeds += 1;
                                        }
                                    }
                                }
                                // Si hay algún canal se los envío con el código de estado 200
                                if (nFeeds > 0) {
                                    winston.info(Mustache.render('listFeeds || idUser: {{{idUser}}} - nFeeds: {{{nFeeds}}} || {{{time}}}', {
                                        idUser: user.id,
                                        nFeeds: nFeeds,
                                        time: Date.now() - start
                                    }));
                                    logHttp(req, 200, 'listFeeds', start);
                                    res.send(JSON.stringify(feedsToClient));
                                } else {
                                    winston.info(Mustache.render('listFeeds || empty || {{{time}}}', { time: Date.now() - start }));
                                    logHttp(req, 204, 'listFeeds', start);
                                    res.sendStatus(204);
                                }
                            });
                        } else {
                            // El usuario no está en la base de datos
                            logHttp(req, 404, 'listFeeds', start);
                            res.sendStatus(404);
                        }
                    });
                } else {
                    logHttp(req, 401, 'listFeeds', start);
                    res.sendStatus(401);
                }
            });
    } catch (error) {
        winston.error(Mustache.render(
            'listFeeds || {{{error}}} || {{{time}}}',
            {
                error: error,
                time: Date.now() - start
            }
        ));
        logHttp(req, 500, 'listFeeds', start);
        res.sendStatus(500);
    }
}

async function newFeed(req, res) {
    const start = Date.now();
    try {
        // (1) Compruebo la identidad del usuario
        FirebaseAdmin.auth().verifyIdToken(getTokenAuth(req.headers.authorization))
            .then(async dToken => {
                const { uid } = dToken;
                if (uid !== '') {
                    getInfoUser(uid).then(async infoUser => {
                        if (infoUser !== null) {
                            const user = new InfoUser(infoUser);
                            if (user.isTeacher) {
                                // (2) Compruebo el cuerpo del objeto que me ha enviado el usuario
                                if (req.body) {
                                    let save = true;
                                    let { labels, comments, password } = req.body;
                                    if (typeof labels === 'object') {
                                        labels = [labels];
                                    }
                                    labels.forEach(label => {
                                        if (!(typeof label === 'object' &&
                                            label.value !== undefined && typeof label.value === 'string' &&
                                            label.lang !== undefined && typeof label.lang === 'string')) {
                                            save = false;
                                        }
                                    });

                                    if (save) {
                                        if (typeof comments === 'object') {
                                            comments = [comments];
                                        }

                                        comments.forEach(label => {
                                            if (!(typeof label === 'object' &&
                                                label.value !== undefined && typeof label.value === 'string' &&
                                                label.lang !== undefined && typeof label.lang === 'string')) {
                                                save = false;
                                            }
                                        });

                                        if (save) {
                                            // (3) Preparo para guardar y envío al cliente el identificador del nuevo canal
                                            const dataFeed = {}
                                            dataFeed.id = await generateUid();
                                            dataFeed.labels = labels;
                                            dataFeed.comments = comments;
                                            dataFeed.password = password;
                                            dataFeed.date = (new Date(Date.now())).toISOString();
                                            dataFeed.owner = uid;
                                            const feed = new Feed(dataFeed);
                                            const id = await saveNewFeed(user.id, feed);
                                            if (id !== null) {
                                                winston.info(Mustache.render(
                                                    'newFeed || 201 - {{{id}}} || {{{time}}}',
                                                    {
                                                        id: feed.id,
                                                        time: Date.now() - start
                                                    }
                                                ));
                                                logHttp(req, 201, 'newFeed', start);
                                                res.location(feed.id).sendStatus(201);
                                            } else {
                                                winston.error(Mustache.render(
                                                    'newFeed || 500 - I can\'t save the feed || {{{time}}}',
                                                    {
                                                        time: Date.now() - start
                                                    }
                                                ));
                                                logHttp(req, 500, 'newFeed', start);
                                                res.sendStatus(500);
                                            }
                                        } else {
                                            winston.info(Mustache.render(
                                                'newFeed || 400 - comments || {{{time}}}',
                                                {
                                                    time: Date.now() - start
                                                }
                                            ));
                                            logHttp(req, 400, 'newFeed', start);
                                            res.sendStatus(400);
                                        }
                                    } else {
                                        winston.info(Mustache.render(
                                            'newFeed || 400 - labels || {{{time}}}',
                                            {
                                                time: Date.now() - start
                                            }
                                        ));
                                        logHttp(req, 400, 'newFeed', start);
                                        res.sendStatus(400);
                                    }
                                } else {
                                    winston.info(Mustache.render(
                                        'newFeed || 401 || {{{time}}}',
                                        {
                                            time: Date.now() - start
                                        }
                                    ));
                                    logHttp(req, 401, 'newFeed', start);
                                    res.sendStatus(401);
                                }
                            }
                        } else {
                            winston.info(Mustache.render(
                                'newFeed || 404 - {{{uid}}} || {{{time}}}',
                                {
                                    uid: uid,
                                    time: Date.now() - start
                                }
                            ));
                            logHttp(req, 404, 'newFeed', start);
                            res.sendStatus(404);
                        }
                    });
                } else {
                    winston.info(Mustache.render(
                        'newFeed || 403 - Verify email || {{{time}}}',
                        {
                            time: Date.now() - start
                        }
                    ));
                    logHttp(req, 403, 'newFeed', start);
                    res.status(403).send('You have to verify your email!');
                }
            });
    } catch (error) {
        winston.error(Mustache.render(
            'newFeed || 500 || {{{time}}}',
            {
                time: Date.now() - start
            }
        ));
        res.sendStatus(500);
    }
}

module.exports = {
    listFeeds,
    newFeed,
}