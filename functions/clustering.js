// This module handles automatic grouping of related complaints

const admin = require("firebase-admin");
const { GoogleGenerativeAI } = require("@google/generative-ai");

// Initialize Gemini for cluster summary generation
const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
const model = genAI.getGenerativeModel({ model: "gemini-pro" });

// =====================================================================
// CALCULATE KEYWORD SIMILARITY
// Returns a number between 0 and 1:
//   0 = no keywords in common
//   1 = all keywords in common
// =====================================================================
const calculateKeywordSimilarity = (keywords1, keywords2) => {
  console.log(`   Comparing keywords: [${keywords1}] vs [${keywords2}]`);
  
  // Safety check: if either array is empty, no similarity
  if (!keywords1 || !keywords2 || keywords1.length === 0 || keywords2.length === 0) {
    return 0;
  }
  
  // Convert to lowercase sets for comparison (so "Lampu" matches "lampu")
  const set1 = new Set(keywords1.map(k => k.toLowerCase().trim()));
  const set2 = new Set(keywords2.map(k => k.toLowerCase().trim()));
  
  // Count keywords that appear in BOTH sets
  let matchCount = 0;
  for (const keyword of set1) {
    if (set2.has(keyword)) {
      matchCount++;
    }
  }
  
  // Total unique keywords across both sets
  const totalUnique = new Set([...set1, ...set2]).size;
  
  // Similarity = shared / total
  const similarity = matchCount / totalUnique;
  console.log(`   Similarity: ${matchCount} matches / ${totalUnique} total = ${(similarity * 100).toFixed(0)}%`);
  
  return similarity;
};

// =====================================================================
// GENERATE CLUSTER SUMMARY VIA GEMINI
// Takes multiple complaint messages and creates a summary
// =====================================================================
const generateClusterSummary = async (messages, category) => {
  console.log(`📝 Generating cluster summary for ${messages.length} related ${category} complaints...`);
  
  const messagesText = messages.map((m, i) => `${i + 1}. "${m}"`).join("\n");
  
  const prompt = `You are analyzing a group of related community complaints from Malaysia.

RELATED COMPLAINTS (all about the same issue):
${messagesText}

CATEGORY: ${category}

These complaints have been automatically grouped because they appear to be about the same problem.
Create a summary for the community manager.

Respond with ONLY a valid JSON object:
{
  "title": "Short title describing the common issue (max 60 characters)",
  "summary": "2-3 sentence summary of the pattern/issue affecting the community",
  "urgency": "CRITICAL | HIGH | MEDIUM | LOW (based on the most urgent complaint)",
  "recommended_action": "Specific action the community manager should take",
  "affected_areas": ["area1", "area2"]
}

IMPORTANT: Respond with ONLY the JSON. No markdown. No backticks.`;

  try {
    const result = await model.generateContent(prompt);
    const rawText = result.response.text();
    const cleanText = rawText.replace(/```json\n?/g, '').replace(/```\n?/g, '').trim();
    return JSON.parse(cleanText);
  } catch (error) {
    console.error("❌ Failed to generate cluster summary:", error.message);
    // Return a default summary if Gemini fails
    return {
      title: `Multiple ${category} complaints`,
      summary: `${messages.length} related complaints about ${category} issues have been detected.`,
      urgency: "MEDIUM",
      recommended_action: `Review all ${category} complaints and take appropriate action`,
      affected_areas: [],
    };
  }
};

