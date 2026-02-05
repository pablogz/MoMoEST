const fetch = require('node-fetch');
const Mustache = require('mustache');

const winston = require('../../../util/winston.js');
const { logHttp, shortId2Id } = require('../../../util/auxiliar.js');
const { serverPort, urlServer } = require('../../../util/config.js');

async function getTasksFeature(req, res) {
    // /features/:featureShortId/learningTasks
    const start = Date.now();
    try {
        const feature = req.params.feature;
        fetch(Mustache.render('http://127.0.0.1:{{{serverPort}}}/tasks?feature={{{feature}}}', {
            serverPort: serverPort,
            feature: feature,
        })).then((response) => { return response.status == 200 ? response.json() : response.status == 204 ? undefined : null }).then((data) => {
            if (data !== null) {
                if (data !== undefined) {
                    winston.info(Mustache.render(
                        'getLearningTask || {{{feature}}} || nTasks: {{{nTasks}}} || {{{time}}}',
                        {
                            feature: feature,
                            nTasks: data.length,
                            time: Date.now() - start
                        }
                    ));
                    res.send(data);
                } else {
                    winston.info(Mustache.render(
                        'getLearningTask || {{{feature}}} || nTasks: 0 || {{{time}}}',
                        {
                            feature: feature,
                            time: Date.now() - start
                        }
                    ));
                    res.sendStatus(204);
                }
            } else {
                winston.info(Mustache.render(
                    'getTasksFeature || notFound || {{{feature}}} || {{{time}}}',
                    {
                        feature: feature,
                        time: Date.now() - start
                    }
                ));
                res.sendStatus(404);
            }
        });
    } catch (error) {
        winston.info(Mustache.render(
            'getTasksFeature || {{{error}}} || {{{time}}}',
            {
                error: error,
                time: Date.now() - start
            }
        ));
        logHttp(req, 500, 'getTasksFeature', start);
        res.status(500).send(Mustache.render(
            '{{{error}}}\nEx. {{{urlServer}}}/features/chd:exFeature/learningTasks',
            { error: error, urlServer: urlServer }));
    }
}

async function postTaskFeture(req, res) {
    const start = Date.now();
    const needParameters = Mustache.render(
        'Mandatory parameters in the request body are: aT[text/mcq/tf/photo/multiplePhotos/video/photoText/videoText/multiplePhotosText] (answerType); inSpace[virtual/physical] ; comment[string]; hasFeature[uriFeature]\nOptional parameters: image[{image: url, liense: url}], label[string]',
        { urlServer: urlServer });
    try {
        const feature = shortId2Id(req.params.feature);
        const {body} = req;
        if (body) {
            fetch(`http://127.0.0.1:${serverPort}/tasks?feature=${feature}`, {
                method: 'POST',
                headers: { 
                    'Content-Type': 'application/json', 
                    'Authorization': req.headers.authorization, 
                },
                body: JSON.stringify(body),
            }).then((response) => { 
                if(response.headers.get('Location') === undefined) {
                    res.sendStatus(response.status)
                } else {
                    res.location(response.headers.get('Location')).sendStatus(response.status)
                }                
             });
        } else {
            winston.info(Mustache.render(
                'postTaskFeture || {{{time}}}',
                {
                    time: Date.now() - start
                }
            ));
            logHttp(req, 400, 'postTaskFeture', start);
            res.status(400).send(needParameters);
        }
    } catch (error) {
        winston.info(Mustache.render(
            'postTaskFeture || {{{error}}} || {{{time}}}',
            {
                error: error,
                time: Date.now() - start
            }
        ));
        logHttp(req, 500, 'postTaskFeture', start);
        res.status(500).send(Mustache.render(
            '{{{error}}}\nEx. {{{urlServer}}}/features/chd:exFeature/learningTasks',
            { error: error, urlServer: urlServer }));
    }
}

module.exports = { getTasksFeature, postTaskFeture};
