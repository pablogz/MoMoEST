const FirebaseAdmin = require('firebase-admin');
const Mustache = require('mustache');
const fetch = require('node-fetch');

const { Itinerary, PointItinerary } = require("../../util/pojos/itinerary");
const { getTokenAuth, generateUid, options4Request, sparqlResponse2Json, mergeResults, logHttp } = require('../../util/auxiliar');
const { getInfoUser } = require('../../util/bd');
const { insertItinerary, getAllItineraries } = require('../../util/queries');
const { Task } = require('../../util/pojos/tasks');

const winston = require('../../util/winston');

// curl "localhost:11110/itineraries" -v
function getItineariesServer(req, res) {
    const start = Date.now();
    try {
        const options = options4Request(getAllItineraries());
        fetch(options.url, options.init)
            .then(r => { return r.json(); })
            .then(json => {
                const itineraries = mergeResults(sparqlResponse2Json(json), 'it');
                if (itineraries.length > 0) {
                    itineraries.sort((a, b) => b.update - a.update);
                    const itsResponse = [];
                    itineraries.forEach(element => {
                        const v = {};
                        for (let ele in element) {
                            switch (ele) {
                                case 'type':
                                    for (let t of element[ele]) {
                                        if (t !== 'http://moult.gsic.uva.es/ontology/Itinerary') {
                                            switch (t) {
                                                case 'http://moult.gsic.uva.es/ontology/ListItinerary':
                                                case 'http://moult.gsic.uva.es/ontology/BagSTsListTasksItinerary':
                                                case 'http://moult.gsic.uva.es/ontology/ListSTsBagTasks':
                                                case 'http://moult.gsic.uva.es/ontology/BagItinerary':
                                                    v[ele] = t;
                                                    break;
                                                default:
                                                    break;
                                            }
                                            break;
                                        }
                                    }
                                    break;
                                case 'it':
                                    v['id'] = element[ele];
                                    break;
                                default:
                                    v[ele] = element[ele];
                                    break;
                            }
                        }
                        itsResponse.push(v);
                    });
                    winston.info(Mustache.render(
                        'getItineraries || {{{body}}} || {{{time}}}',
                        {
                            body: JSON.stringify(itsResponse),
                            time: Date.now() - start
                        }
                    ));
                    logHttp(req, 200, 'getItineraries', start);
                    res.send(JSON.stringify(itsResponse));
                } else {
                    winston.info(Mustache.render(
                        'getItineraries || empty || {{{time}}}',
                        {
                            time: Date.now() - start
                        }
                    ));
                    logHttp(req, 204, 'getItineraries', start);
                    res.sendStatus(204);
                }
            })
    } catch (error) {
        winston.error(Mustache.render(
            'getItineraries || 500 || {{{time}}}',
            {
                time: Date.now() - start
            }
        ));
        res.sendStatus(500);
    }
}

