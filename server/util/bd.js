const { MongoClient } = require('mongodb');

const winston = require('./winston');
const { mongoAdd, mongoName } = require('./config');
const { FeedsUser } = require('./pojos/user');
const { Feed } = require('./pojos/feed');

const _client = new MongoClient(
    mongoAdd,
    {
        useNewUrlParser: true,
        useUnifiedTopology: true
    });

const DOCUMENT_INFO = 'infoUser';
const DOCUMENT_ANSWERS = 'answers';
const DOCUMENT_FEEDS = 'feeds';

let db;

async function connectToDatabase() {
    if (!db) {
        await _client.connect();
        db = _client.db(mongoName);
    }
    return db;
}

async function disconnectDatabase() {
    if (_client) {
        await _client.close();
    }
}

async function getInfoUser(uid) {
    return await getDocument(uid, DOCUMENT_INFO);
}

async function getFeedsUser(uid) {
    return await getDocument(uid, DOCUMENT_FEEDS)
}

async function getFeed(idOwner, idFeed) {
    const feedsDocument = await getFeedsUser(idOwner);
    if (feedsDocument !== null) {
        const feedsUser = new FeedsUser(feedsDocument);
        const indexFeed = feedsUser.owner.findIndex((f) => {
            const feed = new Feed(f);
            return feed.id == idFeed;
        });
        return indexFeed > -1 ? typeof feedsUser.owner.at(indexFeed) === Feed ?
            feedsUser.owner.at(indexFeed) :
            new Feed(feedsUser.owner.at(indexFeed)) : null;
    } else {
        return null;
    }
}

async function getDocument(colId, id) {
    try {
        const db = await connectToDatabase();
        return await db.collection(colId).findOne({ _id: id });
    }
    catch (error) {
        return null;
    }
}

async function updateDocument(col, doc, obj) {
    const update = {
        $set: obj
    };
    try {
        const db = await connectToDatabase();
        return await db.collection(col).updateOne({ _id: doc }, update);
    }
    catch (error) {
        winston.error(error);
        return null;
    }
}

async function newDocument(col, doc) {
    try {
        const db = await connectToDatabase();
        return await db.collection(col).insertOne(doc);
    }
    catch (error) {
        winston.error(error);
        return null;
    }
}

async function getAnswerWithoutId(userCol, poi, task) {
    try {
        const db = await connectToDatabase();
        const doc = await db.collection(userCol).findOne(
            {
                $and: [
                    { _id: DOCUMENT_ANSWERS },
                    { "answers.idTask": task },
                    { "answers.idPoi": poi }
                ]
            });
        if (doc != null) {
            let ans;
            doc.answers.forEach(answer => {
                if (answer.idTask == task && answer.idPoi == poi) {
                    ans = answer;
                }
            });
            return ans;
        }
    } catch (error) {
        winston.error(error);
        return null;
    }
}

async function checkExistenceAnswer(userCol, poi, task) {
    try {
        const db = await connectToDatabase();
        const doc = await db.collection(userCol).findOne(
            {
                $and: [
                    { _id: DOCUMENT_ANSWERS },
                    { "answers.idTask": task },
                    { "answers.idPoi": poi }
                ]
            });
        return doc != null;
    } catch (error) {
        winston.error(error);
        return null;
    }
}

async function saveAnswer(userCol, feature, task, idAnswer, answerC) {
    try {
        const db = await connectToDatabase();
        var now = Date.now();
        return await db.collection(userCol).updateOne(
            { _id: DOCUMENT_ANSWERS },
            {
                $push: {
                    answers: {
                        id: idAnswer,
                        idFeature: feature,
                        labelContainer: answerC.labelContainer,
                        idTask: task,
                        commentTask: answerC.commentTask,
                        answerType: answerC.answerType,
                        creation: now,
                        time2Complete: answerC.time2Complete,
                        finishClient: answerC.finishClient,
                        answer: answerC.answer,
                    }
                }
            },
            { upsert: true }
        );
    } catch (error) {
        winston.error(error);
        return null;
    }
}

