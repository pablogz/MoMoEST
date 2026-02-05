const { logHttp } = require('../util/auxiliar');

/**
 *
 * @param {*} req
 * @param {*} res
 */
function getIndex(req, res) {
    logHttp(req, 200, '/', Date.now());
    res.send('Welcome to CHEST');
}

module.exports = { getIndex };