import glob
import re
import os

files = glob.glob("/mnt/d/microservices/docs/10-appendix/checklists/workflow/*.md")

summary = []

for f in files:
    with open(f, encoding="utf-8") as file:
        lines = file.readlines()
        
    total, done, p0, p1, p2, un = 0, 0, 0, 0, 0, 0
    
    for l in lines:
        m = re.match(r"^\s*-\s+\[([xX\s])\]", l)
        if m:
            total += 1
            if m.group(1).lower() == "x":
                done += 1
            else:
                if "P0" in l: p0 += 1
                elif "P1" in l: p1 += 1
                elif "P2" in l: p2 += 1
                else: un += 1
                
    filename = os.path.basename(f)
    pct = (done/total*100) if total > 0 else 0
    summary.append({
        "file": filename, "total": total, "done": done, "pct": pct, 
        "p0": p0, "p1": p1, "p2": p2, "un": un
    })

# Sort by completion percentage descending
summary.sort(key=lambda x: x["pct"], reverse=True)

md = []
md.append("# Implementation Review")
md.append("\nThis document provides an automated review of the completion status of all workflow checklists.")
md.append("\n## Overall Summary")

total_all = sum(s["total"] for s in summary)
done_all = sum(s["done"] for s in summary)
p0_all = sum(s["p0"] for s in summary)
p1_all = sum(s["p1"] for s in summary)
p2_all = sum(s["p2"] for s in summary)
un_all = sum(s["un"] for s in summary)
pct_all = (done_all/total_all*100) if total_all > 0 else 0

md.append(f"- **Overall Completion**: {done_all}/{total_all} ({pct_all:.1f}%)")
md.append(f"- **Pending Critical (P0)**: {p0_all}")
md.append(f"- **Pending High (P1)**: {p1_all}")
md.append(f"- **Pending Medium (P2)**: {p2_all}")
md.append(f"- **Other Pending Tasks**: {un_all}")

md.append("\n## Detailed Status by Flow")
md.append("| Flow Checklist | Progress | % Done | Pending P0 | Pending P1 | Pending P2 | Unclassified |")
md.append("|---|---|---|---|---|---|---|")

for s in summary:
    md.append(f"| [{s['file']}](./workflow/{s['file']}) | {s['done']}/{s['total']} | {s['pct']:.1f}% | {s['p0']} | {s['p1']} | {s['p2']} | {s['un']} |")

out_path = "/mnt/d/microservices/docs/10-appendix/checklists/implementation-review.md"
with open(out_path, "w", encoding="utf-8") as f:
    f.write("\n".join(md) + "\n")

print(f"Generated {out_path}")
