# Global preferences
<!-- Managed in dotfiles: ~/dotfiles/claude/.claude/CLAUDE.md, symlinked to ~/.claude/CLAUDE.md -->

- Respond in the language I wrote my message in (e.g. Japanese → Japanese).
- Ask before non-trivial or semi-consequential choices. When a request is
  ambiguous, confirm the interpretation instead of assuming and proceeding.
- Stay strictly scoped to what I asked. If you spot an adjacent bug, cleanup, or
  smell, mention it but don't change it without my go-ahead.
- Surface blockers fast: the moment you hit a genuine blocker or an approach
  starts failing, stop and tell me — don't churn through alternatives.
- Prefer test-driven development: when adding or changing behavior, write a
  failing test first, then implement until it passes.
- Keep comments minimal: none for what's obvious from the code, only for
  non-obvious intent (the why).
- When committing, prefer several logically-scoped commits over one large one,
  as the change warrants.
- No "Co-Authored-By" or "Generated with Claude Code" trailers in commits or PRs.
