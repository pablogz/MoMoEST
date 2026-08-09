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
const DOCUMENT_NOTES = 'notes';

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
                        // Canal activo en el momento de responder (opcional)
                        ...(typeof answerC.idFeed === 'string' && answerC.idFeed !== '' && { idFeed: answerC.idFeed }),
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
                        teachers: [],
                        password: feed.password,
                        date: feed.date,
                        requireFullName: feed.requireFullName,
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

async function addTeacherToFeed(ownerCol, feedId, teacherObj) {
    try {
        const db = await connectToDatabase();
        const resultado = await db.collection(ownerCol).updateOne(
            { _id: DOCUMENT_FEEDS, "owner._id": feedId },
            { $push: { "owner.$.teachers": teacherObj } }
        );
        return resultado.modifiedCount === 1;
    } catch (error) {
        winston.error('addTeacherToFeed:', error);
        return false;
    }
}

async function removeTeacherFromFeed(ownerCol, feedId, teacherId) {
    try {
        const db = await connectToDatabase();
        const resultado = await db.collection(ownerCol).updateOne(
            { _id: DOCUMENT_FEEDS, "owner._id": feedId },
            { $pull: { "owner.$.teachers": { uid: teacherId } } }
        );
        return resultado.modifiedCount === 1;
    } catch (error) {
        winston.error('removeTeacherFromFeed:', error);
        return false;
    }
}

async function updateTeachingFeedBD(teacherCol, data) {
    try {
        const db = await connectToDatabase();
        const resultado = await db.collection(teacherCol).updateOne(
            { _id: DOCUMENT_FEEDS },
            { $push: { teaching: data } },
            { upsert: true }
        );
        return resultado.modifiedCount === 1 || resultado.upsertedId !== null;
    } catch (error) {
        winston.error('updateTeachingFeedBD:', error);
        return false;
    }
}

