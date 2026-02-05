const Mustache = require('mustache');
const fetch = require('node-fetch');
const FirebaseAdmin = require('firebase-admin');

const {
    endpoints,
    options4Request,
    mergeResults,
    sparqlResponse2Json,
    getTokenAuth,
    logHttp,
    shortId2Id,
    id2ShortId,
    options4RequestOSM,
} = require('../../util/auxiliar');
const {
    isAuthor,
    hasTasksOrInItinerary,
    deleteFeatureRepo,
    getInfoFeatureWikidata,
    checkInfo,
    deleteInfoFeature,
    addInfoFeature,
    // SPARQLQuery,
    getInfoFeatureEsDBpedia,
    getInfoFeatureDBpedia1,
    getInfoFeatureDBpedia2,
    queryBICJCyL,
    getInfoFeatureOSM,
    getInfoFeatureLocalRepository2,
} = require('../../util/queries');
const { getInfoUser } = require('../../util/bd');
const winston = require('../../util/winston');
const SPARQLQuery = require('../../util/sparqlQuery');
const { ElementOSM } = require('../../util/pojos/osm');
const { getFeatureCache, InfoFeatureCache, updateFeatureCache, FeatureCache } = require('../../util/cacheFeatures');
const { FeatureWikidata } = require('../../util/pojos/wikidata');
const { FeatureJCyL } = require('../../util/pojos/jcyl');
const { FeatureDBpedia } = require('../../util/pojos/dbpedia');
const { FeatureLocalRepo } = require('../../util/pojos/localRepo');

/**
 * Retrieves a feature from cache or external providers based on the given feature ID.
 * @async
 * @function getFeature
 * @param {Object} req - The request object.
 * @param {Object} res - The response object.
 * @returns {Promise<void>} - A Promise that resolves when the feature is retrieved or sends an error response if the feature is not found.
 */
