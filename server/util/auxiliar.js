const Mustache = require('mustache');
const fs = require('fs');
const short = require('short-uuid');
const fetch = require('node-fetch');


const { addrSparql, portSparql, userSparql, passSparql, addrOPA, portOPA, primaryGraph, localSPARQL } = require('./config');
const { City } = require('./pojos/city');
const SPARQLQuery = require('./sparqlQuery');
const { getArcStyleWikidata } = require('./queries');

const winston = require('./winston');

const vCities = [];
const vArcStyle = [];

const endpoints = {
    'wikidata': 'https://query.wikidata.org/sparql',
    'dbpedia': 'https://dbpedia.org/sparql',
    'esdbpedia': 'https://es.dbpedia.org/sparql',
    'localSPARQL': localSPARQL
}

/**
 * Function to generate query options
 * 
 * @param {Strin} query Query to be made to SPARQL endpoint
 * @param {boolean} isAuth Variable to control whether the query must be authenticated or not
 * @returns Query options
 */
function options4Request(query, isAuth = false) {
    // Todas las consultas tienen en común la necesidad de un host, un puerto y una ruta
    let path = isAuth ? 'sparql-auth' : 'sparql';
    const isPost = query.length > 3500;
    const options = {
        host: addrSparql,
        port: portSparql,
        path: isPost ? path : `${path}?query=${encodeURIComponent(query)}`,
    };

    // Si la consulta es autenticada se agregan las cabeceras necesarias a la consulta
    if (isAuth) {
        options.headers = new fetch.Headers({
            Accept: 'application/sparql-results+json',
            Authorization: Mustache.render(
                'Basic {{{userPass}}}',
                {
                    userPass: Buffer.from(Mustache.render(
                        '{{{user}}}:{{{pass}}}',
                        { user: userSparql, pass: passSparql })
                    ).toString('base64')
                }
            ),
            "Content-Type": isPost ? 'application/sparql-query' : undefined
        });
    } else {
        options.headers = new fetch.Headers({
            Accept: 'application/sparql-results+json',
            'Content-Type': isPost ? 'application/sparql-query' : undefined
        });
    }
    const out = {
        url: `http://${options.host}:${options.port}/${options.path}`,
        init: {
            headers: options.headers,
            body: isPost ? query : undefined,
            method: isPost ? 'POST' : undefined,
        }
    }
    return out;
}

function options4RequestOSM(query, isAuth = false) {
    const options = {
        host: addrOPA,
        port: portOPA,
        path: '?' + query,
    };
    options.headers = {
        Accept: 'application/json',
    };
    return options;
}

function checkExistenceId(id) {
    return Mustache.render(
        `WITH {{{pg}}}
ASK {
    <{{{id}}}> [] [] .
}`,
        { pg: primaryGraph, id: id }
    ).replace(/\s+/g, ' ');
}

/**
 * Function to adapt the response of the SPARQL endpoint 
 * 
 * @param {Object} response Response provided by SPARQL endpoint (JSON)
 * @returns Data ready for processing
 */
