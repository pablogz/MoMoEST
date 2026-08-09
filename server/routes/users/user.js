const FirebaseAdmin = require('firebase-admin');
const fetch = require('node-fetch');
const Mustache = require('mustache');

const { getInfoUser, updateDocument, newDocument, DOCUMENT_INFO, deleteCollection } = require('../../util/bd');
const { getTokenAuth, logHttp, options4Request } = require('../../util/auxiliar');
const winston = require('../../util/winston');
const { checkExistenceAlias, insertPerson, insertCommentPerson, borraAlias, borraDescription, getDescription } = require('../../util/queries');
const SPARQLQuery = require('../../util/sparqlQuery');
const Config = require('../../util/config');

async function getUser(req, res) {
    const start = Date.now();
    try {
        const dToken = await FirebaseAdmin.auth().verifyIdToken(getTokenAuth(req.headers.authorization));
        const { uid } = dToken;
        const infoUser = await getInfoUser(uid);
        if (infoUser !== null) {
            const toCHESTUser = {
                id: uid,
                rol: infoUser.rol,
                alias: infoUser.alias == null ? undefined : infoUser.alias,
                consentimientoInformado: !!infoUser.confConsentimientoInformado,
                lastMapView: infoUser.lpv == null ? undefined : {
                    lat: infoUser.lpv.lat,
                    long: infoUser.lpv.long,
                    zoom: infoUser.lpv.zoom,
                },
                defaultMap: infoUser.defaultMap == null ? undefined : infoUser.defaultMap,
                feed: infoUser.activeFeed == null ? undefined : infoUser.activeFeed,
            };
            try {
                const sparqlQuery = new SPARQLQuery(`http://${Config.addrSparql}:8890/sparql`);
                const response = await sparqlQuery.query(getDescription(uid));
                if (response != null && typeof response.results !== 'undefined' && typeof response.results.bindings !== 'undefined') {
                    const comment = [];
                    response.results.bindings.forEach(binding => {
                        if (typeof binding.comment['xml:lang'] !== 'undefined') {
                            comment.push({ value: binding.comment['value'], lang: binding.comment['xml:lang'] });
                        } else {
                            comment.push({ value: binding.comment['value'] });
                        }
                    });
                    if (comment.length > 0) {
                        // PARCHE TEMPORAL: omitir comment hasta actualizar cliente en stores
                        // toCHESTUser['comment'] = comment;
                    }
                }
            } catch (sparqlError) {
                winston.error(Mustache.render('getUser SPARQL || {{{error}}}', { error: sparqlError }));
            }
            winston.info(Mustache.render('getUser || {{{uid}}} || {{{time}}}', { uid, time: Date.now() - start }));
            logHttp(req, 200, 'getUser', start);
            res.send(JSON.stringify(toCHESTUser));
        } else {
            logHttp(req, 404, 'getUser', start);
            res.sendStatus(404);
        }
    } catch (error) {
        winston.error(Mustache.render('getUser || {{{error}}} || {{{time}}}', { error, time: Date.now() - start }));
        const status = error.code && error.code.startsWith('auth/') ? 401 : 500;
        logHttp(req, status, 'getUser', start);
        res.status(status).send(error.message);
    }
}


