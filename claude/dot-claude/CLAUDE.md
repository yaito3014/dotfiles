# Global preferences
<!-- Managed in dotfiles: ~/dotfiles/claude/dot-claude/CLAUDE.md, symlinked to
     ~/.claude/CLAUDE.md, ~/.codex/AGENTS.md, ~/.gemini/GEMINI.md and
     ~/.copilot/copilot-instructions.md -->

- Respond in the language I wrote my message in (e.g. Japanese → Japanese).
- When writing Japanese: avoid dashes (—/―), preferring commas, parentheses, or
  sentence splits; use half-width () parens and keep 「」 full-width.
- Ask before non-trivial or semi-consequential choices. When a request is
  ambiguous, confirm the interpretation instead of assuming and proceeding.
- Don't be a yes-man. Object with concrete reasoning when a request, decision,
  or claim looks wrong or worse for the goals of the project or conversation
  (ask for them if unclear), and say whether the objection rests on something
  verifiable (spec, docs, code) or on a trade-off judgment. Hold your
  position while the reasoning holds; change it on new arguments or evidence,
  not on repetition. Voice objections, never silently do something other than
  what was asked. Decisions, mine included, should rest on a reason. My
  explicit go-ahead can override the goals but still needs a reason; if
  asking reveals only preference or ego, point that out plainly and wait for
  my confirmation before proceeding, unless the change is trivial and cheap
  to reverse.
- Stay strictly scoped to what I asked. If you spot an adjacent bug, cleanup, or
  smell, mention it but don't change it without my go-ahead.
- Surface blockers fast: the moment you hit a genuine blocker or an approach
  starts failing, stop and tell me — don't churn through alternatives.
- State plainly what an authoritative source (spec, docs, code) establishes;
  where it doesn't, mark the claim as approximate rather than asserting it, and
  don't present unverifiable claims as fact.
- Use precise terminology: distinguish name vs. structure, type vs. value,
  expression vs. its value; don't conflate distinct categories.
- Prefer test-driven development: when adding or changing behavior, write a
  failing test first, then implement until it passes.
- When a test or assertion fails, fix the root cause — don't weaken the
  assertion or the test to make it pass.
- Keep comments minimal: none for what's obvious from the code, only for
  non-obvious intent (the why).
- No bare TODO/FIXME: say what and why, or link an issue. Delete dead code
  instead of commenting it out.
- After editing, re-read the surrounding area for inconsistencies the change
  introduced, and sweep for other instances of the same class of issue —
  including in submodules, and enumerating edge cases exhaustively — before
  committing.
- When committing, prefer several logically-scoped commits over one large one,
  as the change warrants.
- Commit messages: match the repository's existing convention (check
  `git log`); if there is none, use a plain imperative subject.
- Branch names: match the repository's prefix style; if there is none, use a
  type prefix (`feat/`, `fix/`, `refactor/`, `docs/`, `chore/`, ...).
- When addressing feedback on a pushed branch, add new commits; never rewrite
  pushed history.
- Write commit messages in English, regardless of the language of the
  conversation.
- In code comments, commit messages, and PR text, use ASCII only unless a
  non-ASCII character is genuinely needed (e.g. quoting code or output that
  contains one): write `-`, `->`, `...`, and straight quotes instead of
  dashes, arrows, ellipses, and curly quotes. Write code comments in English;
  Japanese is acceptable only when genuinely necessary.
- Keep each branch/PR to one logical change; split out-of-scope work onto its
  own branch (off `main`) rather than folding it in.
- No "Co-Authored-By" or "Generated with Claude Code" trailers in commits or PRs.

## Pull requests

- Write PR titles and descriptions in English, regardless of the language of
  the conversation.
- Title: follow the repository's commit subject convention; if there is none,
  a short imperative summary of the change (`Add X`, `Fix Y when Z`), no
  trailing period, ideally under ~70 characters.
- Write the description for reviewers, even for a single-commit PR; don't
  just copy the commit message.
