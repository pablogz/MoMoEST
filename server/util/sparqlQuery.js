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
                { headers: { 'Accept': 'application/json' } });
            return body.status == 200 ? await body.json() : null;
        } catch (e) {
            // console.error(e);
            return null;
        }
    }
}

module.exports = SPARQLQuery;