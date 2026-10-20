# Evaluation definitions and saved results

Source: `test-data/accuracy_results.csv`, 94 saved test records with expected and predicted labels. The labels originate from project test data, not an independently labeled field dataset. Results below are recomputed from the CSV columns, without invoking Gemini or Firestore.

| Measure | Calculation | Result |
| --- | --- | --- |
| Category exact agreement | 77 / 94 | 81.9% |
| Urgency exact agreement | 74 / 94 | 78.7% |
| Urgency partial-credit score | (74 + 0.5 × 3) / 94 | 80.3% |

Three urgency mismatches are HIGH/CRITICAL swaps. Each receives 0.5 points in `test-data/validate_accuracy.py`. The 80.3% score is therefore not exact accuracy, critical-case recall, or a measured improvement over manual work. Its historical display formula truncated the count to one; the saved CSV contains three partial cases. Use 78.7% when reporting exact urgency agreement on a CV.

There are 17 other urgency mismatches, including two expected HIGH cases predicted MEDIUM. The previous claim that urgent cases were never downgraded to MEDIUM is unsupported. Category agreement is not overall correctness across all output fields. These aggregate scores do not establish subgroup fairness, safety, production readiness, or performance on unseen real-world reports.

`real_metric.txt` is a historical console capture and is retained with a correction notice. Some other artifacts count 100 processed reports; that is a different population from these 94 evaluated records and cannot replace the denominator. Missing processing-time values do not support latency claims. Before/after productivity, cost and safety claims are not established by this CSV. Per-category estimates in chart-generation code are illustrative, not measured subgroup results.

To reproduce the reported CV figures using Python's standard library:

```python
import csv
from pathlib import Path
rows = list(csv.DictReader(Path("test-data/accuracy_results.csv").open()))
n = len(rows)
category = sum(r["ai_category"] == r["expected_category"] for r in rows)
urgency = sum(r["ai_urgency"] == r["expected_urgency"] for r in rows)
partial = sum(r["ai_urgency"] != r["expected_urgency"] and
              {r["ai_urgency"], r["expected_urgency"]} == {"HIGH", "CRITICAL"}
              for r in rows)
print(n, category, urgency, partial)  # 94, 77, 74, 3
print(f"Category exact: {category/n:.1%}")
print(f"Urgency exact: {urgency/n:.1%}")
print(f"Urgency partial credit: {(urgency + 0.5*partial)/n:.1%}")
```
