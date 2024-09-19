const {onRequest} = require("firebase-functions/v2/https");
const axios = require("axios");
const cheerio = require("cheerio");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");

if (!admin.apps.length) {
  admin.initializeApp();
}
const db = admin.firestore();

exports.getScoreboardData = onRequest(async (req, res) => {
  const eventId = req.query.eventId;

  logger.info(`Event ID received: ${eventId}`);

  if (!eventId) {
    return res.status(400).send("Event ID is required");
  }

  try {
    const {data} = await axios.get(eventId);
    const $ = cheerio.load(data);

    const divisions = {};

    $(".flex.flex-col.gap-y-4 > .flex-col").each((i, element) => {
      const divisionName = $(element)
          .find("h2.text-large-strong").text().trim();
      const results = [];

      $(element).find("tbody tr").each((j, row) => {
        const position = $(row)
            .find("td:first-child .text-xs").text().trim();
        const positionNo = parseInt($(row)
            .find("td:first-child .text-xs").text().trim().replace(/^T/, ""));
        const name = $(row)
            .find("td:nth-child(2) .text-wrap.text-start").text().trim();
        const nameLowercase = $(row)
            .find("td:nth-child(2) .text-wrap.text-start")
            .text().trim().toLowerCase();

        results.push({
          position,
          positionNo,
          name,
          nameLowercase,
        });
      });

      divisions[divisionName] = results;
    });

    res.json(divisions);
  } catch (error) {
    logger.error("Error scraping data", error);
    res.status(500).send("Error scraping data");
  }
});

exports.setParticipantData = onRequest(async (req, res) => {
  const url = req.query.url;

  if (!url) {
    return res.status(400).send("URL is required");
  }

  try {
    const {data} = await axios.get(url);
    const $ = cheerio.load(data);

    const participants = [];
    const divisionBlocks =
        $(".border-divider.xs\\:p-5.w-full.border-b.px-1.py-3");

    for (let i = 0; i < divisionBlocks.length; i++) {
      const element = divisionBlocks[i];

      $(element).find(".flex.items-center.justify-between.gap-x-2.w-full")
          .each((j, participantElement) => {
            const name = $(participantElement)
                .find("p.mb-1.leading-none").text().trim();
            const nameLowercase = $(participantElement)
                .find("p.mb-1.leading-none").text().trim().toLowerCase();
            const userId = $(participantElement)
                .find("div.text-subtle p.leading-none")
                .text().trim().replace(/^@/, "");

            if (name && userId) {
              participants.push({name, nameLowercase, userId});
            }
          });
    }

    logger.info("Participants data", {participants});

    const batch = db.batch();

    const eventId = req.body.eventId;
    const eventRef = db.collection("events").doc(eventId);
    const eventDoc = await eventRef.get();

    const eventData = eventDoc.data();
    const organizationId = eventData['organization'];

    for (const participant of participants) {
      const userRef = db
          .collection("organizations")
          .doc(organizationId)
          .collection("members")
          .doc(participant.userId);

      const doc = await userRef.get();
      if (!doc.exists) {
        batch.set(userRef, {
          name: participant.name,
          nameLowercase: participant.nameLowercase,
          admin: false,
          division: "",
          position: "",
          positionNo: 0,
          tag: 0,
          startingTag: 0,
          checkedin: false,
        });

        logger.info(`Writing data for ${participant.userId}`,
            {name: participant.name});
      } else {
        logger.info(`User ${participant.userId} already exists in the db.`);
      }
    }

    await batch.commit();

    res.json({message: "Participants added to Firestore"});
  } catch (error) {
    logger.error("Error scraping participant data", error);
    res.status(500).send("Error scraping participant data");
  }
});

exports.updateUserDatabase = onRequest(async (req, res) => {
  try {
    const eventId = req.body.eventId;
    if (!eventId) {
      res.status(400).send("Missing eventId parameter.");
      return;
    }

    await updateUserDatabaseEvent(eventId);

    res.status(200).send("User database updated successfully.");
  } catch (error) {
    console.error("Error updating user database:", error);
    res.status(500).send("Error updating user database.");
  }
});

/**
 * Fetches participant data for a specific event.
 *
 * @param {string} eventId
 * @return {Promise<Object>}
 * @throws {Error}
 */
async function getParticipantData(eventId) {
  try {
    const participantsUrl =
    eventId.replaceAll("/leaderboard?round=1", "/participants");
    const response = await axios.get(participantsUrl);
    return response.data;
  } catch (error) {
    console.error("Error fetching participant data:", error);
    throw new Error("Failed to fetch participant data");
  }
}

/**
 * Fetches scoreboard data for a specific event.
 *
 * @param {string} eventId
 * @return {Promise<Object>}
 * @throws {Error}
 */
async function getScoreboardData(eventId) {
  try {
    const scoreboardUrl = `${eventId}/leaderboard?round=1`;
    const response = await axios.get(scoreboardUrl);
    return response.data;
  } catch (error) {
    console.error("Error fetching scoreboard data:", error);
    throw new Error("Failed to fetch scoreboard data");
  }
}

/**
 * Updates the user database with data for a specific event.
 *
 * @param {string} eventId
 * @return {Promise<void>}
 */
async function updateUserDatabaseEvent(eventId) {
  try {
    const participantsData = await getParticipantData(eventId); // Use eventId
    const scoreboardData = await getScoreboardData(eventId); // Use eventId

    const batch = db.batch();

    const userIdToNameMap = new Map();
    participantsData.forEach((name, userId) => {
      userIdToNameMap.set(userId, name);
    });

    const eventRef = db.collection("events").doc(eventId);
    const eventDoc = await eventRef.get();

    const eventData = eventDoc.data();
    const organizationId = eventData['organization'];

    for (const [userId, name] of userIdToNameMap) {
      const userRef = db.collection("organizations")
          .doc(organizationId).collection("members").doc(userId);
      const doc = await userRef.get();

      if (doc.exists) {
        const existingData = doc.data();
        if (existingData.name !== name) {
          batch.update(userRef, {name: name});
        }

        const position = scoreboardData[name];
        if (position !== undefined && existingData.position !== position) {
          batch.update(userRef, {position: position});
        }

        const posNo = scoreboardData[name];
        if (posNo !== undefined && existingData.positionNo !== posNo) {
          batch.update(userRef, {positionNo: posNo});
        }
      } else {
        batch.set(userRef, {
          name: name,
          admin: false,
          division: "",
          position: scoreboardData[name] || "",
          positionNo: scoreboardData[name] || 0,
          tag: 0,
          checkedin: false,
        });
      }
    }

    await batch.commit();
  } catch (error) {
    console.error("Error updating user database:", error);
  }
}
