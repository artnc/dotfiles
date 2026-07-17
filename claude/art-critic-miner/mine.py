#!/usr/bin/env python3
"""Mines my GitHub review comments into `corpus.jsonl` for /art-critic distillation"""

import json
import re
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

AUTHOR = "artnc"
# 8 concurrent fetches ≈ 5k requests/hr, right at the API rate limit. `gh()`
# sleeps through any 403s if we run slightly hot
BATCH = 8
DIR = Path(__file__).resolve().parent
CORPUS = DIR / "corpus.jsonl"
# Repo-level endpoints: inline diff comments and PR-level discussion comments.
# PR review summary bodies are skipped since they have no repo-level endpoint
# (one request per PR) and are rarely substantive
KINDS = ["pulls/comments", "issues/comments"]
# Duolingo repo names are private, so they come from gitignored `repos.txt`
# (one name per line) instead of being hardcoded in this public repo
if not (repos_file := DIR / "repos.txt").exists():
    sys.exit(f"Create {repos_file} containing one GitHub repo name per line")
REPOS = repos_file.read_text().split()
STATE = DIR / "state.json"


def gh(*args):
    """Calls `gh api`, sleeping through rate limits and transient errors"""
    for attempt in range(8):
        result = subprocess.run(["gh", "api", *args], capture_output=True, text=True)
        if result.returncode == 0:
            return json.loads(result.stdout)
        # GraphQL exits nonzero on partial errors (e.g. deleted PRs) despite
        # printing a valid response, so accept any payload that has data
        try:
            if isinstance(payload := json.loads(result.stdout), dict) and "data" in payload:
                return payload
        except json.JSONDecodeError:
            pass
        print(f"Retrying after error: {result.stderr.strip()[:200]}", file=sys.stderr)
        time.sleep(300 if "rate limit" in result.stderr.lower() else 30)
    sys.exit(f"Giving up on {args[-1][:200]}")


# Dedupe by (kind, id) since resumed runs and window overlaps refetch pages.
# The two comment kinds use independent id sequences, so bare ids could collide
seen = set()
if CORPUS.exists():
    with CORPUS.open() as f:
        seen = {(r["kind"], r["id"]) for line in f if (r := json.loads(line))}

# GitHub 422s past ~page 300 ("pagination is limited for this resource"), so
# instead of paging forever we sort by updated-asc and periodically restart
# from page 1 with `since` advanced to the last comment seen. State stores each
# repo/kind's `since` cursor for resumability
pool = ThreadPoolExecutor(BATCH)
state = json.loads(STATE.read_text()) if STATE.exists() else {}
for repo in REPOS:
    for kind in KINDS:
        key = f"{repo}/{kind}"
        page = 1
        while state.get(key) != "done":
            since = f"&since={s}" if (s := state.get(key)) else ""
            query = f"repos/duolingo/{repo}/{kind}?per_page=100&sort=updated&direction=asc{since}"
            pages = range(page, page + BATCH)
            batch = list(pool.map(lambda p: gh(f"{query}&page={p}"), pages))
            comments = [c for page_comments in batch for c in page_comments]
            # Keep my comments, restricting issue comments to those on PRs
            records = [
                {
                    "body": c["body"],
                    "created_at": c["created_at"],
                    "diff_hunk": c.get("diff_hunk"),
                    "id": c["id"],
                    "is_reply": "in_reply_to_id" in c,
                    "kind": kind,
                    "path": c.get("path"),
                    "repo": repo,
                    "url": c["html_url"],
                }
                for c in comments
                if (u := c.get("user"))
                and u["login"] == AUTHOR
                and (kind, c["id"]) not in seen
                and (kind == "pulls/comments" or "/pull/" in c["html_url"])
            ]
            with CORPUS.open("a") as f:
                f.writelines(json.dumps(r) + "\n" for r in records)
            seen.update((kind, r["id"]) for r in records)
            print(f"{key} pages {pages[0]}-{pages[-1]}: +{len(records)}", flush=True)
            # An empty page means we're past the last comment. Otherwise either
            # advance within the window or, nearing the page cap, slide `since`
            # up to the newest comment fetched and restart from page 1
            if not all(batch):
                state[key] = "done"
            elif pages[-1] < 240:  # stay safely under GitHub's ~300-page cap
                page += BATCH
            else:
                # Bail if an entire window shares one updated_at, since sliding
                # the cursor to it would refetch the same window forever
                if state.get(key) == comments[-1]["updated_at"]:
                    sys.exit(f"Cursor stuck at {state[key]} for {key}")
                state[key] = comments[-1]["updated_at"]
                page = 1
            STATE.write_text(json.dumps(state))

# Drop comments on my own PRs since those are me replying as an author, not
# reviewing. The list endpoints don't include PR authorship, so batch-resolve
# it via GraphQL (100 PRs per request)
records = [json.loads(line) for line in CORPUS.open()]
prs = sorted(
    {(r["repo"], int(m.group(1))) for r in records if (m := re.search(r"/pull/(\d+)", r["url"]))}
)
authors = {}
for i in range(0, len(prs), 100):
    chunk = prs[i : i + 100]
    fields = " ".join(
        f'p{j}: repository(owner: "duolingo", name: "{repo}") {{ pullRequest(number: {n}) {{ author {{ login }} }} }}'
        for j, (repo, n) in enumerate(chunk)
    )
    print(f"Resolving authors for PRs {i + 1}-{i + len(chunk)} of {len(prs)}...", flush=True)
    data = gh("graphql", "-f", f"query=query {{ {fields} }}")
    for j, (repo, n) in enumerate(chunk):
        # Deleted PRs and ghost users resolve to None, which we keep
        pr = (node := data["data"].get(f"p{j}")) and node["pullRequest"]
        authors[(repo, n)] = pr["author"]["login"] if pr and pr["author"] else None

kept = [
    r
    for r in records
    if not (m := re.search(r"/pull/(\d+)", r["url"]))
    or authors.get((r["repo"], int(m.group(1)))) != AUTHOR
]
# Rewrite atomically so a crash can't truncate the corpus that state.json
# already marks fully mined
(tmp := CORPUS.with_suffix(".tmp")).write_text("".join(json.dumps(r) + "\n" for r in kept))
tmp.replace(CORPUS)
print(f"Done: kept {len(kept)}/{len(records)} comments after dropping my own PRs")
