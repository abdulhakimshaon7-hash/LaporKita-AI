# File: ~/Desktop/laporkita-ai/scripts/7_2_metrics_report.py

import firebase_admin
from firebase_admin import credentials, firestore
import pandas as pd
from datetime import datetime, timezone
from tabulate import tabulate
import json
import os

# ============================================================
# SETUP: Connect to your Firebase project
# ============================================================

# Path to your Firebase service account key
# (Download from Firebase Console → Project Settings → Service Accounts)
SERVICE_ACCOUNT_PATH = "/Users/abdulhakimshaon/Desktop/LaporKita-AI/scripts/firebase-service-account.json"


# Initialize Firebase (only run this once per script execution)
if not firebase_admin._apps:
    cred = credentials.Certificate(SERVICE_ACCOUNT_PATH)
    firebase_admin.initialize_app(cred)

db = firestore.client()
print("✅ Connected to Firebase Firestore!\n")

# ============================================================
# STEP 1: Fetch all reports from Firestore
# ============================================================

print("📥 Fetching all reports from Firestore...")
reports_ref = db.collection("reports")
reports_docs = reports_ref.stream()

reports = []
for doc in reports_docs:
    data = doc.to_dict()
    data["doc_id"] = doc.id  # Save the document ID too
    reports.append(data)

total_reports = len(reports)
print(f"   Found {total_reports} reports total.\n")

if total_reports == 0:
    print("❌ No reports found! Did Stage 6 batch processing complete?")
    exit()

# ============================================================
# STEP 2: Fetch all clusters from Firestore
# ============================================================

print("📥 Fetching all clusters from Firestore...")
clusters_ref = db.collection("clusters")
clusters_docs = clusters_ref.stream()

clusters = []
for doc in clusters_docs:
    data = doc.to_dict()
    data["doc_id"] = doc.id
    clusters.append(data)

total_clusters = len(clusters)
print(f"   Found {total_clusters} clusters total.\n")

# ============================================================
# STEP 3: Calculate Core Metrics
# ============================================================

print("🔢 Calculating metrics...\n")

# --- 3a: AI Processing Success Rate ---
# A report "succeeded" if it has an ai_urgency field (means Gemini ran OK)
successful_ai = [r for r in reports if r.get("ai_urgency")]
failed_ai = [r for r in reports if not r.get("ai_urgency")]

success_count = len(successful_ai)
fail_count = len(failed_ai)
error_rate = (fail_count / total_reports * 100) if total_reports > 0 else 0
success_rate = (success_count / total_reports * 100) if total_reports > 0 else 0

# --- 3b: Average Processing Time ---
# Your Firebase Function should save a "processing_time_ms" field
# If it doesn't exist, we'll note that
processing_times = [
    r.get("processing_time_ms") 
    for r in successful_ai 
    if r.get("processing_time_ms") is not None
]

if processing_times:
    avg_processing_time = sum(processing_times) / len(processing_times)
    min_processing_time = min(processing_times)
    max_processing_time = max(processing_times)
else:
    avg_processing_time = None  # Field not recorded — note this
    print("⚠️  Note: 'processing_time_ms' field not found in reports.")
    print("   Estimate: Gemini typically takes 800-2000ms per request.\n")

# --- 3c: Urgency Distribution ---
# Count how many reports fall into each urgency level
urgency_counts = {"CRITICAL": 0, "HIGH": 0, "MEDIUM": 0, "LOW": 0, "unknown": 0}
for r in successful_ai:
    urgency = r.get("ai_urgency", "unknown").upper()
    if urgency in urgency_counts:
        urgency_counts[urgency] += 1
    else:
        urgency_counts["unknown"] += 1

# --- 3d: Category Distribution ---
category_counts = {}
for r in successful_ai:
    category = r.get("ai_category", "unknown")
    category_counts[category] = category_counts.get(category, 0) + 1

# Sort by count descending
category_counts = dict(sorted(category_counts.items(), key=lambda x: x[1], reverse=True))

