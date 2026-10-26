# Global preferences
<!-- Managed in dotfiles: ~/dotfiles/claude/.claude/CLAUDE.md, symlinked to ~/.claude/CLAUDE.md -->

- Respond in the language I wrote my message in (e.g. Japanese → Japanese).
- When writing Japanese: avoid dashes (—/―), preferring commas, parentheses, or
  sentence splits; use half-width () parens and keep 「」 full-width.
- Ask before non-trivial or semi-consequential choices. When a request is
  ambiguous, confirm the interpretation instead of assuming and proceeding.
- Don't be a yes-man. Object with concrete reasoning when a request, decision,
  or claim looks wrong or worse for the project's goals (ask for them if
  unclear), and hold your position as long as the reasoning holds. Decisions,
  mine included, should rest on a reason. My explicit go-ahead can override
  the goals but still needs a reason; if asking reveals only preference or
  ego, point that out plainly and wait for my confirmation before proceeding.
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
  underscore on private data members (`value_`); everything inside a namespace.
- Include guards with `#ifndef`/`#define`, project-prefixed (e.g. SLOT_SLOT_HPP),
  not `#pragma once`.
- Default idioms: `template<class T>` (not `typename`); `[[nodiscard]]` on pure
  returns; `constexpr`/`noexcept` where correct; concepts/`requires` over SFINAE
  when targeting C++20+ (fall back to `enable_if`/`void_t` below C++20);
  explicit `= default`/`= delete`; deducing-`this` for value-category-correct
  accessors.
- `explicit` on single-argument constructors unless implicit conversion is intended.
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
- For libraries, ship a full install/export (FILE_SET public headers, exported
  `*-targets.cmake`, public deps linked PUBLIC) so they're consumable via both
  `find_package` and FetchContent; as a consumer, take deps via
  `find_package`/vcpkg, not FetchContent.

## Shell

- Prefer POSIX `sh`; use bash only when its features are needed.
- Scripts must pass shellcheck.

## Python

- Use uv for projects, dependencies, and scripts; ruff for lint and format.
- Type-hint fully and keep the type checker clean; follow the project's
  choice of checker.
