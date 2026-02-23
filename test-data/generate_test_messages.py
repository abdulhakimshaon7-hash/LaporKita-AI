# File: test-data/generate_test_messages.py
# Run this script to generate 100 realistic Malaysian complaint messages

import json
import csv
import random
import datetime

# ============================================================
# SECTION 1: RAW MATERIAL — all the building blocks we'll mix
# ============================================================

# Real Malaysian locations — mix of states and neighbourhoods
LOCATIONS = [
    "Taman Melati, Kuala Lumpur",
    "SS2, Petaling Jaya",
    "Jalan Ipoh, KL",
    "Puchong Jaya",
    "Taman Desa, KL",
    "Cheras Batu 9",
    "Kepong Baru",
    "Wangsa Maju",
    "Taman Connaught",
    "Sri Petaling",
    "Subang Jaya USJ",
    "Damansara Damai",
    "Setapak",
    "Ampang Jaya",
    "Bandar Tun Razak",
    "Bangsar South",
    "Segambut",
    "Batu Caves",
    "Gombak",
    "Shah Alam Seksyen 7",
    "Klang Jalan Meru",
    "Pandan Indah",
    "Bukit Jalil",
    "Cyberjaya",
    "Putrajaya Presint 9",
]

# Complaint templates grouped by CATEGORY and URGENCY
# Format: (message_template, category, urgency)
COMPLAINT_TEMPLATES = [

    # ===== INFRASTRUCTURE - CRITICAL =====
    ("Tiang letrik nak roboh dah!!! Berbahaya sangat, ada kanak-kanak main dekat sini 😱 {loc}", "infrastructure", "CRITICAL"),
    ("EMERGENCY - gas pipe burst at {loc}!! Bau gas kuat gila, semua orang keluar rumah dah", "infrastructure", "CRITICAL"),
    ("Banjir teruk masuk rumah di {loc}! Air dah sampai lutut, tolong hantar bantuan segera!!!", "infrastructure", "CRITICAL"),
    ("Jambatan {loc} crack besar dah nampak, takut roboh, please close asap", "infrastructure", "CRITICAL"),
    ("Tiang letrik tercabut pasal ribut tadi kt {loc}. Api nampak keluar! Bahaya!", "infrastructure", "CRITICAL"),

    # ===== INFRASTRUCTURE - HIGH =====
    ("Lampu jalan dah rosak 2 minggu dekat {loc}. Gelap gila mlm ni, takut crime berlaku", "infrastructure", "HIGH"),
    ("Paip air pecah kt depan rumah {loc}. Air membazir dah 3 hari, dah report tapi takde response", "infrastructure", "HIGH"),
    ("Street light kat {loc} semua mati. Dah 1 week, kawasan gelap sangat malam", "infrastructure", "HIGH"),
    ("Jalan raya berlubang besar dekat {loc} dah sebabkan 2 motosikal jatuh minggu ni", "infrastructure", "HIGH"),
    ("Lif blok A rosak dah 4 hari di {loc}. Orang tua & OKU tak boleh naik turun langsung", "infrastructure", "HIGH"),

    # ===== INFRASTRUCTURE - MEDIUM =====
    ("Longkang tersumbat kt {loc}, bau busuk dan nyamuk banyak. Dah lama ni", "infrastructure", "MEDIUM"),
    ("Road sign kt {loc} dah terbalik, confuse pemandu. Boleh betulkan?", "infrastructure", "MEDIUM"),
    ("Bench kat taman {loc} dah patah, berbahaya untuk duduk. Tolong repair", "infrastructure", "MEDIUM"),
    ("Tandas awam kat {loc} air tak jalan dah seminggu. Sangat kotor dan bau", "infrastructure", "MEDIUM"),
    ("Drain cover hilang kt {loc}. Lubang besar, bahaya kalau orang jalan malam", "infrastructure", "MEDIUM"),

    # ===== INFRASTRUCTURE - LOW =====
    ("Cat dinding community hall {loc} dah pudar dan comot sikit. Boleh cat balik?", "infrastructure", "LOW"),
    ("Signboard taman {loc} dah fade, susah nak baca. Perlu update", "infrastructure", "LOW"),
    ("Kerusi kat bus stop {loc} dah longgar sikit. Mintak repair bila ada masa", "infrastructure", "LOW"),
    ("Pokok renek kt {loc} dah panjang masuk jalan sikit. Boleh trim?", "infrastructure", "LOW"),
    ("Playground {loc} swing dah berkarat sikit. Tak urgent tapi boleh tengok?", "infrastructure", "LOW"),

    # ===== WASTE - CRITICAL =====
    ("Ada orang buang bahan kimia haram kt {loc}!! Bau sangat kuat dan warna pelik. BAHAYA!", "waste", "CRITICAL"),
    ("Sampah medical waste dibuang tepi jalan kt {loc}. Nampak jarum dan glove! Berbahaya!", "waste", "CRITICAL"),

    # ===== WASTE - HIGH =====
    ("Tong sampah komuniti {loc} tak dikutip dah 10 hari! Melimpah dah, bau busuk, tikus ada", "waste", "HIGH"),
    ("Illegal dumping besar-besaran kt hutan simpan {loc}. Ada TV, tilam, segala. Tolong ambik", "waste", "HIGH"),
    ("Sampah bertimbun kt depan sekolah {loc}. Budak-budak berjalan kat situ. Tak selamat", "waste", "HIGH"),
    ("Someone dumping rubbish every night at {loc}. CCTV takleh capture, dah 2 minggu ni", "waste", "HIGH"),

    # ===== WASTE - MEDIUM =====
    ("Orang buang sampah kt taman permainan {loc} walaupun ada tong sampah sebelah je 🤦", "waste", "MEDIUM"),
    ("Sampah berterabur kt {loc} selepas weekend market. Boleh hantar cleaner?", "waste", "MEDIUM"),
    ("Tong sampah kat {loc} dah penuh dan tak ada replacement. Sampah melimpah", "waste", "MEDIUM"),
    ("Ada bekas makanan seminggu kt lorong {loc}. Bau je. Siapa yang patut kutip ni?", "waste", "MEDIUM"),

    # ===== WASTE - LOW =====
    ("Sikit je sampah kt taman {loc} tapi bersepah. Boleh sweeping sekejap?", "waste", "LOW"),
    ("Daun kering berterabur kt {loc}, buat jalan nampak tak kemas. Mintak bancuh", "waste", "LOW"),

    # ===== SAFETY - CRITICAL =====
    ("ADA ORANG MENCURI KERETA KT {loc} SEKARANG!!! Tolong hantar polis segera!!!!", "safety", "CRITICAL"),
    ("Api kecil nampak kt belakang kedai {loc}! Dah call bomba tapi nak report sini jugak", "safety", "CRITICAL"),
    ("Orang suspicious bawak senjata nampak kt {loc}!! Tolong polis sekarang!", "safety", "CRITICAL"),

    # ===== SAFETY - HIGH =====
    ("Anjing liar garang serang orang kt {loc}! 2 orang dah kena gigit minggu ni. Bahaya!", "safety", "HIGH"),
    ("Rempit aktiviti malam2 kt {loc} setiap malam. Dah kacau penduduk, accident pun ada", "safety", "HIGH"),
    ("CCTV kt {loc} nampak dah rosak/tutup. Kawasan jadi gelap dan rasa tak selamat", "safety", "HIGH"),
    ("Pencuri masuk kereta kt parking {loc} semalam. Cermin pecah, radio hilang", "safety", "HIGH"),
    ("Budak-budak main kt construction site {loc} yang tak berpagar. Bahaya sangat!", "safety", "HIGH"),

    # ===== SAFETY - MEDIUM =====
    ("Jalan gelap di {loc} malam - rasa tak selamat jalan kaki. Boleh pasang lampu?", "safety", "MEDIUM"),
    ("Gate kawasan {loc} selalu tak kunci malam. Guard pun kadang tak ada. Rasa risau", "safety", "MEDIUM"),
    ("Orang dok lepak suspicious kt {loc} setiap malam. Tak buat apa tapi risau juga", "safety", "MEDIUM"),
    ("Motor dipark block entrance {loc}. Kalau emergency susah nak masuk. Tolong act", "safety", "MEDIUM"),

    # ===== SAFETY - LOW =====
    ("Speed bump kt {loc} dah haus, driver bawak laju je sekarang. Boleh repaint?", "safety", "LOW"),
    ("Mirror pandang kt simpang {loc} sudah kabur. Boleh replace?", "safety", "LOW"),

    # ===== NOISE - HIGH =====
    ("Renovation haram 7 pagi di {loc}! Bunyi drill kuat gila. Semua tak boleh tido", "noise", "HIGH"),
    ("Karaoke sampai 2am kt {loc} setiap hujung minggu! Anak-anak tak boleh tido. Dah report banyak kali", "noise", "HIGH"),
    ("Factory baru kt {loc} operasi 24 jam, bunyi mesin buat kepala pening. Tak boleh tahan dah", "noise", "HIGH"),

    # ===== NOISE - MEDIUM =====
    ("Jiran sebelah main muzik kuat setiap malam kt {loc}. Boleh tolong tegur?", "noise", "MEDIUM"),
    ("Anjing jiran menggonggong sepanjang malam kt {loc}. Dah 1 bulan, tak boleh tido", "noise", "MEDIUM"),
    ("Lorry besar lalu kt {loc} buat bunyi kuat malam2. Jalan tu supposed residential je", "noise", "MEDIUM"),

    # ===== NOISE - LOW =====
    ("Budak-budak main basketball malam2 kt court {loc}. Sikit bising. Boleh letak signage?", "noise", "LOW"),
    ("Speaker masjid {loc} nampak rosak, bunyi distorted. Boleh check?", "noise", "LOW"),

    # ===== ENVIRONMENT =====
    ("Sungai kt {loc} bertukar warna coklat pekat! Ada kilang buang habuan kot. Urgent!", "environment", "HIGH"),
    ("Asap hitam tebal keluar dari kilang haram kt {loc}. Budak2 batuk-batuk dah. Tolong!", "environment", "CRITICAL"),
    ("Pokok besar kt {loc} dah condong ke jalan. Ribut semalam buat dia hampir tumbang. Bahaya!", "environment", "HIGH"),
    ("Air longkang {loc} berbau mcm chemical. Ikan2 pun dah mati. Ada pencemaran", "environment", "HIGH"),
    ("Tanah runtuh kecil kt cerun {loc} selepas hujan lebat. Jalan dah partially block", "environment", "HIGH"),
    ("Habuk banyak dari tapak bina {loc} masuk rumah2 penduduk. Dah risau kesihatan", "environment", "MEDIUM"),
    ("Pokok-pokok kt taman {loc} dah lama tak dipotong. Nampak tidak kemas", "environment", "LOW"),

    # ===== COMMUNITY FACILITIES =====
    ("Wifi percuma kt community centre {loc} tak jalan dah 2 minggu. Pelajar susah nak study", "facilities", "MEDIUM"),
    ("Dewan olahraga {loc} aircond semua rosak. Panas gila, tak boleh guna", "facilities", "MEDIUM"),
    ("Library community {loc} dah closed 3 bulan tapi takde notice. Nak guna bila?", "facilities", "MEDIUM"),
    ("Court badminton {loc} lampu separuh mati. Tak boleh main malam", "facilities", "MEDIUM"),
    ("Swimming pool {loc} air nampak hijau! Dah berapa lama tak tukar air? Tak selamat berenang", "facilities", "HIGH"),
    ("Kiosk bayaran bil kt {loc} rosak. Orang tua tak tahu bayar online, susah dorang", "facilities", "MEDIUM"),
    ("Surau taman {loc} paip wudhu tersumbat. Dah 3 hari, solat pun susah", "facilities", "HIGH"),

    # ===== MIXED LANGUAGE & COLLOQUIAL (more realistic!) =====
    ("Weh drain dekat {loc} mmg dah overflow time hujan je. Tiap kali hujan banjir. Fix la pls", "infrastructure", "HIGH"),
    ("eh jiran i buang sampah kt longkang {loc} je. buat org lain kena banjir. report lah", "waste", "MEDIUM"),
    ("lif rosak lagi kt {loc}!! 3rd time this month. maintenance mcm tak buat kerja je", "infrastructure", "HIGH"),
    ("tolong la lampu taman {loc} dah off dari semalam. anak i takut jalan mlm", "infrastructure", "MEDIUM"),
    ("Guard parking {loc} kasar dgn penduduk. Dah 2 orang complain, takde action pun", "safety", "MEDIUM"),
    ("banjir kilat teruk gila tadi kt {loc}. kereta i dah lemas 😭 tolong la buat sesuatu", "infrastructure", "HIGH"),
    ("ok so the playground at {loc} - the slide is broken and sharp edges nampak. children playing there!", "safety", "HIGH"),
    ("Can someone fix the road at {loc}? Big pothole near the junction, already 3 accidents this month", "infrastructure", "HIGH"),
    ("Hello, I would like to report that the rubbish at {loc} has not been collected for 2 weeks already. Thank you", "waste", "HIGH"),
    ("Attention: Flooding issue at {loc} getting worse every rain. Need drainage upgrade urgently.", "infrastructure", "HIGH"),
    ("噪音投诉：{loc} 的工厂夜间很吵。Could someone look into this?", "noise", "MEDIUM"),  # Mixed Chinese-English
    ("Bising gila la construction kt {loc}. 6am dah start drill. Sabtu pun sama!! 😤😤", "noise", "HIGH"),
    ("saya nak report pasal jalan kt {loc} yang berlubang besar. dah lama sangat dah ni. terima kasih", "infrastructure", "MEDIUM"),

    # ===== WITH TYPOS (realistic!) =====
    ("lampu jlan kt {loc} dah rosak 1 minggu! gelpak sangat mlam ni", "infrastructure", "MEDIUM"),  # typos
    ("smapah tak kuti dekat {loc} dah lama. bau busuk gle", "waste", "MEDIUM"),  # typos
    ("ada kecurian kt kawasn {loc} tadi, tolong polis", "safety", "HIGH"),  # typos
    ("bnajir kecil kt dpn umah {loc} pasal longkang trsumbat", "infrastructure", "MEDIUM"),  # typos

    # ===== WITH EMOJI =====
    ("🚨🚨 BAHAYA! Tiang elektrik nak tumbang kt {loc}! Tolong cepat!! 🚨🚨", "infrastructure", "CRITICAL"),
    ("😡 Sampah kt {loc} dah 2 minggu tak kutip. Bau busuk masuk rumah. TOLONGLAH", "waste", "HIGH"),
    ("💧💧 paip pecah kt {loc} dah 2 hari. Air membazir sangat. tolongg fix", "infrastructure", "HIGH"),
    ("🐕 anjing liar kt {loc} garang, dah gigit jiran I semalam. tolong tangkap", "safety", "HIGH"),
    ("😰 takut nak jalan malam kt {loc}. gelap sangat, takde lampu. pls fix", "infrastructure", "MEDIUM"),
]

