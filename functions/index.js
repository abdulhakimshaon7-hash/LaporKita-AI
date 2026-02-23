// File: functions/index.js
// LaporKita AI — Complete backend: Webhook + Gemini Analysis + Clustering + Authority Alerts

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const twilio = require('twilio');
const { GoogleGenerativeAI } = require('@google/generative-ai');

// firebase-admin v13 — must import Firestore this way
const { getFirestore, FieldValue } = require('firebase-admin/firestore');

admin.initializeApp();
const db = getFirestore(); // ← replaces the old admin.firestore()

// Malaysian location coordinates lookup table
// Gemini extracts location names — we convert them to lat/lng for the map
const MALAYSIA_COORDS = {
  // Kuala Lumpur areas
  "bukit jalil": { lat: 3.0580, lng: 101.6900 },
  "cheras": { lat: 3.0833, lng: 101.7500 },
  "wangsa maju": { lat: 3.2000, lng: 101.7333 },
  "taman melati": { lat: 3.2167, lng: 101.7333 },
  "setapak": { lat: 3.2000, lng: 101.7167 },
  "kepong": { lat: 3.2167, lng: 101.6333 },
  "segambut": { lat: 3.1833, lng: 101.6667 },
  "bangsar": { lat: 3.1333, lng: 101.6833 },
  "chow kit": { lat: 3.1667, lng: 101.7000 },
  "ampang": { lat: 3.1500, lng: 101.7667 },
  "pandan indah": { lat: 3.1167, lng: 101.7500 },
  "sri petaling": { lat: 3.0667, lng: 101.6833 },
  "taman desa": { lat: 3.0833, lng: 101.6833 },
  "bangsar south": { lat: 3.1116, lng: 101.6641 },
  "batu caves": { lat: 3.2333, lng: 101.6833 },
  "gombak": { lat: 3.2500, lng: 101.7167 },
  "jalan ipoh": { lat: 3.1833, lng: 101.6833 },
  "bandar tun razak": { lat: 3.0833, lng: 101.7333 },
  "taman connaught": { lat: 3.0833, lng: 101.7500 },
  // Selangor areas
  "petaling jaya": { lat: 3.1073, lng: 101.6067 },
  "ss2": { lat: 3.1167, lng: 101.6167 },
  "subang jaya": { lat: 3.0500, lng: 101.5833 },
  "usj": { lat: 3.0333, lng: 101.5833 },
  "puchong": { lat: 3.0000, lng: 101.6167 },
  "cyberjaya": { lat: 2.9167, lng: 101.6500 },
  "putrajaya": { lat: 2.9264, lng: 101.6964 },
  "klang": { lat: 3.0333, lng: 101.4500 },
  "shah alam": { lat: 3.0733, lng: 101.5185 },
  "damansara": { lat: 3.1500, lng: 101.6167 },
  "batu 9 cheras": { lat: 3.0000, lng: 101.7500 },
  // Default KL center if nothing matches
  "kuala lumpur": { lat: 3.1390, lng: 101.6869 },
  "kl": { lat: 3.1390, lng: 101.6869 },
};

// Convert a location string to coordinates
// Returns { lat, lng } or null if not found
function getCoordinates(locationString) {
  if (!locationString) return null;
  const lower = locationString.toLowerCase();
  // Try exact match first
  if (MALAYSIA_COORDS[lower]) return MALAYSIA_COORDS[lower];
  // Try partial match — e.g. "Jalan PJU 1/1, Petaling Jaya" should match "petaling jaya"
  for (const [key, coords] of Object.entries(MALAYSIA_COORDS)) {
    if (lower.includes(key)) return coords;
  }
  return null;
}