async function saveNewFeed(userCol, feed) {
    try {
        const db = await connectToDatabase();
        return await db.collection(userCol).updateOne(
            { _id: DOCUMENT_FEEDS },
            {
                $push: {
                    owner: {
                        _id: feed.id,
                        id: feed.id,
                        owner: feed.owner,
                        labels: feed.labels,
                        comments: feed.comments,
                        subscribers: feed.subscribers,
                        password: feed.password,
                        date: feed.date,
                    }
                }
            },
            { upsert: true }
        );
    } catch (error) {
        winston.error(error);
        return null;
    }
}

async function getAnswersDB(userCol, allAnswers = true) {
    try {
        const db = await connectToDatabase();
        const docAnswers = await db.collection(userCol).findOne({ _id: DOCUMENT_ANSWERS });
        if (docAnswers !== null) {
            if (docAnswers.answers !== undefined && Array.isArray(docAnswers.answers) && docAnswers.answers.length > 0) {
                if (allAnswers) {
                    return docAnswers.answers.sort((a, b) => b.lastUpdate - a.lastUpdate);
                } else {
                    return docAnswers.answers.sort((a, b) => b.lastUpdate - a.lastUpdate).splice(0, Math.min(docAnswers.answers.length, 20));
                }
            } else {
                return [];
            }
        } else {
            return docAnswers;
        }
    } catch (error) {
        winston.error(error);
        return null;
    }
}

async function deleteCollection(userCol) {
    try {
        const db = await connectToDatabase();
        return await db.dropCollection(userCol);
    } catch (error) {
        winston.error(error);
        return false;
    }
}

async function deleteFeedSubscriber(userCol, feedId) {
    try {
        const db = await connectToDatabase();
        const results = await db.collection(userCol).updateOne(
            { _id: DOCUMENT_FEEDS },
            {
                $pull: {
                    subscribed: { idFeed: feedId }
                }
            });
        return results.modifiedCount == 1;
    } catch (error) {
        winston.error(error);
        return false;
    }
}

async function deleteFeedOwner(userCol, feedId) {
    try {
        const db = await connectToDatabase();
        const results = await db.collection(userCol).updateOne(
            { _id: DOCUMENT_FEEDS },
            {
                $pull: {
                    owner: { id: feedId }
                }
            });
        return results.modifiedCount == 1;
    } catch (error) {
        winston.error(error);
        return false;
    }
}

async function updateFeedDB(userCol, feedData) {
    try {
        const db = await connectToDatabase();
        const results = await db.collection(userCol).updateOne(
            { _id: DOCUMENT_FEEDS, "owner._id": feedData.id },
            {
                $set: {
                    "owner.$": feedData
                }
            }
        );
        return results.modifiedCount == 1;
    } catch (error) {
        winston.error(error);
        return false;
    }
}

async function getInfoSubscriber(userCol, feedId, nAnswers = true) {
    try {
        const db = await connectToDatabase();
        const resultadoSubscribed = await db.collection(userCol).findOne(
            { _id: DOCUMENT_FEEDS, subscribed: { $elemMatch: { idFeed: feedId } } },
            { projection: { subscribed: { $elemMatch: { idFeed: feedId } } } },
        );
        if (resultadoSubscribed?.subscribed?.length === 1) {
            const out = {};
            const subscribed = resultadoSubscribed.subscribed.at(0);
            const infoUser = await getInfoUser(userCol);
            out.id = userCol;
            if (infoUser.alias !== undefined) {
                out.alias = infoUser.alias;
            }
            out.date = subscribed.date;
            if (subscribed.answers !== undefined && Array.isArray(subscribed.answers)) {
                if (nAnswers) {
                    out.nAnswers = subscribed.answers.length;
                } else {
                    out.answers = subscribed.answers;
                }
            }
            return out;
        } else {
            return null;
        }
    } catch (error) {
        winston.error(error);
        return null;
    }
}

