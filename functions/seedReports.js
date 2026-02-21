// File: functions/seedReports.js
// Test reports for The Grand Subang SS13, Subang Jaya
// Run with: node seedReports.js

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

const testReports = [

  // ─────────────────────────────────────────────
  // LIFT / ELEVATOR (Tower 1 & Tower 2) — cluster group
  // ─────────────────────────────────────────────
  {
    message: "Lif Tower 1 rosak dah 3 hari. Orang tua dan ibu mengandung susah sangat nak naik turun. Tolong baiki segera!",
    sender: "whatsapp:+60111111111",
    urgency: "HIGH",
    category: "infrastructure",
    sentiment: "distressed",
    keywords: ["lif", "rosak", "tower 1", "orang tua", "segera"],
    location: "Tower 1",
    summary: "Elevator at Tower 1 broken for 3 days affecting elderly and pregnant residents",
    action_suggested: "Contact elevator maintenance for urgent repair at Tower 1",
    status: "pending",
    cluster_id: "",
  },
  {
    message: "Lift at Tower 1 still not working. Already 3 days. Residents have to climb stairs. Very inconvenient especially for elderly.",
    sender: "whatsapp:+60122222222",
    urgency: "HIGH",
    category: "infrastructure",
    sentiment: "frustrated",
    keywords: ["lift", "tower 1", "stairs", "elderly", "broken"],
    location: "Tower 1",
    summary: "Tower 1 lift broken for 3 days forcing residents to use stairs",
    action_suggested: "Urgently repair Tower 1 elevator",
    status: "pending",
    cluster_id: "",
  },
  {
    message: "Lif Tower 2 pun dah rosak sekarang. Dua lif rosak serentak. Ini tidak boleh jadi. Sila ambil tindakan segera.",
    sender: "whatsapp:+60133333333",
    urgency: "HIGH",
    category: "infrastructure",
    sentiment: "distressed",
    keywords: ["lif", "rosak", "tower 2", "segera", "tindakan"],
    location: "Tower 2",
    summary: "Tower 2 elevator also broken, both towers now without working lifts",
    action_suggested: "Emergency repair needed for both Tower 1 and Tower 2 elevators",
    status: "pending",
    cluster_id: "",
  },

  // ─────────────────────────────────────────────
  // NOISE COMPLAINTS — cluster group
  // ─────────────────────────────────────────────
  {
    message: "Jiran kat tingkat 12 Tower 1 buat bising sampai pukul 3 pagi. Dah tak boleh tidur. Tolong ambil tindakan.",
    sender: "whatsapp:+60144444444",
    urgency: "MEDIUM",
    category: "general",
    sentiment: "frustrated",
    keywords: ["bising", "jiran", "tower 1", "malam", "tidur"],
    location: "Tower 1",
    summary: "Neighbour at Tower 1 level 12 making noise until 3am disturbing sleep",
    action_suggested: "Issue noise complaint warning to unit at Tower 1 level 12",
    status: "pending",
    cluster_id: "",
  },
  {
    message: "Neighbour in Tower 1 playing loud music every night. Cannot sleep. This has been going on for 2 weeks already.",
    sender: "whatsapp:+60155555555",
    urgency: "MEDIUM",
    category: "general",
    sentiment: "frustrated",
    keywords: ["noise", "music", "tower 1", "night", "sleep"],
    location: "Tower 1",
    summary: "Resident in Tower 1 playing loud music nightly for 2 weeks disturbing neighbours",
    action_suggested: "Issue formal noise complaint notice to the unit",
    status: "pending",
    cluster_id: "",
  },
  {
    message: "Bising sangat dari unit atas kat Tower 2. Budak-budak berlari dan melompat sampai malam. Dah 2 minggu.",
    sender: "whatsapp:+60166666666",
    urgency: "MEDIUM",
    category: "general",
    sentiment: "frustrated",
    keywords: ["bising", "tower 2", "malam", "jiran", "minggu"],
    location: "Tower 2",
    summary: "Excessive noise from upstairs unit in Tower 2 with children running at night for 2 weeks",
    action_suggested: "Send noise complaint notice to unit above in Tower 2",
    status: "pending",
    cluster_id: "",
  },

  // ─────────────────────────────────────────────
  // CLEANLINESS / RUBBISH — cluster group
  // ─────────────────────────────────────────────
  {
    message: "Kawasan tong sampah basement Tower 1 sangat kotor dan berbau busuk. Sampah melimpah keluar. Dah 4 hari tak dikosongkan.",
    sender: "whatsapp:+60177777777",
    urgency: "MEDIUM",
    category: "environment",
    sentiment: "frustrated",
    keywords: ["sampah", "kotor", "busuk", "basement", "tower 1"],
    location: "Basement Parking",
    summary: "Rubbish bin area at Tower 1 basement overflowing and smelly for 4 days",
    action_suggested: "Arrange urgent rubbish collection and clean bin area at basement",
    status: "pending",
    cluster_id: "",
  },
  {
    message: "Rubbish bin area at basement is overflowing again. Very bad smell reaching the parking area. Please empty it.",
    sender: "whatsapp:+60188888888",
    urgency: "MEDIUM",
    category: "environment",
    sentiment: "frustrated",
    keywords: ["rubbish", "overflow", "basement", "smell", "parking"],
    location: "Basement Parking",
    summary: "Overflowing rubbish bins at basement causing bad smell in parking area",
    action_suggested: "Empty rubbish bins at basement and increase collection frequency",
    status: "pending",
    cluster_id: "",
  },
  {
    message: "Koridor Tower 2 tingkat 8 kotor sangat. Ada sampah berterabur dan habuk tebal. Dah lama tak dibersihkan.",
    sender: "whatsapp:+60199999999",
    urgency: "LOW",
    category: "environment",
    sentiment: "frustrated",
    keywords: ["koridor", "kotor", "sampah", "tower 2", "habuk"],
    location: "Tower 2",
    summary: "Corridor at Tower 2 level 8 dirty with scattered rubbish and dust",
    action_suggested: "Schedule corridor cleaning at Tower 2 level 8",
    status: "pending",
    cluster_id: "",
  },

  // ─────────────────────────────────────────────
  // WATER / DRAIN ISSUES — cluster group
  // ─────────────────────────────────────────────
  {
    message: "Paip air kat koridor Tower 1 tingkat 5 bocor. Air menitik dan lantai licin. Bahaya boleh terjatuh.",
    sender: "whatsapp:+60100000001",
    urgency: "HIGH",
    category: "infrastructure",
    sentiment: "distressed",
    keywords: ["paip", "bocor", "tower 1", "licin", "bahaya"],
    location: "Tower 1",
    summary: "Leaking pipe at Tower 1 level 5 corridor causing slippery floor and safety hazard",
    action_suggested: "Repair leaking pipe at Tower 1 level 5 immediately",
    status: "pending",
    cluster_id: "",
  },
  {
    message: "Water leaking from ceiling at Tower 2 lobby. Floor is wet and slippery. Someone might fall and get hurt.",
    sender: "whatsapp:+60100000002",
    urgency: "HIGH",
    category: "infrastructure",
    sentiment: "distressed",
    keywords: ["water", "leaking", "tower 2", "lobby", "slippery"],
    location: "Tower 2",
    summary: "Water leaking from ceiling at Tower 2 lobby creating slip hazard",
    action_suggested: "Fix ceiling leak at Tower 2 lobby urgently",
    status: "pending",
    cluster_id: "",
  },
  {
    message: "Longkang kat kawasan swimming pool tersumbat. Air bertakung dan ada bau busuk. Nyamuk pun banyak dah.",
    sender: "whatsapp:+60100000003",
    urgency: "MEDIUM",
    category: "infrastructure",
    sentiment: "frustrated",
    keywords: ["longkang", "tersumbat", "swimming pool", "bertakung", "nyamuk"],
    location: "Swimming Pool",
    summary: "Drain near swimming pool clogged causing water pooling and mosquito breeding",
    action_suggested: "Clear drain at swimming pool area and apply mosquito fogging",
    status: "pending",
    cluster_id: "",
  },

  // ─────────────────────────────────────────────
  // FACILITIES — individual complaints
  // ─────────────────────────────────────────────
  {
    message: "Gym equipment rosak — treadmill dan dumbbell bench dah patah. Dah 2 minggu tak dibaiki. Bila nak fix?",
    sender: "whatsapp:+60100000004",
    urgency: "LOW",
    category: "infrastructure",
    sentiment: "frustrated",
    keywords: ["gym", "equipment", "rosak", "treadmill", "minggu"],
    location: "Gym",
    summary: "Gym treadmill and dumbbell bench broken for 2 weeks without repair",
    action_suggested: "Arrange gym equipment repair or replacement",
    status: "pending",
    cluster_id: "",
  },
  {
    message: "Surau kat Tower 1 aircond rosak. Panas sangat masa solat. Dah lapor minggu lepas tapi tiada tindakan lagi.",
    sender: "whatsapp:+60100000005",
    urgency: "MEDIUM",
    category: "infrastructure",
    sentiment: "frustrated",
    keywords: ["surau", "aircond", "rosak", "tower 1", "panas"],
    location: "Tower 1",
    summary: "Surau air conditioning broken at Tower 1 making prayer space uncomfortably hot",
    action_suggested: "Repair or replace surau air conditioning unit",
    status: "pending",
    cluster_id: "",
  },
  {
    message: "Swimming pool water looks very green and dirty. Has not been cleaned for weeks. Not safe to swim.",
    sender: "whatsapp:+60100000006",
    urgency: "MEDIUM",
    category: "health",
    sentiment: "frustrated",
    keywords: ["swimming pool", "dirty", "green", "unsafe", "cleaning"],
    location: "Swimming Pool",
    summary: "Swimming pool water is green and dirty indicating lack of maintenance",
    action_suggested: "Clean and treat swimming pool water immediately",
    status: "pending",
    cluster_id: "",
  },
  {
    message: "Lampu kat playground dah rosak. Budak-budak takut nak main malam sebab gelap sangat. Tolong baiki.",
    sender: "whatsapp:+60100000007",
    urgency: "MEDIUM",
    category: "infrastructure",
    sentiment: "distressed",
    keywords: ["lampu", "playground", "rosak", "gelap", "malam"],
    location: "Playground",
    summary: "Playground lights broken making it dark and unsafe for children at night",
    action_suggested: "Replace playground lighting urgently",
    status: "pending",
    cluster_id: "",
  },
  {
    message: "Guard house barrier arm rosak. Kereta orang luar boleh masuk tanpa izin. Keselamatan terjejas.",
    sender: "whatsapp:+60100000008",
    urgency: "HIGH",
    category: "safety",
    sentiment: "distressed",
    keywords: ["guard house", "barrier", "rosak", "keselamatan", "kereta"],
    location: "Guard House",
    summary: "Guard house barrier broken allowing unauthorised vehicles to enter compound",
    action_suggested: "Repair barrier arm at guard house immediately for security",
    status: "pending",
    cluster_id: "",
  },
  {
    message: "Basement parking lighting very dim at level B2. Very dark and feel unsafe especially late at night.",
    sender: "whatsapp:+60100000009",
    urgency: "HIGH",
    category: "safety",
    sentiment: "distressed",
    keywords: ["basement", "parking", "dark", "unsafe", "lighting"],
    location: "Basement Parking",
    summary: "Basement parking B2 lighting too dim creating safety concerns at night",
    action_suggested: "Replace or add lighting at basement parking B2",
    status: "pending",
    cluster_id: "",
  },
];

async function seedDatabase() {
  console.log(`🚀 Adding ${testReports.length} test reports for The Grand Subang SS13...`);
  console.log('─────────────────────────────────────────');

  for (const report of testReports) {
    const docRef = await db.collection('reports').add({
      ...report,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      analyzed_at: admin.firestore.FieldValue.serverTimestamp(),
    });
    console.log(`✅ [${report.location}] "${report.message.substring(0, 50)}..."`);
  }

  console.log('─────────────────────────────────────────');
  console.log(`🎉 Done! ${testReports.length} reports added.`);
  console.log('Next steps:');
  console.log('  1. Run analyzeAllPending to process with Gemini');
  console.log('  2. Run runClustering to detect clusters');
  process.exit(0);
}

seedDatabase().catch(err => {
  console.error('❌ Error:', err);
  process.exit(1);
});