// ─────────────────────────────────────────────
// GEMINI AI ANALYSIS
// ─────────────────────────────────────────────
async function analyzeWithGemini(messageText) {
  const apiKey = process.env.GEMINI_API_KEY;
  const genAI = new GoogleGenerativeAI(apiKey);
  const model = genAI.getGenerativeModel({ model: 'gemini-2.0-flash' });

  const prompt = `
You are an AI assistant for LaporKita, a Malaysian community complaint management system serving both residential condos and public neighbourhoods (taman perumahan).
Analyze the complaint and return ONLY valid JSON. No explanation, no markdown, no text outside JSON.

Message: "${messageText}"

Return exactly this JSON structure:
{
  "urgency": "CRITICAL or HIGH or MEDIUM or LOW",
  "category": "infrastructure or safety or waste or noise or environment or facilities or general",
  "sentiment": "distressed or frustrated or neutral or informational",
  "keywords": ["keyword1", "keyword2", "keyword3"],
  "location": "most specific location mentioned, or empty string if none",
  "summary": "one sentence English summary of the complaint",
  "action_suggested": "specific recommended action for the community manager"
}

━━━ CATEGORY — pick the single best match ━━━
- infrastructure → roads/jalan berlubang, drains/longkang, streetlights/lampu jalan, lifts/lif, pipes/paip, bridges/jambatan, electricity/elektrik, buildings
- safety → crime/kecurian, stray animals/anjing liar, dangerous structures, fire/api, suspicious people, accidents, broken CCTV/gate
- waste → rubbish/sampah not collected, illegal dumping, overflowing bins, littering, chemical waste disposal
- noise → loud music, renovation noise, machinery, barking dogs, late-night disturbance, karaoke
- environment → river/sungai pollution, air/smoke pollution, fallen trees/pokok tumbang, landslide/tanah runtuh, flooding from rain
- facilities → playgrounds/taman permainan, community halls/dewan, gyms, pools/kolam renang, wifi, surau, public toilets/tandas
- general → anything not fitting above

━━━ URGENCY — read carefully, this matters most ━━━

CRITICAL — life-threatening, respond within 1 hour:
✓ Gas leak / bau gas
✓ Fire / api / kebakaran
✓ Flooding WITH electrocution risk (water + exposed wires)
✓ Structural collapse imminent (tiang nak roboh, jambatan crack)
✓ Person trapped (dalam lif, dalam bangunan)
✓ Violent crime in progress RIGHT NOW
✓ Chemical/toxic waste spill with immediate health risk
✓ Medical emergency in public area
SIGNALS: "sekarang", "bahaya", "tolong cepat", "emergency", "!!!!", multiple 🚨

HIGH — serious disruption, respond same day:
✓ Lift broken 24h+ AND elderly/disabled affected
✓ Main water pipe burst flooding multiple units/homes
✓ Complete power outage affecting whole block/area
✓ Stray animal ALREADY attacked/bit someone
✓ Large pothole ALREADY caused accidents this week
✓ Flooding entering homes (banjir masuk rumah)
✓ Rubbish not collected 7+ days (health risk, tikus/rats mentioned)
✓ CCTV/main gate fully broken at night
✓ Fallen tree blocking main road
✓ Ongoing crime (break-ins reported multiple times this week)
SIGNALS: "dah X hari/minggu", "dah accident", "dah kena gigit", "masuk rumah", "semua orang"

MEDIUM — inconvenient, needs response within 2-3 days:
✓ Single streetlight out (no accident yet)
✓ Drain clogged, minor pooling on road (NOT entering homes)
✓ Rubbish bin overflowing (collected within last 7 days)
✓ Noise complaint from neighbour
✓ Broken playground equipment (no injury yet)
✓ Pool dirty or not cleaned
✓ Broken gym equipment (treadmill, weights)
✓ Surau/toilet facilities not working
✓ Suspicious loitering (no active crime)
✓ Pothole (no accidents reported yet)
✓ Single lift broken but second lift still working
✓ Swimming pool water looks dirty/green
✓ Community hall/dewan aircon broken
✓ Wifi not working in community centre

NOT MEDIUM — these are LOW (do not upgrade these):
✗ Faded/worn road markings or speed bumps → LOW
✗ Blurry or tilted road mirrors → LOW
✗ Overgrown grass or bushes → LOW
✗ Faded paint on walls or signs → LOW
✗ Suggestion or feedback with no safety risk → LOW
✗ Single bench broken in park (not causing injury) → LOW

SIGNALS for MEDIUM: "dah seminggu", "tak best", "tolong tengok", single 😡, moderate complaint tone

LOW — minor, schedule for next maintenance cycle:
✓ Faded speed bump markings (drivers can still see it)
✓ Blurry or slightly tilted road mirror
✓ Overgrown grass or tree branches (not blocking path)
✓ Faded paint on walls, signs, or road markings  
✓ Single light bulb out in non-critical area
✓ Suggestion or improvement idea (no safety issue)
✓ Minor corridor cleanliness (not health risk)
✓ Broken bench in park (can sit elsewhere)
✓ Signboard fallen or faded

NOT LOW — these are MEDIUM (do not downgrade these):
✗ Rubbish not collected 7+ days → MEDIUM
✗ Pool water green/dirty → MEDIUM  
✗ Gym equipment broken → MEDIUM
✗ Community hall aircon broken → MEDIUM
✗ Surau facilities broken → MEDIUM

SIGNALS for LOW: "sikit je", "cadangan", "bila ada masa", "minor", polite tone, no urgency words
━━━ SPECIAL RULES ━━━
1. Typos are normal — "smapah"=sampah, "bnajir"=banjir, "gelpak"=gelap, "longkng"=longkang
2. Emoji signal urgency: 🚨🔴 = CRITICAL/HIGH, 😡😤 = HIGH/MEDIUM, 😰😟 = MEDIUM, 😊 = LOW
3. "dah lama" / "dah X minggu" (2+ weeks) → upgrade one level (MEDIUM→HIGH)
4. Multiple exclamation !!! → upgrade one level
5. If injury/accident ALREADY happened → minimum HIGH
6. ALL-CAPS words → higher urgency signal
7. Messages in Malay, English, Manglish, or mixed with Chinese are all valid — understand all
  `;

  for (let attempt = 1; attempt <= 3; attempt++) {
    try {
      const result = await model.generateContent(prompt);
      const text = result.response.text().trim();
      const cleaned = text.replace(/```json|```/g, '').trim();
      return JSON.parse(cleaned);

    } catch (err) {
      console.warn(`Gemini attempt ${attempt} failed:`, err.message);
      if (attempt === 3) {
        return {
          urgency: 'UNKNOWN',
          category: 'general',
          sentiment: 'neutral',
          keywords: [],
          location: '',
          summary: 'Analysis failed — review manually.',
          action_suggested: 'Manual review required.'
        };
      }
      await new Promise(r => setTimeout(r, 1000));
    }
  }
}

