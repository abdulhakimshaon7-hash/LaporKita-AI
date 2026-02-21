// File: functions/index.js
// LaporKita AI — Complete backend: Webhook + Gemini Analysis + Clustering

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const twilio = require('twilio');
const { GoogleGenerativeAI } = require('@google/generative-ai');

// Initialize Firebase ONCE
admin.initializeApp();
const db = admin.firestore();

// ─────────────────────────────────────────────
// GEMINI AI ANALYSIS
// ─────────────────────────────────────────────
async function analyzeWithGemini(messageText) {
  const apiKey = process.env.GEMINI_API_KEY;
  const genAI = new GoogleGenerativeAI(apiKey);
  const model = genAI.getGenerativeModel({ model: 'gemini-2.0-flash' });

  const prompt = `
You are an AI assistant for LaporKita, a Malaysian community complaint management system.
Analyze the following complaint message and return ONLY a valid JSON object.
Do not include any explanation, markdown, or text outside the JSON.

Message: ${messageText}

Return this exact JSON structure:
{
  "urgency": "CRITICAL | HIGH | MEDIUM | LOW",
  "category": "infrastructure | safety | health | environment | general",
  "sentiment": "distressed | frustrated | neutral | informational",
  "keywords": ["keyword1", "keyword2"],
  "location": "extracted location or empty string",
  "summary": "one sentence English summary",
  "action_suggested": "brief recommended action"
}

Urgency: CRITICAL=immediate danger, HIGH=significant disruption,
MEDIUM=needs attention soon, LOW=minor inconvenience.
Message may be Malay, English, or mixed Manglish. Understand all three.

LOCATION EXTRACTION GUIDELINES:
- Extract the most specific location mentioned in the message
- Include taman names (e.g. "Taman Melati"), street names (e.g. "Jalan PJU 1/1")
- Include block or unit references (e.g. "Block B", "Blok A", "Level 3")
- If only a general area is mentioned (e.g. "near playground"), extract that
- If NO location is mentioned at all, return empty string ""
- Format: most specific location first (e.g. "Blok A, Taman Maju" or "Jalan Mawar")
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
    updated_at: admin.firestore.FieldValue.serverTimestamp(),
  };

  let clusterId;

  if (existingClusterId) {
    await db.collection('clusters').doc(existingClusterId).update(clusterData);
    clusterId = existingClusterId;
    console.log(`✅ Updated existing cluster: ${clusterId}`);
  } else {
    const ref = await db.collection('clusters').add({
      ...clusterData,
      created_at: admin.firestore.FieldValue.serverTimestamp(),
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
// EXPORTED FUNCTION: Analyze single report by ID
// Usage: /analyzeReport?id=YOUR_DOCUMENT_ID
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
    analyzed_at: admin.firestore.FieldValue.serverTimestamp()
  });

  res.json({ success: true, reportId, analysis });
});

// ─────────────────────────────────────────────
// EXPORTED FUNCTION: Analyze ALL reports
// Usage: visit /analyzeAllPending in browser
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
        analyzed_at: admin.firestore.FieldValue.serverTimestamp()
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
// EXPORTED FUNCTION: Manually trigger clustering
// Usage: visit /runClustering in browser
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
// EXPORTED FUNCTION: WhatsApp Webhook
// Twilio calls this when a WhatsApp message arrives
// ─────────────────────────────────────────────
exports.whatsappWebhook = functions.https.onRequest(async (req, res) => {
  try {
    const incomingMessage = req.body.Body;
    const senderNumber = req.body.From;

    console.log(`📨 New message from ${senderNumber}: "${incomingMessage}"`);

    const reportRef = await db.collection('reports').add({
      message: incomingMessage,
      sender: senderNumber,
      status: 'pending',
      urgency: 'ANALYZING',
      category: 'ANALYZING',
      cluster_id: '',
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`✅ Saved report: ${reportRef.id}`);

    // Count Malay word matches — need at least 2 matches to confirm Malay
    // This prevents single accidental matches (e.g. "air" in "repair")
    const malayWords = ['rosak', 'tolong', 'dah', 'tak', 'nak', 'saya',
      'kat', 'dengan', 'untuk', 'boleh', 'longkang',
      'lampu', 'jalan', 'rumah', 'blok', 'paip', 'busuk',
      'tersumbat', 'melimpah', 'bertakung', 'depan', 'belakang'];

    const messageLower = incomingMessage.toLowerCase();

    // Split into words to avoid partial matches (e.g. "air" inside "repair")
    const messageWords = messageLower.split(/\s+/);
    const malayMatchCount = malayWords.filter(word => messageWords.includes(word)).length;
    const isMalay = malayMatchCount >= 2;

    console.log(`Language detection: ${malayMatchCount} Malay words found → ${isMalay ? 'Malay' : 'English'}`);

    const replyMessage = isMalay
      ? 'Terima kasih! Aduan anda sedang dianalisis oleh AI kami.\nReport ID: ' + reportRef.id.substring(0, 6).toUpperCase()
      : 'Thank you! Your complaint is being analyzed by our AI.\nReport ID: ' + reportRef.id.substring(0, 6).toUpperCase();

    const twiml = new twilio.twiml.MessagingResponse();
    twiml.message(replyMessage);
    res.type('text/xml').send(twiml.toString());

    analyzeWithGemini(incomingMessage).then(async analysis => {
      await reportRef.update({
        ...analysis,
        analyzed_at: admin.firestore.FieldValue.serverTimestamp()
      });
      console.log(`🤖 Analysis done for ${reportRef.id}: ${analysis.urgency}`);

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