function sparqlResponse2Json(response) {
    // Compruebo que la respuesta tiene los campos necesarios para precesarla
    if (response.head === undefined ||
        response.head.vars === undefined ||
        response.results === undefined ||
        response.results.bindings === undefined) {
        return null;
    } else {
        // Parámetros consultados
        const vars = response.head.vars;
        // Datos de la respuesta
        const bindings = response.results.bindings;
        // Vector que voy a devolver a la función previa
        const results = [];
        bindings.forEach(element => {
            const r = {};
            vars.forEach(v => {
                const ele = element[v];
                if (ele !== undefined && ele.type !== undefined) {
                    // Dependiendo del tipo de dato realizo un procesado u otro
                    switch (ele.type) {
                        case 'typed-literal':
                            switch (ele.datatype) {
                                case 'http://www.w3.org/2001/XMLSchema#decimal':
                                    r[v] = parseFloat(ele.value);
                                    break;
                                case 'http://www.w3.org/2001/XMLSchema#dateTime':
                                    r[v] = Date.parse(ele.value);
                                    break;
                                case 'http://www.w3.org/2001/XMLSchema#boolean':
                                    r[v] = ele.value != 0;
                                    break;
                                default:
                                    r[v] = ele.value;
                                    break;
                            }
                            // r[v] = (ele.datatype === 'http://www.w3.org/2001/XMLSchema#decimal') ?
                            //     parseFloat(ele.value) :
                            //     ele.value;
                            break;
                        case 'literal':
                            if (ele["xml:lang"] === undefined) {
                                if (ele.datatype !== undefined && ele.datatype === 'http://www.w3.org/2001/XMLSchema#dateTime') {
                                    let value = ele.value;
                                    // Comprobación por si la fecha no tiene el formato correcto
                                    if (value[0] === '-') {
                                        let parts = value.split('-');
                                        parts[1] = '0'.repeat(6 - parts[1].length).concat(parts[1]);
                                        value = parts.join('-');
                                    }
                                    r[v] = Date.parse(value);
                                } else {
                                    r[v] = ele.value;
                                }
                            } else {
                                r[v] = {
                                    lang: ele["xml:lang"],
                                    value: ele.value
                                };
                            }
                            break;
                        case 'uri':
                            r[v] = ele.value;
                            break;
                        default:
                            r[v] = ele.value;
                            break;
                    }
                }
            });
            results.push(r);
        });
        return (results);
    }
}

/**
 * Function to merge objects of an array taking into account an identifier.
 * 
 * @param {Array} vector Object array. They all have to have the property that is sent as idKey
 * @param {String} idKey Object identifier key
 * @return Merged array 
 */
function mergeResults(vector, idKey) {
    const out = [];
    let element;
    // Extaigo los elementos del vector (empezando por el final ya que utilizo pop)
    while ((element = vector.pop()) !== undefined) {
        let inter = JSON.parse(JSON.stringify(element)); // Copia del objeto
        let repe;
        const id = element[idKey];
        // Busco en el vector la primera coincidencia e itero
        while ((repe = vector.find(e => e[idKey] === id)) !== undefined) {
            // Busco la diferencia entre las dos entradas
            Object.keys(repe).forEach(k => {
                let equals = true;
                // Si es un objeto compruebo cada uno de sus campos (solo un nivel, es decir, 
                // no puede haber un objeto dentro de un objeto).
                if (typeof repe[k] === 'object') {
                    Object.keys(repe[k]).forEach(k2 => {
                        if (element[k][k2] !== undefined && element[k][k2] !== repe[k][k2]) {
                            equals = false;
                        }
                    });
                } else {
                    // Si no es un objeto comparo directamente (no espero funciones)
                    equals = (repe[k] === element[k]);
                }
                // Guardo si no son iguales
                if (!equals) {
                    let save = true;
                    // Compruebo ahora si no lo he guardado previamente
                    if (typeof repe[k] === 'object') {
                        if (Array.isArray(inter[k])) {
                            inter[k].forEach(o => {
                                let save2 = false;
                                Object.keys(o).forEach(k2 => {
                                    if (o[k2] !== repe[k][k2])
                                        save2 = true;
                                });
                                save = save2;
                            });
                        } else {
                            Object.keys(inter[k]).forEach(k2 => {
                                let save2 = false;
                                if (inter[k][k2] !== repe[k][k2]) {
                                    save2 = true;
                                }
                                save = save2;
                            });
                        }
                    } else {
                        if (Array.isArray(inter[k])) {
                            inter[k].forEach(e => { if (e === repe[k]) save = false; });
                        } else {
                            save = inter[k] !== repe[k];
                        }
                    }
                    // Guardo como vector los resultados
                    if (save) {
                        Array.isArray(inter[k]) ?
                            inter[k].push(repe[k]) :
                            inter[k] = [inter[k], repe[k]];
                    }
                }
            });
            // Elimino en el elemento con el que acabo de trabajar
            vector.splice(vector.indexOf(repe), 1);
        }
        //Compruebo que no tenga nada repetido
        const inter2 = {};
        Object.keys(inter).forEach((k) => {
            if (Array.isArray(inter[k])) {
                const a = [];
                inter[k].forEach((i2) => {
                    try {
                        if (i2.lang !== undefined && i2.value !== undefined) {
                            let yaExiste = false;
                            a.forEach((i3) => {
                                if (i3.lang === i2.lang && i2.value === i3.value) {
                                    yaExiste = true;
                                }
                            });
                            if (!yaExiste) {
                                a.push(i2);
                            }
                        } else {
                            if (a.includes(i2)) {
                                console.log(i2);
                            } else {
                                a.push(i2);
                            }
                        }
                    } catch (error) {
                        console.log(error);
                    }
                });
                inter2[k] = a;
            } else {
                inter2[k] = inter[k];
            }
        })
        //Agrego al vector de salida la fusión
        out.push(inter2);
    }
    return out;
}

