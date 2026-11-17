# Supabase migration delivery

Verified on November 17, 2026, following the [interface redesign](2026-11-17-redesign-delivery.md).

## Delivered behavior

CivicConnect now uses Supabase for authentication, private citizen accounts, reports, support, and photos. Firebase SDKs, active configuration, and native build plugins have been removed. A new dedicated `civic-connect` project was provisioned in Mumbai (`ap-south-1`); existing projects were not modified. Historical Firebase data was not imported.

The Flutter client receives only the project URL and public client key. Operator credentials, local test credentials, and CLI link state are excluded from Git. The Android startup script applies pending migrations to the project identified by the selected client configuration before starting Flutter. The hosted backend runs independently of that process.

## Server migrations

| Version | Responsibility |
| --- | --- |
| `20261117000100` | Private profiles, reports, counters, support relations, validation, signup trigger, and identity protection. |
| `20261117000200` | Report/avatar buckets, MIME and size limits, and owner-scoped storage policies. |
| `20261117000300` | Verified profile/report RPCs, references, feed projection, support, and ownership checks. |
| `20261117000400` | Shared media locks, reference protection, and durable deletion cleanup. |
| `20261117000500` | Retired submission IDs, terminal deletion reconciliation, and avatar-only updates. |

All five versions were applied with the authenticated Supabase CLI. Future database changes must use forward migrations. The application does not run privileged SQL or initialize schemas from the client.

## Recovery and privacy

- Profiles are created atomically with Auth users and remain inaccessible until email confirmation. CNIC and identity ownership are immutable. Citizen clients cannot directly change status, counters, or report authors.
- The community feed exposes report content, display name, avatar, support count, and the caller's own support state. Contact details and other supporters' identities are excluded.
- Upload and reference checks share database locks with file deletion. Referenced photos remain protected even when attachment and deletion overlap.
- A local request journal stores each account/request separately before dispatch. Recovery reloads storage, confirms the original request, and removes only its own entry. It works after restart without picker files and preserves a different current draft.
- Deleted submissions remain terminal after storage cleanup. A delayed create cannot resurrect them; other accounts cannot inspect their tombstones.
- An uncertain account write invalidates cached data and requires reload. Changing an avatar does not replay cached contact fields.
- Callback navigation handles recovery events before and after app mount. Consumed browser callback parameters are removed from history. PKCE requires the originating browser/device.

## Verification evidence

Environment: Flutter 3.47.1, Dart 3.13.1, Supabase CLI 3.2.0, JDK 17, Android API 36 emulator (`emulator-5554`).

| Check | Observed result |
| --- | --- |
| `flutter analyze` | No issues. |
| `flutter test --reporter expanded` | 131 tests passed. |
| Account reconciliation/service tests after final lint cleanup | 21 tests passed. |
| Configured release web build | Passed, including the Wasm compatibility dry run. |
| Preview release web build | Passed, including the Wasm compatibility dry run. |
| Configured Android debug APK | Built successfully. |
| `supabase/tests/backend_security.sql` on the new project | Passed; synthetic users and metadata rolled back. |
| `supabase db lint` on the new project | No schema errors. |
| Authenticated live Auth/Storage/PostgREST checks | 12 groups passed; disposable accounts removed. |
| Android native smoke | Sign-in, photo picker, manual coordinates, upload/create, saved report details, support, and confirmed deletion succeeded. |

The native smoke created synthetic report `MC00002`. Its photo loaded from Supabase, support changed from zero to one, and deletion returned the empty My Reports state. A subsequent authenticated API check confirmed no test report, report photo, or cleanup manifest remained for that citizen. The test account is retained locally for interactive testing; its credentials are not in this repository.

Live API checks covered private profile isolation, denied anonymous/direct writes, owned storage paths, sequential and concurrent idempotent creation, changed-payload rejection, concurrent support consistency, cross-owner deletion denial, reference protection, authoritative cleanup, deleted-request replay before and after cleanup, profile updates, and avatar-only preservation of contact fields.

Regression coverage also includes preview isolation, session changes during asynchronous operations, browser-tab journal interleaving, restart recovery without a populated form, consumed web callback reloads, cold/warm auth navigation, uncertain account writes, geographic boundaries, image validation, theme contrast, responsive navigation, and reduced motion. The local-only concurrency harness additionally exercises overlapping database transactions; its platform fixture must never be deployed to hosted Supabase.

Two independent reviews examined authentication/correctness and SQL/privacy/concurrency. Their recovery findings were fixed and verified. A separate final reviewer approved the frozen implementation and inspected the recorded test/build evidence; final follow-up edits only removed an unused exception variable and added required braces. No outstanding correctness or security findings remained in that review scope.

## Operational limits

- Configure custom SMTP and production redirect origins before inviting real users. Actual confirmation/reset inbox delivery and a complete emailed PKCE exchange were not verified. An admin-generated implicit recovery link is not compatible with the client's PKCE flow and is not evidence for that exchange.
- The Linux environment did not verify an iOS build. Android uses debug signing and the example application ID until release configuration is supplied.
- Maps are disabled by default; manual coordinates and the service-area checks work. Configure restricted platform keys before enabling the interactive map.
- Photos are intentionally public. Private identity data is excluded from the feed, but citizens must avoid sensitive material in report text or images.
- Unreferenced upload maintenance, production monitoring/backups, authority status management, and push notifications require separate operational setup. No administrator dashboard is included.

See [Backend operations](../backend.md) and the [README](../../README.md) for repeatable setup, startup, verification, and deployment instructions.
