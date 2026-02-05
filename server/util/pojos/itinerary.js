const {Task} = require('./tasks'); 

/**
 * Clase que modela a un itineario. Opcionalmente el itinerario puede tener un track y unas tareas de itineraio.
 *
 * @class Itinerary
 */
class Itinerary {
    /**
     * Creates an instance of Itinerary.
     * 
     * @param {String?} id Identificador del itinerario. Si no se proporciona un String se inicia a null.
     * @param {String?} type Tipo de itinerario (ordenado, sin orden, orden parcial, etc.). Si no se proporciona un String se inicia a null.
     * @param {List?} labels Lista con el título del itinerario.
     * @param {List?} comments Lista con la descripción del itinerario.
     * @param {String?} author Autor del itinerario. Si no es un String se inicia a null
     * @param {List?} points Lista de puntos del itinerario. Los puntos deben ser de la clase PointItinerary
     * @memberof Itinerary
     */
    constructor(id, type, labels, comments, author, points) {
        this._id = typeof id === 'string' ? id : null;
        if (typeof type === 'string') {
            switch (type) {
                case 'List':
                    this._type = 'http://moult.gsic.uva.es/ontology/ListItinerary';
                    break;
                case 'BagSTsListTasks':
                    this._type = 'http://moult.gsic.uva.es/ontology/BagSTsListTasks';
                    break;
                case 'ListSTsBagTasks':
                    this._type = 'http://moult.gsic.uva.es/ontology/ListSTsBagTasks';
                    break;
                case 'Bag':
                    this._type = 'http://moult.gsic.uva.es/ontology/ItineraryBag';
                    break;
                default:
                    this._type = null;
            }
        } else {
            this._type = null;
        }
        // this._type = typeof type === 'string' ? type : null;
        this._labels = labels !== null && Array.isArray(labels) ?
            labels :
            [];
        this._comments = comments !== null && Array.isArray(comments) ?
            comments :
            [];
        this._author = typeof author === 'string' ? author : null;
        this._points = points !== null && Array.isArray(points) ?
            points :
            [];
        this._track = null;
        this._tasks = [];
    }


    /**
     * Constructor de un itinerario vacío
     *
     * @static
     * @return {Itinerary} Devuelve un itinerario vacío. 
     * @memberof Itinerary
     */
    static ItineraryEmpty() {
        return new Itinerary(null, null, null, null, null);
    }

    get id() { return this._id; }
    get type() { return this._type; }
    get labels() { return this._labels; }
    get comments() { return this._comments; }
    get author() { return this._author; }
    get points() { return this._points; }
    /**
     * Devuelve el track del itinerario (objeto de la clase Track). puede ser null si no se ha inicializado.
     *
     * @readonly
     * @memberof Itinerary
     */
    get track() { return this._track; }
    /**
     * Devuelve una lista con las tareas de itineraio. Puede devolver null si el itinerario no tiene tareas de itineario. 
     *
     * @readonly
     * @memberof Itinerary
     */
    get tasks() { return this._tasks.length > 0 ? this._tasks : null; }

