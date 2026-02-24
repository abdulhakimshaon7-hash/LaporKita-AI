# 🇲🇾 LaporKita AI
### AI-Powered Community Issue Reporting via WhatsApp

> **KitaHack 2026 Submission** · Team SoulNet · Monash University Malaysia

[![SDG 11](https://img.shields.io/badge/SDG-11%20Sustainable%20Cities-orange?style=flat-square)](https://sdgs.un.org/goals/goal11)
[![SDG 16](https://img.shields.io/badge/SDG-16%20Peace%20%26%20Justice-red?style=flat-square)](https://sdgs.un.org/goals/goal16)
[![Gemini AI](https://img.shields.io/badge/Google%20AI-Gemini-4285F4?style=flat-square&logo=google)](https://ai.google.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Firestore%20%2B%20Functions-FFCA28?style=flat-square&logo=firebase)](https://firebase.google.com)
[![Flutter](https://img.shields.io/badge/Flutter-Web%20Dashboard-54C5F8?style=flat-square&logo=flutter)](https://flutter.dev)

---

## 📌 Problem Statement

Communities across Malaysia face a critical gap in issue reporting infrastructure. When residents encounter problems — broken infrastructure, safety hazards, public disturbances — there is no simple, accessible channel to raise concerns and expect a timely, data-driven response.

Existing systems are either buried in government portals (requiring internet literacy and app installs), or they produce unstructured reports that authorities cannot efficiently act upon. As a result, **issues go unresolved, trust erodes, and community problems compound**.

LaporKita bridges this gap by meeting people where they already are — **WhatsApp** — and using **Gemini AI** to transform raw, messy community messages into structured, prioritised, and geographically clustered intelligence that local authorities and NGOs can act on immediately.

---

## 💡 Solution Overview

LaporKita is a **WhatsApp-first AI reporting system** that allows any community member to send a text message describing a local issue. The system automatically:

1. **Receives** the report via WhatsApp (Twilio integration)
2. **Understands** the message in **Bahasa Malaysia, English, or Manglish** — no fixed format required
3. **Analyses** it with Google Gemini AI — extracting urgency level, issue category, sentiment, and location keywords
4. **Stores** the structured data in Firebase Firestore in real-time
5. **Clusters** related reports geographically and thematically
6. **Visualises** everything on a Flutter web dashboard with Google Maps
7. **Responds** to the sender automatically in **the same language they wrote in** — Malay reply for Malay messages, English reply for English messages

Community managers, local councils, NGOs, and even the public can monitor the dashboard to see live community signals and take targeted action.

---

## 🎯 SDG Alignment

| SDG | Target | How LaporKita Contributes |
|-----|--------|--------------------------|
| **SDG 11** — Sustainable Cities & Communities | 11.3 — Inclusive urbanisation & participatory planning | LaporKita gives every resident a voice through WhatsApp, enabling participatory community monitoring without requiring tech literacy |
| **SDG 16** — Peace, Justice & Strong Institutions | 16.6 — Accountable & transparent institutions | Real-time, AI-structured reports create an auditable trail of community issues and institutional responses, driving accountability |

---

## 🏗️ System Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        COMMUNITY MEMBER                              │
│                    (Any WhatsApp User)                               │
└─────────────────────────────┬───────────────────────────────────────┘
                              │ Sends WhatsApp message
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                        TWILIO (WhatsApp Gateway)                     │
│  • Receives incoming messages from WhatsApp Business Sandbox        │
│  • Forwards payload (Body, From, MessageSid) via webhook POST       │
│  • Sends automated reply back to the user                           │
└─────────────────────────────┬───────────────────────────────────────┘
                              │ Webhook POST (HTTP)
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    FIREBASE CLOUD FUNCTIONS (Node.js)                │
│                                                                      │
│  ┌─────────────────┐    ┌──────────────────┐    ┌────────────────┐  │
│  │  Stage 1        │    │  Stage 2          │    │  Stage 3       │  │
│  │  receiveReport  │───▶│  analyseWithAI    │───▶│  clusterReport │  │
│  │                 │    │                   │    │                │  │
│  │ • Validate msg  │    │ • Call Gemini API  │    │ • Keyword match│  │
│  │ • Save to       │    │ • Extract urgency  │    │ • Find nearby  │  │
│  │   Firestore     │    │ • Category         │    │   clusters     │  │
│  │ • Trigger AI    │    │ • Sentiment        │    │ • Create or    │  │
│  │   pipeline      │    │ • Location hints   │    │   update       │  │
│  │                 │    │ • Update doc       │    │   cluster doc  │  │
│  └─────────────────┘    └──────────────────┘    └────────────────┘  │
└──────────────┬──────────────────────────────────┬───────────────────┘
               │ API Call                          │ Read/Write
               ▼                                   ▼
┌──────────────────────────────┐   ┌──────────────────────────────────┐
│   GOOGLE GEMINI AI           │   │   FIREBASE FIRESTORE              │
│   (Google AI Studio)         │   │                                  │
│                              │   │  Collections:                    │
│  Model: gemini-2.0-flash     │   │  • /reports  (individual msgs)   │
│                              │   │  • /clusters (grouped issues)    │
│  Analyses each report for:   │   │                                  │
│  • Urgency (Critical/High/   │   │  Each report document:           │
│    Medium/Low)               │   │  • message, sender, timestamp    │
│  • Category (Infrastructure/ │   │  • urgency, category, sentiment  │
│    Safety/Environment/etc.)  │   │  • keywords, location, cluster_id│
│  • Sentiment (Frustrated/    │   │  • status, ai_processed          │
│    Concerned/Neutral)        │   │                                  │
│  • Keywords & location hints │   └──────────────────────────────────┘
└──────────────────────────────┘                    │
                                                    │ Firestore SDK
                                                    │ (real-time stream)
                                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│                  FLUTTER WEB DASHBOARD                               │
│                                                                      │
│  ┌──────────────┐  ┌──────────────┐  ┌─────────────────────────┐   │
│  │   Overview   │  │   Reports    │  │   Map View               │   │
│  │   Screen     │  │   Feed       │  │   (Google Maps API)      │   │
│  │              │  │              │  │                          │   │
│  │ • Total      │  │ • Filter by  │  │ • Pins per cluster       │   │
│  │   reports    │  │   urgency    │  │ • Heatmap overlay        │   │
│  │ • Critical   │  │ • Filter by  │  │ • Click pin for details  │   │
│  │   alerts     │  │   category   │  │                          │   │
│  │ • Cluster    │  │ • Real-time  │  └─────────────────────────┘   │
│  │   count      │  │   updates    │                                  │
│  │ • Stats      │  │ • Take action│  ┌─────────────────────────┐   │
│  └──────────────┘  └──────────────┘  │   Clusters Screen        │   │
│                                      │ • Grouped issues         │   │
│  Users: Local councils, NGOs,        │ • Status tracking        │   │
│         community managers,          │ • Resolve / In Progress  │   │
│         general public               └─────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 🔄 Product Flow (End-to-End)

```
STEP 1 — USER SENDS REPORT
  Community member opens WhatsApp
  Sends message to LaporKita number, e.g.:
  "Longkang tersumbat dekat Jalan Utama, bau busuk sangat"
         │
         ▼
STEP 2 — TWILIO RECEIVES & FORWARDS
  Twilio WhatsApp Sandbox catches the message
  Sends HTTP POST webhook to Firebase Cloud Function endpoint
  Payload includes: message body, sender number, message ID
         │
         ▼
STEP 3 — CLOUD FUNCTION: SAVE TO FIRESTORE
  Function validates the incoming payload
  Creates a new document in /reports collection
  Fields: message, sender, timestamp, status="pending", ai_processed=false
  Triggers the AI analysis pipeline
         │
         ▼
STEP 4 — GEMINI AI ANALYSIS
  Cloud Function calls Gemini 2.0 Flash via Google AI Studio API
  Sends the raw message text with a structured prompt
  Gemini returns JSON with:
    • urgency:   "CRITICAL" | "HIGH" | "MEDIUM" | "LOW"
    • category:  "Infrastructure" | "Safety" | "Environment" | "Public Order" | etc.
    • sentiment: "Frustrated" | "Concerned" | "Neutral" | "Positive"
    • keywords:  ["drain", "blocked", "smell", "Jalan Utama"]
    • location:  "Jalan Utama" (extracted from text)
  Firestore document updated with AI results, ai_processed=true
         │
         ▼
STEP 5 — CLUSTERING
  Cloud Function checks existing clusters in /clusters collection
  Matches report by keyword overlap + location similarity
  If similar cluster exists → adds report to cluster, increments count
  If no match → creates new cluster document
  Report document updated with cluster_id
         │
         ▼
STEP 6 — AUTO RESPONSE TO USER (MULTILINGUAL)
  Gemini detects the language of the original message
  Twilio sends a WhatsApp reply in the SAME language:
  → Malay input:   "✅ Laporan anda telah diterima! Kami akan tindakan segera. Terima kasih."
  → English input: "✅ Your report has been received! We will take action shortly. Thank you."
  → Manglish:      Response matches the dominant language used
  User knows their report was received in a language they're comfortable with
         │
         ▼
STEP 7 — DASHBOARD UPDATE (REAL-TIME)
  Flutter dashboard (via Firestore StreamBuilder) auto-refreshes
  New report appears in Reports Feed instantly
  Stats cards update (total count, critical alerts)
  Cluster list updates with new or modified cluster
  Google Maps pin appears at detected location
         │
         ▼
STEP 8 — AUTHORITY ACTION
  Community manager / local council sees report on dashboard
  Reviews urgency level and cluster context
  Updates status: Pending → In Progress → Resolved
  Status reflected in Firestore and visible on dashboard
```

---

## 🛠️ Tech Stack & Google Technologies

| Technology | Role | Why We Chose It |
|-----------|------|----------------|
| **Google Gemini 2.0 Flash** (Google AI Studio) | Core AI engine — analyses every report for urgency, category, sentiment, keywords, and location; detects message language and generates replies in the same language (Malay, English, or Manglish) | Gemini's multilingual understanding and instruction-following made it ideal for Malaysia's bilingual communities. Its structured JSON output transforms unstructured WhatsApp text into actionable data, and the Flash model delivers the speed needed for near real-time analysis |
| **Firebase Cloud Functions** (Node.js) | Serverless backend — runs the entire processing pipeline from receiving webhooks to calling Gemini and updating Firestore | Eliminated the need for a dedicated server; scales automatically with report volume and integrates natively with Firestore |
| **Firebase Firestore** | Real-time NoSQL database — stores all reports and clusters | Real-time snapshot listeners allow the Flutter dashboard to update instantly without polling, essential for a live monitoring tool |
| **Flutter (Web)** | Front-end dashboard for community managers | Cross-platform with excellent Firebase SDKs; single codebase targets web today and mobile in the future |
| **Google Maps API** | Visualises report clusters geographically on the dashboard | Gives authorities spatial context — seeing that multiple reports cluster around one neighbourhood is more actionable than a plain list |
| **Twilio WhatsApp Sandbox** | WhatsApp messaging gateway — receives community reports and sends automated replies | WhatsApp has the highest penetration among Malaysian communities, making it the most accessible reporting channel requiring zero app installs |

---

## ⚙️ Setup & Installation

### Prerequisites

- Node.js v18+
- Flutter SDK (stable channel)
- Firebase CLI (`npm install -g firebase-tools`)
- FlutterFire CLI (`dart pub global activate flutterfire_cli`)
- A Firebase project (Blaze plan for Cloud Functions)
- Google AI Studio API key (Gemini)
- Twilio account with WhatsApp Sandbox configured

### 1. Clone the Repository

```bash
git clone https://github.com/abdulhakimshaon7-hash/LaporKita-AI.git
cd LaporKita-AI
```

### 2. Environment Variables

Create a `.env` file in the `/functions` directory. Use `.env.example` as a template:

```bash
cp functions/.env.example functions/.env
```

Fill in your values:

```env
GEMINI_API_KEY=your_google_ai_studio_api_key
TWILIO_ACCOUNT_SID=your_twilio_account_sid
TWILIO_AUTH_TOKEN=your_twilio_auth_token
TWILIO_WHATSAPP_NUMBER=whatsapp:+14155238886
```

> ⚠️ **Never commit your `.env` file.** It is listed in `.gitignore`.

### 3. Firebase Setup

```bash
# Login to Firebase
firebase login

# Set your Firebase project
firebase use --add
# Select your project: laporkita-ai

# Install Cloud Functions dependencies
cd functions
npm install
cd ..
```

### 4. Deploy Cloud Functions

```bash
firebase deploy --only functions
```

Copy the deployed function URL (e.g. `https://us-central1-laporkita-ai.cloudfunctions.net/receiveReport`) — you will need this for Twilio.

### 5. Configure Twilio Webhook

In your [Twilio Console](https://console.twilio.com):
- Go to **Messaging → Sandbox for WhatsApp**
- Set **"When a message comes in"** to your Cloud Function URL
- Method: `HTTP POST`

### 6. Flutter Dashboard Setup

```bash
cd app/laporkita_dashboard

# Install dependencies
flutter pub get

# Configure Firebase for Flutter
flutterfire configure
# Select your Firebase project when prompted
# Select Web platform

# Run locally
flutter run -d chrome
```

### 7. Create Admin Account

In Firebase Console → Authentication → Add user:
- Email: `admin@laporkita.com`
- Password: *(set your own)*

---

## 🧪 Testing

### Testing the WhatsApp Flow

1. Join the Twilio sandbox by sending `join <your-sandbox-keyword>` to `+1 415 523 8886` on WhatsApp
2. Send a test report message, for example:
   - `"Lampu jalan rosak dekat taman sri muda"`
   - `"Broken drain near school causing flooding"`
3. You should receive an automated acknowledgement reply within seconds
4. Open the Flutter dashboard — the report will appear in real-time

### User Testing Results

We tested LaporKita with both team members across different devices (iOS and Android) and friends from our university. Key findings:

- **Ease of use:** All testers found the WhatsApp reporting flow intuitive — no instructions were needed, they simply sent a message naturally as they would to a friend
- **Multilingual support:** Users can write in Bahasa Malaysia, English, or a mix of both (Manglish) — Gemini understands all inputs equally well and automatically replies in the same language the user wrote in, making the system feel natural and inclusive for all Malaysian communities
- **AI accuracy:** Gemini correctly identified urgency levels and categories for the majority of test messages, including mixed Malay/English (Manglish) inputs
- **Dashboard clarity:** Testers found the real-time dashboard updates satisfying — seeing their report appear live built immediate trust in the system
- **Key improvement from feedback:** Based on tester feedback, we added the automated WhatsApp acknowledgement reply so users know their report was received — this was the single most requested feature during testing

---

## 🚧 Technical Challenges & Solutions

### Challenge 1: Google Maps API Integration
Integrating Google Maps into the Flutter web dashboard was more complex than anticipated — particularly configuring the API key for the web platform, handling map initialisation timing with Firestore data loading, and positioning cluster pins accurately from location strings extracted by Gemini rather than precise GPS coordinates. We resolved this by implementing a geocoding step that converts location keywords into lat/lng coordinates before rendering map pins.

### Challenge 2: Gemini Model Selection
When integrating Google AI Studio, it was initially unclear which Gemini model to use — the API offered multiple variants with different capabilities and quotas. After testing several options, we settled on **`gemini-2.0-flash`**, which provided the right balance of speed (essential for near real-time report processing) and instruction-following quality to consistently return well-structured JSON from unstructured community messages.

### Challenge 3: Twilio Sandbox Rate Limits
The Twilio WhatsApp Sandbox limits free sessions to 5 active conversations at a time. During testing we hit this limit and had to wait for sessions to expire before continuing. We worked around this by batching our test messages, coordinating timing across the team, and using Firestore's direct write capability to simulate incoming reports during functional testing without going through the WhatsApp gateway every time.

---

## 📊 Impact & Scalability

### Current Impact (Prototype)
- Processes WhatsApp reports in under 3 seconds end-to-end
- AI analysis correctly classifies urgency and category for Malay, English, and Manglish inputs
- Real-time dashboard enables sub-minute response awareness for community managers
- Cluster detection automatically surfaces recurring neighbourhood issues

### Scalability Roadmap

| Phase | Timeline | Feature |
|-------|----------|---------|
| **Phase 1** | Now | Prototype — WhatsApp + Gemini + Flutter dashboard |
| **Phase 2** | 3 months | Upgrade to Twilio production account; onboard 3 pilot communities |
| **Phase 3** | 6 months | Add image/photo report support via WhatsApp media; Gemini Vision for visual issue detection |
| **Phase 4** | 12 months | Government API integration for direct issue ticketing to local councils (MBPJ, DBKL) |
| **Phase 5** | 18 months | Mobile app for community managers; predictive analytics for recurring issue hotspots |

Firebase and Cloud Functions scale automatically with zero infrastructure changes — the architecture is production-ready for thousands of concurrent reports from day one.

---

## 👥 Team

**Team SoulNet** · KitaHack 2026 · Monash University Malaysia

| Name | Role | University |
|------|------|-----------|
| Abdul Hakim Shaon | Backend, AI Integration (Gemini + Firebase Cloud Functions) | Monash University Malaysia |
| Sumaiya Rana Ridy | Frontend, Flutter Dashboard, UI/UX | Monash University Malaysia |

---

## 📄 License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

---

## 🙏 Acknowledgements

- [Google AI Studio](https://ai.google.dev) — Gemini API
- [Firebase](https://firebase.google.com) — Cloud Functions & Firestore
- [Flutter](https://flutter.dev) — Dashboard framework
- [Google Maps Platform](https://developers.google.com/maps) — Map visualisation
- [Twilio](https://twilio.com) — WhatsApp integration
- [GDGoC Malaysia](https://gdg.community.dev) — KitaHack 2026 organising team

---

*Built with ❤️ for KitaHack 2026 — using Google technology to make communities safer and more connected.*
