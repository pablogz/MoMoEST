const Mustache = require('mustache');
const fetch = require('node-fetch');

const { tokenCraft } = require('../../util/config');
const { NearSug } = require('../../util/pojos/near_sug');
const { logHttp } = require('../../util/auxiliar');
const winston = require('../../util/winston');

async function getFeaturesLOD(req, res) {
    const start = Date.now();
    try {
        const { lat, long, incr } = req.query;
        if (lat != undefined && long != undefined && incr != undefined) {
            try {
                const latF = parseFloat(lat), longF = parseFloat(long), incrF = parseFloat(incr);
                const templateNearFeatures = 'https://crafts.gsic.uva.es/apis/localizarteV2/query?id=places-en&latCenter={{lat}}&lngCenter={{lng}}&halfSideDeg={{incr}}&isNotType=http://dbpedia.org/ontology/PopulatedPlace&limit=800';
                const headers = {
                    Authorization: Mustache.render(
                        'Bearer {{{token}}}',
                        {
                            token: tokenCraft
                        }),
                    Accept: 'application/json'
                };
                fetch(
                    Mustache.render(
                        templateNearFeatures,
                        {
                            lat: latF,
                            lng: longF,
                            incr: incrF
                        }
                    ),
                    { headers: headers },
                ).then((response) => {
                    switch (response.status) {
                        case 200:
                            return response.json();
                        default:
                            return null;
                    }
                }).then((data) => {
                    if (data != null && data !== undefined && data.results !== undefined && data.results.bindings !== undefined) {
                        const places = data.results.bindings;
                        const nearSug = [];
                        for (let ns of places) {
                            try {
                                const n = new NearSug(ns['place']['value'], parseFloat(ns['lat']['value']), parseFloat(ns['lng']['value']));
                                n.setDistance(latF, longF);
                                nearSug.push(n);
                            } catch (error) {
                                //console.log(error)
                            }
                        }
                        if (nearSug.length > 0) {
                            nearSug.sort((a, b) => a.distance - b.distance);
                            let q2 =
                                'https://crafts.gsic.uva.es/apis/localizarteV2/resources?id=Place-en&ns=http://dbpedia.org/resource/&nspref=p';
                            const nearSugRequest = nearSug.slice(0, Math.min(10, nearSug.length));
                            nearSugRequest.forEach(n => {
                                q2 = Mustache.render(
                                    '{{{s}}}&iris={{{p}}}',
                                    {
                                        s: q2,
                                        p: n.id.replace('http://dbpedia.org/resource/', 'p:')
                                    });
                            });
                            fetch(q2, { headers: headers }
                            ).then((response) => {
                                if (response.status == 200) { return response.json(); } else { return null; }
                            }
                            ).then(data => {
                                if (data != null) {
                                    if (!Array.isArray(data)) {
                                        data = [data];
                                    }

                                    let features = [];
                                    for (let d of data) {
                                        try {
                                            let feature = {};
                                            for (let p in d) {

                                                switch (p) {
                                                    case 'iri':
                                                        feature['id'] = d[p];
                                                        for (let i = 0, tama = nearSugRequest.length; i < tama; i++) {
                                                            if (nearSugRequest[i].id == d[p]) {
                                                                feature['lat'] = nearSugRequest[i].lat;
                                                                feature['lng'] = nearSugRequest[i].long;
                                                                break;
                                                            }
                                                        }
                                                        break;
                                                    case 'label':
                                                    case 'comment': {
                                                        feature[p] = procesaPairLang(d[p]);
                                                        break;
                                                    }
                                                    case 'image':
                                                        d[p].iri = d[p].iri.replace('?width=300', '');
                                                        feature['thumbnailImg'] = d[p].iri;
                                                        if (d[p].rights !== undefined) {
                                                            feature['thumbnailLic'] = d[p].rights;
                                                        }
                                                        break;
                                                    case 'categories': {
                                                        let categories = [];
                                                        let auxiliar;
                                                        if (Array.isArray(d[p])) {
                                                            auxiliar = d[p];
                                                        } else {
                                                            auxiliar = [d[p]];
                                                        }
                                                        for (let categoryRaw of auxiliar) {
                                                            let category = {};
                                                            if (categoryRaw['iri'] !== undefined) {
                                                                category['iri'] = categoryRaw['iri'].trim();
                                                                if (categoryRaw['label'] !== undefined) {
                                                                    category['label'] = procesaPairLang(categoryRaw['label']);
                                                                }
                                                                if (categoryRaw['broader'] !== undefined) {
                                                                    if (Array.isArray(categoryRaw['broader'])) {
                                                                        category['broader'] = categoryRaw['broader'];
                                                                    } else {
                                                                        category['broader'] = [categoryRaw['broader']];
                                                                    }
                                                                }
                                                                categories.push(category);
                                                            }
                                                        }
                                                        feature['categories'] = categories;
                                                        break;
                                                    }
                                                    default:
                                                        break;
                                                }
                                            }
                                            features.push(feature);
                                        } catch (error) {
                                            //console.log(error);
                                        }
                                    }
                                    winston.info(Mustache.render(
                                        'getFeaturesLOD || {{{latF}}} || {{{longF}}} || {{{incrF}}} || {{{features}}} || {{{time}}}',
                                        {
                                            latF: latF,
                                            longF: longF,
                                            incrF: incrF,
                                            features: JSON.stringify(features),
                                            time: Date.now() - start
                                        }
                                    ));
                                    logHttp(req, 200, 'getFeaturesLOD', start);
                                    res.send(JSON.stringify(features));
                                } else {
                                    winston.info(Mustache.render(
                                        'getFeaturesLOD || {{{latF}}} || {{{longF}}} || {{{incrF}}} || {{{time}}}',
                                        {
                                            latF: latF,
                                            longF: longF,
                                            incrF: incrF,
                                            time: Date.now() - start
                                        }
                                    ));
                                    logHttp(req, 204, 'getFeaturesLOD', start);
                                    res.sendStatus(204);
                                }
                            }).catch(error => {
                                winston.info(Mustache.render(
                                    'getFeaturesLOD || {{{latF}}} || {{{longF}}} || {{{incrF}}} || {{{error}}} || {{{time}}}',
                                    {
                                        latF: latF,
                                        longF: longF,
                                        incrF: incrF,
                                        error: error,
                                        time: Date.now() - start
                                    }
                                ));
                                logHttp(req, 500, 'getFeaturesLOD', start);
                                res.sendStatus(500);
                            });
                        } else {
                            winston.info(Mustache.render(
                                'getFeaturesLOD || {{{latF}}} || {{{longF}}} || {{{incrF}}} || {{{time}}}',
                                {
                                    latF: latF,
                                    longF: longF,
                                    incrF: incrF,
                                    time: Date.now() - start
                                }
                            ));
                            logHttp(req, 204, 'getFeaturesLOD', start);
                            res.sendStatus(204);
                        }
                    } else {
                        winston.info(Mustache.render(
                            'getFeaturesLOD || {{{latF}}} || {{{longF}}} || {{{incrF}}} || {{{time}}}',
                            {
                                latF: latF,
                                longF: longF,
                                incrF: incrF,
                                time: Date.now() - start
                            }
                        ));
                        logHttp(req, 204, 'getFeaturesLOD', start);
                        res.sendStatus(204);
                    }
                }
                ).catch((error) => {
                    winston.info(Mustache.render(
                        'getFeaturesLOD || {{{error}}} || {{{time}}}',
                        {
                            error: error,
                            time: Date.now() - start
                        }
                    ));
                    logHttp(req, 500, 'getFeaturesLOD', start);
                    res.status(500).send(error);
                }
                );
            } catch (error) {
                winston.info(Mustache.render(
                    'getFeaturesLOD || {{{time}}}',
                    {
                        time: Date.now() - start
                    }
                ));
                logHttp(req, 400, 'getFeaturesLOD', start);
                res.sendStatus(400);
            }
        } else {
            winston.info(Mustache.render(
                'getFeaturesLOD || {{{time}}}',
                {
                    time: Date.now() - start
                }
            ));
            logHttp(req, 400, 'getFeaturesLOD', start);
            res.sendStatus(400);
        }
    } catch (error) {
        winston.error(Mustache.render(
            'getFeaturesLOD || {{{error}}} || {{{time}}}',
            {
                error: error,
                time: Date.now() - start
            }
        ));
        logHttp(req, 500, 'getFeaturesLOD', start);
        res.sendStatus(500);
    }
}

function procesaPairLang(raw) {
    let valorCampo = [];
    let idiomas = [];
    let auxiliar;
    if (Array.isArray(raw)) {
        auxiliar = raw;
    } else {
        auxiliar = [raw];
    }
    for (let par of auxiliar) {
        for (let idioma in par) {
            if (idiomas.includes(idioma) == false) {
                valorCampo.push({
                    'lang': idioma,
                    'value': par[idioma]
                });
                idiomas.push(idioma);
            } else {
                valorCampo.forEach(vC => {
                    if (vC.lang === idioma) {
                        if (!Array.isArray(vC.value)) {
                            let value = [];
                            value.push(vC.value);
                            vC.value = value;
                        }
                        vC.value.push(par[idioma]);
                    }
                });
            }
        }
    }
    return valorCampo;
}

module.exports = {
    getFeaturesLOD
}