const Mustache = require('mustache');
const fetch = require('node-fetch');
const FirebaseAdmin = require('firebase-admin');

const { options4Request, mergeResults, sparqlResponse2Json, getTokenAuth, logHttp, shortId2Id } = require('../../util/auxiliar');
const { isAuthor, taskInIt0, taskInIt1, getInfoTask, checkInfo, deleteInfoPoi, addInfoPoi, deleteObject } = require('../../util/queries');
const { getInfoUser } = require('../../util/bd');

const winston = require('../../util/winston');

/**
 *
 * @param {*} req
 * @param {*} res
 */
function getTask(req, res) {
    const start = Date.now();
    try {
        // const idTask = Mustache.render('http://chest.gsic.uva.es/data/{{{task}}}', { task: req.params.task });
        const idTask = shortId2Id(req.params.task);
        const options = options4Request(getInfoTask(idTask));
        fetch(options.url, options.init)
            .then(r => {
                return r.json();
            }).then(json => {
                const task = mergeResults(sparqlResponse2Json(json), 'task');
                if (!task.length) {
                    winston.info(Mustache.render(
                        'getTask || {{{uid}}} || {{{time}}}',
                        {
                            uid: idTask,
                            time: Date.now() - start
                        }
                    ));
                    logHttp(req, 404, 'getTask', start);
                    res.sendStatus(404);
                } else {
                    const out = JSON.stringify(task.pop());
                    winston.info(Mustache.render(
                        'getTask || {{{uid}}} || {{{body}}} || {{{time}}}',
                        {
                            uid: idTask,
                            body: out,
                            time: Date.now() - start
                        }
                    ));
                    logHttp(req, 200, 'getTask', start);
                    res.send(out);
                }
            });
    } catch (error) {
        winston.error(Mustache.render(
            'getTask || {{{error}}} || {{{time}}}',
            {
                error: error,
                time: Date.now() - start
            }
        ));
        logHttp(req, 500, 'getTask', start);
        res.status(500).send(error);
    }
}

/**
 *
 * @param {*} req
 * @param {*} res
 */
