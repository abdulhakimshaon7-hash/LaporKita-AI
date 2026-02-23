# File: test-data/validate_accuracy.py
# Reads all processed reports from Firestore, exports to CSV,
# and calculates AI accuracy statistics automatically.
# Run with: python3 validate_accuracy.py

import json
import csv
import os
import datetime
import firebase_admin
from firebase_admin import credentials, firestore

# ============================================================
# SECTION 1: CONNECT TO FIRESTORE
# ============================================================

# Initialize Firebase with your service account key
# The service account key allows this Python script to read/write Firestore
# without being logged into Firebase CLI
SERVICE_ACCOUNT_PATH = "./serviceAccountKey.json"  # Relative to this script

if not os.path.exists(SERVICE_ACCOUNT_PATH):
    print("❌ serviceAccountKey.json not found!")
    print("   Download it from: Firebase Console → Settings → Service Accounts")
    exit(1)

cred = credentials.Certificate(SERVICE_ACCOUNT_PATH)
firebase_admin.initialize_app(cred)
db = firestore.client()  # This is your Firestore database connection

print("✅ Connected to Firestore successfully")

# ============================================================
# SECTION 2: LOAD GROUND TRUTH LABELS
# This is the "correct answers" from our test message generator
# ============================================================

# Load the original test messages (they have expected_category, expected_urgency)
GROUND_TRUTH_FILE = "./test_messages.json"

ground_truth = {}  # Will be: { "whatsapp:+60123456789_timestamp" : {expected data} }

if os.path.exists(GROUND_TRUTH_FILE):
    with open(GROUND_TRUTH_FILE, "r", encoding="utf-8") as f:
        test_messages = json.load(f)
    
    # Index by sender+first-30-chars-of-message (so we can match)
    for msg in test_messages:
        key = msg["sender"] + "|" + msg["message"][:30]
        ground_truth[key] = {
            "expected_category": msg["expected_category"],
            "expected_urgency": msg["expected_urgency"],
        }
    print(f"✅ Loaded {len(ground_truth)} ground truth records")
else:
    print("⚠️  test_messages.json not found — accuracy scoring will be skipped")
    print("   (We'll still export what's in Firestore)")

# ============================================================
# SECTION 3: FETCH ALL PROCESSED REPORTS FROM FIRESTORE
# ============================================================

print("\n📡 Fetching reports from Firestore...")

# Query all reports that have a real urgency value (not ANALYZING or missing)
reports_ref = db.collection("reports")
query = reports_ref.where("urgency", "not-in", ["ANALYZING", "UNKNOWN"])
docs = query.stream()  # Stream = process one at a time (memory efficient)

all_reports = []
for doc in docs:
    data = doc.to_dict()
    data["doc_id"] = doc.id  # Add the document ID for reference
    all_reports.append(data)

print(f"✅ Found {len(all_reports)} processed reports")

if len(all_reports) == 0:
    print("❌ No processed reports found!")
    print("   Did you run the batch processor (6.2)?")
    print("   Make sure you're connecting to the RIGHT Firebase project (not emulator)")
    exit(1)

# ============================================================
# SECTION 4: MATCH REPORTS WITH GROUND TRUTH & SCORE ACCURACY
# ============================================================

# Accuracy rubric (how to decide if AI was "correct"):
# URGENCY: Exact match required (CRITICAL/HIGH/MEDIUM/LOW must match exactly)
#           EXCEPTION: CRITICAL vs HIGH = only 0.5 penalty (both are urgent)
# CATEGORY: Exact match required (infrastructure/waste/safety/etc.)
#           EXCEPTION: "noise" vs "safety" may overlap, count as 0.5

scored_reports = []

urgency_correct = 0
urgency_partial = 0  # CRITICAL vs HIGH (close but not exact)
urgency_total = 0

category_correct = 0
category_partial = 0
category_total = 0

for report in all_reports:
    # Try to find this report's ground truth by matching sender + message prefix
    sender = report.get("sender", "")
    message = report.get("message", "")
    lookup_key = sender + "|" + message[:30]
    
    gt = ground_truth.get(lookup_key, None)
    
    # AI's answers
    ai_urgency = report.get("urgency", "UNKNOWN")
    ai_category = report.get("category", "UNKNOWN")
    
    # Score vs ground truth
    urgency_verdict = "N/A"
    category_verdict = "N/A"
    
    if gt:
        expected_urgency = gt["expected_urgency"]
        expected_category = gt["expected_category"]
        urgency_total += 1
        category_total += 1
        
        # --- Urgency scoring ---
        if ai_urgency == expected_urgency:
            urgency_correct += 1
            urgency_verdict = "✅ CORRECT"
        elif (ai_urgency in ["CRITICAL", "HIGH"] and expected_urgency in ["CRITICAL", "HIGH"]):
            # Both are "urgent" — partial credit
            urgency_partial += 0.5
            urgency_verdict = "⚠️ PARTIAL (CRITICAL/HIGH swap)"
        else:
            urgency_verdict = f"❌ WRONG (got {ai_urgency}, expected {expected_urgency})"
        
        # --- Category scoring ---
        if ai_category == expected_category:
            category_correct += 1
            category_verdict = "✅ CORRECT"
        elif (ai_category == "noise" and expected_category == "safety") or \
             (ai_category == "safety" and expected_category == "noise"):
            category_partial += 0.5
            category_verdict = "⚠️ PARTIAL (noise/safety overlap)"
        else:
            category_verdict = f"❌ WRONG (got {ai_category}, expected {expected_category})"
    
    # Gather processing time (if your webhook logs it)
    processing_time = report.get("processing_time_ms", None)
    
    scored_reports.append({
        "doc_id": report.get("doc_id", ""),
        "message": message[:80],  # Truncate for CSV readability
        "sender": sender,
        "timestamp": str(report.get("timestamp", "")),
        "ai_urgency": ai_urgency,
        "ai_category": ai_category,
        "ai_keywords": ", ".join(report.get("keywords", [])),
        "ai_location": report.get("location", ""),
        "ai_sentiment": report.get("sentiment", ""),
        "cluster_id": report.get("cluster_id", ""),
        "status": report.get("status", ""),
        "processing_time_ms": processing_time,
        # Ground truth & scoring
        "expected_urgency": gt["expected_urgency"] if gt else "UNKNOWN",
        "expected_category": gt["expected_category"] if gt else "UNKNOWN",
        "urgency_verdict": urgency_verdict,
        "category_verdict": category_verdict,
    })

