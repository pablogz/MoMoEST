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
        FirebaseAdmin.auth().verifyIdToken(getTokenAuth(req.headers.authorization))
            .then(async (dToken) => {
                const { uid } = dToken;
                getInfoUser(uid).then(async (infoUser) => {
                    if (infoUser !== null) {
                        const toCHESTUser = {
                            id: uid,
                            rol: infoUser.rol,
                            alias: infoUser.alias === null ? undefined : infoUser.alias,
                            lastMapView: infoUser.lpv === null || infoUser.lpv === undefined ? undefined : {
                                lat: infoUser.lpv.lat,
                                long: infoUser.lpv.long,
                                zoom: infoUser.lpv.zoom,
                            },
                            defaultMap: infoUser.defaultMap === null ? undefined : infoUser.defaultMap,
                        };
                        const sparqlQuery = new SPARQLQuery(`http://${Config.addrSparql}:8890/sparql`);
                        const query = getDescription(uid);
                        sparqlQuery.query(query).then((response) => {
                            if (response != null && typeof response !== 'undefined' && typeof response.results !== 'undefined' && typeof response.results.bindings !== 'undefined') {
                                const comment = [];
                                response.results.bindings.forEach(binding => {
                                    if (typeof binding.comment['xml:lang'] !== 'undefined') {
                                        comment.push(
                                            {
                                                value: binding.comment['value'],
                                                lang: binding.comment['xml:lang']
                                            }
                                        );
                                    } else {
                                        comment.push(
                                            {
                                                value: binding.comment['value']
                                            }
                                        );
                                    }
                                });
                                if (comment.length > 0) {
                                    toCHESTUser['comment'] = comment;
                                }
                            }
                            winston.info(Mustache.render(
                                'getUser || {{{uid}}} || {{{time}}}',
                                {
                                    uid: uid,
                                    time: Date.now() - start
                                }
                            ));
                            logHttp(req, 200, 'getUser', start);
                            res.send(JSON.stringify(toCHESTUser));
                        });
                    } else {
                        logHttp(req, 404, 'getUser', start);
                        res.sendStatus(404);
                    }
                });
            })
            .catch(error => {
                winston.error(Mustache.render(
                    'getUser || {{{error}}} || {{{time}}}',
                    {
                        error: error,
                        time: Date.now() - start
                    }
                ));
                logHttp(req, 401, 'getUser', start);
                res.status(401).send(error.message);
            });
    } catch (error) {
        winston.error(Mustache.render(
            'getUser || {{{error}}} || {{{time}}}',
            {
                error: error,
                time: Date.now() - start
            }
        ));
        logHttp(req, 500, 'getUser', start);
        res.status(500).send(error.message);
    }
}


