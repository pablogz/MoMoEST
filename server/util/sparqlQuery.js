const Mustache = require('mustache');
const fetch = require("node-fetch");

class SPARQLQuery {
    /**
     * 
     * @param {String} endpoint SPARQL endpoint. Ex. https://dbpedia.org/sparql or https://query.wikidata.org/sparql
     */
    constructor(endpoint) {
        this.endpoint = endpoint;
    }

    /**
     * 
     * @param {String} q Query to the endpoint 
     * @returns Data in JSON format
     */
    async query(q) {
        try {
            const body = await fetch(Mustache.render(
                '{{{ep}}}?query={{{query}}}',
                { ep: this.endpoint, query: encodeURIComponent(q.replace(/\s+/g, ' ')) }),
                { headers: { 
                    'Accept': 'application/json', 
                    'User-Agent': 'MoMoEST/1.0 (https://gsic.uva.es/; momoest@gsic.uva.es)'
                } });
            if (body.status !== 200) {
                console.error(`SPARQLQuery error: HTTP ${body.status} from ${this.endpoint}`);
                return null;
            }
            return await body.json();
        } catch (e) {
            // console.error(e);
            console.error(`SPARQLQuery exception from ${this.endpoint}:`, e);
            return null;
        }
    }
}

module.exports = SPARQLQuery;