# --- 3e: Urgency Accuracy (only if manually_verified field exists) ---
# During Stage 6, if you marked reports as correct/incorrect, this calculates accuracy
verified_reports = [r for r in reports if "manually_verified_urgency" in r]
if verified_reports:
    urgency_correct = [r for r in verified_reports if r.get("manually_verified_urgency") == r.get("ai_urgency")]
    urgency_accuracy = len(urgency_correct) / len(verified_reports) * 100
    
    category_correct = [r for r in verified_reports if r.get("manually_verified_category") == r.get("ai_category")]
    category_accuracy = len(category_correct) / len(verified_reports) * 100
else:
    urgency_accuracy = None
    category_accuracy = None
    print("⚠️  Note: No manually_verified fields found.")
    print("   To add accuracy data, manually edit some Firestore documents")
    print("   adding 'manually_verified_urgency' and 'manually_verified_category' fields.\n")

# --- 3f: Clustering Metrics ---
# How many reports are part of a cluster?
reports_in_clusters = [r for r in reports if r.get("cluster_id")]
cluster_rate = (len(reports_in_clusters) / total_reports * 100) if total_reports > 0 else 0

# Average reports per cluster
if total_clusters > 0:
    avg_reports_per_cluster = len(reports_in_clusters) / total_clusters
else:
    avg_reports_per_cluster = 0

# --- 3g: Language Distribution ---
# Check if your reports have a detected_language field
# (You may need to add this to your Gemini prompt — useful for showing Malay/English support)
malay_reports = [r for r in reports if "malay" in str(r.get("detected_language", "")).lower() 
                  or any(word in str(r.get("original_message", "")).lower() 
                         for word in ["yang", "ada", "ini", "itu", "nak", "dah", "lah", "buat"])]
multilang_rate = (len(malay_reports) / total_reports * 100) if total_reports > 0 else 0

# ============================================================
# STEP 4: Print the Formatted Report
# ============================================================

print("=" * 65)
print("       🎯  LAPORKITA-AI TESTING METRICS REPORT")
print(f"       Generated: {datetime.now().strftime('%d %B %Y, %I:%M %p')}")
print("=" * 65)

# --- Section 1: Volume Metrics ---
print("\n📊 SECTION 1: VOLUME & PROCESSING\n")
volume_data = [
    ["Total reports submitted",         total_reports,    "—"],
    ["AI processing successful",        success_count,    f"{success_rate:.1f}%"],
    ["AI processing failed",            fail_count,       f"{error_rate:.1f}%"],
    ["Reports assigned to clusters",    len(reports_in_clusters), f"{cluster_rate:.1f}%"],
    ["Total clusters detected",         total_clusters,   "—"],
]
print(tabulate(volume_data, headers=["Metric", "Count", "Rate"], tablefmt="rounded_outline"))

# --- Section 2: Processing Time ---
print("\n⚡ SECTION 2: PERFORMANCE\n")
if processing_times:
    perf_data = [
        ["Average AI processing time",  f"{avg_processing_time:.0f} ms",   "Target: < 3000ms"],
        ["Fastest processing",          f"{min_processing_time:.0f} ms",   "✅"],
        ["Slowest processing",          f"{max_processing_time:.0f} ms",   "✅" if max_processing_time < 5000 else "⚠️"],
        ["Samples measured",            len(processing_times),              "—"],
    ]
else:
    perf_data = [["AI processing time", "~800-2000ms (estimated)", "Based on Gemini API typical response"]]
print(tabulate(perf_data, headers=["Metric", "Value", "Notes"], tablefmt="rounded_outline"))

# --- Section 3: Accuracy ---
print("\n🎯 SECTION 3: AI ACCURACY\n")
if urgency_accuracy is not None:
    acc_data = [
        ["Urgency detection accuracy",  f"{urgency_accuracy:.1f}%",    "Target: > 80%",
         "✅" if urgency_accuracy >= 80 else "❌ Needs improvement"],
        ["Category accuracy",           f"{category_accuracy:.1f}%",   "Target: > 80%",
         "✅" if category_accuracy >= 80 else "❌ Needs improvement"],
        ["Reports manually verified",   len(verified_reports),         "—", "—"],
    ]
    print(tabulate(acc_data, headers=["Metric", "Value", "Benchmark", "Status"], tablefmt="rounded_outline"))
