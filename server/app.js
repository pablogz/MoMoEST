const express = require('express');
const path = require('path');
const cookieParser = require('cookie-parser');
// const logger = require('morgan');
const cors = require('cors');
const FirebaseAdmin = require('firebase-admin');
require('https').globalAgent.options.ca = require('ssl-root-cas').create();

const winston = require('./util/winston');

// const config = require('./util/config');
const fileFirebaseAdmin = require('./util/chest-firebase.json');
const { getArcStyle4Wikidata } = require('./util/auxiliar');

const index = require('./routes/index');
const features = require('./routes/feature/features');
const featuresLOD = require('./routes/feature/featuresLOD');
const feature = require('./routes/feature/feature');
const learningTasks = require('./routes/feature/learningTasks/learningTasks');
const tasks = require('./routes/learningTasks/learningTasks');
const learningTask = require('./routes/feature/learningTasks/learningTask');
const task = require('./routes/learningTasks/learningTask');
const user = require('./routes/users/user');
const userPreferences = require('./routes/users/userPreferences/userPreferences')
const answers = require('./routes/users/answers/answers');
// const answer = require('./routes/users/answers/answer');
const itineraries = require('./routes/itineraries/itineraries');
const itinerary = require('./routes/itineraries/itinerary');
const itineraryTrack = require('./routes/itineraries/track');
const itineraryTasks = require('./routes/itineraries/itineraryTasks');
const featuresIt = require('./routes/itineraries/features/features');
const featureIt = require('./routes/itineraries/features/feature');
const feeds = require('./routes/feeds/feeds');
const feed = require('./routes/feeds/feed');
// const feedResources = require('./routes/feeds/resources/resources');
// const feedResource = require('./routes/feeds/resources/resource');
const feedSubscribers = require('./routes/feeds/subscribers/subscribers');
const feedSubscriber = require('./routes/feeds/subscribers/subscriber');
const feedSubscriberAnswers = require('./routes/feeds/subscribers/answers/answers');
const feedSubscriberAnswer = require('./routes/feeds/subscribers/answers/answer');

const app = express();

// app.use(logger('dev'));
app.use(express.json({ limit: '15mb' }));
app.use(express.urlencoded({ extended: false }));
app.use(cookieParser());
app.use(express.static(path.join(__dirname, 'public')));
app.disable('etag');

const rutas = {
    raiz: '/',
    features: '/features/',
    featuresLOD: '/features/lod/',
    feature: '/features/:feature',
    learningTasks: '/features/:feature/learningTasks',
    learningTask: '/features/:feature/learningTasks/:learningTask',
    tasks: '/tasks',
    // task: '/features/:feature/learningTasks/:task',
    task: '/tasks/:task',
    users: '/users/',
    user: '/users/user',
    userPreferences: '/users/user/preferences',
    answers: '/users/user/answers/',
    answer: '/users/user/answers/:answer',
    userItineraries: '/users/user/itineraries/',
    userStatusItinerary: '/users/user/itineraries/:itinerary/status',
    reports: '/users/user/reports/',
    report: '/users/user/reports/:report',
    notifications: '/users/user/notifications/',
    notification: '/users/user/notifications/:notification',
    itineraries: '/itineraries/',
    itinerary: '/itineraries/:itinerary',
    itineraryTrack: '/itineraries/:itinerary/track',
    itineraryTasks: '/itineraries/:itinerary/learningTasks',
    itineraryFeatures: '/itineraries/:itinerary/features',
    itineraryFeature: '/itineraries/:itinerary/features/:feature/learningTasks',
    feeds: '/feeds/',
    feed: '/feeds/:feed',
    feedSubscribers: '/feeds/:feed/subscribers/',
    feedSubscriber: '/feeds/:feed/subscribers/:subscriber',
    feedSubscriberAnswers: '/feeds/:feed/subscribers/:subscriber/answers',
    feedSubscriberAnswer: '/feeds/:feed/subscribers/:subscriber/answers/:answer',
    feedResources: '/feeds/:feed/learningResources/',
    feedResource: '/feeds/:feed/learningResources/:resource'
};

FirebaseAdmin.initializeApp({
    credential: FirebaseAdmin.credential.cert(fileFirebaseAdmin)
})

const error405 = (req, res) => {
    winston.http(`405 || Method Not Allowed - ${req.originalUrl} - ${req.method} - ${req.ip}`);
    res.sendStatus(405);
}