// =====================================================================
// MAIN CLUSTERING FUNCTION
// Call this after AI analysis is complete for a new report
// =====================================================================
const checkForClusters = async (newReportId, analysisData) => {
  console.log(`\n🔍 Checking for clusters for report: ${newReportId}`);
  console.log(`   Category: ${analysisData.category}`);
  console.log(`   Keywords: ${analysisData.keywords?.join(", ")}`);
  
  // Configuration
  const TIME_WINDOW_DAYS = 7;           // Look back 7 days
  const MIN_REPORTS_FOR_CLUSTER = 3;    // Need at least 3 related reports
  const SIMILARITY_THRESHOLD = 0.30;   // 30% keyword overlap

  try {
    // Calculate the cutoff time (7 days ago)
    const cutoffTime = new Date();
    cutoffTime.setDate(cutoffTime.getDate() - TIME_WINDOW_DAYS);
    
    // Query Firestore for recent reports with the same category
    // We only check same-category reports (different categories can't cluster)
    const recentReportsQuery = await admin.firestore()
      .collection("reports")
      .where("category", "==", analysisData.category)  // Same category
      .where("ai_processed", "==", true)               // Only AI-processed reports
      .where("timestamp", ">=", cutoffTime)            // Within 7 days
      .get();
    
    console.log(`   Found ${recentReportsQuery.size} recent reports in same category`);
    
    // Find reports that are "similar" to our new report
    const similarReports = [];
    
    recentReportsQuery.forEach((doc) => {
      // Don't compare the report with itself
      if (doc.id === newReportId) return;
      
      const reportData = doc.data();
      const similarity = calculateKeywordSimilarity(
        analysisData.keywords || [],
        reportData.keywords || []
      );
      
      // If similarity is above threshold, it's a related report
      if (similarity >= SIMILARITY_THRESHOLD) {
        similarReports.push({
          id: doc.id,
          data: reportData,
          similarity: similarity,
        });
        console.log(`   ✅ Similar report found: ${doc.id} (${(similarity * 100).toFixed(0)}% match)`);
      }
    });
    
    // Add the new report itself to the list
    const allRelatedReports = [
      { id: newReportId, data: { message: analysisData.summary || "New report" } },
      ...similarReports,
    ];
    
    console.log(`   Total related reports (including new): ${allRelatedReports.length}`);
    
    // Only create a cluster if we have enough related reports
    if (allRelatedReports.length < MIN_REPORTS_FOR_CLUSTER) {
      console.log(`   ℹ️ Not enough related reports for a cluster (need ${MIN_REPORTS_FOR_CLUSTER}, have ${allRelatedReports.length})`);
      return null;
    }
    
    console.log(`   🎯 Cluster detected! ${allRelatedReports.length} related reports`);
    
    // Check if any of the related reports already has a cluster_id
    // If so, we should update the existing cluster instead of creating a new one
    let existingClusterId = null;
    for (const report of similarReports) {
      if (report.data.cluster_id) {
        existingClusterId = report.data.cluster_id;
        console.log(`   Found existing cluster: ${existingClusterId}`);
        break;
      }
    }
    
    // Get all the message texts for summary generation
    const allMessages = allRelatedReports.map(r => r.data.message || r.data.summary || "Unknown");
    
    // Generate cluster summary using Gemini
    const clusterSummary = await generateClusterSummary(allMessages, analysisData.category);
    console.log(`   📋 Cluster title: "${clusterSummary.title}"`);
    
    // All report IDs in this cluster
    const reportIds = allRelatedReports.map(r => r.id);
    
    let clusterId;
    
    if (existingClusterId) {
      // UPDATE existing cluster
      clusterId = existingClusterId;
      await admin.firestore().collection("clusters").doc(clusterId).update({
        report_ids: reportIds,
        report_count: reportIds.length,
        title: clusterSummary.title,
        summary: clusterSummary.summary,
        urgency: clusterSummary.urgency,
        recommended_action: clusterSummary.recommended_action,
        affected_areas: clusterSummary.affected_areas || [],
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      });
      console.log(`   ✅ Updated existing cluster: ${clusterId}`);
      
    } else {
      // CREATE new cluster
      const clusterRef = await admin.firestore().collection("clusters").add({
        title: clusterSummary.title,
        summary: clusterSummary.summary,
        category: analysisData.category,
        urgency: clusterSummary.urgency,
        recommended_action: clusterSummary.recommended_action,
        affected_areas: clusterSummary.affected_areas || [],
        report_ids: reportIds,
        report_count: reportIds.length,
        status: "open",
        created_at: admin.firestore.FieldValue.serverTimestamp(),
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      });
      clusterId = clusterRef.id;
      console.log(`   ✅ Created new cluster: ${clusterId}`);
    }
    
    // Update ALL related reports with the cluster_id
    const batch = admin.firestore().batch(); // Batch write = update multiple docs at once
    for (const reportId of reportIds) {
      const reportRef = admin.firestore().collection("reports").doc(reportId);
      batch.update(reportRef, { cluster_id: clusterId });
    }
    await batch.commit();
    console.log(`   ✅ Updated ${reportIds.length} reports with cluster_id: ${clusterId}`);
    
    return clusterId;
    
  } catch (error) {
    console.error("❌ Clustering error:", error.message);
    return null; // Return null if clustering fails — don't break the main flow
  }
};

module.exports = { checkForClusters };