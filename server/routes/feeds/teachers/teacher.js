const Mustache = require('mustache');
const FirebaseAdmin = require('firebase-admin');

const winston = require('../../../util/winston');
const { logHttp, getTokenAuth, shortId2Id } = require('../../../util/auxiliar');
const { InfoUser, FeedsUser } = require('../../../util/pojos/user');
const { Feed } = require('../../../util/pojos/feed');
const {
    getInfoUser, getFeedsUser, findCollectionAndFeed,
    addTeacherToFeed, removeTeacherFromFeed,
    updateTeachingFeedBD, deleteTeachingFeedBD
} = require('../../../util/bd');

async function newTeacher(req, res) {
    const start = Date.now();
    try {
        FirebaseAdmin.auth().verifyIdToken(getTokenAuth(req.headers.authorization))
            .then(async dToken => {
                const { uid } = dToken;
                if (uid !== '') {
                    const user = new InfoUser(await getInfoUser(uid));
                    // Solo un profesor puede unirse como co-profesor
                    if (!user.isTeacher) {
                        logHttp(req, 401, 'newTeacher', start);
                        return res.sendStatus(401);
                    }
                    const teacherId = req.params.teacher;
                    // El usuario solo puede registrarse a sí mismo
                    if (uid !== teacherId) {
                        logHttp(req, 403, 'newTeacher', start);
                        return res.sendStatus(403);
                    }
                    const feedId = shortId2Id(req.params.feed);
                    if (feedId === null) {
                        logHttp(req, 400, 'newTeacher', start);
                        return res.sendStatus(400);
                    }
                    // Busco el canal en todas las colecciones
                    const objCollFeed = await findCollectionAndFeed(feedId);
                    if (objCollFeed === null) {
                        logHttp(req, 404, 'newTeacher', start);
                        return res.sendStatus(404);
                    }
                    const ownerId = objCollFeed.userId;
                    const feed = new Feed(objCollFeed.dataFeed);
                    // El propietario no puede ser co-profesor de su propio canal
                    if (ownerId === uid) {
                        logHttp(req, 409, 'newTeacher', start);
                        return res.sendStatus(409);
                    }
                    // Ya es co-profesor
                    if (feed.teachers.includes(uid)) {
                        logHttp(req, 400, 'newTeacher', start);
                        return res.sendStatus(400);
                    }
                    // Si el canal tiene contraseña, la compruebo
                    const { password } = req.body;
                    if (feed.password !== null && feed.password !== undefined) {
                        if (password !== feed.password) {
                            logHttp(req, 400, 'newTeacher', start);
                            return res.sendStatus(400);
                        }
                    }
                    // Añado el profesor al array teachers del canal y el canal al array teaching del profesor
                    const teachingObj = {
                        idFeed: feedId,
                        idOwner: ownerId,
                        date: (new Date(Date.now())).toISOString(),
                    };
                    const [okFeed, okTeacher] = await Promise.all([
                        addTeacherToFeed(ownerId, feedId, uid),
                        updateTeachingFeedBD(uid, teachingObj),
                    ]);
                    const todoBien = okFeed && okTeacher;
                    winston.info(Mustache.render('newTeacher || idUser: {{{uid}}} - idFeed: {{{feed}}} - allOk: {{{ok}}} || {{{time}}}', {
                        uid, feed: feedId, ok: todoBien, time: Date.now() - start
                    }));
                    if (todoBien) {
                        logHttp(req, 204, 'newTeacher', start);
                        res.sendStatus(204);
                    } else {
                        logHttp(req, 406, 'newTeacher', start);
                        res.sendStatus(406);
                    }
                } else {
                    logHttp(req, 401, 'newTeacher', start);
                    res.sendStatus(401);
                }
            });
    } catch (error) {
        winston.error(Mustache.render('newTeacher || {{{error}}} || {{{time}}}', { error, time: Date.now() - start }));
        logHttp(req, 500, 'newTeacher', start);
        res.sendStatus(500);
    }
}

async function byeTeacher(req, res) {
    const start = Date.now();
    try {
        FirebaseAdmin.auth().verifyIdToken(getTokenAuth(req.headers.authorization))
            .then(async dToken => {
                const { uid } = dToken;
                if (uid !== '') {
                    const feedId = shortId2Id(req.params.feed);
                    const teacherId = req.params.teacher;
                    if (feedId === null) {
                        logHttp(req, 400, 'byeTeacher', start);
                        return res.sendStatus(400);
                    }
                    // El co-profesor puede darse de baja él mismo; el propietario puede expulsar a un co-profesor
                    const isSelf = uid === teacherId;
                    if (!isSelf) {
                        // Solo el propietario del canal puede expulsar a un co-profesor
                        const feedsUser = new FeedsUser(await getFeedsUser(uid));
                        const isOwner = feedsUser.owner.some(f => {
                            const feed = new Feed(f);
                            return feed.id === feedId;
                        });
                        if (!isOwner) {
                            logHttp(req, 401, 'byeTeacher', start);
                            return res.sendStatus(401);
                        }
                    }
                    // Busco el canal para obtener el id del propietario
                    const objCollFeed = await findCollectionAndFeed(feedId);
                    if (objCollFeed === null) {
                        logHttp(req, 404, 'byeTeacher', start);
                        return res.sendStatus(404);
                    }
                    const ownerId = objCollFeed.userId;
                    const feed = new Feed(objCollFeed.dataFeed);
                    if (!feed.teachers.includes(teacherId)) {
                        logHttp(req, 404, 'byeTeacher', start);
                        return res.sendStatus(404);
                    }
                    const [okFeed, okTeacher] = await Promise.all([
                        removeTeacherFromFeed(ownerId, feedId, teacherId),
                        deleteTeachingFeedBD(teacherId, feedId),
                    ]);
                    const todoBien = okFeed && okTeacher;
                    winston.info(Mustache.render('byeTeacher || idUser: {{{uid}}} - teacher: {{{teacher}}} - idFeed: {{{feed}}} - allOk: {{{ok}}} || {{{time}}}', {
                        uid, teacher: teacherId, feed: feedId, ok: todoBien, time: Date.now() - start
                    }));
                    if (todoBien) {
                        logHttp(req, 200, 'byeTeacher', start);
                        res.sendStatus(200);
                    } else {
                        logHttp(req, 406, 'byeTeacher', start);
                        res.sendStatus(406);
                    }
                } else {
                    logHttp(req, 401, 'byeTeacher', start);
                    res.sendStatus(401);
                }
            });
    } catch (error) {
        winston.error(Mustache.render('byeTeacher || {{{error}}} || {{{time}}}', { error, time: Date.now() - start }));
        logHttp(req, 500, 'byeTeacher', start);
        res.sendStatus(500);
    }
}

module.exports = { newTeacher, byeTeacher };