// curl -X PUT -H "Authorization: Bearer 1" -H "Content-Type: application/json" -d '{"code": "qTubp5ziML3Q", "confTeacherLOD": "20240304b", "alias": "pepito123", "confAliasLOD": "20240304a", "comment": {"value": "Descripción de 123", "lang": "es"}}' "localhost:11110/users/user" -v
async function editUser(req, res) {
    const start = Date.now();
    try {
        FirebaseAdmin.auth().verifyIdToken(getTokenAuth(req.headers.authorization))
            .then(async dToken => {
                const { uid, email } = dToken;
                if (uid !== '') {
                    getInfoUser(uid).then(async infoUser => {
                        if (infoUser !== null) {
                            // Usuario registrado
                            let { alias, code, comment, confAliasLOD, confTeacherLOD } = req.body;
                            alias = _validaString(alias);
                            code = _validaString(code);
                            confAliasLOD = _validaString(confAliasLOD);
                            confTeacherLOD = _validaString(confTeacherLOD);
                            var commentV = null;
                            if (typeof comment === 'object' && typeof comment['value'] !== 'undefined' && typeof comment['lang'] !== 'undefined') {
                                commentV = { value: _validaString(comment.value), lang: _validaString(comment.lang) };
                            }
                            // ¿Qué información tenemos ya del usuario? Está contenida en infoUser.
                            // El usuario va a poder cambiar el alias y su descripción. Una vez que pase a ser profesor no podrá dejar de serlo
                            if (typeof code !== 'undefined' && typeof confTeacherLOD !== 'undefined') {
                                // El usuario quiere pasar a ser profesor
                                _compruebaCodigoProfe(code, email).then((codeValido) => {
                                    if (codeValido) {
                                        // Si trae alias y confAliasLOD el usuario quiere cambiar el alias. Por ello tengo que comprobar si está disponible.
                                        if (typeof alias !== 'undefined' && typeof confAliasLOD !== 'undefined') {
                                            _aliasUtilizado(alias).then((aliasV) => {
                                                if (!aliasV) {
                                                    _creaProfe(true, uid, alias, confAliasLOD, code, confTeacherLOD, commentV, infoUser.alias).then((v) => {
                                                        if (v === true) {
                                                            logHttp(req, 204, 'editUser', start);
                                                            res.sendStatus(204);
                                                        } else {
                                                            logHttp(req, 500, 'editUser', start);
                                                            res.status(500).send('Internal error!');
                                                        }
                                                    })
                                                } else {
                                                    logHttp(req, 400, 'editUser', start);
                                                    res.status(400).send('Use another alias!');
                                                }
                                            });
                                        } else {
                                            // El profe ya tenía que tener un alias 
                                            if (infoUser.alias !== 'undefined' && infoUser.alias !== null) {
                                                _creaProfe(true, uid, infoUser.alias, infoUser.confAliasLOD, code, confTeacherLOD, commentV).then((v) => {
                                                    if (v === true) {
                                                        res.sendStatus(204);
                                                    } else {
                                                        logHttp(req, 500, 'editUser', start);
                                                        res.status(500).send('Internal error!');
                                                    }
                                                });
                                            } else {
                                                logHttp(req, 400, 'editUser', start);
                                                res.status(400).send('We need an alias for the teacher!');
                                            }
                                        }
                                    } else {
                                        logHttp(req, 403, 'editUser', start);
                                        res.status(403).send('Code is not valid!');
                                    }
                                })
                            } else {
                                // Si trae alias y confAliasLOD el usuario quiere cambiar el alias. Por ello tengo que comprobar si está disponible.
                                if (typeof alias !== 'undefined' && typeof confAliasLOD !== 'undefined') {
                                    _aliasUtilizado(alias).then((aliasV) => {
                                        if (!aliasV) {
                                            _actualizaPersona(uid, alias, confAliasLOD, infoUser.alias).then((v) => {
                                                if (v === true) {
                                                    if (commentV !== null) {
                                                        // El usuario quiere incluir//cambiar su descripción
                                                        _actualizaDescripcion(uid, commentV).then((r) => {
                                                            if (r) {
                                                                logHttp(req, 204, 'editUser', start);
                                                                res.sendStatus(204);
                                                            } else {
                                                                logHttp(req, 200, 'editUser', start);
                                                                res.sendStatus(200);
                                                            }
                                                        });
                                                    } else {
                                                        logHttp(req, 204, 'editUser', start);
                                                        res.sendStatus(204);
                                                    }
                                                } else {
                                                    logHttp(req, 500, 'editUser', start);
                                                    res.status(500).send('Internal error!');
                                                }
                                            });
                                        } else {
                                            logHttp(req, 400, 'editUser', start);
                                            res.status(400).send('Use another alias!');
                                        }
                                    });
                                } else {
                                    // Compruebo si el usuario quiere modifiar su descripción
                                    if (commentV !== null) {
                                        // El usuario quiere incluir//cambiar su descripción
                                        _actualizaDescripcion(uid, commentV).then((r) => {
                                            if (r) {
                                                logHttp(req, 204, 'editUser', start);
                                                res.sendStatus(204);
                                            } else {
                                                logHttp(req, 200, 'editUser', start);
                                                res.sendStatus(200);
                                            }
                                        });
                                    } else {
                                        logHttp(req, 200, 'editUser', start);
                                        res.sendStatus(200);
                                    }
                                }
                            }
                        } else {
                            // Usuario todavía no almacenado
                            // Alias es opcional. Si viene alias tiene que venir confAliasLOD.
                            // Code y comment es opcional. Si viene code tiene que venir confTeacherLOD, alias y aliasData.
                            let { alias, code, comment, confAliasLOD, confTeacherLOD } = req.body;
                            alias = _validaString(alias);
                            code = _validaString(code);
                            confAliasLOD = _validaString(confAliasLOD);
                            confTeacherLOD = _validaString(confTeacherLOD);
                            // Si ha enviado code compruebo si es válido para su email. De ser afirmativo el alias, confAliasLOD y confTeacherLOD son obligatorios.
                            if (typeof code !== 'undefined') {
                                if (typeof confTeacherLOD !== 'undefined' && typeof code === 'string' && typeof alias !== 'undefined' && typeof confAliasLOD !== 'undefined') {
                                    _compruebaCodigoProfe(code, email).then((codeValido) => {
                                        if (codeValido) {
                                            var commentV = null;
                                            if (typeof comment === 'object' && typeof comment['value'] !== 'undefined' && typeof comment['lang'] !== 'undefined') {
                                                commentV = { value: _validaString(comment.value), lang: _validaString(comment.lang) };
                                            }
                                            _aliasUtilizado(alias).then((aliasV) => {
                                                if (!aliasV) {
                                                    _creaProfe(false, uid, alias, confAliasLOD, code, confTeacherLOD, commentV).then((v) => {
                                                        if (v === true) {
                                                            logHttp(req, 201, 'editUser', start);
                                                            res.sendStatus(201);
                                                        } else {
                                                            logHttp(req, 500, 'editUser', start);
                                                            res.status(500).send('Internal error!');
                                                        }
                                                    })
                                                } else {
                                                    logHttp(req, 400, 'editUser', start);
                                                    res.status(400).send('Use another alias!');
                                                }
                                            });
                                        } else {
                                            logHttp(req, 403, 'editUser', start);
                                            res.status(403).send('Code is not valid!');
                                        }
                                    });
                                } else {
                                    logHttp(req, 400, 'editUser', start);
                                    res.status(400).send('We need more parameters!');
                                }
                            } else {
                                if (typeof alias !== 'undefined' && typeof confAliasLOD !== 'undefined') {
                                    // Si ha enviado alias y confAliasLOD compruebo si está disponible. Si está disponible lo almaceno en la BBDD y en LOD
                                    _aliasUtilizado(alias).then((aliasV) => {
                                        if (!aliasV) {
                                            _creaPersona(uid, alias, confAliasLOD).then((v) => {
                                                if (v === true) {
                                                    logHttp(req, 201, 'editUser', start);
                                                    res.sendStatus(201);
                                                } else {
                                                    logHttp(req, 500, 'editUser', start);
                                                    res.status(500).send('Internal error!');
                                                }
                                            });
                                        } else {
                                            logHttp(req, 400, 'editUser', start);
                                            res.status(400).send('Use another alias!');
                                        }
                                    });
                                } else {
                                    _creaPersona(uid, undefined, undefined).then((v) => {
                                        if (v === true) {
                                            logHttp(req, 201, 'editUser', start);
                                            res.sendStatus(201);
                                        } else {
                                            logHttp(req, 500, 'editUser', start);
                                            res.status(500).send('Internal error!');
                                        }
                                    });
                                }
                            }
                        }
                    }
                    )
                }
            });
    } catch (error) {
        winston.error(Mustache.render(
            'editUser || {{{error}}} || {{{time}}}',
            {
                error: error,
                time: Date.now() - start
            }
        ));
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
        var response = await sparqlQuery.query(query);
        return typeof 'response' !== 'undefined' && typeof response.boolean !== 'undefined' ? response.boolean : true;
    } catch (e) {
        console.error(e);
        return true;
    }
}

