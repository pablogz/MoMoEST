const Mustache = require('mustache');
const short = require('short-uuid');

const winston = require('./winston');
const { primaryGraph } = require('./config');
const { Task } = require('./pojos/tasks');
const { forEach } = require('ssl-root-cas');

function getLocationFeatures(bounds) {
    return Mustache.render(
        `PREFIX mo: <http://moult.gsic.uva.es/ontology/>
WITH {{{primaryGraph}}}
SELECT DISTINCT ?feature ?lat ?lng WHERE {
GRAPH <http://moult.gsic.uva.es> {
?feature 
a mo:SpatialThing ;
mo:hasGeometry ?geo .
?geo 
a mo:Point ; 
geo:lat ?lat ; 
geo:long ?lng . 
FILTER(
xsd:decimal(?lat) >= {{{south}}} && 
xsd:decimal(?lat) < {{{north}}} && 
xsd:decimal(?lng) >= {{{west}}} && 
xsd:decimal(?lng) < {{{east}}}) .
}
}`,
        {
            primaryGraph: primaryGraph,
            north: bounds.north,
            east: bounds.east,
            south: bounds.south,
            west: bounds.west
        }).replace(/\s+/g, ' ');
}

function getInfoFeaturesSparql(bounds) {
    return Mustache.render(
        `PREFIX mo: <http://moult.gsic.uva.es/ontology/>
WITH {{{pg}}}
SELECT DISTINCT ?feature ?type ?lat ?lng ?label ?comment ?author ?thumbnailImg ?thumbnailLic ?category WHERE {
?feature 
a mo:SpatialThing ;
a ?type ;
mo:hasGeometry ?geo ;
rdfs:label ?label ;
rdfs:comment ?comment ;
dc:creator ?author .
?geo 
a mo:Point ; 
geo:lat ?lat ; 
geo:long ?lng . 
OPTIONAL{
?feature mo:image ?thumbnailImg .
OPTIONAL {?thumbnailImg dc:license ?thumbnailLic }.
}.
OPTIONAL{ ?feature mo:hasCategory ?category } .
FILTER(
xsd:decimal(?lat) >= {{{south}}} && 
xsd:decimal(?lat) < {{{north}}} && 
xsd:decimal(?lng) >= {{{west}}} && 
xsd:decimal(?lng) < {{{east}}}) .
}`,
        {
            pg: primaryGraph,
            north: bounds.north,
            east: bounds.east,
            south: bounds.south,
            west: bounds.west
        }).replace(/\s+/g, ' ');
}

function getInfoFeatureOSM(idFeature, type = 'nwr') {
    return Mustache.render(
        'data=[out:json][timeout:25];{{{type}}}({{{id}}});out meta geom;',
        {
            id: idFeature,
            type: type
        }
    ).replace(/\s+/g, ' ').replace(RegExp('"', 'g'), '%22').replace(RegExp(/\s/, 'g'), '%20');
}

function getInfoFeaturesOSM(bounds, type) {
    let filter = '';
    let listFilter;
    const area = Mustache.render(
        '({{{s}}},{{{w}}},{{{n}}},{{{e}}})',
        {
            s: bounds.south,
            w: bounds.west,
            n: bounds.north,
            e: bounds.east,
        }
    )
    switch (type) {
        case 'forest':
            listFilter = [
                // { key: "natural", value: "^(tree|wood)$", e: false },
                { typeQuery: "nwr", objs: [{ key: "natural", valor: "tree", e: "=" }], },
            ]
            break;
        case 'schools':
            listFilter = [
                { typeQuery: "nwr", objs: [{ key: "amenity", valor: "^(school|college|university)$", e: "~" }], },
                { typeQuery: "nwr", objs: [{ key: "building", valor: "^(school|college|university)$", e: "~" }], },

            ]
            break;
        default:
            listFilter = [
                { typeQuery: "nwr", objs: [{ key: "heritage", e: "", }], },
                { typeQuery: "nwr", objs: [{ key: "historic", e: "", }], },
                { typeQuery: "nwr", objs: [{ key: "museum", valor: "^(history|art)$", e: "~", }], },
                { typeQuery: "nwr", objs: [{ key: "building", valor: "^(church|palace|tower)$", e: "~", }], },
                { typeQuery: "nwr", objs: [{ key: "amenity", valor: "place_of_worship", e: "=", }], },
                { typeQuery: "nwr", objs: [{ key: "tourism", valor: "^(artwork|attraction|museum)$", e: "~", }], },
                {
                    typeQuery: "nwr",
                    objs: [
                        { key: "place", e: "=", valor: "square" },
                        { key: "tourism", e: "" },
                    ]
                },
                {
                    typeQuery: 'nwr',
                    objs: [
                        { key: "amenity", e: "=", valor: "fountain" },
                        { key: "drinking_water", e: "!=", valor: "yes" },
                    ]
                }
            ];
            break;
    }

    for (let f of listFilter) {
        //f.e: 0 = =; 1 = ~; -1=withoutValue
        filter = Mustache.render(
            '{{{oldF}}}{{{typeQuery}}}{{#objs}}["{{{key}}}"{{{value}}}]{{/objs}}{{{area}}};',
            {
                oldF: filter,
                typeQuery: f.typeQuery,
                objs: f.objs,
                key: this.key,
                value: function () {
                    const o = this.e;
                    return this.e != '' ? `${o}"${this.valor}"` : o;
                },

                area: area
            }
        );
    }

    return Mustache.render(
        'data=[out:json][timeout:25];({{{filter}}});out meta geom;',
        {
            filter: filter
        }).replace(/\s+/g, ' ').replace(RegExp('"', 'g'), '%22').replace(RegExp(/\s/, 'g'), '%20');
}

function getInfoFeatureLocalRepository(idFeature) {
    return Mustache.render(
        `PREFIX mo: <http://moult.gsic.uva.es/ontology/>
WITH {{{pg}}}
SELECT ?type ?lat ?lng ?label ?comment ?author ?thumbnailImg ?thumbnailLic ?category WHERE {
<{{{id}}}> 
a mo:SpatialThing ;
a ?type ;
mo:hasGeometry ?geo;
rdfs:label ?label ;
rdfs:comment ?comment ;
dc:creator ?author .
?geo 
a mo:Point ; 
geo:lat ?lat ; 
geo:long ?long . 
OPTIONAL{
<{{{id}}}> mo:thumbnail ?thumbnailImg .
OPTIONAL {?thumbnailImg dc:license ?thumbnailLic }.
}.
OPTIONAL{ <{{{id}}}> mo:hasCategory ?category } .
}`,
        {
            pg: primaryGraph,
            id: idFeature
        }).replace(/\s+/g, ' ');
}

function getInfoFeatureLocalRepository2(idFeature) {
    return Mustache.render(
        `PREFIX mo: <http://moult.gsic.uva.es/ontology/>
WITH {{{pg}}}
SELECT ?type ?lat ?lng ?label ?comment ?author ?thumbnailImg ?thumbnailLic ?category WHERE {
<{{{id}}}> 
a mo:SpatialThing ;
a ?type ;
mo:hasGeometry ?geo ;
rdfs:label ?label ;
rdfs:comment ?comment ;
dc:creator ?author .
?geo 
a mo:Point ; 
geo:lat ?lat ; 
geo:long ?lng . 
OPTIONAL{
<{{{id}}}> mo:thumbnail ?thumbnailImg .
OPTIONAL {?thumbnailImg dc:license ?thumbnailLic }.
}.
OPTIONAL{ <{{{id}}}> mo:hasCategory ?category } .
}`,
        {
            pg: primaryGraph,
            id: idFeature
        }).replace(/\s+/g, ' ');
}