async function findCollectionAndFeed(feedId) {
    const db = await connectToDatabase();
    const collections = await db.listCollections().toArray();

    for (const c of collections) {
        const collection = db.collection(c.name);
        const result = await collection.findOne({
            _id: DOCUMENT_FEEDS,
            "owner.id": feedId
        });

        if (result && Array.isArray(result.owner)) {
            const dataFeed = result.owner.find(f => { return f.id === feedId });
            return {
                userId: c.name,
                dataFeed: dataFeed
            };
        }
    }

    return null;
}

async function updateSubscribedFeedBD(userCol, dataNewFeed) {
    try {
        const db = await connectToDatabase();
        const resultado = await db.collection(userCol).updateOne(
            { _id: DOCUMENT_FEEDS },
            { $push: { subscribed: dataNewFeed } },
            { upsert: true }
        );
        return resultado.modifiedCount === 1 || resultado.upsertedId !== null
    } catch (error) {
        winston.error('updateSubscribedFeedBD:', error);
        return false;
    }
}

async function deleteSubscriber(userCol, idFeed, idSubscriber) {
    try {
        const db = await connectToDatabase();
        const resultado = await db.collection(userCol).updateOne(
            { _id: DOCUMENT_FEEDS, "owner._id": idFeed },
            { $pull: { "owner.$.subscribers": idSubscriber } }
        );
        return resultado.modifiedCount === 1;
    } catch (error) {
        winston.error('deleteSubscriber:', error);
        return false;
    }
}

async function addAnswerFeedDB(userCol, idFeed, idAnswer) {
    try {
        const db = await connectToDatabase();
        const resultado = await db.collection(userCol).updateOne(
            { _id: DOCUMENT_FEEDS, "subscribed.idFeed": idFeed },
            { $addToSet: { "subscribed.$[elem].answers": idAnswer } },
            { arrayFilters: [{ "elem.idFeed": idFeed }] }
        );
        return resultado.modifiedCount === 1;
    } catch (error) {
        winston.error('addAnswerFeedDB:', error);
        return false;
    }
}


async function deleteAnswerFeedDB(userCol, idFeed, idAnswer) {
    try {
        const db = await connectToDatabase();
        const resultado = await db.collection(userCol).updateOne(
            { _id: DOCUMENT_FEEDS, "subscribed.idFeed": idFeed },
            { $pull: { "subscribed.$[elem].answers": idAnswer } },
            { arrayFilters: [{ "elem.idFeed": idFeed }] }
        );
        return resultado.modifiedCount === 1;
    } catch (error) {
        winston.error('deleteAnswerFeedDB:', error);
        return false;
    }
}

async function updateFeedbackAnswer(userCol, dataAnswer) {
    try {
        const db = await connectToDatabase();
        const resultado = await db.collection(userCol).updateOne(
            { _id: DOCUMENT_ANSWERS, "answers.id": dataAnswer.id },
            { $set: { "answers.$": dataAnswer } },
        );
        return resultado.modifiedCount === 1 || (resultado.matchedCount === 1 && resultado.modifiedCount === 0);
    } catch (error) {
        winston.error('updateFeedbackAnswer:', error);
        return false;
    }
}

module.exports = {
    DOCUMENT_INFO,
    DOCUMENT_ANSWERS,
    getInfoUser,
    getFeedsUser,
    getFeed,
    getDocument,
    updateDocument,
    newDocument,
    checkExistenceAnswer,
    saveAnswer,
    getAnswersDB,
    getAnswerWithoutId,
    deleteCollection,
    saveNewFeed,
    deleteFeedOwner,
    deleteFeedSubscriber,
    disconnectDatabase,
    updateFeedDB,
    getInfoSubscriber,
    findCollectionAndFeed,
    updateSubscribedFeedBD,
    deleteSubscriber,
    addAnswerFeedDB,
    deleteAnswerFeedDB,
    updateFeedbackAnswer,
}