// ─────────────────────────────────────────────
// CLUSTERING
// ─────────────────────────────────────────────
async function checkForClusters(newReportId, analysisData) {
  console.log(`🔍 Checking clusters for report: ${newReportId}`);

  const MIN_REPORTS = 2;
  const SIMILARITY_THRESHOLD = 0.15;

  const snapshot = await db.collection('reports')
    .where('category', '==', analysisData.category)
    .get();

  console.log(`Found ${snapshot.size} reports in same category`);

  const similar = [];
  snapshot.forEach(doc => {
    if (doc.id === newReportId) return;

    const data = doc.data();
    const newKeywords = (analysisData.keywords || []).map(k => k.toLowerCase());
    const docKeywords = (data.keywords || []).map(k => k.toLowerCase());

    const shared = newKeywords.filter(k => docKeywords.includes(k)).length;
    const total = new Set([...newKeywords, ...docKeywords]).size;
    const similarity = total > 0 ? shared / total : 0;

    console.log(`  Report ${doc.id}: ${(similarity * 100).toFixed(0)}% similar`);

    if (similarity >= SIMILARITY_THRESHOLD) {
      similar.push({ id: doc.id, data });
    }
  });

  const allRelated = [newReportId, ...similar.map(r => r.id)];

  if (allRelated.length < MIN_REPORTS) {
    console.log(`ℹ️ Only ${allRelated.length} similar reports — no cluster yet (need ${MIN_REPORTS})`);
    return null;
  }

  console.log(`🎯 Cluster detected! ${allRelated.length} related reports`);

  let existingClusterId = null;
  for (const r of similar) {
    if (r.data.cluster_id) {
      existingClusterId = r.data.cluster_id;
      break;
    }
  }

  const clusterData = {
    category: analysisData.category,
    urgency: analysisData.urgency,
    report_ids: allRelated,
    report_count: allRelated.length,
    status: 'open',
    title: `Multiple ${analysisData.category} complaints`,
    summary: `${allRelated.length} related ${analysisData.category} complaints detected`,
    updated_at: FieldValue.serverTimestamp(), // ← fixed
  };

  let clusterId;

  if (existingClusterId) {
    await db.collection('clusters').doc(existingClusterId).update(clusterData);
    clusterId = existingClusterId;
    console.log(`✅ Updated existing cluster: ${clusterId}`);
  } else {
    const ref = await db.collection('clusters').add({
      ...clusterData,
      created_at: FieldValue.serverTimestamp(), // ← fixed
    });
    clusterId = ref.id;
    console.log(`✅ Created new cluster: ${clusterId}`);
  }

  const batch = db.batch();
  for (const id of allRelated) {
    batch.update(db.collection('reports').doc(id), { cluster_id: clusterId });
  }
  await batch.commit();
  console.log(`✅ Updated ${allRelated.length} reports with cluster_id: ${clusterId}`);

  return clusterId;
}