function getArcStyleWikidata() {
    return `SELECT DISTINCT ?arcStyle ?labelEn ?labelEs ?labelPt WHERE { 
[] wdt:P149 ?arcStyle . 
{ 
SELECT ?arcStyle ?labelEn ?labelEs ?labelPt WHERE { 
?arcStyle rdfs:label ?labelEn . 
FILTER (lang(?labelEn) = "en") . 
OPTIONAL { 
?arcStyle 
rdfs:label ?labelEs . 
FILTER (lang(?labelEs) = "es") . 
} 
OPTIONAL { 
?arcStyle 
rdfs:label ?labelPt . 
FILTER (lang(?labelPt) = "pt") . 
} 
} 
} 
}`.replace(/\s+/g, ' ');
}

function queryBICJCyL(id) {
    // Mantengo chest en la ontología hasta que cambie el fichero que generé con los datos de la Junta
    return Mustache.render(`PREFIX wd: <http://www.wikidata.org/prop/direct/>
PREFIX mo: <http://chest.gsic.uva.es/ontology/>
WITH <http://chest.gsic.uva.es/jcyl>
SELECT DISTINCT ?id ?label ?altLabel ?url ?category ?categoryLabel ?lat ?long ?comment ?license WHERE {
?id
wd:P3177 "{{{id}}}";
rdfs:seeAlso ?url ;
rdfs:label ?label ;
dc:license ?license ;
mo:hasCategory ?category .
?category rdfs:label ?categoryLabel .
OPTIONAL {
?id mo:geometry ?geo .
?geo 
geo:lat ?lat ;
geo:long ?long .
}
OPTIONAL {?id skos:altLabel ?altLabel . }
OPTIONAL {?id rdfs:comment ?comment .}
}`, { pg: primaryGraph, id: id }).replace(/\s+/g, ' ');
}

function getInfoFeatureWikidata(idWikidata) {
    return Mustache.render(
        `SELECT ?type ?label ?description ?image ?arcStyle ?inception ?bicJCyL ?osm ?point WHERE {
{{{idWiki}}}
wdt:P31 ?type .
OPTIONAL {
{{{idWiki}}} 
rdfs:label ?label .
FILTER(
lang(?label)="es" || 
lang(?label)="en" || 
lang(?label)="pt").
}
OPTIONAL {
{{{idWiki}}} 
schema:description ?description .
FILTER(
lang(?description)="es" || 
lang(?description)="en" || 
lang(?description)="pt").
}
OPTIONAL { {{{idWiki}}} wdt:P18 ?image . }
OPTIONAL { {{{idWiki}}} wdt:P149 ?arcStyle . }
OPTIONAL { {{{idWiki}}} wdt:P571 ?inception . }
OPTIONAL { {{{idWiki}}} wdt:P3177 ?bicJCyL . }
OPTIONAL { {{{idWiki}}} wdt:P402 ?osm . }
OPTIONAL { {{{idWiki}}} wdt:P625 ?point .}
}`, {
        pg: primaryGraph,
        idWiki: idWikidata
    }).replace(/\s+/g, ' ');
}

function getInfoFeatureEsDBpedia(idesDBpedia) {
    return Mustache.render(
        `SELECT DISTINCT ?comment ?type ?lat ?long ?label WHERE {
<{{{idDb}}}>
a ?type ;
rdfs:comment ?comment .
FILTER(
lang(?comment)="es" || 
lang(?comment)="en" || 
lang(?comment)="pt"
).
OPTIONAL { <{{{idDb}}}> geo:lat ?lat . }
OPTIONAL { <{{{idDb}}}> geo:long ?long . }
OPTIONAL { <{{{idDb}}}> rdfs:label ?label . 
FILTER(
lang(?label)="es" || 
lang(?label)="en" || 
lang(?label)="pt"
).
}
}`, {
        idDb: idesDBpedia
    }).replace(/\s+/g, ' ');
}

function getInfoFeatureDBpedia1(idDBpedia) {
    return Mustache.render(
        `SELECT DISTINCT ?comment ?type ?label WHERE {
<{{{idDb}}}>
a ?type ;
rdfs:comment ?comment .
FILTER(
lang(?comment)="es" || 
lang(?comment)="en" || 
lang(?comment)="pt"
).
OPTIONAL { <{{{idDb}}}> rdfs:label ?label . 
FILTER(
lang(?label)="es" || 
lang(?label)="en" || 
lang(?label)="pt"
).
}
}`, { idDb: idDBpedia }).replace(/\s+/g, ' ');
}

function getInfoFeatureDBpedia2(idDBpedia) {
    return Mustache.render(
        `SELECT DISTINCT ?place ?type ?comment ?label WHERE {
?place
a ?type ;
rdfs:comment ?comment ;
owl:sameAs <{{{idDb}}}> .
FILTER(
lang(?comment)="es" ||
lang(?comment)="en" ||
lang(?comment)="pt"
) .
OPTIONAL { ?place rdfs:label ?label . 
FILTER(
lang(?label)="es" || 
lang(?label)="en" || 
lang(?label)="pt"
).
}
}`, { idDb: idDBpedia }).replace(/\s+/g, ' ');
}

