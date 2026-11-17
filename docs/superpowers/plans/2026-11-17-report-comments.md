# Report Comments Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add secure, persistent comments to citizen and authority report details.
**Architecture:** Private Supabase table and RPC boundary; report feature domain, data service, controller and shared presentation panel. One writer integrates all changes.
**Tech Stack:** Flutter, Material 3, Supabase Postgres, existing SDK/UUID packages.
**Spec:** `docs/superpowers/specs/2026-11-17-report-comments.md`.

## Constraints and review focus

- Preserve existing reports, authentication, status workflows and user-owned `.agents/`.
- Verify own-only removal, private projections, stale sessions and unavailable reports server-side.
- Verify lost-response retries, post-delete replay, pagination during insertion and non-BMP text.
- Check narrow screens, enlarged text, loading failures and a successful write followed by failed refresh.
- Public comments are plain text; no implicit authority endorsement or status changes.

## Run manifest

Base: `c03e9af`, branch `main`, tracked tree clean; untracked `.agents/` is user-owned. Scope S2: permissions, migration, idempotency and two client surfaces. Existing user authorization covers autonomous changes, hosted migrations, testing, runtime refresh and push. Single writer in the existing workspace keeps the emulator and local configuration available; reviewers are read-only. No nested delegation. Concurrency cap two reviewers; maximum three review rounds. Models explicitly AUTO/inherited because the runtime instructs inheritance unless the user requests an override; reasoning high for plan/client review, max for final security review. Effective sandbox is inherited workspace-write; reviewers are instructed to use read-only tools, no credentials, no external mutations. Actual model identity is not exposed by this tool. Parent owns planning, implementation, synthesis and evidence; independent reviewers gate plan and final integration.

## Tasks

- [ ] Review the plan independently while writing initial failing service/controller and rollback-only SQL tests.
- [ ] Implement `008_report_comments.sql`: private table, verified RPCs, keyset pagination, own-only body-erasing deletion, serialized idempotency. Run candidate migration plus security assertions in one rollback-only hosted transaction.
- [ ] Implement `domain/report_comment.dart`, `data/report_comments_service.dart`, `application/report_comments_controller.dart` and session-only preview data. Test validation, pagination, mutations, unknown outcomes and stale sessions.
- [ ] Implement `widgets/report_comments_panel.dart`; integrate citizen details and authority editor. Verify shared use, responsive/dark/enlarged text, retry, deletion confirmation and successful post feedback.
- [ ] Independent security and client reviews; resolve findings. Run complete Flutter tests/analyzer and existing SQL regressions; deploy migration and test live API with disposable fixtures, including concurrent retries.
- [ ] Build web/Android, inspect browser and emulator behavior, update README/backend docs, remove fixtures, leave both clients running, commit and push; verify remote SHA.

## Rollout and rollback

Apply forward migration through the authenticated Supabase CLI to the existing dedicated project after rollback-only checks. Old clients ignore the new RPCs. Reverting the client commit hides comments without deleting data; retain the schema and private rows rather than a destructive down migration. Record command results, reviews and live checks in a delivery note.
