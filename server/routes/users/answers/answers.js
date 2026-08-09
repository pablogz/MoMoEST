const short = require('short-uuid');
const FirebaseAdmin = require('firebase-admin');
const Mustache = require('mustache');

const winston = require('../../../util/winston');
const { getTokenAuth, logHttp, shortId2Id } = require('../../../util/auxiliar');
const { saveAnswer, getAnswersDB, hideAnswerDB, getFeedsUser } = require('../../../util/bd');
const { removeEntry } = require('../../feature/photoVote');
const { urlServer } = require('../../../util/config');

/**
 * Devuelve un Map idRespuesta -> idCanal a partir de las respuestas que el
 * usuario asoció a cada canal al que está subscrito. Sirve para saber el canal
 * de las respuestas guardadas antes de que existiese el campo idFeed.
 * Solo lee de MongoDB; nada de esto llega al triple-store LOD.
 */
async function getFeedOfAnswers(uid) {
    const feedOfAnswer = new Map();
    try {
        const feedsDocument = await getFeedsUser(uid);
        if (feedsDocument !== null && Array.isArray(feedsDocument.subscribed)) {
            feedsDocument.subscribed.forEach((subscription) => {
                if (typeof subscription?.idFeed === 'string' && Array.isArray(subscription.answers)) {
                    subscription.answers.forEach((idAnswer) => {
                        feedOfAnswer.set(idAnswer, subscription.idFeed);
                    });
                }
            });
        }
    } catch (error) {
        winston.error('getFeedOfAnswers:', error);
    }
    return feedOfAnswer;
}

async function getAnswers(req, res) {
    const start = Date.now();
    try {
        FirebaseAdmin.auth().verifyIdToken(getTokenAuth(req.headers.authorization))
            .then(async dToken => {
                const { uid } = dToken;
                if (uid !== '') {
                    const { allAnswers } = req.query;
                    const answers = await getAnswersDB(uid, allAnswers === 'true');
                    if (answers != null) {
                        if (answers.length > 0) {
                            // Las respuestas anteriores a la incorporación del campo idFeed no lo
                            // llevan guardado, pero el canal sí registra qué respuestas se le
                            // asociaron: se reconstruye la relación desde el documento de canales.
                            const feedOfAnswer = await getFeedOfAnswers(uid);
                            const response = [];
                            answers.filter(a => !a.hidden).forEach((answer) => {
                                const idFeed = typeof answer.idFeed === 'string' && answer.idFeed !== ''
                                    ? answer.idFeed
                                    : feedOfAnswer.get(answer.id);
                                const index = response.findIndex((responseAnswer) =>
                                    responseAnswer.idFeature == answer.idFeature
                                    && responseAnswer.idTask == answer.idTask);
                                if (index == -1) {
                                    response.push({
                                        "id": answer.id,
                                        "idContainer": answer.idFeature,
                                        "labelContainer": answer.labelContainer,
                                        "idTask": answer.idTask,
                                        "commentTask": answer.commentTask,
                                        ...(typeof idFeed === 'string' && idFeed !== '' && { "idFeed": idFeed }),
                                        ...(typeof answer.feedback === 'string' && answer.feedback !== '' && { "feedback": answer.feedback }),
                                        // "traces": [
                                        //     {
                                        //         "idAnswer": answer.id,
                                        //         "finishClient": answer.finishClient,
                                        //         "time2Complete": answer.time2Complete,
                                        //         "hasOptionalText": answer.hasOptionalText
                                        //     },
                                        // ],
                                        "answerType": answer.answerType,
                                        "lastUpdate": answer.finishClient,
                                        "firstFinish": answer.finishClient, 
                                        answer: answer.answer,
                                    });
                                } else {
                                    const prev = response.splice(index, 1).pop();
                                    // prev.traces.push({
                                    //     "idAnswer": answer.id,
                                    //     "finishClient": answer.finishClient,
                                    //     "time2Complete": answer.time2Complete,
                                    //     "hasOptionalText": answer.hasOptionalText
                                    // });
                                    if (prev.lastUpdate < answer.finishClient) {
                                        // Cuando hay varias respuestas para la misma tarea se muestra
                                        // la más reciente (con su canal y su realimentación).
                                        prev.lastUpdate = answer.finishClient;
                                        prev.answer = answer.answer;
                                        prev.id = answer.id;
                                        prev.answerType = answer.answerType;
                                        if (typeof idFeed === 'string' && idFeed !== '') {
                                            prev.idFeed = idFeed;
                                        } else {
                                            delete prev.idFeed;
                                        }
                                        if (typeof answer.feedback === 'string' && answer.feedback !== '') {
                                            prev.feedback = answer.feedback;
                                        } else {
                                            delete prev.feedback;
                                        }
                                    }
                                    if (prev.firstFinish > answer.finishClient) {
                                        prev.firstFinish = answer.firstFinish;
                                    }
                                    response.push(prev);
                                }
                            });
                            winston.info(Mustache.render(
                                'getAnswers || {{{nAnswers}}} || {{{time}}}',
                                {
                                    nAnswers: answers.length,
                                    time: Date.now() - start
                                }
                            ));
                            logHttp(req, 200, 'getAnswers', start);
                            // Igual que en las notas: sin cabeceras de caché el
                            // navegador puede servir la lista anterior tras
                            // borrar o añadir una respuesta.
                            res.setHeader('Cache-Control', 'no-store, no-cache, must-revalidate');
                            res.setHeader('Pragma', 'no-cache');
                            res.send(JSON.stringify(response.sort((a, b) => b.lastUpdate - a.lastUpdate)));
                        } else {
                            winston.info(Mustache.render(
                                'getAnswers || {{{nAnswers}}} || {{{time}}}',
                                {
                                    nAnswers: 0,
                                    time: Date.now() - start
                                }
                            ));
                            logHttp(req, 204, 'getAnswers', start);
                            res.sendStatus(204);
                        }
                    } else {
                        winston.info(Mustache.render(
                            'getAnswers || {{{time}}}',
                            {
                                time: Date.now() - start
                            }
                        ));
                        logHttp(req, 400, 'getAnswers', start);
                        res.sendStatus(400);
                    }
                } else {
                    winston.info(Mustache.render(
                        'getAnswers || {{{time}}}',
                        {
                            time: Date.now() - start
                        }
                    ));
                    logHttp(req, 403, 'getAnswers', start);
                    res.sendStatus(403);
                }
            }).catch(error => {
                winston.info(Mustache.render(
                    'getAnswers || {{{error}}} || {{{time}}}',
                    {
                        error: error,
                        time: Date.now() - start
                    }
                ));
                logHttp(req, 400, 'getAnswers', start);
                res.sendStatus(400);
            });
    } catch (error) {
        winston.error(Mustache.render(
            'getAnswers || {{{error}}} || {{{time}}}',
            {
                error: error,
                time: Date.now() - start
            }
        ));
        logHttp(req, 500, 'getAnswers', start);
        res.sendStatus(500);
    }
}


