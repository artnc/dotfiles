# What Art catches

Distilled from ~5.6k top-level review comments (2014-2026) across 10 Duolingo
repos (TS/TSX, Kotlin, Python, SCSS, Bash, JSON schemas, Makefiles).
Categories ranked by frequency. Percentages are share of substantive comments.

## 1. Simplification and less code (~15%, the signature)

Core doctrine: "Less code is generally better than more code" and "Code is
strictly a liability, not an asset".

- Inline single-use variables, helpers, wrappers, and types at the call site:
  "single-use local variables complicate things by introducing concepts that
  the reader must learn and accumulate in their memory". A comment at the one
  usage site beats inventing a name.
- Return/exit early instead of nesting: "Could save a lot of indenting by
  returning early instead"
- Order branches so conditions have the fewest negations: "Simpler to remove
  `!` and swap operands"
- Prefer the stdlib/library one-liner over hand-rolled logic: `Math.hypot`,
  `padStart`, `Object.fromEntries`, dict comprehensions, Kotlin
  `?.let`/`apply`/`when`/`?: return`/`sumBy`, `_.sortBy`
- Remove no-op constructs: unnecessary braces, template strings, `!!` on
  booleans, `await` on non-promises, inferred type annotations, `> 0` on
  length checks, `else` after `return`
- YAGNI on API surface: "I usually lean toward starting off with as little
  API as possible". Hardcode until a second use case exists. Combine
  functions only ever used together
- Anti-premature-generalization is the counterweight: don't extract a shared
  helper for an intentional one-off

## 2. Correctness bugs (~8%)

Found by mentally executing the code and checking every caller:

- Missing `await` (traces the full async chain), promises that never resolve,
  race conditions, `Promise.all` that doesn't actually guarantee ordering
- React: `&&` in JSX renders falsy `0` - "always use ternary with one `null`
  branch". `setState` asynchrony, inline lambdas causing rerenders
- Unhandled edge cases: `KeyError` after a check that anticipated the missing
  key, off-by-ones, year/locale/timezone boundaries, length-1 strings, regex
  metacharacters and missing `g` flags, "Email addresses are notoriously
  unregexable"
- Signature changes breaking uninspected call sites, caught by grepping for
  every caller of the changed function
- CSS scope leaks: "This affects all inputs on the website. Only classes are
  scoped to the module"
- Refactors that silently change behavior: "To keep the same behavior, this
  would have to go outside of the try/catch"
- Shell: `set -e` semantics, unquoted variables, cwd assumptions, stderr not
  meaning error

## 3. Naming precision (~7%)

- Names must match behavior exactly, neither vaguer nor broader: "`stats` is
  kinda vague", "'User details' is misleadingly general"
- Booleans sound boolean (`isFreeTrial`), non-booleans don't
  (`ShadowbannedUsers` not `shadowbanned`), positive over negated (`isFull`
  not `notFull`), functions are verbs, properties are nouns
- Futureproof names: `isDeveloper` beats `isAdminOrEngineerOrCustomerService`.
  Name constants after their role, not their value
- Include units in time names (`LINKS_UPDATE_INTERVAL_DAYS`), consistent
  acronym casing (`landingUrl`, `XpGraph` per Microsoft convention), and
  sibling/platform naming conventions (`handleClick` handlers)
- File names must match contents. Avoid terms confusable with stdlib/other
  concepts

## 4. Comments and docs (~7%)

- Non-obvious code needs a WHY comment with a link (Stack Overflow, docs,
  Slack, prior PR): "so that someone in the future won't unwittingly undo
  this change"
- Use doc syntax IDEs surface: `/** */` TSDoc/Javadoc/KDoc, never `/*` or
  bare `//` for API docs
- Outdated comments are defects: "wrong documentation is arguably worse than
  no documentation". Docstrings restating the signature are worse than none
- Temporary code needs a TODO with a removal condition or date (TODO is more
  greppable than ad-hoc markers)
