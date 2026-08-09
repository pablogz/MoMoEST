const urlClient = 'https://momoest.gsic.uva.es';
const urlServer = 'https://momoest.gsic.uva.es/server';
const addrSparql = '127.0.0.1';
const serverPort = 11112;
const portSparql = 8890;
const localSPARQL = `http://${addrSparql}:${portSparql}/sparql`;
const userSparql = 'pablo';
const passSparql = 'pablo';
const tokenCraft = '6d8097f8-9fff-40a2-9043-bd57fe89bcb3';
const primaryGraph = '<http://momoest.gsic.uva.es>';
const docomomoGraph = '<http://momoest.gsic.uva.es/docomomo>';

const tamaMaxFile = 25;
const mbNotes = 50;

// const addrOPA = 'https://overpass-api.de/api/interpreter';
// const portOPA = 443;

const addrOPA = 'https://dev-chest.gsic.uva.es/overpass/interpreter';
const portOPA = 443;

// const addrOPA = 'http://10.0.104.91/api/interpreter';
// const portOPA = 80;

const mongoName = 'bdMOMOEST';
const mongoAdd = 'mongodb://localhost:27017';

// TODO depende del dominio
const typeST = [
    'cinema',
    'education',
    'factory',
    'goverment',
    'hotel',
    'place_of_worship',
    'residential',
    'square'
];

const classTypeST = {
    'cinema': 'Cinema',
    'education': 'Education',
    'factory': 'Factory',
    'goverment': 'Goverment',
    'hotel': 'Hotel',
    'fountain': 'Fountain',
    'place_of_worship': 'PlaceOfWorship',
    'residential': 'Residential',
    'square': 'Square'
}; 

module.exports = {
    urlClient,
    urlServer,
    addrSparql,
    portSparql,
    localSPARQL,
    userSparql,
    passSparql,
    tokenCraft,
    addrOPA,
    portOPA,
    serverPort,
    mongoName,
    mongoAdd,
    primaryGraph,
    docomomoGraph,
    typeST,
    classTypeST,
    tamaMaxFile,
    mbNotes,
}