// curl -X POST -H "Content-type: application/json" -d "\"idPoi\": \"123\", \"idTask\": \"321\", \"answerMetada\": {\"hasOptionalText\": false, \"timestamp\": 123456789, \"time2Complete\": 123}" "127.0.0.1:11110/users/user/answers"
async function newAnswer(req, res) {
    const start = Date.now();
    try {
        const { body } = req;
        if (body != undefined) {
            if (body.idTask && body.idContainer && body.answerMetadata) {
                FirebaseAdmin.auth().verifyIdToken(getTokenAuth(req.headers.authorization))
                    .then(async dToken => {
                        const { uid } = dToken;
                        if (uid !== '') {
                            const answerClient = body.answerMetadata;
                            if (answerClient.hasOptionalText !== undefined
                                && typeof answerClient.hasOptionalText === 'boolean'
                                && answerClient.finishClient !== undefined
                                && typeof answerClient.finishClient === 'number'
                                && answerClient.time2Complete !== undefined
                                && typeof answerClient.time2Complete === 'number'
                                && body.answer !== undefined 
                                && body.answerType !== undefined 
                                && body.labelContainer !== undefined 
                                && body.commentTask !== undefined
                            ) {
                                const answer2Server = {};
                                answer2Server["hasOptionalText"] = answerClient.hasOptionalText;
                                answer2Server["finishClient"] = answerClient.finishClient;
                                answer2Server["time2Complete"] = answerClient.time2Complete;
                                answer2Server['answer'] = body.answer;
                                answer2Server['labelContainer'] = body.labelContainer;
                                answer2Server['commentTask'] = body.commentTask;
                                answer2Server['answerType'] = body.answerType;
                                if (typeof body.idFeed === 'string' && body.idFeed.trim() !== '') {
                                    answer2Server['idFeed'] = body.idFeed.trim();
                                }
                                const idAnswer = short.generate();
                                const r = await saveAnswer(uid, body.idContainer, body.idTask, idAnswer, answer2Server);
                                // const r = await saveAnswer(idAnswer, body.idUser, body.idPoi, body.idTask, answer2Server);
                                // if (r.acknowledged && (r.modifiedCount == 1 || r.upsertedCount == 1)) {
                                if (r != null && r.acknowledged) {
                                    const answerLocation = urlServer + "/users/user/answers/" + idAnswer;
                                    winston.info(Mustache.render(
                                        'newAnswer || {{{id}}} || {{{time}}}',
                                        {
                                            id: idAnswer,
                                            time: Date.now() - start
                                        }
                                    ));
                                    logHttp(req, 201, 'newAnswer', start);
                                    res.location(answerLocation).sendStatus(201);
                                } else {
                                    winston.info(Mustache.render(
                                        'newAnswer || {{{time}}}',
                                        {
                                            time: Date.now() - start
                                        }
                                    ));
                                    logHttp(req, 409, 'newAnswer', start);
                                    res.sendStatus(409);
                                }
                            } else {
                                winston.info(Mustache.render(
                                    'newAnswer || {{{time}}}',
                                    {
                                        time: Date.now() - start
                                    }
                                ));
                                logHttp(req, 400, 'newAnswer', start);
                                res.sendStatus(400);
                            }
                        } else {
                            winston.info(Mustache.render(
                                'newAnswer || {{{time}}}',
                                {
                                    time: Date.now() - start
                                }
                            ));
                            logHttp(req, 403, 'newAnswer', start);
                            res.sendStatus(403);
                        }
                    }).catch(error => {
                        winston.info(Mustache.render(
                            'newAnswer || {{{error}}} || {{{time}}}',
                            {
                                error: error,
                                time: Date.now() - start
                            }
                        ));
                        logHttp(req, 500, 'newAnswer', start);
                        res.sendStatus(500);
                    });
            } else {
                winston.info(Mustache.render(
                    'newAnswer || {{{time}}}',
                    {
                        time: Date.now() - start
                    }
                ));
                logHttp(req, 400, 'newAnswer', start);
                res.sendStatus(400);
            }
        } else {
            winston.info(Mustache.render(
                'newAnswer || {{{time}}}',
                {
                    time: Date.now() - start
                }
            ));
            logHttp(req, 400, 'newAnswer', start);
            res.sendStatus(400);
        }
    } catch (error) {
        winston.error(Mustache.render(
            'newAnswer || {{{error}}} || {{{time}}}',
            {
                error: error,
                time: Date.now() - start
            }
        ));
        logHttp(req, 500, 'newAnswer', start);
        res.sendStatus(500);
    }
}