// curl -X PUT -H "Authorization: Bearer 1" -H "Content-Type: application/json" -d '{"code": "qTubp5ziML3Q", "confTeacherLOD": "20240304b", "alias": "pepito123", "confAliasLOD": "20240304a", "comment": "Descripción de 123"}' "localhost:11110/users/user" -v
async function editUser(req, res) {
    const start = Date.now();
    try {
        const dToken = await FirebaseAdmin.auth().verifyIdToken(getTokenAuth(req.headers.authorization));
        const { uid, email } = dToken;
        if (!uid) {
            logHttp(req, 400, 'editUser', start);
            return res.status(400).send('Invalid token!');
        }
        const infoUser = await getInfoUser(uid);
        if (infoUser !== null) {
            // Usuario registrado
            let { alias, code, comment, confAliasLOD, confTeacherLOD, confConsentimientoInformado } = req.body;
            alias = _validaString(alias);
            code = _validaString(code);
            confAliasLOD = _validaString(confAliasLOD);
            confTeacherLOD = _validaString(confTeacherLOD);
            confConsentimientoInformado = _validaString(confConsentimientoInformado);
            const commentV = _parseComment(comment);
            if (typeof code !== 'undefined' && typeof confTeacherLOD !== 'undefined') {
                // El usuario quiere pasar a ser profesor
                const codeValido = await _compruebaCodigoProfe(code, email);
                if (!codeValido) {
                    logHttp(req, 403, 'editUser', start);
                    return res.status(403).send('Code is not valid!');
                }
                if (typeof alias !== 'undefined' && typeof confAliasLOD !== 'undefined') {
                    const aliasV = await _aliasUtilizado(alias);
                    if (aliasV) {
                        logHttp(req, 400, 'editUser', start);
                        return res.status(400).send('Use another alias!');
                    }
                    const v = await _creaProfe(true, uid, alias, confAliasLOD, code, confTeacherLOD, commentV, infoUser.alias, confConsentimientoInformado);
                    logHttp(req, v === true ? 204 : 500, 'editUser', start);
                    return v === true ? res.sendStatus(204) : res.status(500).send('Internal error!');
                } else {
                    // El profe ya tenía que tener un alias
                    if (infoUser.alias !== undefined && infoUser.alias !== null) {
                        const v = await _creaProfe(true, uid, infoUser.alias, infoUser.confAliasLOD, code, confTeacherLOD, commentV, undefined, confConsentimientoInformado);
                        logHttp(req, v === true ? 204 : 500, 'editUser', start);
                        return v === true ? res.sendStatus(204) : res.status(500).send('Internal error!');
                    } else {
                        logHttp(req, 400, 'editUser', start);
                        return res.status(400).send('We need an alias for the teacher!');
                    }
                }
            } else {
                if (typeof alias !== 'undefined' && typeof confAliasLOD !== 'undefined') {
                    const aliasV = await _aliasUtilizado(alias);
                    if (aliasV) {
                        logHttp(req, 400, 'editUser', start);
                        return res.status(400).send('Use another alias!');
                    }
                    const v = await _actualizaPersona(uid, alias, confAliasLOD, infoUser.alias, confConsentimientoInformado);
                    if (v !== true) {
                        logHttp(req, 500, 'editUser', start);
                        return res.status(500).send('Internal error!');
                    }
                    if (commentV !== null) {
                        const r = await _actualizaDescripcion(uid, commentV);
                        logHttp(req, r ? 204 : 200, 'editUser', start);
                        return res.sendStatus(r ? 204 : 200);
                    }
                    logHttp(req, 204, 'editUser', start);
                    return res.sendStatus(204);
                } else {
                    if (confConsentimientoInformado !== undefined) {
                        await updateDocument(uid, DOCUMENT_INFO, { confConsentimientoInformado });
                    }
                    if (commentV !== null) {
                        const r = await _actualizaDescripcion(uid, commentV);
                        logHttp(req, r ? 204 : 200, 'editUser', start);
                        return res.sendStatus(r ? 204 : 200);
                    }
                    logHttp(req, confConsentimientoInformado !== undefined ? 204 : 200, 'editUser', start);
                    return res.sendStatus(confConsentimientoInformado !== undefined ? 204 : 200);
                }
            }
        } else {
            // Usuario todavía no almacenado
            let { alias, code, comment, confAliasLOD, confTeacherLOD } = req.body;
            alias = _validaString(alias);
            code = _validaString(code);
            confAliasLOD = _validaString(confAliasLOD);
            confTeacherLOD = _validaString(confTeacherLOD);
            if (typeof code !== 'undefined') {
                if (typeof confTeacherLOD !== 'undefined' && typeof code === 'string' && typeof alias !== 'undefined' && typeof confAliasLOD !== 'undefined') {
                    const codeValido = await _compruebaCodigoProfe(code, email);
                    if (!codeValido) {
                        logHttp(req, 403, 'editUser', start);
                        return res.status(403).send('Code is not valid!');
                    }
                    const commentV = _parseComment(comment);
                    const aliasV = await _aliasUtilizado(alias);
                    if (aliasV) {
                        logHttp(req, 400, 'editUser', start);
                        return res.status(400).send('Use another alias!');
                    }
                    const v = await _creaProfe(false, uid, alias, confAliasLOD, code, confTeacherLOD, commentV);
                    logHttp(req, v === true ? 201 : 500, 'editUser', start);
                    return v === true ? res.sendStatus(201) : res.status(500).send('Internal error!');
                } else {
                    logHttp(req, 400, 'editUser', start);
                    return res.status(400).send('We need more parameters!');
                }
            } else {
                if (typeof alias !== 'undefined' && typeof confAliasLOD !== 'undefined') {
                    const aliasV = await _aliasUtilizado(alias);
                    if (aliasV) {
                        logHttp(req, 400, 'editUser', start);
                        return res.status(400).send('Use another alias!');
                    }
                    const v = await _creaPersona(uid, alias, confAliasLOD);
                    logHttp(req, v === true ? 201 : 500, 'editUser', start);
                    return v === true ? res.sendStatus(201) : res.status(500).send('Internal error!');
                } else {
                    const v = await _creaPersona(uid);
                    logHttp(req, v === true ? 201 : 500, 'editUser', start);
                    return v === true ? res.sendStatus(201) : res.status(500).send('Internal error!');
                }
            }
        }
    } catch (error) {
        winston.error(Mustache.render('editUser || {{{error}}} || {{{time}}}', { error, time: Date.now() - start }));
        logHttp(req, 500, 'editUser', start);
        res.status(500).send(error.message);
    }
}

