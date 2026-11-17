# Backend operations

CivicConnect runs on Supabase Auth, PostgreSQL, and Storage. There is no local application API process. Use the CLI for schema deployment; Flutter connects with the project's public client key.

## Initialize a server

Use Supabase CLI 3.x, authenticated with an account that can administer the target project. Create a dedicated project in the dashboard or with `supabase projects create`, then run from the repository root:

```bash
supabase link YOUR_PROJECT_REF
supabase db push --remote --dry-run
supabase db push --remote --yes
supabase config diff
supabase config push --yes
```

Review both diffs first. Migrations are ordered under `supabase/migrations/`; the CLI's migration history prevents replay on later starts. Use new forward migrations for schema updates. Never use a remote reset for routine initialization or upgrade. Back up populated projects before changes.

The native callback is `io.supabase.civicconnect://auth-callback/`. Local web development uses port 8080. Configure the deployed web origin in Supabase Auth's site and redirect URLs before hosting the app. The config file is intentionally small so unrelated project settings remain unchanged.

Copy `config/backend.example.json` to `config/backend.local.json` and fill in the public project URL and publishable key. Run `./scripts/start_android.sh` to apply pending migrations to that configured project before Flutter starts. The script requires Python 3 to read the JSON configuration and an already running emulator. A different project URL targets that project explicitly rather than relying on a stale CLI link.

## Data and API boundaries

| Resource | Access and purpose |
| --- | --- |
| `profiles` | One per Auth user; verified owner can read. Full name, phone, CNIC, address, gender, avatar path, timestamps. Email remains in Auth. |
| `reports` | Validated issue content, author, location, photo paths, status, reference, and support count. Accessed through RPCs. |
| `report_counters` | Atomic department reference allocation; inaccessible to citizen clients. |
| `report_supports` | One support relation per citizen/report; inaccessible directly. |
| `report_cleanup` | Private owner-scoped manifest for retrying photo cleanup after report deletion. |
| `civic_private.report_tombstones` | Retired request IDs; survives cleanup and prevents deleted reports from being recreated by delayed retries. |
| `reports-images` | Public community photos; verified uploads/deletes restricted to the owner's UUID folder. |
| `profile-pictures` | Public avatars with the same ownership requirements. |

Signup creates the profile in the same database transaction as the Auth user. Invalid or duplicate identity data aborts registration. An unconfirmed account cannot read profiles, call report RPCs, or upload files. Confirmation checks use Auth's server-owned timestamp. Mutable user metadata never grants a role or bypasses verification.

| RPC | Purpose |
| --- | --- |
| `update_profile` | Update the caller's display name, phone, address, and owned avatar. CNIC and identity ownership stay immutable. |
| `update_avatar` | Change only the owned avatar, without replaying cached contact fields. |
| `list_reports` | Verified feed or own reports, in bounded pages; no contact/identity data or other voters' IDs. |
| `create_report` | Validate content, service-area coordinates, and owned uploaded photos; atomically allocate reference and save. |
| `get_report_submission` | Retrieve the caller's saved request or terminal deletion result for reconciliation. |
| `toggle_report_support` | Lock the report and atomically toggle one support relation. |
| `delete_report` | Remove an owned report and return its authoritative photo paths. |
| `list_report_cleanup` / `complete_report_cleanup` | Resume owner-scoped photo cleanup and acknowledge it only after the objects are absent. |

Only a trusted administrative process can change report status. The repository does not provide an authority dashboard. Do not expose administrator keys to add one to the citizen client.

## Email and recovery

Enable custom SMTP in Supabase before inviting real users. The default mail provider restricts recipients and volume. Configure a sender domain, permitted redirect URLs, and confirmation/recovery templates for your environment. The app reports send failures honestly and provides retry; it does not treat a rejected request as a delivered message.

Native links are handled by `app_links`, then exchanged through Supabase Auth. Recovery links open the password form, including on a cold start. Web callbacks remove consumed credentials from browser history so a reload cannot replay the code. PKCE flows must be completed on the device/browser that initiated them. Verify email delivery and callbacks on the actual deployment; SQL and preview tests cannot establish inbox delivery.

## Database verification

Run the rollback-only SQL integration suite against a fresh test project:

```bash
supabase db query --remote --file supabase/tests/backend_security.sql --yes
supabase db query --remote --file supabase/tests/authority_security.sql --yes
supabase db query --remote --file supabase/tests/report_comments_security.sql --yes
supabase db lint --remote
```

The suite uses synthetic users and storage metadata inside a transaction, then rolls it back. It exercises owner isolation, unconfirmed/anonymous restrictions, immutable fields, storage paths, geographic validation, references, idempotency, and support behavior. Review the test source before running it against a project containing real data.

