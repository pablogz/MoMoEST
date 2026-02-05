const short = require('short-uuid');
const FirebaseAdmin = require('firebase-admin');
const Mustache = require('mustache');

const winston = require('../../../util/winston');
const { getTokenAuth, logHttp } = require('../../../util/auxiliar');
const { saveAnswer, getAnswersDB } = require('../../../util/bd');
const { urlServer } = require('../../../util/config');

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
                            const response = [];
                            answers.forEach((answer) => {
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
                                        prev.lastUpdate = answer.finishClient;
                                        prev.answers = answer.answer;
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

module.exports = {
    getAnswers,
    newAnswer,
}