async function deleteTeachingFeedBD(teacherCol, feedId) {
    try {
        const db = await connectToDatabase();
        const results = await db.collection(teacherCol).updateOne(
            { _id: DOCUMENT_FEEDS },
            { $pull: { teaching: { idFeed: feedId } } }
        );
        return results.modifiedCount === 1;
    } catch (error) {
        winston.error('deleteTeachingFeedBD:', error);
        return false;
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
            // Nombre y apellidos que el estudiante dio para este canal
            if (typeof subscribed.name === 'string' && subscribed.name !== '') {
                out.name = subscribed.name;
            }
            if (typeof subscribed.surname === 'string' && subscribed.surname !== '') {
                out.surname = subscribed.surname;
            }
            out.date = subscribed.date;
            if (subscribed.answers !== undefined && Array.isArray(subscribed.answers)) {
                if (nAnswers) {
                    const answersDB = await getAnswersDB(userCol);
                    const visible = Array.isArray(answersDB)
                        ? answersDB.filter(a => !a.hidden && subscribed.answers.includes(a.id))
                        : [];
                    out.nAnswers = visible.length;
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

async function getAnswerByFile(userCol, fileName) {
    try {
        const db = await connectToDatabase();
        const doc = await db.collection(userCol).findOne(
            { _id: DOCUMENT_ANSWERS, "answers.answer.file": fileName },
            { projection: { "answers.$": 1 } }
        );
        if (doc?.answers?.length === 1) {
            return doc.answers[0];
        }
        return null;
    } catch (error) {
        winston.error(error);
        return null;
    }
}

async function hideAnswerDB(userCol, answerId) {
    try {
        const db = await connectToDatabase();
        const resultado = await db.collection(userCol).updateOne(
            { _id: DOCUMENT_ANSWERS, "answers.id": answerId },
            { $set: { "answers.$.hidden": true } }
        );
        return resultado.modifiedCount === 1;
    } catch (error) {
        winston.error('hideAnswerDB:', error);
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

// Colección con las votaciones públicas de fotografías por lugar. No es una
// colección de usuario: cualquier usuario autenticado puede leerla (el uid del
// autor de cada entrada nunca se expone en las respuestas públicas).
const COLLECTION_PHOTOVOTE = '_photoVote';

async function getPhotoVotePlace(idFeature) {
    try {
        const db = await connectToDatabase();
        return await db.collection(COLLECTION_PHOTOVOTE).findOne({ _id: idFeature });
    } catch (error) {
        winston.error('getPhotoVotePlace:', error);
        return null;
    }
}

async function addPhotoVoteEntry(idFeature, entry) {
    try {
        const db = await connectToDatabase();
        const resultado = await db.collection(COLLECTION_PHOTOVOTE).updateOne(
            { _id: idFeature },
            { $push: { entries: entry } },
            { upsert: true }
        );
        return resultado.modifiedCount === 1 || resultado.upsertedId !== null;
    } catch (error) {
        winston.error('addPhotoVoteEntry:', error);
        return false;
    }
}

// Regla de voto: un único voto por usuario y lugar, que puede cambiarse.
// Con vote=true se mueve el voto del usuario a la entrada indicada; con
// vote=false se retira su voto de esa entrada.
async function votePhotoVoteDB(idFeature, entryId, uid, vote) {
    try {
        const db = await connectToDatabase();
        const collection = db.collection(COLLECTION_PHOTOVOTE);
        if (vote) {
            // Retiro el posible voto previo del usuario en este lugar
            await collection.updateOne(
                { _id: idFeature },
                { $pull: { "entries.$[].votes": uid } }
            );
            const resultado = await collection.updateOne(
                { _id: idFeature, "entries.entryId": entryId },
                { $addToSet: { "entries.$.votes": uid } }
            );
            return resultado.matchedCount === 1;
        }
        const resultado = await collection.updateOne(
            { _id: idFeature, "entries.entryId": entryId },
            { $pull: { "entries.$.votes": uid } }
        );
        return resultado.matchedCount === 1;
    } catch (error) {
        winston.error('votePhotoVoteDB:', error);
        return false;
    }
}

async function getNotesDB(userCol) {
    try {
        const db = await connectToDatabase();
        const doc = await db.collection(userCol).findOne({ _id: DOCUMENT_NOTES });
        if (doc !== null && Array.isArray(doc.notes)) {
            return doc.notes.sort((a, b) => b.lastUpdate - a.lastUpdate);
        }
        return [];
    } catch (error) {
        winston.error('getNotesDB:', error);
        return null;
    }
}

async function addNoteDB(userCol, note) {
    try {
        const db = await connectToDatabase();
        const resultado = await db.collection(userCol).updateOne(
            { _id: DOCUMENT_NOTES },
            { $push: { notes: note } },
            { upsert: true }
        );
        return resultado.modifiedCount === 1 || resultado.upsertedId !== null;
    } catch (error) {
        winston.error('addNoteDB:', error);
        return false;
    }
}

async function updateNoteDB(userCol, note) {
    try {
        const db = await connectToDatabase();
        const resultado = await db.collection(userCol).updateOne(
            { _id: DOCUMENT_NOTES, "notes.id": note.id },
            { $set: { "notes.$": note } }
        );
        return resultado.matchedCount === 1;
    } catch (error) {
        winston.error('updateNoteDB:', error);
        return false;
    }
}

async function deleteNoteDB(userCol, noteId) {
    try {
        const db = await connectToDatabase();
        const resultado = await db.collection(userCol).updateOne(
            { _id: DOCUMENT_NOTES },
            { $pull: { notes: { id: noteId } } }
        );
        return resultado.modifiedCount === 1;
    } catch (error) {
        winston.error('deleteNoteDB:', error);
        return false;
    }
}

module.exports = {
    DOCUMENT_INFO,
    DOCUMENT_ANSWERS,
    DOCUMENT_NOTES,
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
    getNotesDB,
    addNoteDB,
    updateNoteDB,
    deleteNoteDB,
    getPhotoVotePlace,
    addPhotoVoteEntry,
    votePhotoVoteDB,
    hideAnswerDB,
    addTeacherToFeed,
    removeTeacherFromFeed,
    updateTeachingFeedBD,
    deleteTeachingFeedBD,
    getAnswerByFile,
}