// function cities() {
//     if (vCities === null || !vCities.length) {
//         //!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
//         //!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
//         //Aquí haría la petición a Wikidata en vez de leer de fichero
//         const fCities = JSON.parse(fs.readFileSync('./data/cities.json'));
//         //!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
//         //!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
//         //const i = []
//         fCities.forEach(city => {
//             if (typeof city.population !== 'undefined') {
//                 //i.push(new City(city.city, city.lat, city.long, city.population));
//                 vCities.push(new City(city.city, city.lat, city.long, city.population));
//             } else {
//                 //i.push(new City(city.city, city.lat, city.long));
//                 vCities.push(new City(city.city, city.lat, city.long));

//             }
//         });
//         //Ordeno de mayor a menor población
//         vCities.sort((city0, city1) => city1.population - city0.population);
//         //SOLUCIONADO CON LA NUEVA PETICIÓN
//         //Puede traer "filas duplicadas debido "
//         //let inter = {};
//         //let inter2 = i.filter(city => inter[city.id] ? false : inter[city.id] = true);
//         //inter2.forEach(city => vCities.push(city));
//     }
//     return vCities;
// }

async function cities() {
    if (vCities === null || !vCities.length) {
        // await fetch(
        //     Mustache.render(
        //         'https://query.wikidata.org/sparql?query={{{path}}}',
        //         {
        //             path: encodeURIComponent(
        //                 'SELECT DISTINCT ?city ?lat ?long ?population WHERE {\
        //                 {\
        //                   SELECT (MAX(?la) AS ?lat) ?city WHERE {\
        //                     ?city wdt:P31/wdt:P279* wd:Q515 ;\
        //                         p:P625/psv:P625/wikibase:geoLatitude ?la .\
        //                   } GROUP BY ?city\
        //                 }\
        //                 {\
        //                   SELECT (MAX(?lo) AS ?long) ?city WHERE {\
        //                     ?city wdt:P31/wdt:P279* wd:Q515 ;\
        //                         p:P625/psv:P625/wikibase:geoLongitude ?lo .\
        //                   } GROUP BY ?city\
        //                 }\
        //                 OPTIONAL {\
        //                   SELECT (MAX(?p) AS ?population) ?city WHERE {\
        //                     ?city wdt:P1082 ?p .\
        //                   } GROUP BY ?city\
        //                 }\
        //             }'.replace(/\s+/g, ' '))
        //         }),
        //     {
        //         headers: {
        //             Accept: 'application/json',
        //         }
        //     }).then(async result => {
        //         switch (result.status) {
        //             case 200:
        //                 return result.json();
        //             default:
        //                 return null;
        //         }
        //     }).then(async data => {
        const data = null; //TODO ELIMINAR CUANDO SE VUELVA A HACER LA PETICIÓN
        let fCities;
        if (data !== null) {
            fCities = data.results.bindings;
            fCities.forEach(city => {
                if (typeof city.population !== 'undefined') {
                    vCities.push(new City(
                        city.city.value,
                        parseFloat(city.lat.value),
                        parseFloat(city.long.value),
                        parseInt(city.population.value)
                    ));
                } else {
                    vCities.push(new City(
                        city.city,
                        parseFloat(city.lat.value),
                        parseFloat(city.long.value)
                    ));

                }
            });
        } else {
            fCities = JSON.parse(fs.readFileSync('./data/cities.json'));
            fCities.forEach(city => {
                if (typeof city.population !== 'undefined') {
                    vCities.push(new City(city.city, city.lat, city.long, city.population));
                } else {
                    vCities.push(new City(city.city, city.lat, city.long));
                }
            });
        }

        //Ordeno de mayor a menor población
        vCities.sort((city0, city1) => city1.population - city0.population);
        return vCities;
        // })
        // .catch(error => {
        //     console.log(error);
        //     const fCities = JSON.parse(fs.readFileSync('./data/cities.json'));
        //     fCities.forEach(city => {
        //         if (typeof city.population !== 'undefined') {
        //             vCities.push(new City(city.city, city.lat, city.long, city.population));
        //         } else {
        //             vCities.push(new City(city.city, city.lat, city.long));

        //         }
        //     });
        // vCities.sort((city0, city1) => city1.population - city0.population);
        // return vCities;
        // });
    } else {
        return vCities;
    }
}