async function deleteUser(req, res) {
    const start = Date.now();
    try {
        FirebaseAdmin.auth().verifyIdToken(getTokenAuth(req.headers.authorization))
            .then(async (dToken) => {
                const { uid } = dToken;
                deleteCollection(uid).then(async (infoDelete) => {
                    if (infoDelete) {
                        FirebaseAdmin.auth().deleteUser(uid);
                        logHttp(req, 200, 'deleteUser', start);
                        winston.info(Mustache.render(
                            'deleteUser || {{{uid}}} || {{{time}}}',
                            {
                                uid: uid,
                                time: Date.now() - start
                            }
                        ));
                        res.sendStatus(200);
                    } else {
                        logHttp(req, 500, 'deleteUser', start);
                        res.sendStatus(500);
                    }
                });
            })
            .catch(error => {
                winston.error(Mustache.render(
                    'deleteUser || {{{error}}} || {{{time}}}',
                    {
                        error: error,
                        time: Date.now() - start
                    }
                ));
                logHttp(req, 401, 'deleteUser', start);
                res.status(401).send(error.message);
            });
    } catch (error) {
        winston.error(Mustache.render(
            'deleteUser || {{{error}}} || {{{time}}}',
            {
                error: error,
                time: Date.now() - start
            }
        ));
        logHttp(req, 500, 'deleteUser', start);
        res.status(500).send(error.message);
    }
}

async function _compruebaCodigoProfe(codigo, email) {
    // TODO implementar la recuperación de código asignada a la dirección
    return typeof email !== 'undefined' && codigo === 'qTubp5ziML3Q';
}

async function _aliasUtilizado(alias) {
    const query = checkExistenceAlias(alias);
    const sparqlQuery = new SPARQLQuery(`http://${Config.addrSparql}:8890/sparql`);
    try {
        const response = await sparqlQuery.query(query);
        return typeof response !== 'undefined' && typeof response.boolean !== 'undefined' ? response.boolean : true;
    } catch (e) {
        winston.error(`_aliasUtilizado error: ${e}`);
        return true;
    }
}

async function _creaProfe(personaYaCreada, uid, alias, confAliasLOD, code, confTeacherLOD, commentV = undefined, prevAlias = undefined, confConsentimientoInformado = undefined) {
    const personaCreada = personaYaCreada ?
        await _actualizaPersona(uid, alias, confAliasLOD, prevAlias, confConsentimientoInformado) :
        await _creaPersona(uid, alias, confAliasLOD, confConsentimientoInformado);
    if (personaCreada) {
        const date = _getCurrentUTCString();
        const err = await updateDocument(
            uid,
            DOCUMENT_INFO,
            {
                id: uid,
                rol: ["STUDENT", "TEACHER"],
                lastUpdate: date,
                confTeacherLOD: confTeacherLOD,
                code: code,
            }
        );
        if (err !== null && typeof err.acknowledged !== 'undefined' && err.acknowledged) {
            return await _actualizaDescripcion(uid, commentV, date);
        } else {
            return false;
        }
    } else {
        return false;
    }
}

