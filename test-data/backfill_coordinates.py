# File: test-data/backfill_coordinates.py
# Adds lat/lng to all existing reports that have a location string but no coordinates

import firebase_admin
from firebase_admin import credentials, firestore
SERVICE_ACCOUNT_PATH = "./serviceAccountKey.json"
cred = credentials.Certificate(SERVICE_ACCOUNT_PATH)
firebase_admin.initialize_app(cred)
db = firestore.client()

# Same lookup table as in index.js
MALAYSIA_COORDS = {
    "bukit jalil": {"latitude": 3.0580, "longitude": 101.6900},
    "cheras": {"latitude": 3.0833, "longitude": 101.7500},
    "wangsa maju": {"latitude": 3.2000, "longitude": 101.7333},
    "taman melati": {"latitude": 3.2167, "longitude": 101.7333},
    "setapak": {"latitude": 3.2000, "longitude": 101.7167},
    "kepong": {"latitude": 3.2167, "longitude": 101.6333},
    "segambut": {"latitude": 3.1833, "longitude": 101.6667},
    "bangsar": {"latitude": 3.1333, "longitude": 101.6833},
    "ampang": {"latitude": 3.1500, "longitude": 101.7667},
    "pandan indah": {"latitude": 3.1167, "longitude": 101.7500},
    "sri petaling": {"latitude": 3.0667, "longitude": 101.6833},
    "taman desa": {"latitude": 3.0833, "longitude": 101.6833},
    "batu caves": {"latitude": 3.2333, "longitude": 101.6833},
    "gombak": {"latitude": 3.2500, "longitude": 101.7167},
    "bandar tun razak": {"latitude": 3.0833, "longitude": 101.7333},
    "taman connaught": {"latitude": 3.0833, "longitude": 101.7500},
    "petaling jaya": {"latitude": 3.1073, "longitude": 101.6067},
    "ss2": {"latitude": 3.1167, "longitude": 101.6167},
    "subang jaya": {"latitude": 3.0500, "longitude": 101.5833},
    "puchong": {"latitude": 3.0000, "longitude": 101.6167},
    "cyberjaya": {"latitude": 2.9167, "longitude": 101.6500},
    "putrajaya": {"latitude": 2.9264, "longitude": 101.6964},
    "klang": {"latitude": 3.0333, "longitude": 101.4500},
    "shah alam": {"latitude": 3.0733, "longitude": 101.5185},
    "damansara": {"latitude": 3.1500, "longitude": 101.6167},
    "kepong baru": {"latitude": 3.2167, "longitude": 101.6333},
    "kuala lumpur": {"latitude": 3.1390, "longitude": 101.6869},
    "kl": {"latitude": 3.1390, "longitude": 101.6869},
}

def get_coords(location_string):
    if not location_string:
        return None
    lower = location_string.lower()
    if lower in MALAYSIA_COORDS:
        return MALAYSIA_COORDS[lower]
    for key, coords in MALAYSIA_COORDS.items():
        if key in lower:
            return coords
    return None

print("📡 Fetching all reports...")
reports = list(db.collection("reports").stream())
print(f"Found {len(reports)} reports to process\n")

updated = 0
skipped_no_location = 0
skipped_already_has_coords = 0

for doc in reports:
    data = doc.to_dict()
    
    # Skip if already has coordinates
    if data.get("latitude") and data.get("longitude"):
        skipped_already_has_coords += 1
        continue
    
    location = data.get("location", "")
    
    # Skip if no location string at all
    if not location:
        skipped_no_location += 1
        continue
    
    coords = get_coords(location)
    if coords:
        doc.reference.update(coords)
        updated += 1
        print(f"✅ {doc.id[:8]}... '{location}' → {coords['latitude']}, {coords['longitude']}")
    else:
        # Use KL center as fallback so it still shows on map
        doc.reference.update({
            "latitude": 3.1390,
            "longitude": 101.6869
        })
        updated += 1
        print(f"📍 {doc.id[:8]}... '{location}' → KL center (fallback)")

print(f"\n{'='*50}")
print(f"✅ Updated with coordinates: {updated}")
print(f"⏭  Already had coordinates:  {skipped_already_has_coords}")
print(f"⏭  No location string:       {skipped_no_location}")
print(f"\nRefresh your dashboard map — markers should now appear!")