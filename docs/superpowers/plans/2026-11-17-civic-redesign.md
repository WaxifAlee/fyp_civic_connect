# CivicConnect redesign implementation plan

> **For agentic workers:** Use superpowers:executing-plans for the main integration and bounded independent implementation lanes.

**Goal:** Deliver a cohesive, accessible Flutter citizen reporting application with a maintainable feature structure.

**Architecture:** Shared theme and responsive application shell support focused feature modules. Keep backend schemas and provide explicit preview state for local review.

**Tech Stack:** Flutter, Material 3, Firebase Auth/Firestore, Supabase Storage.

**Spec:** `docs/superpowers/specs/2026-11-17-civic-redesign-design.md`

## Global constraints

- Preserve existing report/user schemas and named routes.
- Preserve user-owned `.agents/` files; no remote data changes.
- Use semantic theme colors, 48dp controls, readable flexible layouts, and reduced-motion support.
- Preview data must be labeled and must never invoke production writes.
- Use independent source copies for delegated writes; integrate only reviewed feature paths.

## Review focus

- Narrow screens and 2x text: content and primary actions remain reachable.
- Missing/malformed report fields: loading reports remains resilient.
- Search plus category/status/sort: filters compose and reset together.
- Async navigation/disposal: avoid setState or context use after dispose.
- Backend failure and preview mode: distinguish errors from empty results and prevent preview writes.

### Task 1: Foundations and data contracts (main)

- [x] Replace obsolete tests with report-parsing regression tests; observe baseline failures.
- [x] Add `app/app_session.dart`, `core/theme/app_theme.dart`, `core/widgets/`, and `app/app_shell.dart` using the spec contracts.
- [x] Introduce report taxonomy/filter helpers and resilient model parsing; preserve service schema.
- [x] Configure public storage keys and preview bootstrap without embedded privileged credentials.
- [x] Verify model tests and foundation analysis.

### Task 2: Authentication (isolated worker)

- [x] Analyze original auth, registration, verification, and reset flows.
- [x] Implement `features/auth/` using shared contracts, responsive forms, labels, autofill, inline validation, busy/error states, and mounted guards.
- [x] Preserve Firebase auth/user document semantics and password contents.
- [x] Return file list and integration notes; main verifies navigation and validation.

### Task 3: Report composition (isolated worker)

- [x] Analyze current report submission, category codes, image upload, and map boundary.
- [x] Implement `features/reports/presentation/report_issue_screen.dart`, location picker, and image picker with cross-platform XFile bytes.
- [x] Preserve report schema, image count, boundary checks, and visible submission success.
- [x] Ensure missing configuration and preview mode cannot write production data.
- [x] Return owned paths and verification notes.

### Task 4: Account and notifications (isolated worker)

- [x] Analyze profile editing, security, and notifications.
- [x] Implement `features/account/` with responsive profile/settings, theme choice, password change, honest notification state, and guarded logout.
- [x] Preserve account update semantics; no invented notification backend.
- [x] Return owned paths and verification notes.

### Task 5: Dashboard and browsing (main)

- [x] Implement dashboard with truthful report counts, task-focused report action, recent reports, and community guidance.
- [x] Build one reusable issue card/detail sheet with semantic status, images, category, and guarded vote/delete actions.
- [x] Implement Explore and My Reports with composed search/filter/sort, refresh, and meaningful states.
- [x] Rewire bootstrap/routes and replace former files with compatibility exports; remove obsolete duplicated widgets.

### Task 6: Integration and delivery (main + independent reviewer)

- [x] Integrate bounded worker files and resolve interfaces in one workspace.
- [x] Run `flutter analyze`, `flutter test`, and `flutter build web --release`.
- [x] Verify preview layouts and interactions at phone/tablet/desktop widths, dark mode, large text, and reduced motion.
- [x] Complete independent review, resolve material findings, and rerun affected checks.
- [x] Document architecture, local preview, real configuration, and remaining operational requirements in README.
