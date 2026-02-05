const fetch = require('node-fetch');
const Mustache = require('mustache');

const winston = require('../../../util/winston.js');
const { serverPort, } = require('../../../util/config.js');


async function removeLearningTask(req, res) {
    const start = Date.now();
    try {
        const { feature, learningTask } = req.params;
        fetch(`http://127.0.0.1:${serverPort}/tasks/${learningTask}?feature=${feature}`, {
            method: 'DELETE',
            headers: {
                'Authorization': req.headers.authorization,
            },
        }).then((response) => {
            res.sendStatus(response.status)
        });
    } catch (error) {
        winston.info(Mustache.render(
            'removeLearningTask || {{{error}}} || {{{time}}}',
            {
                error: error,
                time: Date.now() - start
            }
        ));
        res.status(500).send(error);
    }
}

async function getLearningTask(req, res) {
    const start = Date.now();
    try {
        const { feature, learningTask } = req.params;
        fetch(`http://127.0.0.1:${serverPort}/tasks/${learningTask}?feature=${feature}`).then((response) => {
            return response.status == 200 ? response.json() : null
        }).then((data) => {
            if(data != null) {
                winston.info(Mustache.render(
                    'getLearningTask || {{{feature}}} || {{{task}}} || {{{time}}}',
                    {
                        feature: feature,
                        task: learningTask,
                        time: Date.now() - start
                    }
                ));
                res.send(data);
            } else {
                winston.info(Mustache.render(
                    'getLearningTask || notFound || {{{feature}}} || {{{task}}} || {{{time}}}',
                    {
                        feature: feature,
                        task: learningTask,
                        time: Date.now() - start
                    }
                ));
                res.sendStatus(404);
            }
        });
    } catch (error) {
        winston.info(Mustache.render(
            'getLearningTask || {{{error}}} || {{{time}}}',
            {
                error: error,
                time: Date.now() - start
            }
        ));
        res.status(500).send(error);
    }
}

module.exports = {
    getLearningTask,
    removeLearningTask,
}