async function newItineary(req, res) {
    const start = Date.now();
    try {
        // 0
        if (req.body) {
            const { type, points } = req.body;
            let { label, comment } = req.body;
            if (type !== undefined &&
                typeof type === 'string' &&
                points !== undefined &&
                Array.isArray(points) &&
                label !== undefined &&
                comment !== undefined) {
                let sigue = true;
                const itinerary = Itinerary.ItineraryEmpty();
                itinerary.setId(await generateUid());
                itinerary.setType(type);
                sigue = itinerary.type != null;
                if (sigue) {
                    if (!Array.isArray(label)) {
                        label = [label];
                    }
                    for (let l of label) {
                        if (l.value === undefined || l.lang === undefined) {
                            sigue = false;
                            break;
                        }
                    }
                    if (sigue) {
                        itinerary.setLabels(label);
                        if (!Array.isArray(comment)) {
                            comment = [comment];
                        }
                        for (let l of comment) {
                            if (l.value === undefined || l.lang === undefined) {
                                sigue = false;
                                break;
                            }
                        }
                        if (sigue) {
                            itinerary.setComments(comment);
                            for (let point of points) {
                                try {
                                    if (point.id !== undefined &&
                                        point.tasks !== undefined &&
                                        typeof point.id === 'string' &&
                                        Array.isArray(point.tasks)) {
                                        if (typeof point.altComment !== 'undefined') {
                                            itinerary.addPoint(new PointItinerary(point.id, point.altComment, point.tasks))
                                        } else {
                                            itinerary.addPoint(PointItinerary.WitoutComment(point.id, point.tasks));
                                        }
                                    } else {
                                        sigue = false;
                                        break;
                                    }
                                } catch (error) {
                                    // console.log(error);
                                    sigue = false;
                                    break;
                                }
                            }
                            if (sigue) {
                                if (req.body.track !== undefined) {
                                    req.body.track = {
                                        id: await generateUid(),
                                        points: req.body.track
                                    }
                                    itinerary.setTrack(req.body.track);
                                }
                            }
                        }
                    }
                }
                if (sigue) {
                    // 1
                    FirebaseAdmin.auth().verifyIdToken(getTokenAuth(req.headers.authorization))
                        .then(async dToken => {
                            const { uid } = dToken;
                            if (uid !== '') {
                                // 2
                                getInfoUser(uid).then(async infoUser => {
                                    if (infoUser !== null && infoUser.rol.includes('TEACHER')) {
                                        // 3
                                        infoUser.id = infoUser.id.includes('http://moult.gsic.uva.es/data/') ? infoUser.id : `http://moult.gsic.uva.es/data/${infoUser.id}`;
                                        itinerary.setAuthor(infoUser.id);
                                        if (typeof req.body.tasks !== 'undefined') {
                                            let tasksItServer = req.body.tasks;
                                            if (!Array.isArray(tasksItServer)) {
                                                tasksItServer = [tasksItServer];
                                            }
                                            for (const t of tasksItServer) {
                                                try {
                                                    const idTask = await generateUid();
                                                    const task = new Task(t);
                                                    task.id = idTask;
                                                    task.author = itinerary.author;
                                                    task.idContainer = itinerary.id;
                                                    itinerary.addTask(task);
                                                } catch (error) {
                                                    console.error(error);
                                                }
                                            }
                                        }
                                        const queries = insertItinerary(itinerary);
                                        const limPeticiones = 1;
                                        const tama = queries.length;
                                        let sendOK = true;
                                        for (let i = 0; i < tama; i += limPeticiones) {
                                            const parcialQueries = queries.slice(i, i + limPeticiones);
                                            const promises = [];
                                            for (const pQ of parcialQueries) {
                                                const options2 = options4Request(pQ, true);
                                                promises.push(fetch(options2.url, options2.init));
                                            }
                                            const values = await Promise.all(promises);
                                            values.forEach(v => {
                                                if (v.status !== 200) {
                                                    sendOK = false;
                                                }
                                            });
                                            if (!sendOK) {
                                                break;
                                            }
                                        }
                                        if (sendOK) {
                                            winston.info(Mustache.render(
                                                'newItinerary || {{{uid}}} || {{{time}}}',
                                                {
                                                    uid: itinerary.id,
                                                    time: Date.now() - start
                                                }
                                            ));
                                            logHttp(req, 201, 'newItinerary', start);
                                            res.location(itinerary.id).sendStatus(201);
                                        } else {
                                            winston.info(Mustache.render(
                                                'newItinerary || {{{uid}}} || {{{time}}}',
                                                {
                                                    uid: itinerary.id,
                                                    time: Date.now() - start
                                                }
                                            ));
                                            logHttp(req, 500, 'newItinerary', start);
                                            res.sendStatus(500);
                                        }
                                    } else {
                                        winston.info(Mustache.render(
                                            'newItinerary || Unprivileged user || {{{time}}}',
                                            {
                                                time: Date.now() - start
                                            }
                                        ));
                                        logHttp(req, 401, 'newItinerary', start);
                                        res.sendStatus(401);
                                    }
                                });
                            } else {
                                winston.info(Mustache.render(
                                    'newItinerary || 403 - Verify email || {{{time}}}',
                                    {
                                        time: Date.now() - start
                                    }
                                ));
                                logHttp(req, 403, 'newItinerary', start);
                                res.status(403).send('You have to verify your email!');
                            }
                        }).catch(error => {
                            winston.error(Mustache.render(
                                'newItinerary || {{{error}}} || {{{time}}}',
                                {
                                    error: error,
                                    time: Date.now() - start
                                }
                            ));
                            logHttp(req, 500, 'newItinerary', start);
                            res.sendStatus(500);
                        });

                } else {
                    winston.info(Mustache.render(
                        'newItinerary || 400 - Missing or incorrect fields || {{{time}}}',
                        {
                            time: Date.now() - start
                        }
                    ));
                    logHttp(req, 400, 'newItinerary', start);
                    res.sendStatus(400);
                }
            } else {
                winston.info(Mustache.render(
                    'newItinerary || 400 - Missing or incorrect fields || {{{time}}}',
                    {
                        time: Date.now() - start
                    }
                ));
                logHttp(req, 400, 'newItinerary', start);
                res.sendStatus(400);
            }
        } else {
            winston.info(Mustache.render(
                'newItinerary || 400 - Missing body || {{{time}}}',
                {
                    time: Date.now() - start
                }
            ));
            logHttp(req, 400, 'newItinerary', start);
            res.sendStatus(400);
        }
    } catch (error) {
        winston.error(Mustache.render(
            'newItinerary || {{{error}}} || {{{time}}}',
            {
                error: error,
                time: Date.now() - start
            }
        ));
        logHttp(req, 500, 'newItinerary', start);
        res.sendStatus(500);
    }

}

module.exports = {
    getItineariesServer,
    newItineary
}