# ============================================================
# SECTION 5: EXPORT TO CSV
# ============================================================

output_csv = "accuracy_results.csv"
fieldnames = [
    "doc_id", "message", "sender", "timestamp",
    "ai_urgency", "ai_category", "ai_keywords", "ai_location", "ai_sentiment",
    "cluster_id", "status", "processing_time_ms",
    "expected_urgency", "expected_category",
    "urgency_verdict", "category_verdict",
]

with open(output_csv, "w", newline="", encoding="utf-8") as f:
    writer = csv.DictWriter(f, fieldnames=fieldnames)
    writer.writeheader()
    writer.writerows(scored_reports)

print(f"\n✅ Exported {len(scored_reports)} reports to {output_csv}")

# ============================================================
# SECTION 6: PRINT ACCURACY STATISTICS
# ============================================================

if urgency_total > 0:
    urgency_accuracy = ((urgency_correct + urgency_partial) / urgency_total) * 100
    category_accuracy = ((category_correct + category_partial) / category_total) * 100
    
    print("\n" + "="*60)
    print("📊 AI ACCURACY REPORT")
    print("="*60)
    print(f"\nTotal reports analyzed:      {len(all_reports)}")
    print(f"Reports with ground truth:   {urgency_total}")
    print(f"\nURGENCY ACCURACY:")
    print(f"  Exactly correct:           {urgency_correct}/{urgency_total}")
    print(f"  Partial (CRITICAL/HIGH):   {int(urgency_partial*2)//2}/{urgency_total}")
    print(f"  Overall accuracy:          {urgency_accuracy:.1f}%  {'✅ PASS' if urgency_accuracy >= 80 else '❌ FAIL — target is 80%+'}")
    print(f"\nCATEGORY ACCURACY:")
    print(f"  Exactly correct:           {category_correct}/{category_total}")
    print(f"  Partial (noise/safety):    {int(category_partial*2)//2}/{category_total}")
    print(f"  Overall accuracy:          {category_accuracy:.1f}%  {'✅ PASS' if category_accuracy >= 80 else '❌ FAIL — target is 80%+'}")
    
    # Breakdown by urgency level
    print(f"\nURGENCY BREAKDOWN (AI distribution of {len(all_reports)} reports):")
    urgency_dist = {}
    for r in all_reports:
        u = r.get("urgency", "UNKNOWN")
        urgency_dist[u] = urgency_dist.get(u, 0) + 1
    for level in ["CRITICAL", "HIGH", "MEDIUM", "LOW", "UNKNOWN"]:
        cnt = urgency_dist.get(level, 0)
        if cnt > 0:
            pct = cnt / len(all_reports) * 100
            print(f"  {level:10s}: {cnt:3d} ({pct:.0f}%)")
    
    # Breakdown by category
    print(f"\nCATEGORY BREAKDOWN:")
    cat_dist = {}
    for r in all_reports:
        c = r.get("category", "UNKNOWN")
        cat_dist[c] = cat_dist.get(c, 0) + 1
    for cat, cnt in sorted(cat_dist.items(), key=lambda x: -x[1]):
        pct = cnt / len(all_reports) * 100
        print(f"  {cat:15s}: {cnt:3d} ({pct:.0f}%)")
    
    print(f"\n{'='*60}")
    print(f"📁 Full results saved to: {output_csv}")
    print(f"   Open in Numbers/Excel to see per-message breakdown")
    print(f"\nNext steps:")
    if urgency_accuracy < 80:
        print(f"  ⚠️  Urgency accuracy is below 80% — refine your Gemini prompt!")
        print(f"     Look at ❌ rows in the CSV to find patterns in what's wrong")
    else:
        print(f"  ✅ Urgency accuracy passes! Note this for your submission form")
    if category_accuracy < 80:
        print(f"  ⚠️  Category accuracy is below 80% — refine your Gemini prompt!")
    else:
        print(f"  ✅ Category accuracy passes! Note this for your submission form")
else:
    print("\n⚠️  Could not score accuracy (no ground truth matches found)")
    print("   This can happen if you're reading from the PRODUCTION Firestore")
    print("   (instead of emulator) and the test messages weren't sent there")
    print(f"\n   Still exported {len(scored_reports)} reports to {output_csv}")