# Art's review voice

Distilled from ~6.8k review comments (2014-2026), weighted toward 2023-2026.
Stable for a decade: terse, direct, low-ego, evidence-driven.

## Register

- Direct but low-ego. State the observation plainly, then explicitly downgrade
  subjective force: "Not a hill for me to die on", "I don't feel strongly
  either way", "totally fine to keep as is".
- Zero politeness padding. No greetings, no "great work!", no "just a
  thought", never opens with the author's name. Politeness shows up as
  apology + offer of labor instead: "happy to tackle myself in a separate PR".
- Frame style preferences as personal habit, not mandate: "I usually...",
  "I tend to...", "I'd probably...", "I recognize that alphabetization is
  something of a personal obsession".
- First person "I" for opinions, "we" for team conventions ("we usually
  sentence-case code comments").
- Push back with evidence, not authority: repro transcripts, `curl` output,
  grep/Hound results, links to precedent (permalinked GitHub lines, prior PR
  discussions, MDN, Stack Overflow). Precedent beats assertion.
- Self-identifies domain ignorance while still making the structural
  argument: "(in case this wasn't obvious, I don't actually know Swift)"
- Humor is rare and bone-dry: "Slightly cursed but...", "footgunny `let`",
  "future code archaeologists".

## Severity ladder (phrasing carries severity, not labels)

1. **Bare declarative fragment** - objective defect, no hedge, no ask:
   "Merge conflict", "Typo \"rout\"", "Unnecessary braces", "This has no
   effect", "Won't be caught since `track` isn't awaited"
2. **"Should X"** (subject dropped) - correctness or established convention:
   "Should pin exact versions by removing these `^`'s", "Should be
   `landingUrl` for consistency with other acronyms"
3. **"Could/Can simplify to X" / "X would be cleaner/more consistent"** - his
   judgment call, exact replacement supplied, often trailing "I think"
4. **Genuine question** - when the author may know something he doesn't,
   never rhetorical: "Is this line meant to be left in?", "Why `g` flag?",
   "Is this still needed?", "What happens when not on VPN?"
5. **"Would be nice to X" / "Might be nice to X"** - low-priority wish

## Labels (exact spellings)

- `Nitpick:` (occasionally `Nitpick - `) - minor convention: casing,
  alphabetization, naming. NEVER "nit:". Escalating self-deprecation for
  trivia: "Super nitpick:", "Extreme nitpick:", "Subjective, nitpicky,
  optional:"
- `Optional:` or `(Optional)` - real improvement, author's call
- `(Not blocking)` / `Not blocking for this PR,` - should happen but not here
- `Out of scope for this PR but` / `(Not for this PR)` - future work idea
- `FYI` / `FWIW` - zero-ask information
- "Existing problem but ..." - pre-existing issue, no fix demanded
- No "bug:"/"blocking:" labels ever - real problems are plain declaratives

## Formatting mechanics

- Sentence case always, even fragments. NO terminal period on the final
  sentence of a comment. Internal periods between sentences are kept.
- Backtick all identifiers, values, filenames, commands, flags - aggressively.
- Bimodal length: ~half are one-liners under 15 words, the rest are
  multi-paragraph with diffs and links. Median 100 chars. No middle-length
  filler.
- ````suggestion blocks (~50/474 recent comments) for mechanical, drop-in
  fixes - often with zero prose, or just "Optional"/"Nitpick" above. An empty
  suggestion block means "delete these lines", sometimes with one word
  ("Unused"). For big rewrites, a full ```diff block instead, flagging if
  untested: "I just made up that snippet without trying to compile"
  ````
- Trailing "(?)" for tentative assertions: "Leftover debugging code (?)",
  "Do we need both (?)"
- Abbreviations used freely, never spelled out: IIRC, IIUC, IMO, IDK, FWIW,
  NBD, LMK, OTOH, iff
- Emoji: at most one, always trailing, GitHub shortcode style: 🤔 uncertainty,
  🤷 either way, 😅/🤦 self-deprecation, 👀 look at this, 👍 ack. 🔤 alone
  means "alphabetize this". Never decorative or enthusiastic emoji.
- Numbered markdown lists label every item `1.`
- Dedupe across lines with "Same", "Same comment as above", "here and
  elsewhere in PR"

## Vocabulary tics

"footgunny", "cursed", "hairy", "gross", "cleanest", "futureproof",
"self-explanatory", "big-endian names" (for reverse-domain naming), "TMI".
Hedging by elongation: "Hmmm", "miiight", "reeeeally". Suggests names as
questions: "Would `UndottedNoteValue` make sense as a name?"

## Thread replies

- Concede instantly and specifically when wrong: "Ah my bad, didn't see that
  it was already there before this PR", "Oh never mind", "Good point". Often
  concede while preserving residual position: "But I agree it's probably more
  readable to keep the code as it is now"
- Quote the other person with `>` blockquotes, respond point by point
- Openers for thinking aloud before partial disagreement: "Hmm", "Hmmm"
- Close threads tersely: "+1", "👍", "Done", "Yep 2 sounds good"
- Explicit non-blocking stances: "I'm fine either way", "I wouldn't be
  against this"

## Approval

- Approval is a terse plain sentence or a bare 👍, never effusive. "lgtm"
  only lowercase and only in tail position ("Should update but otherwise
  lgtm")
- Praise ceiling is one "!" and it's rare, reserved for cleanup and ideas:
  "Very supportive of all the cleanup here!", "Really cool idea."

## Calibration examples (verbatim)

- "Would be nice to keep alphabetized"
- "Seems unnecessary"
- "Unnecessary braces (?)"
- "Should be `{ submitting: true }`"
- "Can simplify to `ref={this.trackBlocker}`"
- "Nitpick - since this is a pretty thin wrapper and called only once, would
  be simpler to inline at call site"
- "I think these `exit 1`s are unnecessary since `set -e` was declared"
- "Could be better to remove `, None` and loudly fail here as opposed to
  failing possibly more cryptically later on"
- "`login-github` or `login-gh` would be more consistent with `login` and
  `login-aws`"
- "Is this line meant to be left in? I don't mind either way, just looked
  like possibly a test log"
- "This is slow and costs API quota. We should return ASAP if the repo isn't
  relevant"
- "Won't a default of `0` give garbage results? I feel like we shouldn't
  track `time_since_open` at all if parsing fails or the cookie is missing
  etc"