async function getFeature(req, res) {
    const start = Date.now();
    try {
        const idFeature = shortId2Id(req.params.feature);
        if (idFeature !== null) {
            let update = false;
            let feature = await getFeatureCache(idFeature);
            if (feature === null) {
                // No está en la caché
                // Tengo que averiguar el proveedor de la feature a través del identificador
                const shortProvider = req.params.feature.split(':')[0];
                switch (shortProvider) {
                    case 'osmn':
                    case 'osmr':
                    case 'osmw': {
                        const options = options4RequestOSM(getInfoFeatureOSM(idFeature.split('/').pop(), shortProvider == 'osmw' ? 'way' : shortProvider == 'osmn' ? 'node' : 'relation'));
                        const data = await fetch(`${options.host}${options.path}`, { headers: options.headers }).then(r => {
                            return r.status == 200 ? r.json() : null;
                        });
                        if (data != null && data.elements != null && data.elements.length > 0) {
                            const elementOSM = new ElementOSM(data.elements[0]);
                            feature = new FeatureCache(elementOSM.id);
                            feature.addInfoFeatureCache(new InfoFeatureCache('osm', elementOSM.id, elementOSM));
                        }
                        break;
                    }
                    case 'wd': {
                        const query = getInfoFeatureWikidata(id2ShortId(idFeature));
                        const wikidataQuery = new SPARQLQuery(endpoints.wikidata);
                        const data = await wikidataQuery.query(query);
                        if (data != null) {
                            let wdR = mergeResults(sparqlResponse2Json(data)).pop();
                            if (wdR != undefined) {
                                const fWd = new FeatureWikidata(id2ShortId(idFeature), wdR);
                                await fWd.initialize();
                                const ifc = new InfoFeatureCache('wikidata', fWd.id, fWd);
                                feature = new FeatureCache(fWd.id);
                                feature.addInfoFeatureCache(ifc);
                            }
                        }
                        break;
                    }
                    case 'dbpedia': {
                        const dbpediaQuery = new SPARQLQuery(endpoints.dbpedia);
                        const query = getInfoFeatureDBpedia1(idFeature);
                        const data = await dbpediaQuery.query(query);
                        if (data != null) {
                            const dbpedia = mergeResults(sparqlResponse2Json(data)).pop();
                            if (dbpedia != undefined) {
                                const ifc = new InfoFeatureCache('dbpedia', idFeature, new FeatureDBpedia(idFeature, dbpedia));
                                feature = new FeatureCache(idFeature);
                                feature.addInfoFeatureCache(ifc);
                            }
                        }
                        break;
                    }
                    case 'esdbpedia': {
                        const dbpediaQuery = new SPARQLQuery(endpoints.esdbpedia);
                        const query = getInfoFeatureEsDBpedia(idFeature);
                        const data = await dbpediaQuery.query(query);
                        if (data != null) {
                            const esdbpedia = mergeResults(sparqlResponse2Json(data)).pop();
                            if (esdbpedia != undefined) {
                                const ifc = new InfoFeatureCache('esDBpedia', idFeature, new FeatureDBpedia(idFeature, esdbpedia));
                                feature = new FeatureCache(idFeature);
                                feature.addInfoFeatureCache(ifc);
                            }
                        }
                        break;
                    }
                    case 'md':
                        {
                            // PROPIO DEL DOMINIO
                            const localSPARQL = new SPARQLQuery(endpoints.localSPARQL);
                            const query = getInfoFeatureLocalRepository2(idFeature);
                            const data = await localSPARQL.query(query);
                            if (data != null) {
                                const localRepo = mergeResults(sparqlResponse2Json(data)).pop();
                                if (localRepo != undefined) {
                                    localRepo.feature = idFeature;
                                    const ifc = new InfoFeatureCache('localRepo', idFeature, new FeatureLocalRepo(localRepo));
                                    feature = new FeatureCache(idFeature);
                                    feature.addInfoFeatureCache(ifc);
                                }
                            }
                            break;
                        }
                    default:
                        // Nunca se va a entrar aqui porque ya se ha hecho la comprobación de que el shortID es válido
                        logHttp(req, 400, 'getFeature', start);
                        res.sendStatus(400);
                        break;
                }
                if (feature === null) {
                    // No se ha encontrado la feature que solicita el cliente
                    logHttp(req, 404, 'getFeature', start);
                    res.sendStatus(404);
                }
            } else {
                // TODO por ahora solo actualizo la caché cuando la feature ya estaba dentro. Tengo que hacer algo con las features que todavía no tienen zona ¿Creo la zona indicando que está incompleta? 
                update = true;
            }
            if (feature !== null) {
                let lookingFor = true;
                while (lookingFor) {
                    // Por cada proveedor compruebo qué información puedo recuperar. Tengo en cuenta la información que ya tengo.
                    const listPromise = [];
                    const providerPromise = [];
                    const providerPromiseID = [];
                    // Loop with all providers in feature
                    for (let provider of feature.infoFeature) {
                        switch (provider.provider) {
                            case 'osm': {
                                const infoFeatureOSM = feature.infoFeature.find((element) => element.provider == 'osm');
                                if (infoFeatureOSM != undefined && infoFeatureOSM.dataProvider != null) {
                                    if (infoFeatureOSM.dataProvider.wikidata != null && !feature.providers.includes('wikidata')) {
                                        const wikidataQuery = new SPARQLQuery(endpoints.wikidata);
                                        providerPromise.push('wikidata');
                                        providerPromiseID.push(infoFeatureOSM.dataProvider.wikidata)
                                        listPromise.push(wikidataQuery.query(getInfoFeatureWikidata(infoFeatureOSM.dataProvider.wikidata)));
                                    }
                                    if (infoFeatureOSM.dataProvider.dbpedia != null && !feature.providers.includes('dbpedia')) {
                                        const idDBpedia = infoFeatureOSM.dataProvider.dbpedia;
                                        if (idDBpedia.includes('http://es')) {
                                            const esDBpediaQuery = new SPARQLQuery(endpoints.esdbpedia);
                                            providerPromise.push('esDBpedia');
                                            providerPromiseID.push(idDBpedia);
                                            listPromise.push(esDBpediaQuery.query(getInfoFeatureEsDBpedia(idDBpedia)));
                                        }
                                        const dbpediaQuery = new SPARQLQuery(endpoints.dbpedia);
                                        providerPromise.push('dbpedia1');
                                        providerPromiseID.push(idDBpedia);
                                        listPromise.push(dbpediaQuery.query(getInfoFeatureDBpedia1(idDBpedia)));
                                        providerPromise.push('dbpedia2');
                                        providerPromiseID.push(idDBpedia);
                                        listPromise.push(dbpediaQuery.query(getInfoFeatureDBpedia2(idDBpedia)));
                                    }
                                }
                                break;
                            }
                            case 'wikidata': {
                                const infoFeatureWikidata = feature.infoFeature.find((element) => element.provider == 'wikidata');
                                if (infoFeatureWikidata != undefined && infoFeatureWikidata.dataProvider != null) {
                                    if (infoFeatureWikidata.dataProvider.osm != null && !feature.providers.includes('osm')) {
                                        const idOSM = infoFeatureWikidata.dataProvider.osm;
                                        const optionsOSM = options4RequestOSM(getInfoFeatureOSM(idOSM.split('/').pop()));
                                        providerPromise.push('osm');
                                        providerPromiseID.push(idOSM);
                                        listPromise.push(fetch(`${optionsOSM.host}${optionsOSM.path}`, { headers: optionsOSM.headers }).then(r => {
                                            return r.status == 200 ? r.json() : null;
                                        }));
                                    }
                                    if (infoFeatureWikidata.dataProvider.bicJCyL && !feature.providers.includes('jcyl')) {
                                        const localSPARQL = new SPARQLQuery(endpoints.localSPARQL);
                                        providerPromise.push('jcyl');
                                        providerPromiseID.push(infoFeatureWikidata.dataProvider.bicJCyL);
                                        listPromise.push(localSPARQL.query(queryBICJCyL(infoFeatureWikidata.dataProvider.bicJCyL)));
                                    }
                                }
                                break;
                            }
                            case 'dbpedia': {
                                // TODO ¿Relaciones con otros proveedores de información?
                                break;
                            }
                            case 'esDBpedia': {
                                // TODO ¿Relaciones con otros proveedores de información?
                                break;
                            }
                            case 'jcyl': {
                                // TODO ¿Relaciones con otros proveedores de información?
                                break;
                            }
                            case 'localRepo': {
                                // TODO ¿Relaciones con otros proveedores de información?
                                break;
                            }
                            default:
                                break;
                        }
                    }

                    if (providerPromise.length > 0) {
                        // Tengo peticiones que realizar
                        const responses = await Promise.all(listPromise);
                        let dbpedia1 = null, dbpedia2 = null, idDBpedia;
                        for (let i = 0; i < responses.length; i++) {
                            const p = providerPromise[i];
                            const response = responses[i];
                            switch (p) {
                                case 'osm': {
                                    if (response != null && response.elements != null && response.elements.length > 0) {
                                        const elementOSM = new ElementOSM(response.elements[0]);
                                        const ifc = new InfoFeatureCache('osm', providerPromiseID[i], elementOSM);
                                        feature.addInfoFeatureCache(ifc);
                                    } else {
                                        if (!feature.providers.includes('osm')) {
                                            const ifc = new InfoFeatureCache('osm', providerPromiseID[i], null);
                                            feature.addInfoFeatureCache(ifc);
                                        }
                                    }
                                    break;
                                }
                                case 'wikidata': {
                                    if (response != null) {
                                        let wdR = mergeResults(sparqlResponse2Json(response)).pop();
                                        if (wdR != undefined) {
                                            const fWd = new FeatureWikidata(providerPromiseID[i], wdR);
                                            await fWd.initialize();
                                            const ifc = new InfoFeatureCache('wikidata', fWd.id, fWd);
                                            feature.addInfoFeatureCache(ifc);
                                        } else {
                                            const ifc = new InfoFeatureCache('wikidata', providerPromiseID[i], null);
                                            feature.addInfoFeatureCache(ifc);
                                        }
                                    } else {
                                        if (!feature.providers.includes('wikidata')) {
                                            const ifc = new InfoFeatureCache('wikidata', providerPromiseID[i], null);
                                            feature.addInfoFeatureCache(ifc);
                                        }
                                    }
                                    break;
                                }
                                case 'dbpedia1': {
                                    idDBpedia = providerPromiseID[i];
                                    dbpedia1 = response != null ? sparqlResponse2Json(response) : null;
                                    break;
                                }
                                case 'dbpedia2': {
                                    idDBpedia = providerPromiseID[i];
                                    dbpedia2 = response != null ? sparqlResponse2Json(response) : null;
                                    const dbpedia = dbpedia1 != null && dbpedia2 != null ?
                                        mergeResults(dbpedia1.concat(dbpedia2)) :
                                        dbpedia1 != null ?
                                            mergeResults(dbpedia1) :
                                            dbpedia2 != null ?
                                                mergeResults(dbpedia2) :
                                                [];
                                    if (dbpedia != null) {
                                        if (dbpedia.length > 0) {
                                            const ifc = new InfoFeatureCache('dbpedia', idDBpedia, new FeatureDBpedia(idDBpedia, dbpedia.pop()));
                                            feature.addInfoFeatureCache(ifc);
                                        } else {
                                            if (!feature.providers.includes('dbpedia')) {
                                                const ifc = new InfoFeatureCache('dbpedia', idDBpedia, null);
                                                feature.addInfoFeatureCache(ifc);
                                            }
                                        }
                                    }
                                    break;
                                }
                                case 'esDBpedia': {
                                    if (response != null) {
                                        const esDBpediaResult = mergeResults(sparqlResponse2Json(response));
                                        if (esDBpediaResult.length > 0) {
                                            const ifc = new InfoFeatureCache('esDBpedia', providerPromiseID[i], new FeatureDBpedia(providerPromiseID[i], esDBpediaResult.pop()));
                                            feature.addInfoFeatureCache(ifc);
                                        } else {
                                            const ifc = new InfoFeatureCache('esDBpedia', providerPromiseID[i], null);
                                            feature.addInfoFeatureCache(ifc);
                                        }
                                    } else {
                                        if (!feature.providers.includes('esDBpedia')) {
                                            const ifc = new InfoFeatureCache('esDBpedia', providerPromiseID[i], null);
                                            feature.addInfoFeatureCache(ifc);
                                        }
                                    }
                                    break;
                                }
                                case 'jcyl': {
                                    if (response != null) {
                                        const bicJCyL = mergeResults(sparqlResponse2Json(response)).pop();
                                        if (bicJCyL != undefined && bicJCyL != null) {
                                            const fJCyL = new FeatureJCyL('chd:'.concat(bicJCyL['id'].split('/').pop()), bicJCyL)
                                            const ifc = new InfoFeatureCache('jcyl', fJCyL.id, fJCyL);
                                            feature.addInfoFeatureCache(ifc);
                                        } else {
                                            const ifc = new InfoFeatureCache('jcyl', '', null);
                                            feature.addInfoFeatureCache(ifc);
                                        }
                                    } else {
                                        const ifc = new InfoFeatureCache('jcyl', '', null);
                                        feature.addInfoFeatureCache(ifc);
                                    }
                                    break;
                                }
                                case 'localRepo': {
                                    //TODO
                                    break;
                                }
                                default:
                                    break;
                            }
                        }
                    } else {
                        // Ya tengo toda la información
                        lookingFor = false;
                    }
                }
                // Envío la información al cliente
                if (update) {
                    updateFeatureCache(feature);
                }
                const out = [];
                feature.infoFeature.forEach(infoFeature => {
                    if (infoFeature.dataProvider != null) {
                        out.push({
                            provider: infoFeature.provider,
                            data: infoFeature.dataProvider.toCHESTFeature(),
                        });
                    }
                });
                logHttp(req, 200, 'getFeature', start);
                res.send(out);
            }
        } else {
            // El cliente no ha enviado ningún shortID o no es válido el que ha enviado
            logHttp(req, 400, 'getFeature', start);
            res.sendStatus(400);
        }
    } catch (error) {
        console.error(error);
        winston.error(Mustache.render(
            'getFeature || {{{error}}} || {{{time}}}',
            {
                error: error,
                time: Date.now() - start
            }
        ));
        logHttp(req, 500, 'getFeature', start);
        res.status(500).send(error);
    }
}


