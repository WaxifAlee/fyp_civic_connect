# Authority workspace delivery — November 17, 2026

## Delivered behavior

The shared Flutter application now includes `/#/authority`, with verified sign-in, department or administrator access, scoped status counts, literal search, filters, deterministic sorting and bounded pagination. The responsive queue opens a report editor with photos, coordinates, map links and published history. Staff publish a permitted status and a required public progress note atomically.

Citizen overview metrics open the matching personal queue, including Closed reports. Citizen report details load public service progress and align their status badge with the latest loaded update. Preview edits remain in memory and are explicitly labeled.

Authority code is separated into domain, data, application, presentation and widget layers. Status badges and progress history are shared with citizen report details. The README includes the workspace preview and links to the provisioning/workflow guide.

## Database and operational checks

Migrations `20261117000600` and `20261117000700` are applied to the dedicated CivicConnect Supabase project. Membership is private; authenticated users cannot self-grant roles or write directly. The database checks live membership and department scope, locks membership/report rows, and appends immutable audit events with version checks and durable request receipts.

Both `supabase/tests/authority_security.sql` and `supabase/tests/backend_security.sql` passed on the final deployed schema with rollback-only fixtures. Authority fixtures capture pre-existing counts and use their own search references without deleting or modifying existing reports. Candidate migration/security checks also ran transactionally on this project; no local PostgreSQL server was available.

Live public-client API checks with isolated synthetic accounts passed:

- Verified staff access, citizen denial and staff isolation from private citizen profiles.
- Department-scoped queue/detail/update permissions, with administrator access across departments.
- Four concurrent identical updates returning one receipt, version and public note.
- Competing requests at the same version producing one commit and one HTTP 409 conflict.
- Citizen-visible committed progress without actor/request identifiers.
- Revoked membership rejecting a previously issued JWT.
- A separate lock-ordering check held a mutation transaction open; revocation waited for it to commit, then rejected the old session. The retained administrator membership was restored afterward.

The HTTP checks exposed PostgREST retrying manually raised SQLSTATE `40001`. Migration 007 preserves the applied migration history and replaces that business error with `PT409`, producing a non-retrying HTTP 409 response. Live concurrency was rerun successfully. See the [Supabase explanation](https://supabase.com/kb/troubleshooting/high-cpu-and-infinite-transaction-retries-when-using-custom-error-codes-in-rpc-functions-77326b).

Live synthetic reports, their uploaded photos and temporary department accounts were removed after verification; immutable test audit receipts remain private by design. Existing reports were preserved.

An isolated verified administrator login is stored only in ignored `config/authority-test-account.local.json` with mode 0600. Public client configuration remains in ignored `config/backend.local.json`; no administrative credentials belong in Flutter builds. The reusable `supabase/admin/authority_membership.sql` template grants or revokes real staff access through trusted administration.

## Client verification

- Full Flutter suite: **160 tests passed**. The final HTTP-conflict mapping also passed all **9 authority service tests**.
- `flutter analyze --no-pub`: no issues.
- Dart formatting: 90 files checked, no changes required. `git diff --check`: clean.
- Release web build and WebAssembly compatibility dry run: passed.
- Android debug APK build, emulator installation, launch and verified citizen sign-in: passed.
- Chromium demo queue, progress publishing and responsive phone layout: passed with no application errors.
- Chromium live administrator sign-in, synthetic-report publishing, committed history response, cold session restoration and phone navigation between citizen/authority views: passed with no application errors.
- Chromium citizen sign-in showed staff denial, returned to My Reports and opened the published service history. Settled dark-theme and mobile-editor captures were visually inspected.

## Independent review

A separate backend worker implemented the database contract. Fresh read-only security and client reviewers examined frozen snapshots. Security review identified a UUID reuse edge case after reporter-account deletion; an insert trigger now protects retained audit identity, and its regression reproduced failure before the fix and passed afterward.

Client review identified account switching before mutation, conflict draft loss, queue refresh after uncertain outcomes, mobile entry discoverability and acknowledged updates becoming new drafts after refresh failure. Each received a failing regression test before its fix; the final findings-only follow-up confirmed resolution.

## Scope and handoff

Service notes are intentionally public to verified citizens. The workspace does not provide staff self-administration, arbitrary report editing, report deletion or push notifications. SQL provisioning remains trusted administration. Android uses a debug build; no iOS build was run in this Linux environment. Web maps require separate SDK setup, while native map picking remains enabled in the configured Android build.

The local web server serves `build/web` on port 8080. Supabase is hosted, so no additional application API process is required. The Android emulator is left running against the same project.
