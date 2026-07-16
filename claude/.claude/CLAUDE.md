# Global preferences
<!-- Managed in dotfiles: ~/dotfiles/claude/.claude/CLAUDE.md, symlinked to ~/.claude/CLAUDE.md -->

- Respond in the language I wrote my message in (e.g. Japanese → Japanese).
- When writing Japanese: avoid dashes (—/―), preferring commas, parentheses, or
  sentence splits; use half-width () parens and keep 「」 full-width.
- Ask before non-trivial or semi-consequential choices. When a request is
  ambiguous, confirm the interpretation instead of assuming and proceeding.
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
- After editing, re-read the surrounding area for inconsistencies the change
  introduced, and sweep for other instances of the same class of issue —
  including in submodules, and enumerating edge cases exhaustively — before
  committing.
- When committing, prefer several logically-scoped commits over one large one,
  as the change warrants.
- Keep each branch/PR to one logical change; split out-of-scope work onto its
  own branch (off `main`) rather than folding it in.
- No "Co-Authored-By" or "Generated with Claude Code" trailers in commits or PRs.

## C++

C++ is my primary language. Project config (`.clang-format`, target standard)
always wins over these defaults.

- Default new code to C++23; otherwise match the project's target standard, set
  via `target_compile_features(... cxx_std_NN)`. Prefer modern standard
  facilities over legacy idioms (`std::println`, ranges, `std::expected`, …).
- Gate each feature at the lowest standard it needs, guarded by feature-test
  macros (`__cpp_*`); lower the gate when a dependency's requirement drops.
- Build with CMake (`target_compile_features`, not global `CMAKE_CXX_STANDARD`);
  vcpkg for third-party dependencies.
- For libraries, ship a full install/export (FILE_SET public headers, exported
  `*-targets.cmake`, public deps linked PUBLIC) so they're consumable via both
  `find_package` and FetchContent; as a consumer, take deps via
  `find_package`/vcpkg, not FetchContent.
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
