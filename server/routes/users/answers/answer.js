const FirebaseAdmin = require('firebase-admin');

const { getTokenAuth } = require('../../../util/auxiliar');

async function getAnswer(req, res) {
    try {
        FirebaseAdmin.auth().verifyIdToken(getTokenAuth(req.headers.authorization))
            .then(async dToken => {
                const { uid } = dToken;
                if (uid !== '') {
                    res.sendStatus(204);
                } else {
                    res.sendStatus(403);
                }
            }).catch(error => {
                console.log(error);
                res.sendStatus(400);
            });
    } catch (error) {
        res.sendStatus(500);
    }
}

async function putAnswer(req, res) {
    try {
        FirebaseAdmin.auth().verifyIdToken(getTokenAuth(req.headers.authorization))
            .then(async dToken => {
                const { uid } = dToken;
                if (uid !== '') {
                    res.sendStatus(204);
                } else {
                    res.sendStatus(403);
                }
            }).catch(error => {
                console.log(error);
                res.sendStatus(400);
            });
    } catch (error) {
        res.sendStatus(500);
    }
}

async function deleteAnswer(req, res) {
    try {
        FirebaseAdmin.auth().verifyIdToken(getTokenAuth(req.headers.authorization))
            .then(async dToken => {
                const { uid } = dToken;
                if (uid !== '') {
                    res.sendStatus(204);
                } else {
                    res.sendStatus(403);
                }
            }).catch(error => {
                console.log(error);
                res.sendStatus(400);
            });
    } catch (error) {
        res.sendStatus(500);
    }
}

module.exports = {
    getAnswer,
    putAnswer,
    deleteAnswer,
}