- Comments are sentence-cased. Skeptical of section-marker comments ("tend to
  do more harm than good... which turns the comment into a lie")

## 5. Dead code and leftovers (~7%)

- Delete unused imports, params, strings, assets, CSS classes, env vars, and
  files the moment they become unused - including transitively ("`juicy`
  param can probably also be removed now")
- A deletion obligates a repo-wide sweep for newly dead code - he greps and
  pastes the straggler list
- Leftover debug code: "Leftover debugging code (?)", "Is this line meant to
  be left in?"
- Commented-out code always gets challenged: "Why is this code commented
  out?"

## 6. Consistency with codebase precedent (~6%)

His single most-cited justification. Match what the repo already does and
cite the precedent by file/line/link, often with grep counts as evidence
("error variables are usually named `ex`... 137 occurrences"). Reuse existing
helpers, constants, enums, and components instead of near-duplicates. Import
grouping conventions. Cross-platform parity (web/Android/iOS should behave
identically, with links to the other platform's source).

## 7. Process and PR hygiene (~6%)

- PR titles: imperative verb first, accurate, describe the problem not the
  implementation, no trailing period
- One concern per PR: "PRs should be kept small... to simplify code review,
  bisecting, reverts". Refactors and formatting-only changes go in separate
  PRs. Undo unrelated whitespace changes "for cleaner diff and blame"
- Revert-of-revert should build on a `git revert` of the revert so reviewers
  see what changed since the first attempt
- Merge conflicts, CI failures, and missing `make format` flagged as bare
  fragments

## 8. API and schema design (~5%, JSON hyper-schema heavy)

- Don't send what the client can compute. Minimize surface by reusing
  existing routes/fields. "The default behavior should be the correct
  behavior"
- Schemas: `$ref` shared definitions, always specify array element schemas,
  enums over free strings, document nullability/units/defaults, mark
  deprecations. "Making an optional field required is a breaking API change,
  but the other way around isn't" - so require from day one
- Correct HTTP semantics (403 vs 401 client consequences, PATCH for updates,
  error codes over `{"success": false}`)
- Consider old-client version skew before removing or changing fields

## 9. Alphabetization (~4%, the famous one)

Anything unordered stays alphabetized: dict keys, imports, JSX props,
interface members, deps, config lists, doc lists. Rationale: "reduce entropy
and unnecessary decisionmaking/bikeshedding", cleaner diffs, prevents
duplicate keys. Signals with just 🔤. Insertion point matters: "in
alphabetical order, generally not just at the bottom".

## 10. Language idioms (~4%)

- TS/JS: arrow functions never `function`, `===`, type annotation over `as`
  assertion ("former is stricter"), no `any`, `interface` over `type` where
  extendable, objects over `Map`, arrays over `Set` (serializable), native
  over lodash where possible, `??` not `||`, `import type`
- Kotlin: expression bodies, `?: return`, `apply`/`also`/`let`, `to` over
  `Pair`, `lateinit` over nullable, properties over getters, `private` by
  default, `@JvmField` for constants
- Python: comprehensions, walrus, `os.environ["X"]` over `.get` (fail fast),
  bare `raise` re-raises, `in` checks before subscripting
- Bash: `${foo}` braces always ("defensive measure against `$FOObar`"),
  double-quote interpolations, `[[`, `set -eu` with newlines over `&&` chains

## 11. Tooling and linter automation (~4%, highly distinctive)

Any style rule worth stating twice becomes a lint rule - he writes it himself
("I'll add a linter check in a separate change"). Cardinal rule: "never
forcing anyone to fix other people's mistakes" - fix all existing violations
when introducing a rule, never add a check until existing code passes it.
Anti-baseline. Flags when a linter should have caught something.

## 12. The rest (each ~1-3%)

- **Types**: precise types over loose (`LanguageId` not `string`), derive
  from const arrays, make the compiler enforce invariants
- **Perf**: parallelize independent awaits, cheap checks before expensive
  calls, conserve rate-limited API quota, ask for measured bundle/APK size
  deltas before accepting deps. Explicitly tolerates tiny hits for clarity
- **Design tokens/CSS**: never hardcode values that have named constants
  ("This is `$blue`"), match mockups exactly, flat selectors under CSS
  Modules, styles in CSS files not inline
- **Dedup**: extract when 2+ real copies exist ("the difficulty of
  deduplicating grows over time"). Reciprocal "if you change this, also
  change that" comments when copies must exist
- **i18n**: strings through the translation pipeline, pluralization helpers
  over hardcoded numbers, reuse already-translated strings, HTML-safe
  interpolators
- **Error handling**: fail loudly and early over cryptic later failures,
  report unexpected states to error tracking, log "Doing X..." before acting
  not after, self-explanatory log messages with context links
- **Encapsulation**: everything `private`/unexported until needed
- **Dependency hygiene**: pin exact versions (never `^`), challenge every new
  dep by cost (bundle size, learning curve, liveness), prefer vendoring one
  file or hand-rolling five lines
- **File organization**: code lives with its domain, split gigantic files,
  locality ("move to line 354 for better locality"), blame-churn minimization
- **Typos and prose**: relentless, in code, comments, UI copy, and docs -
  reviewed as rigorously as code, often fixed via suggestion block
- **Experiments** (Duolingo-specific): order the experiment-treatment check
  last so short-circuiting avoids unnecessary treatment (and thus dilution),
  and clean up concluded experiments
- **Security** (rare but real): secrets via `--env VAR` name-only so values
  don't leak to `ps`/logs, least-privilege grants, flags committed keys
- **AI-generated code smells** (recent): "AI likes to unnecessarily `export`
  stuff that's never actually used externally and unnecessarily define named
  interfaces for one-off types"

## What he does NOT flag

`calibration.md` holds the canonical don't-say list - don't duplicate it
here. The two standouts in the data: essentially zero a11y comments in 12
years, and instead of demanding unit tests he verifies empirically himself
(runs the branch, pastes repro output, screenshots).
