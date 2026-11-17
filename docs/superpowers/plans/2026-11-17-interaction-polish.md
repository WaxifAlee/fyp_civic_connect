# Familiar app interactions implementation plan

> **For agentic workers:** Use superpowers:executing-plans. The user explicitly requested autonomous execution; design choices below are implementation decisions.

**Goal:** Make refreshing, finding reports, navigating long content and completing forms feel predictable on phones and the web.

**Architecture:** Extend the existing CivicPage scroll surface and existing controllers. Retain Material controls, Public Sans and the current theme. Preserve all authenticated write, draft recovery and Supabase boundaries.

**Tech stack:** Flutter, Material 3, Supabase, flutter_test.

## Run manifest

- Base: main at aafaf52a94781d3a934c9af9acf83def4de11092. Initial tree contains only user-owned untracked .agents/; leave it untouched.
- Scope: S1 moderate interface work. Single resident writer. A read-only UX scout checks forms and details while the resident audits refresh/navigation; a fresh reviewer checks the final implementation.
- Routing: child model AUTO/inherited because runtime policy requires inheritance without a user override; requested effort high. Exact model identity is not exposed. Children share the managed workspace sandbox but are instructed to make no edits, access credentials or delegate further. Concurrency cap two; maximum three review rounds.
- No schema, authentication, report submission protocol or visual identity redesign. No new dependencies.

## Acceptance criteria and review focus

1. Overview, Explore, My reports and authority queue support pulling down at the top, including short/empty/error content. Visible refresh controls remain available.
2. Successful citizen content remains visible during refresh and after refresh failure, with clear retry feedback. Concurrent refresh requests cannot overwrite newer state or resurrect deleted reports.
3. Search provides a one-tap clear action and dismisses the keyboard naturally. Long pages have a predictable route back to the top.
4. Report details remain dismissible while reading long discussions and while the keyboard is open. Existing comment drafts and retry state survive local rebuilds.
5. Address concrete additional form/navigation gaps found in the audit. Respect text scaling, safe areas, keyboard focus and reduced motion.

## Tasks

- [x] Audit forms/details independently; choose bounded improvements from source evidence.
- [x] Add failing behavioral tests for refresh on short content, retained reports on reload/error, request overlap and navigation/keyboard improvements.
- [x] Implement shared scroll/refresh behavior and controller safety, then run targeted tests.
- [x] Implement the remaining audited search/detail/form improvements with meaningful regression tests.
- [ ] Run all Flutter tests, analyzer, release web and Android debug builds; verify browser and emulator interactions.
- [ ] Independently review, resolve findings, update README and delivery evidence, commit and push main; leave the application available for testing.

## Execution ledger

- Read-only scout Ptolemy identified unguarded report/account drafts, detail dismissal losing comment retry identity, and signup errors lacking focus recovery. All four findings were accepted and implemented; the resident added authority note/comment protection through the same shared guard.
- Ruling: preserve the current visual identity and improve interactions in place. User-requested autonomous execution covers local implementation and the previously authorized push to main.
- CivicPage owns refresh gestures and keyboard dismissal; AppShell owns the primary scroll controller and current-tab reselection. LeaveGuard shares discard decisions between explicit navigation, modal dismissal and Back. Form validation guides users to the first error.
- Refresh reads are coalesced and cannot replace a later confirmed support/deletion result. Retained data is scoped to its account; authority refresh also verifies current membership before retaining a queue.
- Red evidence: overlapping refreshes made two requests; delayed reads restored deleted reports and stale support; report/account navigation discarded drafts; detail Close scrolled offscreen; invalid signup left the first field unfocused; root draft dismissal omitted the platform exit. New regressions failed before their fixes.
- Green evidence: complete Flutter suite 202 tests passed; static analysis reports no issues. Small phone, enlarged text and keyboard-inset discussion tests passed.
- No backend or migration changes are required. Existing submission journals and mutation request UUID protocols remain intact.