else:
    print("⚠️  Accuracy not yet measured. See instructions below to add manual verification.\n")
    print("   QUICK WAY TO ADD MANUAL VERIFICATION:")
    print("   1. Open Firestore in browser")
    print("   2. For each test report, add field: manually_verified_urgency = 'HIGH' (or whatever is correct)")
    print("   3. Add field: manually_verified_category = 'infrastructure' (etc.)")
    print("   4. Re-run this script\n")
    print("   OR use your accuracy-results.csv from Stage 6 — see script below!")

# --- Section 4: Urgency Distribution ---
print("\n🚨 SECTION 4: URGENCY DISTRIBUTION\n")
urgency_display = [
    [level, count, f"{count/total_reports*100:.1f}%"]
    for level, count in urgency_counts.items() if count > 0
]
print(tabulate(urgency_display, headers=["Urgency Level", "Count", "% of Total"], tablefmt="rounded_outline"))

# --- Section 5: Category Distribution ---
print("\n🏷️  SECTION 5: TOP COMPLAINT CATEGORIES\n")
category_display = [
    [cat.title(), count, f"{count/total_reports*100:.1f}%"]
    for cat, count in list(category_counts.items())[:8]  # Top 8 categories
]
print(tabulate(category_display, headers=["Category", "Count", "% of Total"], tablefmt="rounded_outline"))

# --- Section 6: Clustering ---
print("\n🗺️  SECTION 6: CLUSTERING INTELLIGENCE\n")
cluster_display = [
    ["Total clusters auto-detected",           total_clusters,                     "—"],
    ["Reports grouped into clusters",          len(reports_in_clusters),           f"{cluster_rate:.1f}%"],
    ["Avg reports per cluster",                f"{avg_reports_per_cluster:.1f}",   "—"],
    ["Standalone (unclustered) reports",       total_reports - len(reports_in_clusters), "—"],
]
print(tabulate(cluster_display, headers=["Metric", "Value", "Notes"], tablefmt="rounded_outline"))

# --- Section 7: Multilingual ---
print("\n🌐 SECTION 7: MULTILINGUAL SUPPORT\n")
lang_display = [
    ["Reports with Malay language indicators", len(malay_reports),       f"{multilang_rate:.1f}%"],
    ["Reports with English language",          total_reports - len(malay_reports), f"{100-multilang_rate:.1f}%"],
]
print(tabulate(lang_display, headers=["Metric", "Count", "% of Total"], tablefmt="rounded_outline"))

# ============================================================
# STEP 5: Save report as JSON for use in other scripts
# ============================================================

metrics_output = {
    "generated_at": datetime.now(timezone.utc).isoformat(),
    "total_reports": total_reports,
    "success_rate_percent": round(success_rate, 1),
    "error_rate_percent": round(error_rate, 1),
    "avg_processing_time_ms": round(avg_processing_time, 0) if avg_processing_time else None,
    "urgency_accuracy_percent": round(urgency_accuracy, 1) if urgency_accuracy else None,
    "category_accuracy_percent": round(category_accuracy, 1) if category_accuracy else None,
    "cluster_detection_rate_percent": round(cluster_rate, 1),
    "total_clusters": total_clusters,
    "urgency_distribution": urgency_counts,
    "top_categories": dict(list(category_counts.items())[:5]),
}

output_path = "../docs/metrics/metrics_data.json"
os.makedirs(os.path.dirname(output_path), exist_ok=True)
with open(output_path, "w") as f:
    json.dump(metrics_output, f, indent=2)

print(f"\n✅ Metrics saved to: {output_path}")
print("   (Use this JSON file in your visualization script next!)\n")

print("=" * 65)
print("  🎓 SUBMISSION TIP:")
print("  Copy the numbers above into your Google Form answers!")
print("  Key stats judges love: success rate, accuracy %, clusters detected")
print("=" * 65)