async function getArcStyle4Wikidata(forceRequest = false) {
    if (vArcStyle.length === 0 || forceRequest) {
        const data = await ((new SPARQLQuery('https://query.wikidata.org/sparql')).query(getArcStyleWikidata()));
        if (data !== null) {
            const dataP = sparqlResponse2Json(data);
            vArcStyle.length = 0;
            dataP.forEach(e => {
                try {
                    vArcStyle.push({
                        id: e.arcStyle,
                        labels: [e.labelEn, e.labelEs, e.labelPt],
                    });
                } catch (error) {
                    console.log(error);
                }
            });
            return vArcStyle;
        } else {
            return vArcStyle;
        }
    } else {
        return vArcStyle;
    }
}

/**
* https://stackoverflow.com/a/5717133
*/
function validURL(str) {
    /*const pattern = new RegExp(
        Mustache.render(
            '{{{protocol}}}{{{domainName}}}{{{ipAdd}}}{{{portPath}}}{{{queryString}}}{{{fragmentLocator}}}',
            {
                protocol: '^(https?:\\/\\/)?', // protocol
                domainName: '((([a-z\\d]([a-z\\d-]*[a-z\\d])*)\\.)+[a-z]{2,}|', // domain name
                ipAdd: '((\\d{1,3}\\.){3}\\d{1,3}))', // OR ip (v4) address
                portPath: '(\\:\\d+)?(\\/[-a-z\\d%_.~+]*)*', // port and path
                queryString: '(\\?[;&a-z\\d%_.~+=-]*)?', // query string
                fragmentLocator: '(\\#[-a-z\\d_]*)?$' // fragment locator
            }
        ),
        'i');*/
    const pattern = new RegExp('^(https?:\\/\\/)?' + // protocol
        '((([a-z\\d]([a-z\\d-]*[a-z\\d])*)\\.)+[a-z]{2,}|' + // domain name
        '((\\d{1,3}\\.){3}\\d{1,3}))' + // OR ip (v4) address
        '(\\:\\d+)?(\\/[-a-z\\d%_.~+]*)*' + // port and path
        '(\\?[;&a-z\\d%_.~+=-]*)?' + // query string
        '(\\#[-a-z\\d_]*)?$', 'i'); // fragment locator

    return !!pattern.test(str);
}

async function generateUid() {
    let uid;
    let isUid = false;
    while (!isUid) {
        uid = Mustache.render(
            'http://moult.gsic.uva.es/data/{{{uid}}}',
            {
                uid: short.generate()
            }
        );
        isUid = await checkUID(uid);
    }
    return uid;
}

