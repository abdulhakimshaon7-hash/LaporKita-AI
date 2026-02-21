# LaporKita AI 🇲🇾

> Community complaint management system powered by Gemini AI and Google Technologies

## 🚨 Problem

Community leaders in Malaysia receive hundreds of complaints via WhatsApp daily.
Manually sorting and prioritizing them takes 2-4 hours per day, causing critical
issues like broken street lights or flooding to get buried under routine complaints.

## 💡 Solution

LaporKita AI automatically:

1. **Receives** complaints via WhatsApp
2. **Analyzes** urgency and category using Gemini AI
3. **Clusters** related complaints to spot widespread issues
4. **Displays** everything on a real-time Flutter dashboard with Google Maps

## 🛠️ Google Technologies Used

| Technology                   | Purpose                               |
| ---------------------------- | ------------------------------------- |
| Gemini AI (Google AI Studio) | Complaint analysis, urgency detection |
| Firebase Firestore           | Real-time database                    |
| Firebase Cloud Functions     | Backend processing                    |
| Firebase Authentication      | Admin dashboard login                 |
| Firebase Hosting             | Dashboard deployment                  |
| Google Maps API              | Location visualization                |
| Flutter                      | Web dashboard                         |

## 🎯 SDG Alignment

- **SDG 11** – Sustainable Cities: Faster response to infrastructure issues
- **SDG 16** – Peace & Justice: Stronger citizen-community communication

## 👥 Team

| Name              | University        |
| ----------------- | ----------------- |
| Abdul Hakim Shaon | Monash University |

## Clustering Algorithm:

1. New report arrives and is analyzed by Gemini
2. Query Firestore for reports in the last 7 days with the same CATEGORY
3. For each existing report, calculate a "similarity score":
   - Count how many keywords match between the two reports
   - Similarity = (matching keywords) / (total unique keywords)
4. If similarity > 30% (0.3) AND same category → these reports are related
5. If we find 3+ related reports (including the new one):
   - Create a cluster document OR add to existing cluster
6. Generate an AI cluster summary using Gemini

CLUSTERING THRESHOLDS (you can adjust these):

- Time window: 7 days (complaints more than 7 days apart are probably separate events)
- Minimum reports for cluster: 3 (1-2 is just coincidence)
- Keyword similarity: 30% (low enough to catch related complaints, high enough to avoid false matches)

## 🏃 How to Run

_(You'll fill this in properly at the end — just leave it for now)_

```bash
# Coming soon
```

```

**Step 4:** Save the file (`Cmd + S`)

**Step 5:** That's it! You'll improve this README throughout the project. At submission time you'll fill in the "How to Run" section with real instructions.

---

## Why does it look like that?

The README uses **Markdown** — a simple formatting language. Here's the cheatsheet:
```

# Big heading

## Medium heading

**bold text**

- bullet point
  | Column 1 | Column 2 | ← table