function getCitiesWikidata() {
    return `SELECT DISTINCT ?city ?lat ?long ?population WHERE {
{
SELECT (MAX(?la) AS ?lat) ?city WHERE {
?city wdt:P31/wdt:P279* wd:Q515 ;
p:P625/psv:P625/wikibase:geoLatitude ?la .
} GROUP BY ?city
}
{
SELECT (MAX(?lo) AS ?long) ?city WHERE {
?city wdt:P31/wdt:P279* wd:Q515 ;
p:P625/psv:P625/wikibase:geoLongitude ?lo .
} GROUP BY ?city
}
OPTIONAL {
SELECT (MAX(?p) AS ?population) ?city WHERE {
?city wdt:P1082 ?p .
} GROUP BY ?city
}
}`.replace(/\s+/g, ' ');
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

function checkExistenceAlias(alias) {
    return Mustache.render(
        `PREFIX mo: <http://moult.gsic.uva.es/ontology/>
WITH {{{pg}}}
ASK {[] a mo:Person ; rdfs:label '''{{{alias}}}''' . }`,
        {
            pg: primaryGraph,
            alias: alias
        }
    ).replace(/\s+/g, ' ');
}

function fields(uid, p4R) {
    const triples = [];
    let idGeo = null;
    let vector;
    for (const key in p4R) {
        switch (key) {
            case 'lat':
            case 'long':
                if (idGeo === null) {
                    idGeo = `http://moult.gsic.uva.es/data/${short.generate()}`;
                    triples.push(Mustache.render(
                        '<{{{uid}}}> a <http://moult.gsic.uva.es/ontology/Point> . ',
                        {
                            uid: idGeo,
                        }
                    ));
                    triples.push(Mustache.render(
                        '<{{{uid}}}> mo:hasGeometry <{{{idGeo}}}> . ',
                        {
                            uid: uid,
                            idGeo: idGeo,
                        }
                    ));
                }
                triples.push(Mustache.render(
                    '<{{{uid}}}> geo:{{{key}}} {{{value}}} . ',
                    {
                        uid: idGeo,
                        key: key,
                        value: p4R[key]
                    }
                ));
                break;
            case 'label':
            case 'comment':
                if (Array.isArray(p4R[key])) {
                    vector = p4R[key];
                } else {
                    vector = [];
                    vector.push(p4R[key]);
                }
                vector.forEach(p => {
                    if (p.lang && p.value) {
                        triples.push(Mustache.render(
                            '<{{{uid}}}> rdfs:{{{key}}} """{{{value}}}"""@{{{lang}}} . ',
                            {
                                uid: uid,
                                key: key,
                                // value: p.value.replace(/"/g, "\\\"").replace(/(\r\n|\n|\r)/gm, ""),
                                value: p.value.replace(/"/g, "\\\""),
                                lang: p.lang
                            }
                        ));
                    } else {
                        if (p.value) {
                            triples.push(Mustache.render(
                                '<{{{uid}}}> rdfs:{{{key}}} """{{{value}}}""" . ',
                                {
                                    uid: uid,
                                    key: key,
                                    value: p.value.replace(/"/g, "\\\""),
                                }
                            ));
                        } else {
                            triples.push(Mustache.render(
                                '<{{{uid}}}> rdfs:{{{key}}} """{{{value}}}""" . ',
                                {
                                    uid: uid,
                                    key: key,
                                    value: p.replace(/"/g, "\\\""),
                                }
                            ));
                            // throw new Error(Mustache.render('{{{key}}} malformed', { key: key }));
                        }
                    }
                });
                break;
            case 'author':
                triples.push(Mustache.render(
                    '<{{{uid}}}> dc:creator <{{{value}}}> . ',
                    {
                        uid: uid,
                        value: p4R[key].includes('http://moult.gsic.uva.es/data/') ? p4R[key] : `http://moult.gsic.uva.es/data/${p4R[key]}`
                    }
                ));
                break;
            case 'aT':
                var type;
                switch (p4R[key]) {
                    // TODO depende del dominio
                    case 'mcq':
                    case 'tf':
                    case 'photo':
                    case 'multiplePhotos':
                    case 'video':
                    case 'photoText':
                    case 'videoText':
                    case 'multiplePhotosText':
                    case 'text':
                    case 'noAnswer':
                        type = p4R[key];
                        break;
                    default:
                        throw new Error('Problem with the client aT');
                }
                triples.push(Mustache.render(
                    '<{{{uid}}}> mo:answerType mo:{{{aT}}} . ',
                    {
                        uid: uid,
                        aT: type
                    }
                ));
                break;
            case 'inSpace':
                var v = [];
                if (!Array.isArray(p4R[key])) {
                    v.push(p4R[key]);
                } else {
                    v = p4R[key];
                }
                v.forEach(spa => {
                    let value;
                    switch (spa) {
                        case 'physical':
                            value = 'PhysicalSpace';
                            break;
                        case 'virtual':
                            value = 'VirtualSpace';
                            break;
                        default:
                            throw new Error('Problem with the client aT');
                    }
                    triples.push(Mustache.render(
                        '<{{{uid}}}> mo:inSpace mo:{{{space}}} . ',
                        {
                            uid: uid,
                            space: value
                        }
                    ));
                });
                break;
            case 'hasFeature':
                triples.push(Mustache.render(
                    '<{{{uid}}}> mo:hasSpatialThing <{{{idFeature}}}> . ',
                    {
                        uid: uid,
                        idFeature: p4R[key]
                    }
                ));
                break;
            case 'image':
                /*
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
                if (Array.isArray(p4R[key])) {
                    vector = p4R[key];
                } else {
                    vector = [];
                    vector.push(p4R[key]);
                }
                vector.forEach(img => {
                    triples.push(Mustache.render(
                        '<{{{uid}}}> mo:image <{{{image}}}> . ',
                        {
                            uid: uid,
                            image: img.image
                        }));
                    triples.push(Mustache.render(
                        '<{{{image}}}> a mo:Image . ',
                        {
                            image: img.image
                        }));
                    if (img.license) {
                        const tL = _validURL(img.license);
                        triples.push(Mustache.render(
                            '<{{{image}}}> dc:license {{{license}}} . ',
                            {
                                image: img.image,
                                license: tL ?
                                    Mustache.render('<{{{l}}}>', { l: img.license }) :
                                    Mustache.render('"{{{l}}}"', { l: img.license })
                            }));
                    }
                    if (img.thumbnail) {
                        triples.push(Mustache.render(
                            '<{{{uid}}}> mo:thumbnail <{{{image}}}> . ',
                            {
                                uid: uid,
                                image: img.image
                            }));
                    }
                });
                break;
            case 'categories':
                // categories = [
                //     ...
                //     {
                //         iri: url,
                //     },
                //     {
                //         iri: url,
                //         label: [
                //             ...
                //             {
                //                 value: string,
                //                 lang: string
                //             },
                //             {
                //                 value: string
                //             }
                //                     ...
                //                 ],
                //     },
                //     {
                //         iri: url,
                //         broader: [
                //             ...
                //             url,
                //             ...
                //                 ]
                //     }
                //             {
                //         iri: url,
                //         label: [
                //             ...
                //             {
                //                 value: string,
                //                 lang: string
                //             },
                //             {
                //                 value: string
                //             }
                //                     ...
                //                 ],
                //         broader: [
                //             ...
                //             url,
                //             ...
                //                 ]
                //     }
                //         ...
                //     ]
                if (Array.isArray(p4R[key])) {
                    vector = p4R[key];
                } else {
                    vector = [];
                    vector.push(p4R[key]);
                }
                vector.forEach(category => {
                    if (category.iri !== undefined) {
                        triples.push(Mustache.render(
                            '<{{{uid}}}> skos:broader <{{{iri}}}> . ',
                            {
                                uid: uid,
                                iri: category.iri
                            }
                        ));
                        if (category.label) {
                            if (Array.isArray(category.label)) {
                                vector = category.label;
                            } else {
                                vector = [];
                                vector.push(category.label);
                            }
                            vector.forEach(p => {
                                if (p.lang && p.value) {
                                    triples.push(Mustache.render(
                                        '<{{{iri}}}> rdfs:label """{{{value}}}"""@{{{lang}}} . ',
                                        {
                                            iri: category.iri,
                                            value: p.value.replace(/"/g, "\\\"").replace(/(\r\n|\n|\r)/gm, ""),
                                            lang: p.lang
                                        }
                                    ));
                                } else {
                                    throw new Error('Category label malformed');
                                }
                            });
                        }
                        if (category.broader) {
                            let aux;
                            if (Array.isArray(category.broader)) {
                                aux = category.broader;
                            } else {
                                aux = [];
                                aux.push(category.broader);
                            }
                            aux.forEach(broader => {
                                triples.push(Mustache.render(
                                    '<{{{iri}}}> skos:broader <{{{broader}}}> . ',
                                    {
                                        iri: category.iri,
                                        broader: broader
                                    }
                                ));
                                triples.push(Mustache.render(
                                    '<{{{broader}}}> skos:narrower <{{{iri}}}> . ',
                                    {
                                        iri: category.iri,
                                        broader: broader
                                    }
                                ));
                            });
                        }
                    }
                });
                break;
            case 'distractors':
                if (Array.isArray(p4R[key])) {
                    vector = p4R[key];
                } else {
                    vector = [];
                    vector.push(p4R[key]);
                }
                vector.forEach(ele => {
                    if (ele['value'] && ele['lang'])
                        triples.push(Mustache.render(
                            '<{{{uid}}}> mo:distractor """{{{v}}}"""@{{{lang}}} . ',
                            {
                                uid: uid,
                                v: ele['value'],
                                lang: ele['lang']
                            }
                        ));
                });
                break;
            case 'correct':
                if (Array.isArray(p4R[key])) {
                    vector = p4R[key];
                } else {
                    vector = [];
                    vector.push(p4R[key]);
                }
                vector.forEach(ele => {
                    if (typeof ele == 'boolean' || ele["value"] && ele["lang"])
                        triples.push(Mustache.render(
                            '<{{{uid}}}> mo:correct {{{d}}} . ',
                            {
                                uid: uid,
                                d: typeof ele == 'boolean' ?
                                    ele :
                                    Mustache.render(
                                        '"""{{{dd}}}"""@{{{lang}}}',
                                        {
                                            dd: ele["value"],
                                            lang: ele["lang"]
                                        }
                                    )
                            }
                        ));
                });
                break;
            case 'singleSelection':
                triples.push(Mustache.render(
                    '<{{{uid}}}> mo:singleSelection {{{d}}} . ',
                    {
                        uid: uid,
                        d: p4R[key]
                    }
                ));
                break;
            case 'created':
                triples.push(Mustache.render(
                    '<{{{uid}}}> dc:created "{{{d}}}"^^xsd:dateTime . ',
                    {
                        uid: uid,
                        d: p4R[key]
                    }
                ));
                break;
            case 'date':
                triples.push(Mustache.render(
                    '<{{{uid}}}> dc:date "{{{d}}}"^^xsd:dateTime . ',
                    {
                        uid: uid,
                        d: p4R[key]
                    }
                ));
                break;
            case 'a':
                if (typeof p4R[key] === 'string') {
                    p4R[key] = [p4R[key]];
                }
                if (Array.isArray(p4R[key])) {
                    p4R[key].forEach((tipo) => {
                        if (typeof tipo === 'string' && tipo.includes('http://moult.gsic.uva.es/ontology/')) {
                            triples.push(Mustache.render(
                                '<{{{uid}}}> a <{{{type}}}> . ',
                                {
                                    uid: uid,
                                    type: tipo
                                }
                            ));
                        }
                    });
                }
                break;
            default:
                break;
        }
    }
    return triples;
}

function insertFeature(p4R) {
    const uid = p4R.id;
    const triples = fields(uid, p4R);
    return spliceQueries('insertData', [{ id: primaryGraph, triples: triples }]);
}

function addInfoFeature(uid, p4R) {
    const triples = fields(uid, p4R);
    return spliceQueries('insertData', [{ id: primaryGraph, triples: triples }]);
}

function deleteInfoFeature(uid, p4R) {
    const triples = fields(uid, p4R);
    return spliceQueries('deleteData', [{ id: primaryGraph, triples: triples }]);
}

function insertPerson(dataPerson) {
    const uid = `http://moult.gsic.uva.es/data/${dataPerson.uid}`;
    const triples = fields(uid, dataPerson);
    triples.push(Mustache.render(
        '<{{{uid}}}> a <http://moult.gsic.uva.es/ontology/Person> . ',
        {
            uid: uid
        }
    ));
    return spliceQueries('insertData', [{ id: primaryGraph, triples: triples }]);
}

function insertCommentPerson(dataTeacher) {
    const uid = `http://moult.gsic.uva.es/data/${dataTeacher.uid}`;
    const triples = fields(uid, dataTeacher);
    return spliceQueries('insertData', [{ id: primaryGraph, triples: triples }]);
}


/*
    triples = [
        ...
        {
            id: graph0
            triples: [
                label: ...,
                comment: ...,
            ]
        },
        ...
    ]
    */
function spliceQueries(action, triples) {
    let head;
    switch (action) {
        case 'insertData':
            head = 'PREFIX mo: <http://moult.gsic.uva.es/ontology/> PREFIX md: <http://moult.gsic.uva.es/data/> INSERT DATA { ';
            break;
        case 'deleteData':
            head = 'PREFIX mo: <http://moult.gsic.uva.es/ontology/> PREFIX md: <http://moult.gsic.uva.es/data/> DELETE DATA { ';
            break;
        default:
            throw new Error('Error in action');
    }

    const requests = [];
    triples.forEach(graphData => {
        let i = 0;
        const parts = [];
        const graph = Mustache.render('GRAPH {{{id}}} {', {
            id: graphData.id.includes('<') && graphData.id.includes('>') ? graphData.id : `<${graphData.id}>`
        });
        graphData.triples.forEach(triple => {
            // if (triple.length + graph.length + 2 >= 10000) {
            //     throw new Error(Mustache.render('{{{triple}}} is too long!!', { triple: triple }));
            // } else {
            //     if (parts[i] === null || parts[i] === undefined) {
            //         parts[i] = [];
            //         parts[i].push(triple);
            //     } else {
            //         let tama = 0;
            //         parts[i].forEach(v => tama += v.length);
            //         if (tama + triple.length + 2 >= 10000) {
            //             i += 1;
            //             parts[i] = [];
            //             parts[i].push(triple);
            //         } else {
            //             parts[i].push(triple);
            //         }
            //     }
            // }
            if (parts[i] === null || parts[i] === undefined) {
                parts[i] = [];
                parts[i].push(triple);
            } else {
                parts[i].push(triple);
            }
        });
        parts.forEach(part => {
            requests.push(Mustache.render(
                '{{{graph}}}{{{part}}}',
                {
                    graph: graph,
                    part: function () {
                        let o = '';
                        part.forEach(p => o = Mustache.render('{{{o}}}{{{p}}}', { o: o, p: p }));
                        return o;
                    }
                }));
        });
    });
    const out = [];
    while (requests.length > 0) {
        let r = requests.shift();
        const s = [];
        let t = r.length;
        for (let i = 0, tama = requests.length; i < tama; i++) {
            if (t + requests[i].length < 10000) {
                t += requests[i].length;
                s.push(i);
            }
        }
        s.forEach(position => {
            r = Mustache.render('{{{r}}}} {{{n}}}', { r: r, n: requests.splice(position, 1) });
        });
        const query = Mustache.render('{{{head}}}{{{r}}}}}', { head: head, r: r });
        winston.info(query);
        out.push(query);
    }
    return out;
}

function isAuthor(uid, author) {
    return Mustache.render(
        `WITH {{{pg}}}
ASK {
<{{{id}}}> dc:creator <{{{author}}}> .
}`,
        {
            pg: primaryGraph,
            id: uid,
            author: author
        }
    ).replace(/\s+/g, ' ');
}

function hasTasksOrInItinerary(uid) {
    return Mustache.render(
        `PREFIX mo: <http://moult.gsic.uva.es/ontology/>
WITH {{{pg}}}
ASK {
?s mo:hasSpatialThing <{{{id}}}>
}`,
        { pg: primaryGraph, id: uid }
    ).replace(/\s+/g, ' ');
}

function taskInIt0(uid) {
    return Mustache.render(
        `WITH {{{pg}}}
ASK {
?s rdf:next <{{{id}}}>
}`,
        { pg: primaryGraph, id: uid }
    ).replace(/\s+/g, ' ');
}

function taskInIt1(uid) {
    return Mustache.render(
        `WITH {{{pg}}}
ASK {
?s rdf:first <{{{id}}}>
}`,
        { pg: primaryGraph, id: uid }
    ).replace(/\s+/g, ' ');
}

function deleteObject(uid) {
    const query = Mustache.render(`WITH {{{pg}}} DELETE WHERE {
<{{{id}}}> ?p ?o .
}`,
        { pg: primaryGraph, id: uid }
    ).replace(/\s+/g, ' ');
    winston.info(query);
    return query;
}

/**
 * UTILIZAR CON CUIDADO
 * Con esta consulta elimino la Spatial Thing ¡¡y su geometría asociada!!
 * UTILIZAR CON CUIDADO
 *
 * @param {*} idFeature Identificador de la Spatial Thing
 * @return {*} Consulta codificada para borrar una Spatail Thing
 */
function deleteFeatureRepo(idFeature) {
    const query = Mustache.render(
        `PREFIX mo: <http://moult.gsic.uva.es/ontology/>
WITH {{{pg}}} DELETE WHERE {
<{{{id}}}> mo:hasGeometry ?geo ;
?p ?o .
?geo ?z ?y .
}`,
        { pg: primaryGraph, id: idFeature }
    ).replace(/\s+/g, ' ');
    winston.info(query);
    return query;
}

function borraAlias(uid, alias) {
    return Mustache.render(
        `WITH {{{pg}}} DELETE WHERE {
DELETE DATA {
GRAPH {{{pg}}} {
<{{{id}}}> rdfs:label '''{{{alias}}}''' .
}}`,
        { pg: primaryGraph, id: `http://moult.gsic.uva.es/data/${uid}`, alias: alias }
    ).replace(/\s+/g, ' ');
}

function borraDescription(uid) {
    const query = Mustache.render(
        `WITH {{{pg}}} DELETE WHERE {
<{{{id}}}> rdfs:comment ?o .
}`,
        { pg: primaryGraph, id: uid }
    ).replace(/\s+/g, ' ');
    return query;
}

function getDescription(uid) {
    return Mustache.render(
        `WITH {{{pg}}} SELECT DISTINCT ?comment WHERE {
<http://moult.gsic.uva.es/data/{{{id}}}> rdfs:comment ?comment .
}`,
        { pg: primaryGraph, id: uid }
    ).replace(/\s+/g, ' ');
}


function getAllInfo(uid) {
    return Mustache.render(
        `WITH {{{pg}}}
SELECT ?p ?o WHERE {
<{{{id}}}> ?p ?o .
}`,
        { pg: primaryGraph, id: uid }
    ).replace(/\s+/g, ' ');
}

function checkInfo(uid, p4R) {
    const triples = [];
    for (const key in p4R) {
        switch (key) {
            case 'lat':
            case 'long':
                triples.push(Mustache.render(
                    '<{{{uid}}}> geo:{{{key}}} {{{value}}} . ',
                    {
                        uid: uid,
                        key: key,
                        value: p4R[key]
                    }
                ));
                break;
            case 'label':
            case 'comment':
                triples.push(Mustache.render(
                    '<{{{uid}}}> rdfs:{{{key}}} """{{{value}}}"""@{{{lang}}} . ',
                    {
                        uid: uid,
                        key: key,
                        value: p4R[key].value,
                        lang: p4R[key].lang
                    }
                ));
                break;
            case 'image':
                triples.push(Mustache.render(
                    '<{{{uid}}}> mo:image <{{{image}}}> . ',
                    {
                        uid: uid,
                        image: p4R[key].image
                    }));
                if (p4R[key].license) {
                    triples.push(Mustache.render(
                        '<{{{image}}}> dc:license {{{license}}} . ',
                        {
                            image: p4R[key].image,
                            license: _validURL(p4R[key].license) ?
                                Mustache.render('<{{{l}}}>', { l: p4R[key].license }) :
                                Mustache.render('"{{{l}}}"', { l: p4R[key].license })
                        }));
                }
                break;
            case 'thumbnail':
                triples.push(Mustache.render(
                    '<{{{uid}}}> mo:thumbnail <{{{image}}}> . ',
                    {
                        uid: uid,
                        image: p4R[key].image
                    }));
                triples.push(Mustache.render(
                    '<{{{image}}}> a mo:Image . ',
                    {
                        image: p4R[key].image
                    }
                ));
                if (p4R[key].license) {
                    triples.push(Mustache.render(
                        '<{{{image}}}> dc:license {{{license}}} . ',
                        {
                            image: p4R[key].image,
                            license: _validURL(p4R[key].license) ?
                                Mustache.render('<{{{l}}}>', { l: p4R[key].license }) :
                                Mustache.render('"{{{l}}}"', { l: p4R[key].license })
                        }));
                }
                break;
            case 'aT':
                var type;
                switch (p4R[key]) {
                    case 'mcq':
                    case 'tf':
                    case 'photo':
                    case 'multiplePhotos':
                    case 'video':
                    case 'photoText':
                    case 'videoText':
                    case 'multiplePhotosText':
                    case 'text':
                    case 'noAnswer':
                        type = p4R[key];
                        break;
                    default:
                        throw new Error('Problem with the client aT');
                }
                triples.push(Mustache.render(
                    '<{{{uid}}}> mo:answerType mo:{{{aT}}} . ',
                    {
                        uid: uid,
                        aT: type
                    }
                ));
                break;
            case 'inSpace':
                var v = [];
                if (!Array.isArray(p4R[key])) {
                    v.push(p4R[key]);
                } else {
                    v = p4R[key];
                }
                v.forEach(spa => {
                    let value;
                    switch (spa) {
                        case 'physical':
                            value = 'PhysicalSpace';
                            break;
                        case 'virtual':
                            value = 'VirtualSpace';
                            break;
                        default:
                            throw new Error('Problem with the client aT');
                    }
                    triples.push(Mustache.render(
                        '<{{{uid}}}> mo:inSpace mo:{{{space}}} . ',
                        {
                            uid: uid,
                            space: value
                        }
                    ));
                });
                break;
            case 'hasSpatialThing':
                triples.push(Mustache.render(
                    '<{{{uid}}}> mo:has <{{{idSpatialThing}}}> . ',
                    {
                        uid: uid,
                        idSpatialThing: p4R[key]
                    }
                ));
                break;
            default:
                throw new Error('401');
        }
    }

    let out = 'ASK { ';
    triples.forEach(triple => {
        out = Mustache.render('{{{o}}}{{{t}}}', { o: out, t: triple });
    });
    return Mustache.render('{{{o}}}}', { o: out });
}

function getTasksFeature(idFeature) {
    return Mustache.render(
        `PREFIX mo: <http://moult.gsic.uva.es/ontology/>
WITH {{{pg}}}
SELECT DISTINCT ?task ?at ?space ?author ?label ?comment ?distractor ?correct ?singleSelection WHERE {
?task 
a mo:LearningTask ; 
mo:hasSpatialThing <{{{feature}}}> ; 
mo:inSpace ?space ; 
mo:answerType ?at ; 
rdfs:comment ?comment ; 
dc:creator ?author . 
OPTIONAL {?task rdfs:label ?label .} 
OPTIONAL {?task mo:distractor ?distractor .} 
OPTIONAL {?task mo:correct ?correct .} 
OPTIONAL {?task mo:singleSelection ?singleSelection .} 
}`,
        {
            pg: primaryGraph,
            feature: idFeature
        }).replace(/\s+/g, ' ');
}
/**
 * Recupera las tareas de itineario de un itinerario
 *
 * @param {String} idIt Iri del itineario
 * @return {String} Query 
 */
function getItineraryTasks(idIt) {
    return `PREFIX mo: <http://moult.gsic.uva.es/ontology/>
WITH <${idIt}>
SELECT DISTINCT ?task ?at ?space ?author ?label ?comment ?distractor ?correct ?singleSelection WHERE {
<${idIt}> mo:hasLearningTask ?task .
?task
a mo:LearningTask ; 
mo:inSpace ?space ; 
mo:answerType ?at ; 
rdfs:comment ?comment ; 
dc:creator ?author . 
OPTIONAL {?task rdfs:label ?label .} 
OPTIONAL {?task mo:distractor ?distractor .} 
OPTIONAL {?task mo:correct ?correct .} 
OPTIONAL {?task mo:singleSelection ?singleSelection .} 
}`
}

function insertTask(p4R) {
    const uid = p4R.id;
    const triples = fields(uid, p4R);
    triples.push(Mustache.render(
        '<{{{uid}}}> a <http://moult.gsic.uva.es/ontology/LearningTask> . ',
        {
            uid: uid
        }
    ));
    return spliceQueries('insertData', [{ id: primaryGraph, triples: triples }]);
}

function getInfoTask(idTask) {
    return Mustache.render(
        `PREFIX mo: <http://moult.gsic.uva.es/ontology/>
WITH {{{pg}}}
SELECT DISTINCT ?feature ?at ?space ?author ?label ?comment ?distractor ?correct ?singleSelection ?image WHERE {
<{{{task}}}> 
a mo:LearningTask ; 
mo:hasSpatialThing ?feature ; 
mo:inSpace ?space ; 
mo:answerType ?at ; 
rdfs:comment ?comment ; 
dc:creator ?author . 
OPTIONAL {<{{{task}}}> rdfs:label ?label .} 
OPTIONAL {<{{{task}}}> mo:distractor ?distractor .} 
OPTIONAL {<{{{task}}}> mo:correct ?correct .} 
OPTIONAL {<{{{task}}}> mo:singleSelection ?singleSelection .}
OPTIONAL {<{{{task}}}> mo:image ?image .} 
}`,
        {
            pg: primaryGraph,
            task: idTask
        }).replace(/\s+/g, ' ');
}

function checkDataSparql(points) {
    let query = 'ASK {';
    for (let point of points) {
        if (point.tasks.length > 0) {
            for (let task of point.tasks) {
                // query = Mustache.render(
                //     '{{{q}}} chd:{{{t}}} cho:hasPoi chd:{{{p}}} .',
                //     {
                //         q: query,
                //         t: task.replace('http://chest.gsic.uva.es/data/', ''),
                //         p: point.idPoi.replace('http://chest.gsic.uva.es/data/', '')
                //     }
                // );
                query = Mustache.render(
                    '{{{q}}} <{{{t}}}> mo:hasSpatialThing <{{{p}}}> .',
                    {
                        q: query,
                        t: task,
                        p: point.idFeature
                    }
                );
            }
        } else {
            query = Mustache.render(
                // '{{{q}}} chd:{{{p}}} a cho:POI .',
                // {
                //     q: query,
                //     p: point.idPoi.replace('http://chest.gsic.uva.es/data/', '')
                // }
                '{{{q}}} <{{{p}}}> a mo:SpatialThing .',
                {
                    q: query,
                    p: point.idFeature
                }
            );
        }
    }
    winston.info(Mustache.render('{{{q}}} }', { q: query }));
    return Mustache.render('{{{q}}} }', { q: query });
}

function insertItinerary(itinerary) {
    //Inserto en el grafo de chest y creo el grafo propio del itinerario
    const grafoComun = [], grafoItinerario = [];
    grafoComun.push(Mustache.render(
        '<{{{id}}}> a <http://moult.gsic.uva.es/ontology/Itinerary> . ',
        {
            id: itinerary.id
        }
    ));
    grafoComun.push(Mustache.render(
        '<{{{id}}}> a <{{{typeIt}}}> . ',
        {
            id: itinerary.id,
            typeIt: itinerary.type
        }
    ));
    itinerary.labels.forEach(l => {
        if (Array.isArray(l.value)) {
            l.value.forEach(v => {
                grafoComun.push(Mustache.render(
                    '<{{{id}}}> rdfs:label """{{{label}}}"""@{{{lang}}} . ',
                    {
                        id: itinerary.id,
                        label: v,
                        lang: l.lang
                    }
                ));
            });
        } else {
            grafoComun.push(Mustache.render(
                '<{{{id}}}> rdfs:label """{{{label}}}"""@{{{lang}}} . ',
                {
                    id: itinerary.id,
                    label: l.value,
                    lang: l.lang
                }
            ));
        }
    });
    itinerary.comments.forEach(c => {
        if (Array.isArray(c.value)) {
            c.value.forEach(v => {
                grafoComun.push(Mustache.render(
                    '<{{{id}}}> rdfs:comment """{{{comment}}}"""@{{{lang}}} . ',
                    {
                        id: itinerary.id,
                        comment: v,
                        lang: c.lang
                    }
                ));
            });
        } else {
            grafoComun.push(Mustache.render(
                '<{{{id}}}> rdfs:comment """{{{comment}}}"""@{{{lang}}} . ',
                {
                    id: itinerary.id,
                    comment: c.value,
                    lang: c.lang
                }
            ));
        }
    });
    grafoComun.push(Mustache.render(
        '<{{{id}}}> dc:creator <{{{author}}}> . ',
        {
            id: itinerary.id,
            author: itinerary.author,
        }
    ));
    let prevFeature = '';
    for (let index = 0, tama = itinerary.points.length; index < tama; index++) {
        const point = itinerary.points[index];
        grafoItinerario.push(Mustache.render(
            '<{{{id}}}> <http://moult.gsic.uva.es/ontology/hasSpatialThing> <{{{feature}}}> . ',
            {
                id: itinerary.id,
                feature: point.idFeature,
            }
        ));
        if (itinerary.type === 'http://moult.gsic.uva.es/ontology/ListItinerary' && index === 0) {
            grafoItinerario.push(Mustache.render(
                '<{{{id}}}> rdf:first <{{{firstPoint}}}> . ',
                {
                    id: itinerary.id,
                    firstPoint: point.idFeature,
                }
            ));
            prevFeature = point.idFeature;
        }
        if (itinerary.type === 'http://moult.gsic.uva.es/ontology/ListItinerary' && index > 0) {
            grafoItinerario.push(Mustache.render(
                '<{{{prev}}}> rdf:next <{{{current}}}> . ',
                {
                    prev: prevFeature,
                    current: point.idFeature,
                }
            ));
            prevFeature = point.idFeature;
        }
        if (point.altCommentFeature !== null) {
            // TODO el comentario puede ser un objeto
            grafoItinerario.push(Mustache.render(
                '<{{{id}}}> rdfs:comment """{{{comment}}}"""@{{{lang}}} . ',
                {
                    id: point.idFeature,
                    comment: point.altCommentFeature.value,
                    lang: point.altCommentFeature.lang
                }
            ));
            if (typeof point.altCommentFeature == 'string') {
                point.altCommentFeature = { value: point.altCommentFeature };
            }
            if (!Array.isArray(point.altCommentFeature)) {
                point.altCommentFeature = [point.altCommentFeature];
            }
        }
        let prevTask = '';
        for (let indexTask = 0, tamaTask = point.tasks.length; indexTask < tamaTask; indexTask++) {
            const task = point.tasks[indexTask];
            grafoItinerario.push(Mustache.render(
                '<{{{idFeature}}}> <http://moult.gsic.uva.es/ontology/hasLearningTask> <{{{idTask}}}> . ',
                {
                    idFeature: point.idFeature,
                    idTask: task,
                }
            ));
            if (itinerary.type !== 'http://moult.gsic.uva.es/ontology/BagItinerary' && indexTask === 0) {
                grafoItinerario.push(Mustache.render(
                    '<{{{idFeature}}}> rdf:first <{{{idTask}}}> . ',
                    {
                        idFeature: point.idFeature,
                        idTask: task,
                    }
                ));
                prevTask = task;
            }
            if (itinerary.type !== 'http://moult.gsic.uva.es/ontology/BagItinerary' && indexTask > 0) {
                grafoItinerario.push(Mustache.render(
                    '<{{{preTask}}}> rdf:next <{{{currentTask}}}> . ',
                    {
                        preTask: prevTask,
                        currentTask: task,
                    }
                ));
                prevTask = task;
            }
        }
    }

    if (itinerary.track != null) {
        const track = itinerary.track;
        grafoItinerario.push(Mustache.render(
            '<{{{idIt}}}> mo:hasTrack <{{{idTrack}}}> . ',
            {
                idIt: itinerary.id,
                idTrack: track.id,
            }
        ));
        grafoItinerario.push(Mustache.render(
            '<{{{idTrack}}}> a mo:Track . ',
            {
                idTrack: track.id,
            }
        ));
        track.pointsTrack.forEach(pointTrack => {
            grafoItinerario.push(Mustache.render(
                '<{{{idTrack}}}> mo:pointTrack <{{{idPT}}}> . ',
                {
                    idTrack: track.id,
                    idPT: pointTrack.id,
                }
            ));
            grafoItinerario.push(Mustache.render(
                '<{{{idPT}}}> a mo:PointTrack . ',
                {
                    idPT: pointTrack.id,
                }
            ));
            grafoItinerario.push(Mustache.render(
                '<{{{idPT}}}> mo:position {{{position}}} . ',
                {
                    idPT: pointTrack.id,
                    position: pointTrack.order,
                }
            ));
            grafoItinerario.push(Mustache.render(
                '<{{{idPT}}}> mo:hasGeometry <{{{idPT}}}_point> . ',
                {
                    idPT: pointTrack.id,
                }
            ));
            if (pointTrack.timestamp != null) {
                grafoItinerario.push(Mustache.render(
                    '<{{{idPT}}}> dc:date "{{{timestamp}}}"^^xsd:dateTime . ',
                    {
                        idPT: pointTrack.id,
                        timestamp: pointTrack.timestamp,
                    }
                ));
            }
            grafoItinerario.push(Mustache.render(
                '<{{{idPT}}}_point> a mo:Point . ',
                {
                    idPT: pointTrack.id,
                }
            ));
            grafoItinerario.push(Mustache.render(
                '<{{{idPT}}}_point>  geo:lat {{{lat}}} . ',
                {
                    idPT: pointTrack.id,
                    lat: pointTrack.lat,
                }
            ));
            grafoItinerario.push(Mustache.render(
                '<{{{idPT}}}_point>  geo:long {{{long}}} . ',
                {
                    idPT: pointTrack.id,
                    long: pointTrack.long,
                }
            ));
            if (pointTrack.alt != null) {
                grafoItinerario.push(Mustache.render(
                    '<{{{idPT}}}_point>  geo:alt {{{alt}}} . ',
                    {
                        idPT: pointTrack.id,
                        alt: pointTrack.alt,
                    }
                ));
            }
        });
    }

    if (itinerary.tasks !== null && itinerary.tasks.length > 0) {
        for (const task of itinerary.tasks) {
            grafoItinerario.push(Mustache.render(
                '<{{{idIt}}}> mo:hasLearningTask <{{{idTask}}}> . ',
                {
                    idIt: itinerary.id,
                    idTask: task.id,
                }
            ));
            const uid = task.id;
            const triples = fields(uid, Task.toMap(task));
            triples.push(Mustache.render(
                '<{{{uid}}}> a <http://moult.gsic.uva.es/ontology/LearningTask> . ',
                {
                    uid: uid
                }
            ));
            triples.forEach(triple => {
                grafoItinerario.push(triple);
            });
        }
    }

    const t = new Date();
    grafoComun.push(Mustache.render(
        '<{{{id}}}> dc:created "{{{time}}}"^^xsd:dateTime . ',
        {
            id: itinerary.id,
            time: t.toISOString()
        }));

    grafoComun.push(Mustache.render(
        '<{{{id}}}> dc:date "{{{time}}}"^^xsd:dateTime . ',
        {
            id: itinerary.id,
            time: t.toISOString()
        }));

    return spliceQueries('insertData', [
        {
            id: primaryGraph,
            triples: grafoComun
        },
        {
            id: itinerary.id,
            triples: grafoItinerario
        }
    ]);
}

function getAllItineraries() {
    return `PREFIX mo: <http://moult.gsic.uva.es/ontology/>
WITH ${primaryGraph}
SELECT ?it ?type ?label ?comment ?author ?authorLbl ?update WHERE { 
?it 
a mo:Itinerary ; 
a ?type ; 
rdfs:label ?label ; 
rdfs:comment ?comment ; 
dc:date ?update ; 
dc:creator ?author . 
OPTIONAL {?author rdfs:label ?authorLbl} . 
}`.replace(/\s+/g, ' ');
}

function getInfoItinerary(idIt) {
    return Mustache.render(
        `PREFIX mo: <http://moult.gsic.uva.es/ontology/>
SELECT DISTINCT ?type ?label ?comment ?author ?authorLbl ?feature ?first ?next ?track ?tasksIt WHERE { 
GRAPH {{{pg}}} {
<{{{itinerario}}}> a ?type ;
rdfs:label ?label ;
rdfs:comment ?comment ;
dc:date ?update ;
dc:creator ?author .
OPTIONAL {?author rdfs:label ?authorLbl} .
}
GRAPH <{{{itinerario}}}> { 
<{{{itinerario}}}> mo:hasSpatialThing ?feature . 
OPTIONAL {<{{{itinerario}}}>  mo:hasLearningTask ?tasksIt . } 
OPTIONAL {<{{{itinerario}}}>  mo:hasTrack ?track . } 
} . 
}`,
        {
            pg: primaryGraph,
            itinerario: idIt,
        }
    );
}

function getFeaturesItinerary(itinerary) {
    return Mustache.render(
        `PREFIX mo: <http://moult.gsic.uva.es/ontology/>
SELECT DISTINCT ?feature ?first ?next WHERE { 
GRAPH <{{{itinerario}}}> { 
<{{{itinerario}}}> mo:hasSpatialThing ?feature . 
OPTIONAL { <{{{itinerario}}}> rdf:first ?first . } 
OPTIONAL {?feature rdf:next ?next . } 
} . 
}`,
        {
            itinerario: itinerary
        }).replace(/\s+/g, ' ');
}

function getCommentFeatureIt(idItinerary, idFeature) {
    return `SELECT ?comment WHERE {
GRAPH <${idItinerary}> {
<${idFeature}> rdfs:comment ?comment .
}
}`;
}

function getTasksFeatureIt(it, feature) {
    return Mustache.render(
        `PREFIX mo: <http://moult.gsic.uva.es/ontology/>
SELECT DISTINCT ?task ?at ?author ?space ?label ?comment ?first ?next WHERE { 
GRAPH <{{{it}}}> { 
<{{{feature}}}> mo:hasLearningTask ?task . 
OPTIONAL { <{{{feature}}}> rdf:first ?first . } 
OPTIONAL {?task rdf:next ?next . } 
}
GRAPH {{{pg}}} {
?task 
mo:answerType ?at ; 
dc:creator ?author ;
mo:inSpace ?space ;
rdfs:comment ?comment . 
OPTIONAL { ?task rdfs:label ?label . }
} 
}`,
        {
            pg: primaryGraph,
            feature: feature,
            it: it
        }
    ).replace(/\s+/g, ' ');
}

function getLocationsTrackIt(it) {
    return `PREFIX mo: <http://moult.gsic.uva.es/ontology/>
PREFIX md: <http://moult.gsic.uva.es/data/>
WITH <${it}>
SELECT DISTINCT ?pointTrack ?position ?lat ?long ?timestamp ?alt {
<${it}> mo:hasTrack ?track .
?track 
a mo:Track ;
mo:pointTrack ?pointTrack .
?pointTrack
a mo:PointTrack ;
mo:position ?position ;
mo:hasGeometry ?point .
?point 
a mo:Point ;
geo:lat ?lat ; 
geo:long ?long .
OPTIONAL { ?pointTrack dc:date ?timestamp . }
OPTIONAL { ?point geo:alt ?alt . }
}`.replace(/\s+/g, ' ');
}

function getTasksItinerary(itinerary, feature) {
    return Mustache.render(`PREFIX mo: <http://moult.gsic.uva.es/ontology/>
SELECT DISTINCT ?task ?aT ?label ?comment ?first ?next WHERE { 
GRAPH {{{pg}}} { 
<{{{feature}}}> mo:hasLearningTask ?task . 
?task 
mo:answerType ?aT ; 
rdfs:label ?label ; 
rdfs:comment ?comment .
} 
GRAPH <{{{itinerario}}}> { 
<{{{feature}}}> mo:hasLearningTask ?task . 
OPTIONAL { <{{{feature}}}> rdf:first ?first . } 
OPTIONAL {?task rdf:next ?next . } 
} 
}`,
        {
            pg: primaryGraph,
            feature: feature,
            itineario: itinerary
        }
    );
}

function deleteItinerarySparql(itinerary) {
    const query = Mustache.render(
        `DELETE WHERE { 
GRAPH {{{pg}}} { 
<{{{itinerario}}}> ?p ?o 
} 
.} 
CLEAR GRAPH <{{{itinerario}}}>`,
        {
            pg: primaryGraph,
            itinerario: itinerary
        }
    ).replace(/\s+/g, ' ');
    winston.info(query);
    return query;
}

function allFeedsLOD() {
    const query = Mustache.render(`PREFIX mo: <http://moult.gsic.uva.es/ontology/>
SELECT DISTINCT ?feed ?label ?comment ?feeder ?feederLbl FROM {{{pg}}} WHERE {
?feed a mo:Feed ;
rdfs:label ?label ;
rdfs:comment ?comment ;
dc:creator ?feeder .
?feeder rdfs:label ?feederLbl .
}`, 
        {
            pg: primaryGraph,
        }
    ).replace(/\s+/g, ' ');
    winston.info(query);
    return query;
}

function basicInfoFeeds(values) {
    let valuesStr = '';
    values.forEach(v => {
        valuesStr += `<${v}>`;
    });
    const query = Mustache.render(`PREFIX mo: <http://moult.gsic.uva.es/ontology/>
SELECT DISTINCT ?feed ?label ?comment ?feeder ?feederLbl FROM {{{pg}}} WHERE {
VALUES ?feed {{{{v}}}}
?feed a mo:Feed ;
rdfs:label ?label ;
rdfs:comment ?comment ;
dc:creator ?feeder .
?feeder rdfs:label ?feederLbl .
}`, 
        {
            pg: primaryGraph,
            v: valuesStr
        }
    ).replace(/\s+/g, ' ');
    winston.info(query);
    return query;
}

/**
* https://stackoverflow.com/a/5717133
*/
function _validURL(str) {
    const pattern = new RegExp('^(https?:\\/\\/)?' + // protocol
        '((([a-z\\d]([a-z\\d-]*[a-z\\d])*)\\.)+[a-z]{2,}|' + // domain name
        '((\\d{1,3}\\.){3}\\d{1,3}))' + // OR ip (v4) address
        '(\\:\\d+)?(\\/[-a-z\\d%_.~+]*)*' + // port and path
        '(\\?[;&a-z\\d%_.~+=-]*)?' + // query string
        '(\\#[-a-z\\d_]*)?$', 'i'); // fragment locator

    return !!pattern.test(str);
}

module.exports = {
    getInfoFeatureLocalRepository,
    getLocationFeatures,
    getInfoFeaturesOSM,
    getInfoFeatureOSM,
    getInfoFeaturesSparql,
    getCitiesWikidata,
    checkExistenceId,
    insertFeature,
    isAuthor,
    hasTasksOrInItinerary,
    deleteObject,
    getAllInfo,
    checkInfo,
    addInfoFeature,
    deleteInfoFeature,
    getTasksFeature,
    insertTask,
    getInfoTask,
    taskInIt0,
    taskInIt1,
    checkDataSparql,
    insertItinerary,
    getAllItineraries,
    getInfoItinerary,
    getCommentFeatureIt,
    getFeaturesItinerary,
    getTasksItinerary,
    deleteItinerarySparql,
    getTasksFeatureIt,
    getInfoFeatureWikidata,
    getInfoFeatureEsDBpedia,
    getInfoFeatureDBpedia1,
    getInfoFeatureDBpedia2,
    getArcStyleWikidata,
    queryBICJCyL,
    getInfoFeatureLocalRepository2,
    checkExistenceAlias,
    insertPerson,
    insertCommentPerson,
    borraAlias,
    borraDescription,
    getDescription,
    deleteFeatureRepo,
    getLocationsTrackIt,
    getItineraryTasks,
    basicInfoFeeds,
    allFeedsLOD,
}