The optional concurrency harness, `supabase/tests/concurrency.py`, requires a disposable PostgreSQL database on a local Unix socket. `supabase/tests/local_platform_fixture.sql` supplies a minimal Auth/Storage test platform for that database only. Never apply that fixture to a hosted Supabase project. Apply the normal migrations after the fixture, then invoke the harness with `--socket`, `--port`, and `--database`. Discard the local database afterward.

Flutter checks remain separate:

```bash
flutter analyze
flutter test
```

## Storage and retry maintenance

Report creation persists its request UUID and canonical payload before dispatch. Each account/request owns a separate local journal key; one tab cannot clear another request when confirming its own. The database serializes identical requests and returns the original reference; a conflicting owner or payload is rejected. A missing lookup result cannot prove that a network request will never commit. The report form offers recovery independently of current fields or temporary picker files and keeps a changed draft intact.

Deletion records a private tombstone in the same transaction as the cleanup manifest. An owner lookup returns a terminal deletion result, even after cleanup completes; other users receive no result. Reusing that request ID cannot create a new report. The client removes only the matching journal record after a confirmed save or deletion.

The client retains photos after an ambiguous create response. Referenced objects cannot be deleted through citizen policies; attachment and deletion share database locks to cover concurrent transactions. After successful report deletion, cleanup removes the returned paths and retries from the durable manifest on later account report loads. Connectivity failures may temporarily leave unreferenced files. Avatar replacement can also leave a prior image. Periodically review unreferenced objects with a conservative age threshold and verify that no report, profile, or pending request still needs them before deletion. Do not delete recent uploads merely because they are not yet referenced.

Account entry reloads the server profile. A write with an unknown outcome invalidates the cached profile and requires refresh before more edits. Avatar changes use a separate RPC, preserving contact fields committed by another request.

Buckets intentionally serve public photos. Avoid sensitive personal information in community photos. CNIC, phone, address, and account email are not part of the report feed.

## Credentials and release operations

Keep database passwords, access tokens, and secret/service-role keys in server-side secret storage. Only the project URL and public key belong in a Flutter build. Local configuration, CLI link state, and environment files are ignored by Git.

An older revision exposed credentials for a different Supabase project and image-compression provider. Revoke those original credentials in their provider accounts; deleting source does not revoke a key. The replacement project uses separate credentials.

Use production Android signing and a final application ID before distribution. Validate iOS builds on macOS. Configure backups, SMTP, operational monitoring, and an authorized status-management process for production. Free hosted projects can pause after inactivity; check project health before a testing session.

## Service-team permissions and progress

Migrations `20261117000600` and `20261117000700` add the [authority workspace](authority-workspace.md). Membership is private and granted only through trusted database administration; metadata never grants a role. Department staff can review/update their own department, while administrators can review all departments. Public notes are visible to verified citizens without exposing audit actor/request IDs or private profile identity/contact fields.

Status updates lock current membership and report rows, check the expected version and permitted transition, then append an immutable request receipt with the status change. Identical retries return the original receipt; conflicting versions require reload. Retained history prevents report UUID reuse even after reporter-account deletion. [authority_security.sql](../supabase/tests/authority_security.sql) covers the added boundaries with rollback-only fixtures.

## Report discussions

Migration `20261117000800` adds comments through `list_report_comments`, `add_report_comment`, and `delete_report_comment`. The private RLS table has no API-role grants. Every RPC requires a verified account and an existing report. Public responses contain only the comment ID, report ID, text, display name, creation time, and an ownership flag. Staff use the same discussion and own-only removal rules as citizens; official status updates retain their separate authority permissions.

Posts are plain text with 1–1,000 Unicode code points after Unicode whitespace trimming. The client preserves a UUID across uncertain retries. The database serializes add/remove on that UUID and binds it to the author, report, and canonical body digest. The public comment ID doubles as this UUID and never grants access. Removal erases the body and retains a private SHA-256 tombstone; delayed post retries return terminal HTTP 409 instead of resurrecting it. Report and account deletion cascade the associated rows. Known successful posts appear from their validated receipt even if a later read fails.

Listings use `(created_at,id)` keysets, a default of 20 comments and a server maximum of 50. Flutter retains the exact server timestamp for its next cursor, including microseconds on web. Activity updates when the user refreshes or reopens the report; there are no realtime subscriptions. Preview discussions stay in memory. The [rollback-only comment suite](../supabase/tests/report_comments_security.sql) covers privacy, verification, ownership, Unicode, replay, pagination and cascading deletion.