- Body: if the repository has a PR template, follow its structure. Otherwise
  write a short paragraph on what changed and why, add a bullet list only when
  there are several distinct changes, and say how it was verified (tests
  added, commands run) and plainly what wasn't tested. Link related issues
  (`Fixes #123`, `Refs #456`) where applicable.
- Describe the diff, not the session: no narration of how the change was
  arrived at, and no restating what is obvious from the code.
- No decorative structure in commit messages or PR text: no section headers or
  bold labels unless the content is long enough to genuinely need them.
- Ask whether to open the PR as a draft or ready for review.
- Before opening a PR or pushing to one: build and tests pass, formatters and
  linters are clean, and the full diff has been re-read for stray changes,
  debug output, and scope creep.
- On review comments on my PRs, summarize the comment and the proposed fix to
  me before acting.
- For other GitHub text (issue bodies, comments, replies), follow the
  thread's language; ASCII is still preferred.

## Issues

- Use the repository's issue templates; otherwise plain prose, with the same
  formatting rules as PR text (no decorative structure).
- Write in the language the repository's existing issues use; when commenting
  on an existing issue, follow the thread's language.

## Code review

- Label each finding by severity: blocking, should-fix, or nit.
- Pair each finding with a concrete suggested fix.
- Back correctness claims with the standard, docs, or code.

## Code organization

Applies when designing new code or when I ask for restructuring. In an
existing codebase, follow its established structure; where it conflicts with
these rules, point out the conflict instead of reorganizing.

- Core rule: dependency order is reading order. The codebase should be
  readable bottom-up along its dependency DAG.
- No dependency cycles at any granularity (function, file, module, package).
  Genuine mutual recursion (e.g. a recursive data type) is collapsed into one
  unit, not split across modules.
- Within a file, define before use, so it reads top-down without forward
  references.
- Each module hides one design decision likely to change, statable in one
  sentence. If it can't be stated, the boundary is wrong; raise it.
- Prefer deep modules: small interface, much hidden. Merge pass-through layers
  instead of adding them.
- Organize by feature, not by technical layer. Place each module under the
  lowest common ancestor of its consumers (the dominator tree of the
  dependency graph, rooted at the composition root), so nesting means private
  to the parent. When a consumer outside the parent appears, hoist the module
  and say so in the change: a private detail is becoming shared API.
- Cross-feature access goes only through the feature's public entry point.
- Record allowed edges between top-level features in one manifest, in
  topological order (every dependency listed before its dependents). A new
  edge means editing the manifest and stating why in the commit or PR.
- When a dependency would point upward, invert it: the consumer owns the
  interface, the provider implements it, and only the composition root wires
  concrete implementations. Pass dependencies explicitly; no ambient globals,
  service locators, or auto-wiring containers.
- Enforce in CI where the project supports it: manifest order, entry-point-only
  access, no cycles, and a generated dependency graph in the docs.

### In C++

- A feature is a CMake target; the `target_link_libraries` graph is the
  manifest. Keep it acyclic even though CMake tolerates cycles among static
  libraries; inspect with `cmake --graphviz`.
- Public entry point: the target's public headers (FILE_SET). Private nested
  parts that public headers need (templates, inline code) go in the owner's
  `detail/` directory and `detail` namespace; parts only the target's sources
  need stay out of public headers (an unnamed namespace in one source, or a
  private header). With C++20 modules, use non-exported partitions and export
  only from the primary module interface.
- No header includes a header of a feature that is not below it in the
  manifest.
- Single-header libraries: order sections by level, lowest first; forward
  declarations only for intentional recursion within one collapsed unit.
- Injection: statically via concept-constrained template parameters, where the
  consumer owns the concept; dynamically via type erasure or a consumer-owned
  virtual interface. Prefer static unless runtime substitution is needed.

### In TypeScript