async function _creaProfe(personaYaCreada, uid, alias, confAliasLOD, code, confTeacherLOD, commentV = undefined, prevAlias = undefined) {
    const personaCreada = personaYaCreada ?
        await _actualizaPersona(uid, alias, confAliasLOD) :
        await _creaPersona(uid, alias, confAliasLOD, prevAlias);
    if (personaCreada) {
        const date = _getCurrentUTCString();
        let err = await updateDocument(
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

async function _creaPersona(uid, alias = undefined, confAliasLOD = undefined) {
    const creation = _getCurrentUTCString();
    const doc = {
        _id: DOCUMENT_INFO,
        id: uid,
        rol: ["STUDENT"],
        creation: creation,
        alias: alias,
        confAliasLOD: confAliasLOD,
    };
    var v = await newDocument(uid, doc);
    if (v !== null) {
        let lodPerson = {
            uid: uid,
            created: creation,
        }
        if (typeof alias !== 'undefined') {
            lodPerson['label'] = alias;
        }
        const requests = insertPerson(lodPerson);
        const promises = [];
        requests.forEach((request) => {
            const options = options4Request(request, true);
            promises.push(
                fetch(options.url, options.init));
        });
        var values = await Promise.all(promises);
        let allOk = true;
        values.forEach((v) => {
            if (v.status !== 200) {
                allOk = false;
            }
        });
        return allOk;
    }
    return false;
}

async function _actualizaPersona(uid, alias = undefined, confAliasLOD = undefined, prevAlias = undefined) {
    let todoOk = true;
    let date = _getCurrentUTCString();
    let err = await updateDocument(
        uid,
        DOCUMENT_INFO,
        {
            id: uid,
            lastUpdate: date,
            alias: alias,
            confAliasLOD: confAliasLOD
        }
    )
    if (err !== null && typeof err.acknowledged !== 'undefined' && err.acknowledged) {
        if (typeof prevAlias !== 'undefined') {
            // BORRO de LOD el alias
            const request = borraAlias(uid, prevAlias);
            const options = options4Request(request, true);
            const response = await fetch(options.url, options.init);
            todoOk = response.status === 200;
        }
        if (todoOk && typeof alias !== 'undefined') {
            const rs = insertPerson({ uid: uid, label: alias, date: date });
            const ps = [];
            rs.forEach((r) => {
                const options = options4Request(r, true);
                ps.push(fetch(options.url, options.init))
            });
            let values = await Promise.all(ps);
            values.forEach((v) => {
                if (v.status !== 200) {
                    todoOk = false;
                }
            });
        }
        return todoOk;
    } else {
        return false;
    }
}

async function _actualizaDescripcion(uid, nuevaDescripcion = undefined, date = undefined) {
    // Borro la descripción actual
    let allOk = true;
    if (typeof date === 'undefined') {
        date = _getCurrentUTCString();
    }
    const request = borraDescription(uid);
    const options = options4Request(request, true);
    const response = await fetch(options.url, options.init);
    if (response.status !== 200) {
        allOk = false;
    }
    if (allOk && nuevaDescripcion !== undefined && nuevaDescripcion !== null) {
        // Agrego la nueva descripción
        const requests = insertCommentPerson({ uid: uid, comment: nuevaDescripcion, date: date });
        const promises = [];
        requests.forEach((request) => {
            const options = options4Request(request, true);
            promises.push(fetch(options.url, options.init));
        });
        let values = await Promise.all(promises);
        values.forEach((v) => {
            if (v.status !== 200) {
                allOk = false;
            }
        });
        return allOk;
    }
    return allOk;
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