async function hideAnswer(req, res) {
    const start = Date.now();
    try {
        FirebaseAdmin.auth().verifyIdToken(getTokenAuth(req.headers.authorization))
            .then(async dToken => {
                const { uid } = dToken;
                if (uid !== '') {
                    const { answer } = req.params;
                    const answers = await getAnswersDB(uid);
                    const target = Array.isArray(answers)
                        ? answers.find(a => a.id === answer && !a.hidden)
                        : undefined;
                    if (target !== undefined) {
                        const ok = await hideAnswerDB(uid, answer);
                        if (ok) {
                            // Borrado simétrico: si la respuesta era una foto de
                            // una votación pública, la foto y sus votos también
                            // desaparecen, para no dejar recursos sueltos
                            if (target.answerType === 'photoVote'
                                && typeof target.answer?.entryId === 'string') {
                                const idFeature = shortId2Id(target.idFeature) ?? target.idFeature;
                                const result = await removeEntry(idFeature, target.answer.entryId, uid);
                                if (result !== 'ok') {
                                    winston.info(Mustache.render(
                                        'hideAnswer || photoVote {{{result}}} || {{{entry}}}',
                                        { result: result, entry: target.answer.entryId }
                                    ));
                                }
                            }
                            winston.info(Mustache.render(
                                'hideAnswer || {{{id}}} || {{{time}}}',
                                { id: answer, time: Date.now() - start }
                            ));
                            logHttp(req, 204, 'hideAnswer', start);
                            res.sendStatus(204);
                        } else {
                            logHttp(req, 409, 'hideAnswer', start);
                            res.sendStatus(409);
                        }
                    } else {
                        logHttp(req, 404, 'hideAnswer', start);
                        res.sendStatus(404);
                    }
                } else {
                    logHttp(req, 401, 'hideAnswer', start);
                    res.sendStatus(401);
                }
            }).catch(error => {
                winston.info(Mustache.render(
                    'hideAnswer || {{{error}}} || {{{time}}}',
                    { error: error, time: Date.now() - start }
                ));
                logHttp(req, 400, 'hideAnswer', start);
                res.sendStatus(400);
            });
    } catch (error) {
        winston.error(Mustache.render(
            'hideAnswer || {{{error}}} || {{{time}}}',
            { error: error, time: Date.now() - start }
        ));
        logHttp(req, 500, 'hideAnswer', start);
        res.sendStatus(500);
    }
}

module.exports = {
    getAnswers,
    newAnswer,
    hideAnswer,
}