function rebuildURI(id, provider) {
    switch (provider) {
        case 'wikidata':
            return `http://www.wikidata.org/entity/${id}`;
        case 'dbpedia':
            return `http://http://dbpedia.org/resource/${id}`;
        default:
            return id;
    }
}

function shortId2Id(shortId) {
    let id = null;
    if (shortId !== null && shortId !== undefined) {
        const parts = shortId.split(':');
        if (parts.length === 2) {
            const end = parts[1];
            switch (parts[0]) {
                case 'osmn':
                    id = `https://www.openstreetmap.org/node/${end}`;
                    break;
                case 'osmr':
                    id = `https://www.openstreetmap.org/relation/${end}`;
                    break;
                case 'osmw':
                    id = `https://www.openstreetmap.org/way/${end}`;
                    break;
                case 'wd':
                    id = `http://www.wikidata.org/entity/${end}`;
                    break;
                case 'dbpedia':
                    id = `http://dbpedia.org/resource/${end}`;
                    break;
                case 'esdbpedia':
                    id = `http://es.dbpedia.org/resource/${end}`;
                    break;
                case 'md':
                    id = `http://moult.gsic.uva.es/data/${end}`;
                    break;
                case 'mo':
                    id = `http://moult.gsic.uva.es/ontology/${end}`;
                    break;
                default:
                    break;
            }
        }
    }
    return id;
}

function id2ShortId(id) {
    let shortId = null;
    const end = id.split('/').pop();
    switch (id.split('/').slice(0, -1).join('/').concat('/')) {
        case 'https://www.openstreetmap.org/node/':
            shortId = 'osmn:';
            break;
        case 'https://www.openstreetmap.org/relation/':
            shortId = 'osmr:';
            break;
        case 'https://www.openstreetmap.org/way/':
            shortId = 'osmw:';
            break;
        case 'http://www.wikidata.org/entity/':
            shortId = 'wd:';
            break;
        case 'http://dbpedia.org/resource/':
            shortId = 'dbpedia:';
            break;
        case 'http://es.dbpedia.org/resource/':
            shortId = 'esdbpedia:';
            break;
        case 'http://moult.gsic.uva.es/data/':
            shortId = 'md:';
            break;
        case 'http://moult.gsic.uva.es/ontology/':
            shortId = 'mo:'
            break;
        default:
            break;
    }
    if (shortId !== null) {
        shortId = shortId.concat(end);
    }
    return shortId;
}

async function checkUID(uid) {
    const options = options4Request(checkExistenceId(uid));
    return await fetch(options.url, options.init)
        .then(async r => {
            return await r.json();
        })
        .then(async j => { return !j.boolean; });
    //.catch(async error => { return true; });
}

function getTokenAuth(authorization) {
    const parts = authorization.split(' ');
    switch (parts.length) {
        case 1:
            return authorization;
        case 2:
            if (parts[0] === 'Bearer') {
                return parts[1];
            } else {
                throw new Error('401 Unauthorized');
            }
        default:
            throw new Error('401 Unauthorized');
    }
}

function logHttp(_req, statusCode, label, start) {
    winston.http(Mustache.render(
        '{{{label}}} || {{{statusCode}}} || {{{path}}} {{{method}}} {{{ip}}} || {{{time}}}',
        {
            label: label,
            statusCode: statusCode,
            path: _req.originalUrl,
            method: _req.method,
            ip: _req.ip,
            time: Date.now() - start,
        }
    ));
}

module.exports = {
    endpoints,
    options4Request,
    sparqlResponse2Json,
    mergeResults,
    cities,
    generateUid,
    checkUID,
    getTokenAuth,
    logHttp,
    options4RequestOSM,
    rebuildURI,
    getArcStyle4Wikidata,
    shortId2Id,
    id2ShortId,
}