# jef — agent instructions

## Model routing & verification

These rules apply whatever AI coding harness is used (Claude Code, Codex, Copilot, Cursor, opencode, ...). "Top / mid / small tier" means the provider's most capable, mid-range and cheapest current models (for Claude: latest Opus / Sonnet / Haiku).

### Model routing
- The main (orchestrating) session runs on the top tier and handles user prompts, planning, choosing and briefing executors, and final review. It avoids heavy execution itself.
- Execution goes to the **cheapest tier that suits the task**, via sub-agents/executors where the harness supports choosing their model:
  - **Small tier:** searches, running commands, single-file or repeated edits with an exact spec, formatting, boilerplate.
  - **Mid tier:** multi-file or logic changes, debugging, writing specs and tests, anything needing judgment.
  - **Top tier:** only after the mid tier has failed, or when the task clearly needs deeper reasoning. State the reason.
- Exception: an obvious change of about one line, or a trivial lookup, is done directly; a handoff would cost more than the work.
- Briefs are self-contained: goal, files, constraints, definition of done, "report back concisely".
- If the harness can't choose a sub-agent's model, the main session does the work itself but still applies the cost check and verification.

### Cost check
- Whenever a handoff decision is needed (anything beyond the trivial exception), estimate the executor's input tokens (files + context it must read) and output tokens, then run `handoff-cost --in <N> --out <N> --models <suitable tiers>` (installed at `~/.local/bin/handoff-cost`; prices refresh daily).
- Follow its recommendation and report it in one line: chosen option, estimated cost, saving vs doing it directly. If direct is cheaper, do it directly.
- Figures are API-price estimates; on subscription plans read them as relative usage. If `handoff-cost` is unavailable, give a brief manual estimate instead.

### Verification
1. Always run cheap objective checks first (tests, linters, syntax checks, validators, reviewing the diff). If they fully prove the result, skip model review.
2. Review by a higher tier is required when any of these applies:
   - The change affects logic or behaviour, or touches more than one file.
   - The work is destructive or hard to undo, or touches security or credentials.
   - Objective checks are missing or only partial.
   - The executor reported uncertainty, retries, or deviations from the brief.
3. Escalation ladder: small-tier work is reviewed by a read-only mid-tier reviewer; mid-tier work is reviewed by the main top-tier session reading the diff and report; top-tier work gets objective checks only.
4. On FAIL: send the findings back to the same executor once. If it fails again, move the task up one tier.
5. Summaries to the user say which model executed and which verified.

### User override & suggestions
- If the user explicitly names a model for execution or verification, use it, even if it isn't the cheapest or the rules would pick differently. You may note the cost difference once, in one line.
- You may suggest changes that fit the scenario (a different model, splitting or batching work, more or less verification, tuning `handoff-cost` defaults, changing these rules). Suggestions are applied only with the user's approval.

### jef specifics
- Make changes through OpenSpec when applicable (new features, behaviour or flag changes, bug fixes that change observable behaviour, refactors that touch specs): propose a change under `openspec/changes/`, implement it from its tasks, and keep specs in sync. Skip OpenSpec only for trivial edits that don't affect specified behaviour (typos, comments, docs-only tweaks) or when the user says otherwise.
- Objective checks before any model review: `bash -n` on every changed `.sh` file; `openspec validate --specs --strict` (and `openspec validate <change> --strict`) after spec or change edits.
- Scripts must work on macOS (bash 3.2, BSD tools) and Linux; reviewers flag GNU-only flags.
- Never commit, and never run `openspec archive`, unless the user explicitly asks.