    setId(id) { this._id = id; }
    setType(type) {
        if (typeof type === 'string') {
            switch (type) {
                case 'ListItinerary':
                    this._type = 'http://moult.gsic.uva.es/ontology/ListItinerary';
                    break;
                case 'BagSTsListTasksItinerary':
                    this._type = 'http://moult.gsic.uva.es/ontology/BagSTsListTasksItinerary';
                    break;
                case 'ListSTsBagTasksItinerary':
                    this._type = 'http://moult.gsic.uva.es/ontology/ListSTsBagTasksItinerary';
                    break;
                case 'BagItinerary':
                    this._type = 'http://moult.gsic.uva.es/ontology/BagItinerary';
                    break;
                default:
                    this._type = null;
            }
        } else {
            this._type = null;
        }
    }
    setAuthor(author) { this._author = author; }
    setPoints(points) {
        this._points = points !== null && Array.isArray(points) ?
            points :
            [];
    }
    addPoint(point) { if (point !== null) this._points.push(point); }
    setLabels(labels) {
        var error = false;
        if(labels !== null && Array.isArray(labels)) {
            for(var label of labels) {
                if (label.value.trim() === '') {
                    error = true;
                    break;
                }
            }
            this._labels = error ? [] : labels;
        }
    }
    addLabel(label) {
        if (label !== null &&
            label.value &&
            label.lang)
            this._points.push(label);
    }
    setComments(comments) {
        var error = false;
        if(comments !== null && Array.isArray(comments)) {
            for(var comment of comments) {
                if (comment.value.trim() === '') {
                    error = true;
                    break;
                }
            }
            this._comments = error ? [] : comments;
        }
    }
    addComment(comment) {
        if (comment !== null &&
            comment.value &&
            comment.lang)
            this._points.push(comment);
    }
    /**
     * Establece el track del itinerario
     *
     * @param {dynamic} dataTrack Puede ser una lista de puntos o directamente un objeto Track. Si es un conjunto de puntos después se le debe dar un identificador.
     * @memberof Itinerary
     */
    setTrack(dataTrack) {
        this._track = Array.isArray(dataTrack) ? new Track({points: dataTrack}) : new Track(dataTrack);
    }
    
    /**
     * Establece la lista de tareas de itineario
     *
     * @param {List<Task>} lstTasks Lista de tareas.
     * @memberof Itinerary
     */
    setTasks(lstTasks) {
        this._tasks = [];
        if(!Array.isArray(lstTasks)) {
            lstTasks = [lstTasks]; 
        }
        lstTasks.forEach(t => {
            this._tasks.push(t instanceof Task ? t : Task(t));
        });
    }

    /**
     * Agrega una tarea de itinerario
     *
     * @param {Task} task Tiene que ser de tipo Task
     * @memberof Itinerary
     */
    addTask(task) {
            this._tasks.push(task);
        }
    }

class Track {
    constructor(data) {
        this._id = data.id !== undefined ? data.id : '';
        this._pointsTrack = [];
        if(data.points !== undefined) {
            let index = 0;
            data.points.forEach(pointTrak => {
                this._pointsTrack.push(new PointTrack(pointTrak, this._id, index))
                index += 1;
            });
        }
    }

    get id() { return this._id === '' ? null : this._id; }
    set id(id) { this._id = id; }
    get pointsTrack() { return this._pointsTrack.length > 0 ? this._pointsTrack : null; }
    set pointsTrack(pointsTrack) { this._pointsTrack = pointsTrack; }
}

class PointTrack {
    constructor(data, idTrack, order) {
        this._id = `${idTrack}_${order}`;
        this._order = order;
        if(data.lat !== undefined && typeof data.lat === 'number' && data.lat >= 0 && data.lat <= 90 &&
        data.long !== undefined && typeof data.long === 'number' && data.long >= -180 && data.long <= 180) {
            this._lat = data.lat;
            this._long = data.long;
            if(data.alt !== undefined && typeof data.alt === 'number') {
                this._alt = data.alt;
            }
            if(data.timestamp !== undefined && typeof data.timestamp === 'string') {
                this._timestamp = data.timestamp;
            }
        } else {
            new Error('Problem with data (lat or long)')
        }
    }

    get id() {return this._id; }
    get order() { return this._order; }
    get lat() { return this._lat; }
    get long() { return this._long; }
    get alt() { return this._alt !== undefined ? this._alt : null; }
    get timestamp() { return this._timestamp !== undefined ? this._timestamp : null; }
}

class PointItinerary {
    constructor(id, altComment, tasks) {
        this._id = typeof id === 'string' ? id : null;
        this._altComment = typeof altComment === 'string' ? altComment : null;
        this._tasks = tasks !== null && Array.isArray(tasks) ?
            tasks :
            [];
    }

    static WitoutComment(id, tasks) {
        return new PointItinerary(id, null, tasks);
    }

    get idFeature() { return this._id; }
    get altCommentFeature() { return this._altComment; }
    get tasks() { return this._tasks; }
}

module.exports = {
    Itinerary,
    Track,
    PointItinerary,
    PointTrack,
}