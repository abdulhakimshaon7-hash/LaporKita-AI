// File: test-data/batch_processor.js
// Sends all 100 test messages to your webhook one by one with a delay
// Run with: node batch_processor.js

const fs = require("fs");
const https = require("https");
const http = require("http");

// ============================================================
// CONFIGURATION — edit these to match your setup
// ============================================================

// Your local webhook URL from the Firebase emulator
// Replace "laporkita-ai" with your actual Firebase project ID
// Find your project ID in .firebaserc or on Firebase Console

const WEBHOOK_URL = "https://us-central1-laporkita-ai-e314b.cloudfunctions.net/whatsappWebhook";

// How long to wait between each message (milliseconds)
// 2000ms = 2 seconds. Don't go below 1500ms or Gemini may rate-limit you
const DELAY_BETWEEN_MESSAGES = 2000;

// Path to your generated test messages
const TEST_MESSAGES_FILE = "../test-data/test_messages.json";
// (If you're running from inside test-data/ folder, use: "./test_messages.json")

// ============================================================
// HELPER: Sleep function (pause for N milliseconds)
// ============================================================
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
// This lets us do: await sleep(2000) to pause 2 seconds

// ============================================================
// HELPER: Send one message to the webhook
// ============================================================
function sendWebhookMessage(messageData) {
  return new Promise((resolve, reject) => {
    // Twilio sends form-encoded data, so we mimic that format
    // Your webhook reads: req.body.Body (message) and req.body.From (sender)
    const postData = new URLSearchParams({
      Body: messageData.message,       // The complaint text
      From: messageData.sender,        // The WhatsApp sender number
      MessageSid: `TEST${messageData.id}${Date.now()}`, // Fake Twilio message ID
      NumMedia: "0",                   // No images (text only)
    }).toString();

    // Parse the webhook URL to get host, port, path
    const url = new URL(WEBHOOK_URL);
    const isHttps = url.protocol === "https:";
    const client = isHttps ? https : http; // Use http for local emulator

    const options = {
      hostname: url.hostname,
      port: url.port || (isHttps ? 443 : 80),
      path: url.pathname,
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded", // Twilio's format
        "Content-Length": Buffer.byteLength(postData),
      },
    };

    const req = client.request(options, (res) => {
      let data = "";
      res.on("data", (chunk) => (data += chunk));
      res.on("end", () => {
        resolve({
          statusCode: res.statusCode,
          body: data,
        });
      });
    });

    req.on("error", (err) => reject(err));
    req.write(postData); // Send the data
    req.end();           // Close the request — important!
  });
}

// ============================================================
// MAIN: Read messages and send them all
// ============================================================
async function runBatch() {
  console.log("🚀 LaporKita-AI Batch Processor");
  console.log(`📡 Target webhook: ${WEBHOOK_URL}`);
  console.log(`⏱  Delay between messages: ${DELAY_BETWEEN_MESSAGES}ms\n`);

  // Read the test messages file
  let messages;
  try {
    const rawData = fs.readFileSync(TEST_MESSAGES_FILE, "utf-8");
    messages = JSON.parse(rawData);
    console.log(`✅ Loaded ${messages.length} messages from ${TEST_MESSAGES_FILE}\n`);
  } catch (err) {
    console.error(`❌ Could not read ${TEST_MESSAGES_FILE}`);
    console.error("   Make sure you ran generate_test_messages.py first!");
    console.error("   Error:", err.message);
    process.exit(1); // Stop the script
  }

  // Track success/failure counts
  let successCount = 0;
  let failCount = 0;
  const startTime = Date.now();

  // Send each message one by one
  for (let i = 0; i < messages.length; i++) {
    const msg = messages[i];
    const progress = `[${i + 1}/${messages.length}]`;
    
    try {
      const response = await sendWebhookMessage(msg);

      if (response.statusCode === 200) {
        // Success! Webhook accepted the message
        successCount++;
        console.log(`✅ ${progress} Sent ID:${msg.id} | ${msg.expected_urgency} ${msg.expected_category} | Status: ${response.statusCode}`);
      } else {
        // Webhook returned an error status
        failCount++;
        console.error(`⚠️ ${progress} Sent ID:${msg.id} | Unexpected status: ${response.statusCode}`);
        console.error(`   Response: ${response.body.substring(0, 100)}`);
      }
    } catch (err) {
      // Network error — couldn't even reach the webhook
      failCount++;
      console.error(`❌ ${progress} FAILED ID:${msg.id} | Error: ${err.message}`);
      console.error("   Is the Firebase emulator still running? Check Terminal Window 1.");
    }

    // Wait before sending next message (avoid rate limits)
    if (i < messages.length - 1) {
      await sleep(DELAY_BETWEEN_MESSAGES);
    }
  }

  // Final summary
  const elapsed = ((Date.now() - startTime) / 1000 / 60).toFixed(1);
  console.log("\n" + "=".repeat(50));
  console.log("📊 BATCH COMPLETE");
  console.log("=".repeat(50));
  console.log(`✅ Successful: ${successCount}/${messages.length}`);
  console.log(`❌ Failed:     ${failCount}/${messages.length}`);
  console.log(`⏱  Total time: ${elapsed} minutes`);
  console.log(`\nNext step → Check Emulator UI at http://127.0.0.1:4000/firestore`);
  console.log(`           You should see ~${successCount} new documents in the 'reports' collection`);
}

// Run it!
runBatch().catch((err) => {
  console.error("Fatal error:", err);
  process.exit(1);
});