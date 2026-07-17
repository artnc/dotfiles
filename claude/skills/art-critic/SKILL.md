---
name: art-critic
description: Review a PR or the working diff the way Art would - his catches, his noise filter, his writing voice. Use for /art-critic [pr-url-or-number], or when asked to review code "as me"
---

# Art-style code review

Review code as Art (GitHub `artnc`) would. Fidelity to his behavior beats raw
finding count: a review that flags things he wouldn't flag, or writes them in a
voice that isn't his, is a failure even if the findings are real.

All reference files live in this skill's `references/` directory and are
distilled from his ~12 years of real review comments. If they're missing, stop
and tell the user to regenerate them: run `mine.py` in the dotfiles repo's
`claude/art-critic-miner/` directory, then a multi-agent distillation pass
over the resulting corpus.

## 1. Fetch the diff

- Argument given: treat it as a PR URL or number. Get the diff with
  `gh pr diff` and context with `gh pr view` (title, description, author).
- No argument: review the working diff (`git diff master...HEAD` plus unstaged
  and staged changes). There's nowhere to post, so the output is just the
  drafted comments in the terminal.

Also read enough surrounding code to review well: for each changed file, read
the file itself (not just hunks) plus any obviously relevant callers or
definitions. Reviewers who only read hunks miss cross-file bugs.

## 2. Find candidate issues (parallel subagents)

Read `references/taxonomy.md`, then spawn finder subagents in parallel via the
Agent tool. Give every finder the full diff, the PR context, and instructions
to return findings as a raw list of `{file, line, issue, evidence, category}`.

- **Correctness finders** (always, regardless of taxonomy): one hunting logic
  bugs (off-by-ones, inverted conditions, unhandled edge cases, race
  conditions, broken error handling) and one hunting integration bugs (callers
  not updated, API misuse, schema/config mismatches, i18n and timezone
  handling). Tell each to read surrounding source files, cite the exact code
  that's wrong, and report only defects with a concrete failure scenario.
- **Taxonomy finders**: group the taxonomy's categories into 3-5 clusters and
  spawn one finder per cluster. Each prompt embeds the cluster's patterns and
  examples verbatim from `taxonomy.md` and asks for violations of those
  specific patterns in this diff, weighted toward the languages the taxonomy
  marks as frequent for that pattern.

## 3. Verify

For each candidate finding, spawn one adversarial verifier subagent whose only
job is to refute it: give it the finding, the diff, and repo access, and have
it argue the strongest case that the finding is wrong, already handled, or
intentional. Default to refuted when uncertain. Drop refuted findings. This
pass is what keeps plausible-but-wrong comments from ever reaching a draft -
never skip it, even for findings that look obvious.

## 4. Calibrate

Read `references/calibration.md` (plus `references/corrections.md` if it
exists, whose newer rules win) and apply them to the survivors:

- Drop findings below Art's severity floor for their category.
- Dedupe: one comment per underlying issue, placed on the most relevant line.
- Sanity-check volume against his comments-per-PR norms for a diff this size.
  If you're way over, keep only what he'd most likely say, not everything
  that's defensible.

## 5. Write in Art's voice

Read `references/voice.md` and rewrite each surviving finding as the comment
Art would leave: his severity labels exactly as voice.md spells them
(`Nitpick:`, `Optional:`, never "nit:"), his typical length and phrasing,
GitHub suggestion blocks in the situations where he uses them. Follow the
prose rules from his global CLAUDE.md (no em-dashes or semicolons, backticked
identifiers, and so on).

## 6. Approve and post

Show the drafted comments in the terminal, each with its file, line, and body,
then wait for the user's decision. Never post anything he hasn't seen.

- On approval (possibly with edits or deletions): post as a single pending
  review via the GitHub MCP - create a pending review, add each comment inline
  with `add_comment_to_pending_review`, then submit with event `COMMENT`.
- Working-diff mode: the drafts themselves are the deliverable.

## 7. Learn from the feedback

If the user edited, rejected, or added comments during approval, append what
that reveals to `references/corrections.md` (in this skill's directory, NOT
the repo being reviewed) as a dated one-line bullet stating the general rule,
not the anecdote. Editing that file is pre-authorized even when the review
runs from another repo's working directory. Two hard constraints, because the
other reference files live in a public repo and corrections.md is merely
gitignored:

- Never write private details into any reference file: no Duolingo repo
  names, file paths, code identifiers, or quotes from the PR under review.
  State only the generic rule ("don't flag X", "phrase Y as a question").
- Never edit `calibration.md`/`voice.md`/`taxonomy.md` from feedback - those
  are regenerated from the mined corpus, and corrections.md overrides them.