async function _creaPersona(uid, alias = undefined, confAliasLOD = undefined, confConsentimientoInformado = undefined) {
    const creation = _getCurrentUTCString();
    const doc = {
        _id: DOCUMENT_INFO,
        id: uid,
        rol: ["STUDENT"],
        creation: creation,
        alias: alias,
        confAliasLOD: confAliasLOD,
        ...(confConsentimientoInformado !== undefined && { confConsentimientoInformado }),
    };
    const v = await newDocument(uid, doc);
    if (v !== null) {
        const lodPerson = { uid: uid, created: creation };
        if (typeof alias !== 'undefined') {
            lodPerson['label'] = alias;
        }
        const requests = insertPerson(lodPerson);
        try {
            const values = await Promise.all(requests.map((request) => {
                const options = options4Request(request, true);
                return fetch(options.url, options.init);
            }));
            return values.every((v) => v.status === 200);
        } catch (e) {
            winston.error(`_creaPersona LOD error: ${e}`);
            return false;
        }
    }
    return false;
}

async function _actualizaPersona(uid, alias = undefined, confAliasLOD = undefined, prevAlias = undefined, confConsentimientoInformado = undefined) {
    let todoOk = true;
    const date = _getCurrentUTCString();
    const err = await updateDocument(
        uid,
        DOCUMENT_INFO,
        {
            id: uid,
            lastUpdate: date,
            alias: alias,
            confAliasLOD: confAliasLOD,
            ...(confConsentimientoInformado !== undefined && { confConsentimientoInformado }),
        }
    );
    if (err !== null && typeof err.acknowledged !== 'undefined' && err.acknowledged) {
        try {
            if (prevAlias != null) {
                const request = borraAlias(uid, prevAlias);
                const options = options4Request(request, true);
                const response = await fetch(options.url, options.init);
                todoOk = response.status === 200;
            }
            if (todoOk && typeof alias !== 'undefined') {
                const values = await Promise.all(
                    insertPerson({ uid: uid, label: alias, date: date }).map((r) => {
                        const options = options4Request(r, true);
                        return fetch(options.url, options.init);
                    })
                );
                todoOk = values.every((v) => v.status === 200);
            }
        } catch (e) {
            winston.error(`_actualizaPersona LOD error: ${e}`);
            return false;
        }
        return todoOk;
    } else {
        return false;
    }
}

async function _actualizaDescripcion(uid, nuevaDescripcion = undefined, date = undefined) {
    if (typeof date === 'undefined') {
        date = _getCurrentUTCString();
    }
    try {
        const request = borraDescription(uid);
        const options = options4Request(request, true);
        const response = await fetch(options.url, options.init);
        if (response.status !== 200) {
            return false;
        }
        if (nuevaDescripcion !== undefined && nuevaDescripcion !== null) {
            const values = await Promise.all(
                insertCommentPerson({ uid: uid, comment: nuevaDescripcion, date: date }).map((request) => {
                    const options = options4Request(request, true);
                    return fetch(options.url, options.init);
                })
            );
            return values.every((v) => v.status === 200);
        }
        return true;
    } catch (e) {
        winston.error(`_actualizaDescripcion LOD error: ${e}`);
        return false;
    }
}

function _parseComment(comment) {
    if (typeof comment === 'string' && comment.trim() !== '') {
        return { value: comment.trim() };
    }
    if (typeof comment === 'object' && comment !== null && typeof comment['value'] !== 'undefined') {
        const c = { value: _validaString(comment.value) };
        if (typeof comment['lang'] !== 'undefined') {
            c.lang = _validaString(comment.lang);
        }
        return c.value !== undefined ? c : null;
    }
    return null;
}

function _validaString(string) {
    return typeof string !== 'undefined' && string !== null ? string.trim() !== '' ? string.trim() : undefined : undefined;
}

function _getCurrentUTCString() {
    return (new Date(Date.now())).toISOString();
}

module.exports = {
    getUser,
    editUser,
    deleteUser,
}