/**
 * Edits a feature.
 * @async
 * @function editFeature
 * @param {Object} req - The request object.
 * @param {Object} res - The response object.
 * @returns {Promise<void>} - A Promise that resolves when the feature is edited.
 */
async function editFeature(req, res) {
    /*
curl -X PUT -H "Authorization: Bearer adfasd" -H "Content-Type: application/json" -d "{\"body\": [ {\"lat\": {\"action\": \"UPDATE\", \"newValue\": 12, \"oldValue\": 4}}, {\"comment\": {\"action\": \"REMOVE\", \"value\": {\"lang\": \"en\", \"value\": \"Hi!\"}}}, {\"comment\": {\"action\": \"ADD\", \"value\": {\"lang\": \"it\", \"value\": \"Chao!\"}}}]}" "localhost:11110/features/Ttulo_punto"

    */
    const start = Date.now();
    try {
        const idFeature = Mustache.render('http://moult.gsic.uva.es/data/{{{feature}}}', { feature: req.params.feature });
        FirebaseAdmin.auth().verifyIdToken(getTokenAuth(req.headers.authorization))
            .then(async dToken => {
                const { uid } = dToken;
                if (uid !== '') {
                    getInfoUser(uid).then(async infoUser => {
                        if (infoUser !== null && infoUser.rol.includes('TEACHER')) {
                            let { body } = req;
                            if (body && body.body) {
                                body = body.body;
                                //Compruebo que el feature pertenezca al usuario
                                let options = options4Request(isAuthor(idFeature, infoUser.id));
                                fetch(options.url, options.init)
                                    .then(r => {
                                        return r.json();
                                    }).then(json => {
                                        if (json.boolean === true || infoUser.rol === 0) {
                                            //Compruebo el formato de la petición del cliente
                                            //Obtengo todas las eliminaciones e inserciones                                
                                            /*
                                             [
                                                 {
                                                    lat: {
                                                     action: 'UPDATE'
                                                     newValue: 12
                                                     oldValue: 10
                                                 }},
                                                 {
                                                    label: {
                                                     action: 'ADD',
                                                     value: {
                                                         lang: 'it',
                                                         value: 'Chao'
                                                     }
                                                 }},
                                                 {
                                                    thumbnail: {
                                                     action: 'REMOVE',
                                                     value: 'url'
                                                 }}
                                             ]
                                             */
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
                                                //Compruebo que los parámetros de las eliminaciones estuvieran en el repositorio (ASK)
                                                options = options4Request(checkInfo(idFeature, remove));
                                                fetch(options.url, options.init)
                                                    .then(r => {
                                                        return r.json();
                                                    }).then(json => {
                                                        if (json.boolean === true) {
                                                            //Realizo las eliminaciones y, posteriormente, las inserciones
                                                            //TODO tengo que controlar cuando han finalizado las promesas
                                                            const requestsDelete = deleteInfoFeature(idFeature, remove);
                                                            requestsDelete.forEach(request => {
                                                                options = options4Request(request, true);
                                                                fetch(options.url, options.init);
                                                            });
                                                            const requestsAdd = addInfoFeature(idFeature, add);
                                                            requestsAdd.forEach(request => {
                                                                options = options4Request(request, true);
                                                                fetch(options.url, options.init);
                                                            });
                                                            winston.info(Mustache.render(
                                                                'editFeature || {{{feature}}} || {{{uid}}} || {{{time}}}',
                                                                {
                                                                    feature: idFeature,
                                                                    uid: uid,
                                                                    time: Date.now() - start
                                                                }
                                                            ));
                                                            logHttp(req, 202, 'editFeature', start);
                                                            res.sendStatus(202);
                                                        } else {
                                                            winston.info(Mustache.render(
                                                                'editFeature || {{{feature}}} || {{{uid}}} || {{{time}}}',
                                                                {
                                                                    feature: idFeature,
                                                                    uid: uid,
                                                                    time: Date.now() - start
                                                                }
                                                            ));
                                                            logHttp(req, 400, 'editFeature', start);
                                                            res.sendStatus(400);
                                                        }
                                                    });
                                            } catch (error) {
                                                winston.info(Mustache.render(
                                                    'editFeature || {{{feature}}} || {{{uid}}} || {{{time}}}',
                                                    {
                                                        feature: idFeature,
                                                        uid: uid,
                                                        time: Date.now() - start
                                                    }
                                                ));
                                                logHttp(req, 400, 'editFeature', start);
                                                res.sendStatus(400);
                                            }
                                        } else {
                                            winston.info(Mustache.render(
                                                'editFeature || {{{feature}}} || {{{uid}}} || User is not the author || {{{time}}}',
                                                {
                                                    feature: idFeature,
                                                    uid: uid,
                                                    time: Date.now() - start
                                                }
                                            ));
                                            logHttp(req, 401, 'editFeature', start);
                                            res.status(401).send('User is not the author of the feature');
                                        }
                                    });

                            } else {
                                winston.info(Mustache.render(
                                    'editFeature || {{{feature}}} || {{{uid}}} || {{{time}}}',
                                    {
                                        feature: idFeature,
                                        uid: uid,
                                        time: Date.now() - start
                                    }
                                ));
                                logHttp(req, 400, 'editFeature', start);
                                res.sendStatus(400);
                            }
                        } else {
                            winston.info(Mustache.render(
                                'editFeature || {{{feature}}} || {{{uid}}} || {{{time}}}',
                                {
                                    feature: idFeature,
                                    uid: uid,
                                    time: Date.now() - start
                                }
                            ));
                            logHttp(req, 401, 'editFeature', start);
                            res.sendStatus(401);
                        }
                    });
                } else {
                    winston.info(Mustache.render(
                        'editFeature || {{{feature}}} || {{{uid}}} || {{{time}}}',
                        {
                            feature: idFeature,
                            uid: uid,
                            time: Date.now() - start
                        }
                    ));
                    logHttp(req, 403, 'editFeature', start);
                    res.status(403).send('You have to verify your email!');
                }
            }).catch(error => {
                winston.info(Mustache.render(
                    'editFeature || {{{feature}}} || {{{error}}} || {{{time}}}',
                    {
                        feature: idFeature,
                        error: error,
                        time: Date.now() - start
                    }
                ));
                logHttp(req, 401, 'editFeature', start);
                res.sendStatus(401);
            });
    } catch (error) {
        winston.error(Mustache.render(
            'editFeature || {{{error}}} || {{{time}}}',
            {
                error: error,
                time: Date.now() - start
            }
        ));
        logHttp(req, 500, 'editFeature', start);
        res.sendStatus(500);
    }
}