// ─────────────────────────────────────────────
// SEND AUTHORITY ALERT
// Sends WhatsApp to authority for CRITICAL or HIGH complaints
// ─────────────────────────────────────────────
async function sendAuthorityAlert(reportId, analysis) {
  const urgency = analysis.urgency;
  if (urgency !== 'CRITICAL' && urgency !== 'HIGH') return;

  const authorityNumber = process.env.AUTHORITY_WHATSAPP;
  if (!authorityNumber) {
    console.warn('⚠️ AUTHORITY_WHATSAPP not set in .env — skipping alert');
    return;
  }

  const accountSid = process.env.TWILIO_ACCOUNT_SID;
  const authToken = process.env.TWILIO_AUTH_TOKEN;
  const fromNumber = process.env.TWILIO_WHATSAPP_NUMBER;
  const client = twilio(accountSid, authToken);

  const urgencyEmoji = urgency === 'CRITICAL' ? '🚨' : '⚠️';

  const message =
    `${urgencyEmoji} *LaporKita Alert — ${urgency} Priority*\n\n` +
    `📍 Location: ${analysis.location || 'Not specified'}\n` +
    `📂 Category: ${analysis.category}\n` +
    `📝 Summary: ${analysis.summary}\n` +
    `💡 Action: ${analysis.action_suggested}\n` +
    `🔖 Report ID: ${reportId.substring(0, 6).toUpperCase()}\n\n` +
    `Please review on the LaporKita dashboard:\n` +
    `https://laporkita-ai-e314b.web.app`;

  try {
    await client.messages.create({
      from: fromNumber,
      to: authorityNumber,
      body: message,
    });
    console.log(`🚨 Authority alert sent for report ${reportId} (${urgency})`);
  } catch (err) {
    console.error('Failed to send authority alert:', err.message);
  }
}

// ─────────────────────────────────────────────
// EXPORTED: Analyze single report by ID
// ─────────────────────────────────────────────
exports.analyzeReport = functions.https.onRequest(async (req, res) => {
  const reportId = req.query.id;
  if (!reportId) return res.status(400).send('Missing ?id= parameter');

  const ref = db.collection('reports').doc(reportId);
  const doc = await ref.get();
  if (!doc.exists) return res.status(404).send('Report not found');

  const analysis = await analyzeWithGemini(doc.data().message);
  await ref.update({
    ...analysis,
    analyzed_at: FieldValue.serverTimestamp() // ← fixed
  });

  res.json({ success: true, reportId, analysis });
});

// ─────────────────────────────────────────────
// EXPORTED: Analyze ALL reports
// ─────────────────────────────────────────────
exports.analyzeAllPending = functions.https.onRequest(async (req, res) => {
  const snapshot = await db.collection('reports').get();

  if (snapshot.empty) {
    return res.json({ message: 'No reports found in Firestore', count: 0 });
  }

  console.log(`Found ${snapshot.size} reports — starting analysis...`);

  const results = [];
  for (const doc of snapshot.docs) {
    try {
      const data = doc.data();
      console.log(`Analyzing report ${doc.id}: "${data.message?.substring(0, 50)}..."`);

      const analysis = await analyzeWithGemini(data.message);

      await doc.ref.update({
        ...analysis,
        analyzed_at: FieldValue.serverTimestamp() // ← fixed
      });

      results.push({
        id: doc.id,
        urgency: analysis.urgency,
        category: analysis.category,
        summary: analysis.summary
      });

      console.log(`✓ Done: ${doc.id} → ${analysis.urgency} / ${analysis.category}`);

    } catch (err) {
      console.error(`✗ Failed on report ${doc.id}:`, err.message);
      results.push({ id: doc.id, error: err.message });
    }

    await new Promise(r => setTimeout(r, 600));
  }

  res.json({ success: true, processed: results.length, results });
});