async function editTask(req, res) {
    const start = Date.now();
    try {
        const idTask = Mustache.render('http://moult.gsic.uva.es/data/{{{task}}}', { task: req.params.task });
        FirebaseAdmin.auth().verifyIdToken(getTokenAuth(req.headers.authorization))
            .then(async dToken => {
                const { uid } = dToken;
                if ( uid !== '') {
                    getInfoUser(uid).then(async infoUser => {
                        if (infoUser !== null && infoUser.rol.includes('TEACHER')) {
                            let { body } = req;
                            if (body && body.body) {
                                body = body.body;
                                let options = options4Request(isAuthor(idTask, `http://moult.gsic.uva.es/data/${infoUser.id}`));
                                fetch(options.url, options.init)
                                    .then(r => {
                                        return r.json();
                                    }).then(json => {
                                        if (json.boolean === true || infoUser.rol === 0) {
                                            const add = {};
                                            const remove = {};
                                            try {
                                                body.forEach(v => {
                                                    const k = Object.keys(v);
                                                    switch (v[k[0]].action) {
                                                        case 'UPDATE':
                                                            if (!v[k[0]].newValue || !v[k[0]].oldValue) {
                                                                throw new Error('400');
                                                            } else {
                                                                add[k[0]] = v[k[0]].newValue;
                                                                remove[k[0]] = v[k[0]].oldValue;
                                                            }
                                                            break;
                                                        case 'ADD':
                                                            if (!v[k[0]].value) {
                                                                throw new Error('400');
                                                            } else {
                                                                add[k[0]] = v[k[0]].value;
                                                            }
                                                            break;
                                                        case 'REMOVE':
                                                            if (!v[k[0]].value) {
                                                                throw new Error('400');
                                                            } else {
                                                                remove[k[0]] = v[k[0]].value;
                                                            }
                                                            break;
                                                        default:
                                                            throw new Error('400');
                                                    }
                                                });
                                                options = options4Request(checkInfo(idTask, remove));
                                                fetch(options.url, options.init)
                                                    .then(r => {
                                                        return r.json();
                                                    }).then(json => {
                                                        if (json.boolean === true) {
                                                            //TODO tengo que controlar cuando han finalizado las promesas
                                                            const requestsDelete = deleteInfoPoi(idTask, remove);
                                                            requestsDelete.forEach(request => {
                                                                options = options4Request(request, true);
                                                                fetch(options.url, options.init);
                                                            });
                                                            const requestsAdd = addInfoPoi(idTask, add);
                                                            requestsAdd.forEach(request => {
                                                                options = options4Request(request, true);
                                                                fetch(options.url, options.init);
                                                            });
                                                            winston.info(Mustache.render(
                                                                'editTask || {{{uid}}} || {{{idTask}}} || {{{time}}}',
                                                                {
                                                                    uid: uid,
                                                                    idTask: idTask,
                                                                    time: Date.now() - start
                                                                }
                                                            ));
                                                            logHttp(req, 401, 'editTask', start);
                                                            res.sendStatus(202);
                                                        } else {
                                                            winston.info(Mustache.render(
                                                                'editTask || 400 - {{{uid}}} || {{{time}}}',
                                                                {
                                                                    uid: uid,
                                                                    time: Date.now() - start
                                                                }
                                                            ));
                                                            logHttp(req, 401, 'editTask', start);
                                                            res.sendStatus(400);
                                                        }
                                                    });
                                            } catch (error) {
                                                winston.info(Mustache.render(
                                                    'editTask || 400 - {{{uid}}} || {{{time}}}',
                                                    {
                                                        uid: uid,
                                                        time: Date.now() - start
                                                    }
                                                ));
                                                logHttp(req, 401, 'editTask', start);
                                                res.sendStatus(400);
                                            }
                                        } else {
                                            winston.info(Mustache.render(
                                                'editTask || 401 - {{{uid}}} - User is not the author of the POI || {{{time}}}',
                                                {
                                                    uid: uid,
                                                    time: Date.now() - start
                                                }
                                            ));
                                            logHttp(req, 401, 'editTask', start);
                                            res.status(401).send('User is not the author of the POI');
                                        }
                                    });

                            } else {
                                winston.info(Mustache.render(
                                    'editTask || 400 - {{{uid}}} || {{{time}}}',
                                    {
                                        uid: uid,
                                        time: Date.now() - start
                                    }
                                ));
                                logHttp(req, 401, 'editTask', start);
                                res.sendStatus(400);
                            }
                        } else {
                            winston.info(Mustache.render(
                                'editTask || 401 - {{{uid}}}|| {{{time}}}',
                                {
                                    uid: uid,
                                    time: Date.now() - start
                                }
                            ));
                            logHttp(req, 401, 'editTask', start);
                            res.sendStatus(401);
                        }
                    });
                } else {
                    winston.error(Mustache.render(
                        'editTask || 403 - {{{idUser}}} || {{{time}}}',
                        {
                            idUser: uid,
                            time: Date.now() - start
                        }
                    ));
                    logHttp(req, 403, 'editTask', start);
                    res.status(403).send('You have to verify your email!');
                }
            }).catch(error => {
                winston.info(Mustache.render(
                    'editTask || 401 - {{{error}}} || {{{time}}}',
                    {
                        error: error,
                        time: Date.now() - start
                    }
                ));
                logHttp(req, 401, 'editTask', start);
                res.sendStatus(401);
            });
    } catch (error) {
        winston.error(Mustache.render(
            'editTask || {{{error}}} || {{{time}}}',
            {
                error: error,
                time: Date.now() - start
            }
        ));
        logHttp(req, 500, 'editTask', start);
        res.status(500).send(error);
    }
}

/**
 *
 * @param {*} req
 * @param {*} res
 */
