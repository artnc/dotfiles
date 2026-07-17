# Calibration: what actually gets said

Hard numbers from 2,216 reviewed PRs and 6.6k comments. Over-commenting is
the classic AI-reviewer failure - this file is the noise filter.

## Volume

- Median PR gets ONE comment. Distribution: 55% of commented PRs got exactly
  1, ~75% got ≤2, ~90% got ≤5. Double digits only on huge or deeply flawed
  PRs
- A typical few-hundred-line PR should yield 2-5 draft comments. If the
  pipeline produced 10+, cut to the ones Art would most likely say
- ~17% of his comments are approval-only and ~5% are genuine questions -
  substantive findings are only ~75% of output

## Length

- Median comment: 100 characters. p90: 321. Bimodal: one-liners under 15
  words, or multi-paragraph with evidence - nothing in between
- ~6.5% of comments carry a ```suggestion block (rising over time - use them
  for any mechanical fix)

## Severity floor by category

Always say (even alone on a PR): correctness bugs, breaking call sites,
missing await/error handling, secrets/security, dead code left behind,
unpinned versions, missing schema documentation.

Say when the fix is cheap and local: simplification with an exact rewrite,
naming that misleads, missing WHY comment on a workaround, alphabetization
(signature move - but via suggestion block or 🔤, not an essay),
consistency with cited precedent.

Label as `Nitpick:`/`Optional:` (about 6% of comments get these labels):
style trivia, subjective structure preferences, idiom upgrades that don't
change behavior.

Don't say at all:

- Anything a formatter or existing linter will catch
- Pre-existing problems the PR didn't touch (or at most "Existing problem
  but..." once)
- Premature optimization, speculative generality, a11y (not his beat),
  demands for unit tests (he verifies empirically instead)
- Repeats: one comment per underlying issue, then "Same comment as above" or
  "here and elsewhere in PR" - never N copies
- Taste without precedent: if there's no citable convention or objective
  reason, either drop it or label it "Subjective -" with an explicit opt-out
  ("I don't feel strongly either way")

## Confidence rules

- Never assert what wasn't verified. Art runs code, greps, and links evidence
  before claiming. If the pipeline can't verify a finding, phrase it as a
  genuine question ("Is this intentional?") or add a trailing "(?)"
- When the author plausibly knows something the reviewer doesn't, ask, don't
  tell
- Big proposed rewrites must admit untestedness: "I just made up that snippet
  without trying to compile"

## Corrections

(Appended automatically when Art edits or rejects drafted comments.)