winston.info('START');
getArcStyle4Wikidata();

app
    //Index
    .get(rutas.raiz, cors({
        origin: '*'
    }), (req, res) => index.getIndex(req, res))
    .options(rutas.raiz, cors({
        origin: '*',
        methods: ['GET', 'OPTIONS']
    }), (req, res) => {
        res.sendStatus(204);
    })
    //Features
    .all(rutas.raiz, cors({
        origin: '*'
    }), error405)
    .get(rutas.features, cors({
        origin: '*'
    }), (req, res) => features.getFeatures(req, res))
    .post(rutas.features, cors({
        // origin: config.urlClient
        origin: '*',
        exposedHeaders: ['Location']
    }), (req, res) => req.headers.authorization ?
        req.is('application/json') ?
            features.newFeature(req, res) :
            res.sendStatus(415) :
        res.sendStatus(401))
    .options(rutas.features, cors({
        origin: '*',
        methods: ['GET', 'POST', 'OPTIONS']
    }), (req, res) => {
        res.sendStatus(204);
    })
    .all(rutas.features, cors({
        origin: '*'
    }), error405)
    //FeatureLOD
    .get(rutas.featuresLOD, cors({
        origin: '*'
    }), (req, res) => featuresLOD.getFeaturesLOD(req, res))
    .options(rutas.featuresLOD, cors({
        origin: '*',
        methods: ['GET', 'OPTIONS']
    }), (req, res) => {
        res.sendStatus(204);
    })
    .all(rutas.featuresLOD, cors({
        origin: '*'
    }), error405)
    //Feature
    .get(rutas.feature, cors({
        origin: '*'
    }), (req, res) => feature.getFeature(req, res))
    .put(rutas.feature, cors({
        // origin: config.urlClient
        origin: '*'
    }), (req, res) => req.headers.authorization ?
        req.is('application/json') ?
            feature.editFeature(req, res) :
            res.sendStatus(415) :
        res.sendStatus(401))
    .delete(rutas.feature, cors({
        // origin: config.urlClient
        origin: '*'
    }), (req, res) => req.headers.authorization ?
        feature.deleteFeature(req, res) : res.sendStatus(401))
    .options(rutas.feature, cors({
        origin: '*',
        methods: ['GET', 'PUT', 'DELETE', 'OPTIONS']
    }), (req, res) => {
        res.sendStatus(204);
    })
    //Tasks
    .get(rutas.learningTasks, cors({
        origin: '*'
    }), (req, res) => learningTasks.getTasksFeature(req, res))
    .get(rutas.tasks, cors({
        origin: '*'
    }), (req, res) => tasks.getTasks(req, res))
    .post(rutas.learningTasks, cors({
        origin: '*',
        exposedHeaders: ['Location']
    }), (req, res) => req.headers.authorization ?
        req.is('application/json') ?
            learningTasks.postTaskFeture(req, res) :
            res.sendStatus(415) :
        res.sendStatus(401))
    .post(rutas.tasks, cors({
        // origin: config.urlClient
        origin: '*',
        exposedHeaders: ['Location']
    }), (req, res) => req.headers.authorization ?
        req.is('application/json') ?
            tasks.newTask(req, res) :
            res.sendStatus(415) :
        res.sendStatus(401))
    .options(rutas.learningTasks, cors({
        origin: '*',
        methods: ['GET', 'POST', 'OPTIONS']
    }), (req, res) => {
        res.sendStatus(204);
    })
    .options(rutas.tasks, cors({
        origin: '*',
        methods: ['GET', 'POST', 'OPTIONS']
    }), (req, res) => {
        res.sendStatus(204);
    })
    .all(rutas.learningTasks, cors({
        origin: '*'
    }), error405)
    .all(rutas.tasks, cors({
        origin: '*'
    }), error405)
    //Task
    .get(rutas.learningTask, cors({
        origin: '*'
    }), (req, res) => learningTask.getLearningTask(req, res))
    .get(rutas.task, cors({
        origin: '*'
    }), (req, res) => task.getTask(req, res))
    .put(rutas.task, cors({
        // origin: config.urlClient
        origin: '*'
    }), (req, res) => req.headers.authorization ?
        req.is('application/json') ?
            task.editTask(req, res) :
            res.sendStatus(415) :
        res.sendStatus(401))
    .delete(rutas.learningTask, cors({
        origin: '*'
    }), (req, res) => req.headers.authorization ?
        learningTask.removeLearningTask(req, res) : res.sendStatus(401))
    .delete(rutas.task, cors({
        origin: '*'
    }), (req, res) => req.headers.authorization ?
        task.deleteTask(req, res) : res.sendStatus(401))
    .options(rutas.learningTask, cors({
        origin: '*',
        methods: ['GET', 'PUT', 'DELETE', 'OPTIONS']
    }), (req, res) => {
        res.sendStatus(204);
    })
    .options(rutas.task, cors({
        origin: '*',
        methods: ['GET', 'PUT', 'DELETE', 'OPTIONS']
    }), (req, res) => {
        res.sendStatus(204);
    })
    .all(rutas.learningTask, cors({
        origin: '*'
    }), error405)
    .all(rutas.task, cors({
        origin: '*'
    }), error405)
    //Users
    .all(rutas.task, cors({
        origin: '*'
    }), error405)
    //User
    .get(rutas.user, cors({
        // origin: config.urlClient
        origin: '*'
    }), (req, res) => req.headers.authorization ?
        user.getUser(req, res) :
        res.sendStatus(401))
    .put(rutas.user, cors({
        //origin: config.urlClient
        origin: '*'
    }), (req, res) => req.headers.authorization ?
        req.is('application/json') ?
            user.editUser(req, res) :
            res.sendStatus(415) :
        res.sendStatus(401))
    .delete(rutas.user, cors({
        //origin: config.urlClient
        origin: '*'
    }), (req, res) => req.headers.authorization ?
        req.is('application/json') ?
            user.deleteUser(req, res) :
            res.sendStatus(415) :
        res.sendStatus(401))
    .options(rutas.user, cors({
        origin: '*',
        methods: ['GET', 'PUT', 'DELETE', 'OPTIONS']
    }), (req, res) => {
        res.sendStatus(204);
    })
    .all(rutas.user, cors({
        origin: '*'
    }), error405)
    // User Preferences
    .get(rutas.userPreferences, cors({
        // origin: config.urlClient
        origin: '*'
    }), (req, res) => req.headers.authorization ?
        userPreferences.getPreferences(req, res) :
        res.sendStatus(401))
    .put(rutas.userPreferences, cors({
        //origin: config.urlClient
        origin: '*'
    }), (req, res) => req.headers.authorization ?
        req.is('application/json') ?
            userPreferences.putPreferences(req, res) :
            res.sendStatus(415) :
        res.sendStatus(401))
    .options(rutas.userPreferences, cors({
        origin: '*',
        methods: ['GET', 'PUT', 'OPTIONS']
    }), (req, res) => {
        res.sendStatus(204);
    })
    .all(rutas.user, cors({
        origin: '*'
    }), error405)
    // ANSWERS
    .get(rutas.answers, cors({
        origin: '*'
    }), (req, res) => req.headers.authorization ? answers.getAnswers(req, res) : res.sendStatus(401))
    .post(rutas.answers, cors({
        origin: '*',
        exposedHeaders: ['Location']
    }), (req, res) => req.headers.authorization ? answers.newAnswer(req, res) : res.sendStatus(401))
    .all(rutas.answers, cors({
        origin: '*'
    }), error405)
    // ANSWER
    // .get(rutas.answer, cors({
    //     origin: '*'
    // }), (req, res) => req.headers.authorization ?
    //     answer.getAnswer(req, res) :
    //     res.sendStatus(401))
    // .put(rutas.answer, cors({
    //     origin: '*'
    // }), (req, res) => req.headers.authorization ?
    //     req.is('application/json') ?
    //         answer.putAnswer(req, res) :
    //         res.sendStatus(415) :
    //     res.sendStatus(401))
    // .delete(rutas.answer, cors({
    //     origin: '*'
    // }), (req, res) => req.headers.authorization ?
    //     answer.deleteAnswer(req, res) : res.sendStatus(401))
    // .options(rutas.answer, cors({
    //     origin: '*',
    //     methods: ['GET', 'PUT', 'DELETE', 'OPTIONS']
    // }), (req, res) => {
    //     res.sendStatus(204);
    // })
    .all(rutas.answer, cors({
        origin: '*'
    }), error405)
    //ITINERARIES
    .get(rutas.itineraries, cors({
        origin: '*'
    }), (req, res) => itineraries.getItineariesServer(req, res))
    .post(rutas.itineraries, cors({
        origin: '*',
        exposedHeaders: ['Location']
    }), (req, res) => itineraries.newItineary(req, res))
    .options(rutas.itineraries, cors({
        origin: '*',
        methods: ['GET', 'POST', 'OPTIONS']
    }), (req, res) => {
        res.sendStatus(204);
    })
    .all(rutas.itineraries, cors({
        origin: '*'
    }), error405)
    //ITINERARY
    .get(rutas.itinerary, cors({
        origin: '*'
    }), (req, res) => itinerary.getItineraryServer(req, res))
    .put(rutas.itinerary, cors({
        origin: '*'
    }), (req, res) => req.headers.authorization ?
        req.is('application/json') ?
            itinerary.updateItineraryServer(req, res) :
            res.sendStatus(415) :
        res.sendStatus(401))
    .delete(rutas.itinerary, cors({
        origin: '*'
    }), (req, res) => req.headers.authorization ?
        itinerary.deleteItineraryServer(req, res) : res.sendStatus(401))
    .options(rutas.itinerary, cors({
        origin: '*',
        methods: ['GET', 'PUT', 'DELETE', 'OPTIONS']
    }), (req, res) => {
        res.sendStatus(204);
    })
    .all(rutas.itinerary, cors({
        origin: '*'
    }), error405)
    // TRACK ITINERARY
    .get(rutas.itineraryTrack, cors({
        origin: '*'
    }), (req, res) => itineraryTrack.getTrackIt(req, res))
    .options(rutas.itineraryTrack, cors({
        origin: '*',
        methods: ['GET', 'OPTIONS']
    }), (req, res) => {
        res.sendStatus(204);
    })
    .all(rutas.itineraryTrack, cors({
        origin: '*'
    }), error405)
    // TASKS ITINERARY
    .get(rutas.itineraryTasks, cors({
        origin: '*'
    }), (req, res) => itineraryTasks.getTasksIt(req, res))
    .options(rutas.itineraryTasks, cors({
        origin: '*',
        methods: ['GET', 'OPTIONS']
    }), (req, res) => {
        res.sendStatus(204);
    })
    .all(rutas.itineraryTasks, cors({
        origin: '*'
    }), error405)
    // FEATURE ITINERARY
    .get(rutas.itineraryFeatures, cors({
        origin: '*'
    }), (req, res) => featuresIt.getAllFeaturesIt(req, res))
    .options(rutas.itineraryFeatures, cors({
        origin: '*',
        methods: ['GET', 'OPTIONS']
    }), (req, res) => {
        res.sendStatus(204);
    })
    .all(rutas.itineraryFeatures, cors({
        origin: '*'
    }), error405)
    //POINT ITINERARY
    .get(rutas.itineraryFeature, cors({
        origin: '*'
    }), (req, res) => featureIt.getTasksPointItineraryServer(req, res))
    .options(rutas.itineraryFeature, cors({
        origin: '*',
        methods: ['GET', 'OPTIONS']
    }), (req, res) => {
        res.sendStatus(204);
    })
    .all(rutas.itineraryFeature, cors({
        origin: '*'
    }), error405)
    // FEEDS
    .get(rutas.feeds, cors({
        origin: '*'
    }), (req, res) => req.headers.authorization ?
        feeds.listFeeds(req, res) :
        res.sendStatus(401))
    .post(rutas.feeds, cors({
        origin: '*',
        exposedHeaders: ['Location']
    }), (req, res) => req.headers.authorization ?
        req.is('application/json') ?
            feeds.newFeed(req, res) :
            res.sendStatus(415)
        : res.sendStatus(401))
    .options(rutas.feeds, cors({
        origin: '*',
        methods: ['GET', 'POST', 'OPTIONS']
    }))
    .all(rutas.feeds, cors({
        origin: '*'
    }), error405)
    .get(rutas.feed, cors({
        origin: '*'
    }), (req, res) => feed.objFeed(req, res))
    .put(rutas.feed, cors({
        origin: '*'
    }), (req, res) => req.headers.authorization ?
        req.is('application/json') ?
            feed.updateFeed(req, res) :
            res.sendStatus(415)
        : res.sendStatus(401))
    .delete(rutas.feed, cors({
        origin: '*'
    }), (req, res) => req.headers.authorization ?
        feed.byeFeed(req, res) :
        res.sendStatus(401))
    .options(rutas.feed, cors({
        origin: '*',
        methods: ['GET', 'PUT', 'DELETE', 'OPTIONS']
    }))
    .all(rutas.feed, cors({
        origin: '*'
    }), error405)
    .get(rutas.feedResources, cors({
        origin: '*'
    }), (req, res) => feedResources.listFeedResources(req, res))
    .post(rutas.feedResources, cors({
        origin: '*',
        exposedHeaders: ['Location']
    }), (req, res) => req.headers.authorization ?
        req.is('application/json') ?
            feedResources.newResource(req, res) :
            res.sendStatus(415)
        : res.sendStatus(401))
    .options(rutas.feedResources, cors({
        origin: '*',
        methods: ['GET', 'POST', 'OPTIONS']
    }))
    .all(rutas.feedResources, cors({
        origin: '*'
    }), error405)
    .get(rutas.feedResource, cors({
        origin: '*'
    }), (req, res) => feedResource.objResource(req, res))
    .put(rutas.feedResource, cors({
        origin: '*'
    }), (req, res) => req.headers.authorization ?
        req.is('application/json') ?
            feedResource.updateResouce(req, res) :
            res.sendStatus(415)
        : res.sendStatus(401))
    .delete(rutas.feedResource, cors({
        origin: '*'
    }), (req, res) => req.headers.authorization ?
        feedResource.byeResource(req, res) :
        res.sendStatus(401))
    .options(rutas.feedResource, cors({
        origin: '*',
        methods: ['GET', 'PUT', 'DELETE', 'OPTIONS']
    }))
    .all(rutas.feedResource, cors({
        origin: '*'
    }), error405)
    .get(rutas.feedSubscribers, cors({
        origin: '*'
    }), (req, res) => req.headers.authorization ?
        feedSubscribers.listSubscribers(req, res) :
        res.sendStatus(401))
    .options(rutas.feedSubscribers, cors({
        origin: '*',
        methods: ['GET', 'OPTIONS']
    }))
    .all(rutas.feedSubscribers, cors({
        origin: '*'
    }), error405)
    .get(rutas.feedSubscriber, cors({
        origin: '*'
    }), (req, res) => req.headers.authorization ?
        feedSubscriber.subscriber(req, res) :
        res.sendStatus(401))
    .put(rutas.feedSubscriber, cors({
        origin: '*'
    }), (req, res) => req.headers.authorization ?
        req.is('application/json') ?
            feedSubscriber.newSubscriber(req, res) :
            res.sendStatus(415)
        : res.sendStatus(401))
    .delete(rutas.feedSubscriber, cors({
        origin: '*'
    }), (req, res) => req.headers.authorization ?
        feedSubscriber.byeSubscriber(req, res) :
        res.sendStatus(401))
    .options(rutas.feedSubscriber, cors({
        origin: '*',
        methods: ['GET', 'PUT', 'DELETE', 'OPTIONS']
    }))
    .all(rutas.feedSubscriber, cors({
        origin: '*'
    }), error405)
    .get(rutas.feedSubscriberAnswers, cors({
        origin: '*'
    }), (req, res) => req.headers.authorization ?
        feedSubscriberAnswers.listAnswers(req, res) :
        res.sendStatus(401))
    .options(rutas.feedSubscriberAnswers, cors({
        origin: '*',
        methods: ['GET', 'OPTIONS']
    }))
    .all(rutas.feedSubscriberAnswers, cors({
        origin: '*'
    }), error405)
    .get(rutas.feedSubscriberAnswer, cors({
        origin: '*'
    }), (req, res) => req.headers.authorization ?
        feedSubscriberAnswer.objAnswer(req, res) :
        res.sendStatus(401)
    )
    .put(rutas.feedSubscriberAnswer, cors({
        origin: '*'
    }), (req, res) => req.headers.authorization ?
        req.is('application/json') ?
            feedSubscriberAnswer.updateAnswer(req, res) :
            res.sendStatus(415)
        : res.sendStatus(401))
    .delete(rutas.feedSubscriberAnswer, cors({
        origin: '*'
    }), (req, res) => req.headers.authorization ?
        feedSubscriberAnswer.byeAnswer(req, res)
        : res.sendStatus(401))
    .options(rutas.feedSubscriberAnswer, cors({
        origin: '*',
        methods: ['GET', 'PUT', 'DELETE', 'OPTIONS']
    }))
    .all(rutas.feedSubscriberAnswer, cors({
        origin: '*'
    }), error405);
winston.info("Server started");

module.exports = app;