- A feature is a directory whose declared entry modules are the only
  cross-feature import targets. Declare them in one place, e.g. the
  `package.json` `exports`/`imports` map (`#feature`, `#feature/sub`) or the
  path alias config; an `index.ts` is one option, not required. Import across
  features via those specifiers, never `../` out of a feature (enforce with a
  dependency-cruiser rule forbidding cross-feature imports of non-entry
  modules; `import/no-relative-parent-imports` is stricter, banning `../`
  within a feature too).
- Manifest: one file (e.g. `architecture.json`, or the dependency-cruiser
  config itself), checked by a script or dependency-cruiser.
  Check cycles with madge or dependency-cruiser; ES modules permit cycles, but
  they cause TDZ and load-order bugs.
- Injection: factory functions taking a deps object, typed with
  consumer-owned interfaces. The composition root is the app's entry module
  (e.g. `main.ts`).
- Use `#private` for real hiding (`private` is compile-time only) and branded
  types where an opaque boundary matters.

### In Python

- A feature is a package; `__init__.py` is its entry point and defines
  `__all__`. Private nested modules and packages are underscore-prefixed.
- Manifest: import-linter contracts (layers, independence, forbidden) in
  `pyproject.toml`. No import cycles.
- Injection: pass collaborators as arguments, typed with a consumer-owned
  `Protocol`.

## C++

C++ is my primary language. Project config (`.clang-format`, target standard)
always wins over these defaults.

- Default new code to C++23; otherwise match the project's target standard, set
  via `target_compile_features(... cxx_std_NN)`. Prefer modern standard
  facilities over legacy idioms (`std::println`, ranges, `std::expected`, …).
- Gate each feature at the lowest standard it needs, guarded by feature-test
  macros (`__cpp_*`); lower the gate when a dependency's requirement drops.
- Build with CMake (see the CMake section).
- Always run clang-format; the project's `.clang-format` is authoritative. It
  sets east const — write `int const` / `T const&` by hand to match.
- std-library naming: snake_case for types, functions, and variables; trailing
  underscore on private data members (`value_`); everything inside a
  namespace, except what must belong to the global scope (`main`, replacement
  `operator new`/`operator delete`).
- Include guards with `#ifndef`/`#define`, project-prefixed (e.g. SLOT_SLOT_HPP),
  not `#pragma once`.
- Default idioms: `template<class T>` (not `typename`); `[[nodiscard]]` on pure
  returns; `constexpr`/`noexcept` where correct; concepts/`requires` over SFINAE
  when targeting C++20+ (fall back to `enable_if`/`void_t` below C++20);
  explicit `= default`/`= delete`; deducing-`this` for value-category-correct
  accessors.
- `explicit` on converting constructors callable with one argument (not
  copy/move constructors) unless implicit conversion is intended.
- Const-correct throughout; prefer pure functions and immutable locals,
  introducing mutation or side-effects only where genuinely needed.
- Justify UB, strict-aliasing, `constexpr`, and `noexcept` claims against the
  standard rather than intuition; for standard-library work, verify against the
  WG21 draft (`~/repos/cplusplus/draft`), not memory.
- Tests: Catch2 for new work (legacy uses Boost.Test) — match the project. Per
  the TDD rule, write the failing Catch2 case first. For properties you can't
  eyeball (noexcept, `static_assert`, compile-time traits), add a test that
  actually exercises them.

## CMake

- Set the standard with `target_compile_features`, not global
  `CMAKE_CXX_STANDARD`; vcpkg for third-party dependencies.
- Target-based only: no directory-scoped commands (`include_directories`,
  `add_definitions`, `link_libraries`).
- For libraries meant for outside consumers (not internal feature targets),
  ship a full install/export (FILE_SET public headers, exported
  `*-targets.cmake`, public deps linked PUBLIC) so they're consumable via both
  `find_package` and FetchContent; as a consumer, take deps via
  `find_package`/vcpkg, not FetchContent.

## Shell

- Prefer POSIX `sh`; use bash only when its features are needed.
- sh and bash scripts must pass shellcheck (it does not support zsh).

## Python

- Use uv for projects, dependencies, and scripts; ruff for lint and format.
- Type-hint fully and keep the type checker clean; follow the project's
  choice of checker.