/**
 *
 * @param {*} req
 * @param {*} res
 */
async function deleteFeature(req, res) {
    /*
curl -X DELETE --user pablo:pablo "localhost:11110/features/Ttulo_punto"
    */
    // const idFeature = Mustache.render('http://chest.gsic.uva.es/data/{{{feature}}}', { feature: encodeURIComponent(req.params.feature) });
    const idFeature = Mustache.render('http://moult.gsic.uva.es/data/{{{feature}}}', { feature: req.params.feature });
    try {
        FirebaseAdmin.auth().verifyIdToken(getTokenAuth(req.headers.authorization))
            .then(async dToken => {
                const { uid } = dToken;
                if (uid !== '') {
                    getInfoUser(uid).then(async infoUser => {
                        if (infoUser !== null && infoUser.rol.includes('TEACHER')) {
                            //Compruebo que el feature pertenezca al usuario
                            let options = options4Request(isAuthor(idFeature, `http://moult.gsic.uva.es/data/${infoUser.id}`));
                            fetch(options.url, options.init)
                                .then(r => {
                                    return r.json();
                                }).then(json => {
                                    if (json.boolean === true || infoUser.rol === 0) {
                                        //Compruebo que el feature no tiene ninguna tarea ni itinerario asociado
                                        options = options4Request(hasTasksOrInItinerary(idFeature));
                                        fetch(options.url, options.init)
                                            .then(r => {
                                                return r.json();
                                            }).then(json => {
                                                if (json.boolean === false) {
                                                    //Elimino el feature
                                                    options = options4Request(deleteFeatureRepo(idFeature), true);
                                                    fetch(options.url, options.init)
                                                        .then(r =>
                                                            res.sendStatus(r.status)
                                                        ).catch(error => res.status(500).send(error));
                                                } else {
                                                    res.status(401).send('This feature has associated tasks or itineraries');
                                                }
                                            });
                                    } else {
                                        res.status(401).send('User is not the author of the feature');
                                    }
                                });
                        } else {
                            res.sendStatus(401);
                        }
                    });
                } else {
                    res.status(403).send('You have to verify your email!');
                }
            }).catch(error => {
                console.error(error);
                res.sendStatus(401);
            });
    } catch (error) {
        res.status(500).send(error);
    }
}

module.exports = {
    getFeature,
    editFeature,
    deleteFeature,
};
