# Authority workspace

CivicConnect includes a service-team workspace at `/#/authority`. It shares the citizen application's Supabase sign-in and theme. Open **Service-team workspace** from the welcome page or **Authority workspace** from the navigation or mobile header. A signed-out direct link opens staff sign-in and returns to the workspace after authentication.

## Access and setup

Apply the versioned migrations with `supabase db push --remote --yes`. Migrations `20261117000600` and `20261117000700` install membership, progress history, versioning, scoped reads and transactional updates with HTTP 409 conflict responses. No separate API process is required.

Register and verify the staff account first. In a trusted SQL environment, customize and run [authority_membership.sql](../supabase/admin/authority_membership.sql):

- `admin`: all departments; department must be `NULL`.
- `department`: one existing department value, including the legacy `Municipal Corportaion` spelling. The UI displays its friendly label.

Membership is held in a private table. Only trusted database administration can grant, change or revoke it. Citizen registration, editable user metadata, URL routes and browser state cannot grant authority access. Revoke access by setting `active=false`; mutations check current membership and serialize with membership changes. Staff accounts still have a normal citizen profile, without gaining access to other citizens' CNIC, phone or contact details.

## Review and publish

1. Use the status counts to narrow the queue. Counts always cover the team's entire authorized department scope; the table follows the search and filters.
2. Search a title, reference or description, choose a department if you are an administrator, and order by oldest, newest or most supported. Requests return 20 reports per page.
3. Select **Review** to inspect the description, report photos, precise coordinates and published history. **Open location in Maps** opens the reported coordinates in a separate map application.
4. Select a permitted status and write a public progress note of 10–1,000 characters. Notes are visible in citizen report details; include the outcome or next step and avoid private information.
5. **Publish update** saves the status and note in one database transaction. The editor reloads committed history and refreshes the queue.

Permitted changes are Submitted → In progress or Closed; In progress → Resolved or Closed; and Resolved/Closed → In progress to reopen. Same-status notes are also supported. Submitted reports must enter In progress before being resolved.

If another team member changed the report, reload its latest version. Your unpublished note is preserved; a status that is no longer permitted resets to the current status for review. If a response was lost, the draft is locked and **Retry same update** reuses the original request. Reloading an uncertain update checks current history, refreshes the queue and clears that uncertain draft. The database keeps a durable request receipt and an immutable progress ledger; retries cannot create duplicate notes or overwrite another update.

Reporter deletion preserves audit identities while preventing their report UUIDs from being reused for unrelated content. Citizens retain their existing report deletion workflow; deleted reports are no longer visible through progress APIs.

## Citizen dashboard

Overview counts now open the matching personal report queue and include Closed reports. Report details load service updates and align the visible status with the latest loaded progress. Citizens refresh their feed or overview to obtain new counts; the app does not claim push or real-time notification delivery.

## Preview and checks

Enter the existing demo, then open **Authority workspace**. Sample reports and updates remain in memory and never reach Supabase. The workspace explicitly labels its demo state.

```bash
flutter analyze
flutter test
flutter build web --release --dart-define-from-file=config/backend.local.json \
  --dart-define=GOOGLE_MAPS_ENABLED=false
python3 -m http.server 8080 --directory build/web
```

Database regression files [authority_security.sql](../supabase/tests/authority_security.sql) and [backend_security.sql](../supabase/tests/backend_security.sql) use synthetic, rollback-only fixtures. Run them through trusted `supabase db query --remote --file ... --yes` on the migrated project or `psql` on a disposable migrated database. The offline platform fixture is only for an empty local PostgreSQL database and must never be run on Supabase.
