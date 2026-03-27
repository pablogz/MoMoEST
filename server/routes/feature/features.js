const Mustache = require('mustache');
const fetch = require('node-fetch');
const FirebaseAdmin = require('firebase-admin');
// const short = require('short-uuid');

const { urlServer } = require('../../util/config');
const { options4Request, options4RequestOSM, checkUID, getTokenAuth, logHttp, mergeResults, sparqlResponse2Json, endpoints } = require('../../util/auxiliar');
const { getInfoFeaturesOSM, insertFeature, getInfoFeaturesSparql, getInceptionWikidata } = require('../../util/queries');
const { getInfoUser } = require('../../util/bd');
const winston = require('../../util/winston');
const { ElementOSM } = require('../../util/pojos/osm');
const { FeatureLocalRepo } = require('../../util/pojos/localRepo');
const { updateFeatureCache, FeatureCache, InfoFeatureCache } = require('../../util/cacheFeatures');
const Config = require('../../util/config');
const SPARQLQuery = require('../../util/sparqlQuery');
// const { log } = require('winston');


// http://127.0.0.1:11110/features?north=41.6582&south=41.6382&west=-4.7263&east=-4.7063
// http://127.0.0.1:11110/features?north=41.6582&south=41.6382&west=-4.7263&east=-4.7063&type=forest
// http://127.0.0.1:11110/features?north=41.6582&south=41.6382&west=-4.7263&east=-4.7063&type=schools
async function getFeatures(req, res) {
    const start = Date.now();
    function chunk(arr, size) {
        const out = [];
        for (let i = 0; i < arr.length; i += size) {
            out.push(arr.slice(i, i + size));
        }
        return out;
    }
    try {
        let { interval, north, south, west, east, type } = req.query;
        const bounds = { 'north': north, 'south': south, 'west': west, 'east': east };
        ['north', 'south', 'west', 'east'].forEach(l => {
            if (bounds[l] === undefined) {
                throw new Error('Need location (nort/south/west/east)');
            } else {
                bounds[l] = parseFloat(bounds[l]);
            }
        });
        //Compruebo que la posición enviada por el cliente "tenga sentido"
        if (bounds.north > 90 ||
            bounds.north <= -90 ||
            bounds.south >= 90 ||
            bounds.south < -90 ||
            bounds.north <= bounds.south ||
            bounds.east >= 180 ||
            bounds.east <= -180 ||
            bounds.west >= 180 ||
            bounds.west <= -180 ||
            bounds.east <= bounds.west
        ) {
            throw new Error('Location problem');
        }
        //Ya tengo la información en la variable bounds
        north = null; south = null; west = null; east = null;
        if (interval !== undefined) {
            interval = period(interval);
        }
        // Recupero los datos de OSM
        if (bounds.north - bounds.south > 0.5 || Math.abs(bounds.east - bounds.west) > 0.5) {
            throw new Error('The distance between the ends of the bound has to be less than 0.5 degrees');
        } else {
            const interT = Date.now() - start;
            const listPromise = [];
            // Petición para recuperar la información de OSM
            const options = options4RequestOSM(getInfoFeaturesOSM(bounds, type));
            listPromise.push(fetch(
                options.host + options.path,
                { headers: options.headers }).then(
                    r => { return r.status == 200 ? r.json() : null; }
                ));
            // Petición para recuperar los objetos del punto SPARQL
            const queryLocalSparql = getInfoFeaturesSparql(bounds);
            const sparqlQuery = new SPARQLQuery(`http://${Config.addrSparql}:8890/sparql`);
            listPromise.push(sparqlQuery.query(queryLocalSparql));
            Promise.all(listPromise).then(async ([dataOSM, dataLocalSparql]) => {
                const out = [];
                const vOSM = [];
                // Proceso los datos de Wikidata
                if (dataOSM != null) {
                    // Adapto el resultado para que sea compatible
                    for (let ele of dataOSM.elements) {
                        try {
                            const nOSM = new ElementOSM(ele);
                            if (interval === undefined || nOSM.wikidata) {
                                vOSM.push(nOSM);
                            }
                            // out.push(nOSM.toChestMap());
                            // const nFeatureCache = new FeatureCache(nOSM.id);
                            // // console.log(nOSM.id);
                            // const nInfoFeatureCache = new InfoFeatureCache('osm', nOSM.id, nOSM);
                            // nFeatureCache.addInfoFeatureCache(nInfoFeatureCache);
                            // updateFeatureCache(nFeatureCache);
                        } catch (error) {
                            console.error(error);
                        }
                    }
                }

                // let wikidataPromise = null;
                // if(vOSM.length > 0 && interval !== undefined) {
                //     // Hago la consulta SPARQL
                //     let values = '';
                //     for(let ele  of vOSM) {
                //         values += ele.wikidata + ' ';
                //     }
                //     values = values.trim();
                //     const wikidataQuery = new SPARQLQuery(endpoints.wikidata);
                //     winston.info(getInceptionWikidata(values, interval));
                //     wikidataPromise = wikidataQuery.query(getInceptionWikidata(values, interval));
                // }

                let wikidataDict = {};
                let wikidataPromises = null;
                if (vOSM.length > 0 && interval !== undefined) {
                    const qids = vOSM
                        .filter(e => e.wikidata)
                        .map(e => e.wikidata.trim());

                    const groups = chunk(qids, 20);
                    const wikidataQuery = new SPARQLQuery(endpoints.wikidata);

                    wikidataPromises = groups.map(g => {
                        const values = g.join(" ");
                        const query = getInceptionWikidata(values, interval);
                        winston.info(query);
                        try {
                            return wikidataQuery.query(query);
                        } catch (err) {
                            console.error("Error en chunk Wikidata:", err);
                            return null;
                        }
                    });
                }
                winston.info(wikidataPromises.length);

                if (dataLocalSparql != null) {
                    const data = mergeResults(sparqlResponse2Json(dataLocalSparql), 'feature');
                    data.forEach(f => {
                        try {
                            const feature = new FeatureLocalRepo(f);
                            out.push(feature.toChestMap());
                            // const nFeatureCache = new FeatureCache(feature.id);
                            // const nInfoFeatureCache = new InfoFeatureCache('localRepo', feature.id, feature);
                            // nFeatureCache.addInfoFeatureCache(nInfoFeatureCache);
                            // updateFeatureCache(nFeatureCache);
                        } catch (error) {
                            console.error(error);
                        }
                    });
                }

                if (vOSM.length > 0) {
                    winston.info(wikidataPromises.length);
                    if (interval === undefined) {
                        for (let ele of vOSM) {
                            out.push(ele.toChestMap());
                        }
                    } else {
                        if (wikidataPromises) {
                            const responses = await Promise.all(wikidataPromises);
                            let wikidataResults = [];
                            
                            for (const r of responses) {
                                if (!r) continue;
                                const parsed = sparqlResponse2Json(r);
                                if (!parsed) continue;
                                const merged = mergeResults(parsed, 'id');
                                wikidataResults = wikidataResults.concat(merged);
                            }

                            for (let w of wikidataResults) {
                                if (w.id) {
                                    wikidataDict[w.id] = w;
                                }
                            }

                            for (let ele of vOSM) {
                                if (!ele.wikidata) continue;
                                if (!wikidataDict[ele.wikidata]) continue;
                                out.push(ele.toChestMap());
                            }
                        }
                    }
                }

                // Se envía al cliente
                winston.info(Mustache.render(
                    'getFeatures,{{{out}}},{{{inter}}},{{{time}}}',
                    {
                        out: out.length,
                        inter: interT,
                        time: Date.now() - start
                    }
                ));
                if (out.length > 0) {
                    logHttp(req, 200, 'getFeatures', start);
                    res.send(out);
                } else {
                    logHttp(req, 204, 'getFeatures', start);
                    res.sendStatus(204);
                }
            }).catch(error => {
                console.error(error);
                res.sendStatus(500);
            });

        }
    } catch (error) {
        winston.error(Mustache.render(
            'getFeatures || {{{error}}} || {{{time}}}',
            {
                error: error,
                time: Date.now() - start
            }
        ));
        logHttp(req, 500, 'getFeatures', start);
        res.status(400).send(Mustache.render(
            '{{{error}}}\nEx. {{{urlServer}}}/features?north=41.653555&south=41.64954&west=-4.730360&east=-4.721197&group=false',
            { error: error, urlServer: urlServer }));
    }
}