// ─────────────────────────────────────────────
// EXPORTED: Manually trigger clustering
// ─────────────────────────────────────────────
exports.runClustering = functions.https.onRequest(async (req, res) => {
  const snapshot = await db.collection('reports')
    .where('urgency', '!=', 'UNKNOWN')
    .get();

  if (snapshot.empty) {
    return res.json({ message: 'No analyzed reports found', count: 0 });
  }

  console.log(`Running clustering on ${snapshot.size} reports...`);

  const clusterResults = [];
  for (const doc of snapshot.docs) {
    const data = doc.data();
    if (!data.category || !data.keywords) continue;

    const clusterId = await checkForClusters(doc.id, data);
    clusterResults.push({ id: doc.id, clusterId: clusterId || 'none' });

    await new Promise(r => setTimeout(r, 200));
  }

  res.json({ success: true, processed: clusterResults.length, results: clusterResults });
});

// ─────────────────────────────────────────────
// EXPORTED: WhatsApp Webhook
// ─────────────────────────────────────────────
exports.whatsappWebhook = functions.https.onRequest(async (req, res) => {
  try {
    const incomingMessage = req.body.Body;
    const senderNumber = req.body.From;

    // Ignore Twilio status callbacks with no message body
    if (!incomingMessage || !senderNumber) {
      console.log('Ignoring empty callback from Twilio');
      return res.status(200).send('OK');
    }

    console.log(`📨 New message from ${senderNumber}: "${incomingMessage}"`);

    const reportRef = await db.collection('reports').add({
      message: incomingMessage,
      sender: senderNumber,
      status: 'pending',
      urgency: 'ANALYZING',
      category: 'ANALYZING',
      cluster_id: '',
      timestamp: FieldValue.serverTimestamp(), // ← fixed
    });

    console.log(`✅ Saved report: ${reportRef.id}`);

    // Detect language — require 2+ Malay words to avoid false positives
    const malayWords = ['rosak', 'tolong', 'dah', 'tak', 'nak', 'saya',
      'kat', 'dengan', 'untuk', 'boleh', 'longkang', 'lampu',
      'jalan', 'rumah', 'blok', 'paip', 'busuk', 'tersumbat',
      'melimpah', 'bertakung', 'depan', 'belakang'];

    const messageWords = incomingMessage.toLowerCase().split(/\s+/);
    const malayMatchCount = malayWords.filter(word => messageWords.includes(word)).length;
    const isMalay = malayMatchCount >= 2;

    console.log(`🌐 Language: ${malayMatchCount} Malay words → ${isMalay ? 'Malay' : 'English'}`);

    const replyMessage = isMalay
      ? 'Terima kasih! Aduan anda sedang dianalisis oleh AI kami.\nReport ID: ' + reportRef.id.substring(0, 6).toUpperCase()
      : 'Thank you! Your complaint is being analyzed by our AI.\nReport ID: ' + reportRef.id.substring(0, 6).toUpperCase();

    const twiml = new twilio.twiml.MessagingResponse();
    twiml.message(replyMessage);
    res.type('text/xml').send(twiml.toString());

    // Background: analyze + alert + cluster
    analyzeWithGemini(incomingMessage).then(async analysis => {
      // Convert location string → lat/lng for the map
      const coords = getCoordinates(analysis.location);

      await reportRef.update({
        ...analysis,
        analyzed_at: FieldValue.serverTimestamp(), // ← fixed
        ai_processed: true,        // ← ADD THIS LINE
        status: 'processed',       // ← ADD THIS LINE
        // Add coordinates if we found them — this is what the map reads
        latitude: coords ? coords.lat : null,
        longitude: coords ? coords.lng : null,
      });
      console.log(`🤖 Analysis done for ${reportRef.id}: ${analysis.urgency}`);

      await sendAuthorityAlert(reportRef.id, analysis);

      const clusterId = await checkForClusters(reportRef.id, analysis);
      if (clusterId) {
        console.log(`🔗 Report ${reportRef.id} added to cluster: ${clusterId}`);
      }
    }).catch(err => {
      console.error('Background analysis failed:', err.message);
    });

  } catch (err) {
    console.error('Webhook error:', err.message);
    res.status(500).send('Internal server error');
  }
});