# ============================================================
# SECTION 2: GENERATOR FUNCTION
# ============================================================

def generate_messages(count=100):
    """
    Generate `count` unique complaint messages.
    We'll pull from templates and fill in realistic locations.
    """
    messages = []
    
    # Shuffle templates so we get variety
    shuffled = random.sample(COMPLAINT_TEMPLATES, min(len(COMPLAINT_TEMPLATES), count))
    
    # If we need more than available templates, repeat with different locations
    while len(shuffled) < count:
        shuffled += random.sample(COMPLAINT_TEMPLATES, min(len(COMPLAINT_TEMPLATES), count - len(shuffled)))
    
    for i, (template, category, urgency) in enumerate(shuffled[:count]):
        # Fill in a random location from our list
        location = random.choice(LOCATIONS)
        message_text = template.format(loc=location)
        
        # Generate a fake WhatsApp sender number (Malaysian format)
        # Real Malaysian numbers: +601X-XXXXXXXX
        prefix = random.choice(["011", "012", "013", "014", "016", "017", "018", "019"])
        number_suffix = str(random.randint(1000000, 9999999))
        sender = f"whatsapp:+60{prefix[1:]}{number_suffix}"
        
        # Generate a timestamp spread over the last 14 days
        days_ago = random.randint(0, 13)
        hours_ago = random.randint(0, 23)
        timestamp = datetime.datetime.now() - datetime.timedelta(days=days_ago, hours=hours_ago)
        
        messages.append({
            "id": i + 1,
            "message": message_text,
            "sender": sender,
            "timestamp": timestamp.isoformat(),
            "expected_category": category,   # Ground truth — we'll use this to check AI accuracy
            "expected_urgency": urgency,      # Ground truth — compare against AI result
        })
    
    return messages