function widthTesela(difL) {
    let widthLat = 0;
    let prevWidth = 361;
    for (let i = 1; i < 20; i++) {
        let p = difL / i;
        if (p == 1) {
            widthLat = p;
            break;
        } else {
            if (p > 1) {
                prevWidth = p;
            } else {
                widthLat = prevWidth;
                break;
            }
        }
    }
    return widthLat;
}

/**
 *
 * @param {*} req
 * @param {*} res
 */
async function newFeature(req, res) {
    /*
curl -X POST --user pablo:pablo -H "Content-Type: application/json" -d "{\"lat\": 4, \"long\": 5, \"comment\": [{\"value\": \"Hi!\", \"lang\": \"en\"}, {\"value\": \"Hola caracola\", \"lang\": \"es\"}], \"label\": [{\"value\":\"Título punto\", \"lang\":\"es\"}]}" "localhost:11110/pois"
    */
    const needParameters = Mustache.render(
        'Mandatory parameters in the request body are: lat[double] (latitude); long[double] (longitude); comment[string]; label[string]\nOptional parameters: thumbnail[url]; thumbnailLicense[url]; category[uri]',
        { urlServer: urlServer });
    const start = Date.now();
    try {
        const { body } = req;
        if (body) {
            if (body.lat && body.long && body.comment && body.label) {
                FirebaseAdmin.auth().verifyIdToken(getTokenAuth(req.headers.authorization))
                    .then(async dToken => {
                        const { uid } = dToken;
                        if (uid !== '') {
                            getInfoUser(uid).then(async infoUser => {
                                if (infoUser !== null && infoUser.rol.includes('TEACHER')) {
                                    let labelEs;
                                    body.label.some(label => {
                                        labelEs = label.value;
                                        return label.lang && label.lang === 'es';
                                    });
                                    const idFeature = Mustache.render(
                                        'http://moult.gsic.uva.es/data/{{{idFeature}}}',
                                        { idFeature: labelEs.replace(/ /g, '_').replace(/\//g, '').replace(/"/g, '') }
                                        // { idPoi: encodeURIComponent(labelEs.replace(/ /g, '_')) }
                                        // { idPoi: labelEs.replace(/ /g, '_').replace(/[^a-zA-Z:_]/g, '') }
                                    );
                                    //Compruebo que el id del Feature no exista. Si existe rechazo
                                    const repeatedId = await checkUID(idFeature);
                                    if (repeatedId === true) {
                                        //Inserto el nuevo Feature al no existir el id en el repositorio
                                        const p4R = {
                                            id: idFeature,
                                            author: infoUser.id,
                                            lat: body.lat,
                                            long: body.long,
                                            label: body.label,
                                            comment: body.comment
                                        };
                                        //TODO necesito comprobar si vienen parámetros adicionales (fijos, como el thumbnail)
                                        /*
                                        PARA LAS IMÁGENES
                                        image = [
                                            ...
                                            {
                                                image: url,
                                                license: url || string,
                                                thumbnail: true/false
                                            },
                                            ...
                                        ]
                                        */
                                        if (body.image) {
                                            p4R.image = body.image;
                                        }

                                        if (body.categories) {
                                            p4R.categories = body.categories;
                                        }

                                        if (body.type) {
                                            let type = body.type;
                                            if (typeof a === 'string') {
                                                type = [type];
                                            }
                                            let types = [];
                                            if (Array.isArray(type)) {
                                                type.forEach(ele => {
                                                    if (Config.typeST.includes(ele)) {
                                                        types.push(`http://moult.gsic.uva.es/ontology/${Config.classTypeST[ele]}`);
                                                    }
                                                });
                                            }
                                            if (!types.includes('http://moult.gsic.uva.es/ontology/SpatialThing')) {
                                                types.push('http://moult.gsic.uva.es/ontology/SpatialThing');
                                            }
                                            p4R.a = types;
                                        }

                                        const requests = insertFeature(p4R);
                                        const promises = [];
                                        requests.forEach(request => {
                                            const options = options4Request(request, true);
                                            promises.push(fetch(options.url, options.init));
                                        });
                                        Promise.all(promises).then((values) => {
                                            let sendOK = true;
                                            values.forEach(v => {
                                                if (v.status !== 200) {
                                                    sendOK = false;
                                                }
                                            });
                                            if (sendOK) {
                                                winston.info(Mustache.render(
                                                    'newFeature || {{{uid}}} || {{{idFeature}}} || {{{time}}}',
                                                    {
                                                        uid: uid,
                                                        idFeature: idFeature,
                                                        time: Date.now() - start
                                                    }
                                                ));
                                                logHttp(req, 201, 'newFeature', start);
                                                res.location(idFeature).sendStatus(201);
                                            } else {
                                                winston.error(Mustache.render(
                                                    'newFeature || {{{uid}}} || {{{time}}}',
                                                    {
                                                        uid: uid,
                                                        time: Date.now() - start
                                                    }
                                                ));
                                                logHttp(req, 500, 'newFeature', start);
                                                res.sendStatus(500);
                                            }
                                        });
                                    } else {
                                        winston.info(Mustache.render(
                                            'newFeature || {{{uid}}} || Label used || {{{time}}}',
                                            {
                                                uid: uid,
                                                time: Date.now() - start
                                            }
                                        ));
                                        logHttp(req, 400, 'newFeature', start);
                                        res.status(400).send('Label used in other Feature');
                                    }
                                } else {
                                    winston.info(Mustache.render(
                                        'newFeature || {{{uid}}} || {{{time}}}',
                                        {
                                            uid: uid,
                                            time: Date.now() - start
                                        }
                                    ));
                                    logHttp(req, 401, 'newFeature', start);
                                    res.sendStatus(401);
                                }
                            }).catch(error => {
                                winston.error(Mustache.render(
                                    'newFeature || {{{uid}}} || {{{error}}} || {{{time}}}',
                                    {
                                        uid: uid,
                                        error: error,
                                        time: Date.now() - start
                                    }
                                ));
                                logHttp(req, 500, 'newFeature', start);
                                res.sendStatus(500);
                            });
                        } else {
                            winston.info(Mustache.render(
                                'newFeature || {{{uid}}} || {{{time}}}',
                                {
                                    uid: uid,
                                    time: Date.now() - start
                                }
                            ));
                            logHttp(req, 403, 'newFeature', start);
                            res.status(403).send('You have to verify your email!');
                        }
                    })
                    .catch((error) => {
                        winston.info(Mustache.render(
                            'newFeature || {{{error}}} || {{{time}}}',
                            {
                                error: error,
                                time: Date.now() - start
                            }
                        ));
                        logHttp(req, 401, 'newFeature', start);
                        res.sendStatus(401);
                    });
            } else {
                winston.info(Mustache.render(
                    'newFeature || {{{time}}}',
                    {
                        time: Date.now() - start
                    }
                ));
                logHttp(req, 400, 'newFeature', start);
                res.status(400).send(needParameters);
            }
        } else {
            winston.info(Mustache.render(
                'newFeature || {{{time}}}',
                {
                    time: Date.now() - start
                }
            ));
            logHttp(req, 400, 'newFeature', start);
            res.status(400).send(needParameters);
        }
    } catch (error) {
        winston.error(Mustache.render(
            'newFeature || {{{error}}} || {{{time}}}',
            {
                error: error,
                time: Date.now() - start
            }
        ));
        logHttp(req, 400, 'newFeature', start);
        res.status(400).send(Mustache.render('{{{error}}}\n{{{parameteres}}}', { error: error, parameters: needParameters }));
    }
}

function period(interval) {
    if (typeof interval !== 'string') {
        throw new Error("Interval is not a string");
    }
    const parts = interval.split("-");
    if (parts.length !== 2) {
        throw new Error("Problem with the format of the interval");
    }
    const start = Number(parts[0].trim());
    const end = Number(parts[1].trim());
    if (isNaN(start) || isNaN(end) || start >= end) {
        throw new Error("Values must be numbers and start year must be lower than end year.");
    }
    return { start, end };
}

module.exports = {
    getFeatures,
    newFeature,
};
