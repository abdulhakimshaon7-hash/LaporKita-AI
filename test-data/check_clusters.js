// File: test-data/check_clusters.js
// Quick script to print all clusters and their reports
// Run with: node check_clusters.js

const admin = require("firebase-admin");
const serviceAccount = require("./serviceAccountKey.json");

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function printClusterReport() {
  console.log("🔍 LaporKita-AI Cluster Report\n");

  // Fetch all clusters, sorted by urgency (CRITICAL first)
  const snapshot = await db
    .collection("clusters")
    .orderBy("report_count", "desc")  // Show biggest clusters first
    .get();

  if (snapshot.empty) {
    console.log("❌ No clusters found in Firestore!");
    console.log("   Either clustering hasn't triggered yet,");
    console.log("   or the threshold wasn't reached (need 3+ similar reports).");
    process.exit(0);
  }

  console.log(`Found ${snapshot.size} clusters total\n`);
  console.log("=".repeat(70));

  const urgencyOrder = { CRITICAL: 0, HIGH: 1, MEDIUM: 2, LOW: 3 };
  const clusters = [];
  
  snapshot.forEach((doc) => {
    clusters.push({ id: doc.id, ...doc.data() });
  });
  
  // Sort by urgency then by report count
  clusters.sort((a, b) => {
    const uOrder = (urgencyOrder[a.urgency] ?? 4) - (urgencyOrder[b.urgency] ?? 4);
    if (uOrder !== 0) return uOrder;
    return (b.report_count || 0) - (a.report_count || 0);
  });

  for (const cluster of clusters) {
    const urgencyEmoji = {
      CRITICAL: "🔴",
      HIGH: "🟠",
      MEDIUM: "🟡",
      LOW: "🟢",
    }[cluster.urgency] || "⚪";

    console.log(`\n${urgencyEmoji} Cluster: ${cluster.title || "(no title)"}`);
    console.log(`   ID:       ${cluster.id}`);
    console.log(`   Urgency:  ${cluster.urgency}`);
    console.log(`   Category: ${cluster.category}`);
    console.log(`   Reports:  ${cluster.report_count || 0}`);
    console.log(`   Status:   ${cluster.status}`);
    console.log(`   Areas:    ${(cluster.affected_areas || []).join(", ") || "not specified"}`);
    console.log(`   Summary:  ${(cluster.summary || "").substring(0, 120)}...`);
    if (cluster.recommended_action) {
      console.log(`   Action:   ${cluster.recommended_action.substring(0, 100)}`);
    }

    // Also fetch and show the first 3 report messages in this cluster
    if (cluster.report_ids && cluster.report_ids.length > 0) {
      console.log(`   Sample reports:`);
      const sampleIds = cluster.report_ids.slice(0, 3); // First 3 only
      for (const reportId of sampleIds) {
        const reportDoc = await db.collection("reports").doc(reportId).get();
        if (reportDoc.exists) {
          const msg = reportDoc.data().message || "";
          console.log(`     → "${msg.substring(0, 80)}"`);
        }
      }
      if (cluster.report_ids.length > 3) {
        console.log(`     ... and ${cluster.report_ids.length - 3} more reports`);
      }
    }
    console.log("-".repeat(70));
  }

  // Summary statistics
  const catCounts = {};
  const urgencyCounts = {};
  let totalClustered = 0;
  
  for (const c of clusters) {
    catCounts[c.category] = (catCounts[c.category] || 0) + 1;
    urgencyCounts[c.urgency] = (urgencyCounts[c.urgency] || 0) + 1;
    totalClustered += c.report_count || 0;
  }

  console.log("\n📊 CLUSTER SUMMARY STATISTICS");
  console.log("=".repeat(70));
  console.log(`Total clusters:       ${clusters.length}`);
  console.log(`Total reports in clusters: ${totalClustered}`);
  console.log("\nBy urgency:");
  for (const [u, cnt] of Object.entries(urgencyCounts)) {
    console.log(`  ${u}: ${cnt} clusters`);
  }
  console.log("\nBy category:");
  for (const [cat, cnt] of Object.entries(catCounts)) {
    console.log(`  ${cat}: ${cnt} clusters`);
  }

  process.exit(0);
}

printClusterReport().catch((err) => {
  console.error("Error:", err.message);
  process.exit(1);
});