# ============================================================
# SECTION 3: SAVE TO FILES
# ============================================================

def save_messages(messages):
    """Save messages to both JSON and CSV formats."""
    
    # --- Save as JSON (used by Node.js batch processor in 6.2) ---
    json_path = "test_messages.json"
    with open(json_path, "w", encoding="utf-8") as f:
        json.dump(messages, f, ensure_ascii=False, indent=2)
        # ensure_ascii=False means Malaysian/Chinese chars are saved properly
    print(f"✅ Saved {len(messages)} messages to {json_path}")
    
    # --- Save as CSV (easy to open in Excel for manual review) ---
    csv_path = "test_messages.csv"
    with open(csv_path, "w", newline="", encoding="utf-8") as f:
        fieldnames = ["id", "message", "sender", "timestamp", "expected_category", "expected_urgency"]
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(messages)
    print(f"✅ Saved {len(messages)} messages to {csv_path}")
    
    return json_path, csv_path

# ============================================================
# SECTION 4: PREVIEW — show 5 sample messages
# ============================================================

def preview_messages(messages, count=5):
    """Print a preview of the first N messages so you can sanity-check."""
    print(f"\n{'='*60}")
    print(f"PREVIEW: First {count} generated messages")
    print(f"{'='*60}")
    for msg in messages[:count]:
        print(f"\n[{msg['id']}] Expected: {msg['expected_urgency']} / {msg['expected_category']}")
        print(f"     Sender: {msg['sender']}")
        print(f"     Message: {msg['message'][:100]}...")  # Trim if long
    print(f"\n{'='*60}")
    
    # Also print urgency distribution so you can see the spread
    urgency_counts = {}
    category_counts = {}
    for msg in messages:
        u = msg["expected_urgency"]
        c = msg["expected_category"]
        urgency_counts[u] = urgency_counts.get(u, 0) + 1
        category_counts[c] = category_counts.get(c, 0) + 1
    
    print("\nURGENCY DISTRIBUTION:")
    for level in ["CRITICAL", "HIGH", "MEDIUM", "LOW"]:
        count_val = urgency_counts.get(level, 0)
        bar = "█" * count_val
        print(f"  {level:10s}: {count_val:3d} {bar}")
    
    print("\nCATEGORY DISTRIBUTION:")
    for cat, cnt in sorted(category_counts.items(), key=lambda x: -x[1]):
        bar = "█" * cnt
        print(f"  {cat:15s}: {cnt:3d} {bar}")

# ============================================================
# SECTION 5: MAIN — run everything
# ============================================================

if __name__ == "__main__":
    print("🇲🇾 LaporKita-AI — Test Message Generator")
    print("Generating 100 realistic Malaysian complaint messages...\n")
    
    random.seed(42)  # Fixed seed = same results every run (good for reproducibility)
    
    messages = generate_messages(100)
    preview_messages(messages, count=5)
    json_path, csv_path = save_messages(messages)
    
    print(f"\n🎉 Done! Files created:")
    print(f"   📄 {json_path}  (use this in 6.2 batch processor)")
    print(f"   📊 {csv_path}   (open in Excel/Numbers to review)")
    print(f"\nNext step → Run Stage 6.2 batch processor!")