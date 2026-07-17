#!/usr/bin/env python3
"""Prepares distillation inputs from `corpus.jsonl`: holdout split, stats, chunks"""

import json
import re
import statistics
import sys
from collections import Counter
from pathlib import Path

CHUNKS = 12
DIR = Path(__file__).resolve().parent
OUT = DIR / "data"
OUT.mkdir(exist_ok=True)

# Load and dedupe by (kind, id) since the two comment kinds use independent id
# sequences, oldest first
records = {
    (r["kind"], r["id"]): r for line in (DIR / "corpus.jsonl").open() if (r := json.loads(line))
}
records = sorted(records.values(), key=lambda r: r["created_at"])
pr = lambda r: (r["repo"], int(re.search(r"/pull/(\d+)", r["url"]).group(1)))

# Hold out the 20 most recently reviewed PRs with >=2 top-level comments, for
# validating /art-critic against what I actually said
latest = {}
counts = Counter()
for r in records:
    if not r["is_reply"]:
        latest[k := pr(r)] = r["created_at"]
        counts[k] += 1
holdout = sorted((k for k in latest if counts[k] >= 2), key=lambda k: latest[k])[-20:]
(OUT / "holdout.json").write_text(
    json.dumps([{"pr": n, "repo": repo} for repo, n in holdout], indent=2)
)
# Hoisted so the comprehension doesn't rebuild the set once per record
holdout_set = set(holdout)
train = [r for r in records if pr(r) not in holdout_set]
top = [r for r in train if not r["is_reply"]]
if not top:
    sys.exit("Corpus has no top-level comments to distill")

# Hard stats to ground voice.md and calibration.md in data rather than vibes.
# Exclude holdout PRs so the numbers can't leak into validation
first_words = Counter(s[0].lower().rstrip(":,") for r in top if (s := r["body"].split(None, 1)))
lengths = sorted(len(r["body"]) for r in top)
train_counts = Counter(pr(r) for r in top)
stats = {
    "body_chars_median": statistics.median(lengths),
    "body_chars_p90": lengths[int(len(lengths) * 0.9)],
    "comments_per_pr": dict(Counter(train_counts.values()).most_common()),
    "prs_reviewed": len(train_counts),
    "question_rate": sum("?" in r["body"] for r in top) / len(top),
    "suggestion_block_rate": sum("```suggestion" in r["body"] for r in top) / len(top),
    "top_first_words": dict(first_words.most_common(25)),
    "top_level_comments": len(top),
    "total_comments": len(train),
}
(OUT / "stats.json").write_text(json.dumps(stats, indent=2))

# Taxonomy chunks: round-robin so each agent sees the full 12-year range, with
# diff hunks trimmed (the commented line is at the end of a hunk)
for i in range(CHUNKS):
    with (OUT / f"chunk_{i:02}.jsonl").open("w") as f:
        for r in top[i::CHUNKS]:
            f.write(
                json.dumps(
                    {
                        "body": r["body"],
                        "created_at": r["created_at"][:10],
                        "hunk": (r["diff_hunk"] or "")[-600:],
                        "path": r["path"],
                        "repo": r["repo"],
                    }
                )
                + "\n"
            )

# Voice samples by era, replies included since tone shows up in discussion.
# Stride-sample to cap size while spanning each era evenly
for start, end in [(2014, 2019), (2019, 2023), (2023, 9999)]:  # last era open-ended
    era = [r for r in train if start <= int(r["created_at"][:4]) < end]
    with (OUT / f"voice_{start}.jsonl").open("w") as f:
        for r in era[:: max(1, len(era) // 400)]:
            f.write(
                json.dumps(
                    {
                        "body": r["body"],
                        "created_at": r["created_at"][:10],
                        "is_reply": r["is_reply"],
                        "repo": r["repo"],
                    }
                )
                + "\n"
            )

print("Prepared", len(train), "train comments,", len(holdout), "holdout PRs")