async function deleteTask(req, res) {
    const start = Date.now();
    try {
        // const idTask = Mustache.render('http://chest.gsic.uva.es/data/{{{task}}}', { task: req.params.task });
        const idTask = shortId2Id(req.params.task);
        const idFeature = req.query.feature !== undefined ? shortId2Id(req.query.feature) : undefined;
        FirebaseAdmin.auth().verifyIdToken(getTokenAuth(req.headers.authorization))
            .then(async dToken => {
                const { uid } = dToken;
                if (uid !== '') {
                    getInfoUser(uid).then(async infoUser => {
                        if (infoUser !== null && infoUser.rol.includes('TEACHER')) {
                            let options = options4Request(isAuthor(idTask, `http://moult.gsic.uva.es/data/${infoUser.id}`));
                            fetch(options.url, options.init)
                                .then(r => {
                                    return r.json();
                                }).then(json => {
                                    if (json.boolean === true) {
                                        options = options4Request(taskInIt0(idTask));
                                        fetch(options.url, options.init)
                                            .then(r => {
                                                return r.json();
                                            }).then(json => {
                                                if (json.boolean === false) {
                                                    options = options4Request(taskInIt1(idTask));
                                                    fetch(options.url, options.init)
                                                        .then(r => {
                                                            return r.json();
                                                        }).then(json => {
                                                            if (json.boolean === false) {
                                                                options = options4Request(deleteObject(idTask), true);
                                                                fetch(options.url, options.init)
                                                                    .then(r => {
                                                                        winston.info(Mustache.render(
                                                                            'deleteTask || {{{uid}}} || {{{idTask}}} || {{{time}}}',
                                                                            {
                                                                                uid: uid,
                                                                                idTask: idTask,
                                                                                time: Date.now() - start
                                                                            }
                                                                        ));
                                                                        logHttp(req, r.status, 'deleteTask', start);
                                                                        res.sendStatus(r.status);
                                                                    }
                                                                    ).catch(error => res.status(500).send(error));
                                                            } else {
                                                                winston.info(Mustache.render(
                                                                    'deleteTask || {{{uid}}} || {{{idTask}}} || This task has associated itineraries || {{{time}}}',
                                                                    {
                                                                        uid: uid,
                                                                        idTask: idTask,
                                                                        time: Date.now() - start
                                                                    }
                                                                ));
                                                                logHttp(req, 401, 'deleteTask', start);
                                                                res.status(401).send('This task has associated itineraries');
                                                            }
                                                        });
                                                } else {
                                                    winston.info(Mustache.render(
                                                        'deleteTask || {{{uid}}} || {{{idTask}}} || This task has associated itineraries || {{{time}}}',
                                                        {
                                                            uid: uid,
                                                            idTask: idTask,
                                                            time: Date.now() - start
                                                        }
                                                    ));
                                                    logHttp(req, 401, 'deleteTask', start);
                                                    res.status(401).send('This task has associated itineraries');
                                                }
                                            });
                                    } else {
                                        winston.info(Mustache.render(
                                            'deleteTask || {{{uid}}} || {{{idTask}}} || User is not the author of the task || {{{time}}}',
                                            {
                                                uid: uid,
                                                idTask: idTask,
                                                time: Date.now() - start
                                            }
                                        ));
                                        logHttp(req, 401, 'deleteTask', start);
                                        res.status(401).send('User is not the author of the task');
                                    }
                                });
                        } else {
                            winston.info(Mustache.render(
                                'deleteTask || {{{uid}}} || {{{idTask}}} || {{{time}}}',
                                {
                                    uid: uid,
                                    idTask: idTask,
                                    time: Date.now() - start
                                }
                            ));
                            logHttp(req, 401, 'deleteTask', start);
                            res.sendStatus(401);
                        }
                    });
                } else {
                    winston.info(Mustache.render(
                        'deleteTask || {{{uid}}} || {{{idTask}}} || {{{time}}}',
                        {
                            uid: uid,
                            idTask: idTask,
                            time: Date.now() - start
                        }
                    ));
                    logHttp(req, 403, 'deleteTask', start);
                    res.status(403).send('You have to verify your email!');
                }
            }).catch(error => {
                winston.info(Mustache.render(
                    'deleteTask || {{{idTask}}} || {{{error}}} || {{{time}}}',
                    {
                        idTask: idTask,
                        error: error,
                        time: Date.now() - start
                    }
                ));
                logHttp(req, 401, 'deleteTask', start);
                res.sendStatus(401);
            });
    } catch (error) {
        winston.error(Mustache.render(
            'deleteTask || {{{error}}} || {{{time}}}',
            {
                error: error,
                time: Date.now() - start
            }
        ));
        logHttp(req, 500, 'deleteTask', start);
        res.status(500).send(error.menssage);
    }
}

module.exports = {
    getTask,
    editTask,
    deleteTask,
};
