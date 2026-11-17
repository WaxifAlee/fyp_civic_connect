# Authority workspace

## Intent and direction

Add a web-first service-team workspace to the existing Flutter application, as requested after completing map pin selection. Citizens continue reporting and following issues; staff triage their department's queue and publish clear, visible progress updates. Keep the existing evergreen, neutral surfaces, Public Sans and outlined Material icons. Favor compact operational tables, clear status counts, bounded pagination, accessible controls and responsive detail views.

The user requested autonomous implementation and selected an authority/admin dashboard in addition to the existing citizen experience. Implementation choices below are agent decisions within that scope.

## Scope

- Separate `/authority` route, a discoverable service-team entry, explicit access/loading/error states and an offline labeled demo.
- Administrator access to all departments; department staff access only to their assigned department. Membership comes exclusively from trusted database administration, never registration metadata or a client-side toggle.
- Search by title/reference/description, department/status filters, oldest/newest/support sorting, page navigation, accurate scoped totals and a report detail workspace.
- Publish a required public progress note with a status change or same-status update. Show immutable progress history to staff and citizens.
- Database-controlled optimistic versions, permitted status transitions and idempotent update requests prevent lost edits and duplicate updates.
- No staff access to private citizen identity/contact fields; no deletion, arbitrary report editing or self-service staff grants.

## Approaches

Extend the shared Flutter codebase and Supabase migrations rather than create a separate web stack or introduce a new application API. This shares authentication, theme and report contracts and keeps authorization in PostgreSQL. A dedicated authority screen provides a denser work surface than the citizen shell. Trusted SQL provisioning keeps the initial membership boundary small and auditable; a user management application is outside this iteration.

## Backend contract

Migrations `20261117000600_authority_workspace.sql` and `20261117000700_authority_conflict_http.sql`:

- `civic_private.authority_members(user_id uuid primary key references auth.users, role text admin|department, department text nullable, active boolean)`; admin requires null department, department role requires one existing category. No API table privileges or public signup integration.
- `reports.version integer NOT NULL DEFAULT 0` and `updated_at timestamptz NOT NULL DEFAULT now()`.
- Private audit records with unique `request_id`, report/actor IDs, prior/new canonical status, required trimmed 10–1000 character public note, expected/new version, timestamp. Client table reads/writes denied.
- `get_authority_access()` returns null for verified nonmembers or `{role,department}`. All other authority RPCs deny missing/inactive/unverified membership.
- `authority_dashboard(p_query text='', p_status text=null, p_category text=null, p_sort text='oldest', p_limit integer=20, p_offset integer=0)` returns `{reports:[],total:int,counts:{total,pending,inprogress,resolved,rejected}}`. Counts cover the entire permitted department scope; total/rows honor filters. Limit 1–50; offset nonnegative; query <=120; strict category/status/sort validation. Literal case-insensitive search; deterministic order. Scoped rows use the existing public report JSON keys plus `version` and `updatedAt`; exclude private profile identity/contact data.
- `authority_report_detail(p_report_id uuid)` returns `{report:{...},history:[]}` only within current membership scope. History is newest first, max 100, with `{id,fromStatus,toStatus,note,createdAt,version}`.
- `authority_update_report(p_report_id uuid,p_expected_version integer,p_status text,p_note text,p_request_id uuid)` authorizes current membership and department, serializes request/report, and atomically increments report version/status/updated_at plus inserts one audit event. Identical request replay is allowed only for the same actor and payload; mismatch is validation failure. Version conflict uses SQLSTATE `PT409`, forbidden scope `42501`, invalid inputs/transitions `23514`. Return `{id,status,version,updatedAt}`; clients reload committed detail/page after success or uncertain outcomes.
- Allowed changes: pending -> inprogress/rejected; inprogress -> resolved/rejected; resolved/rejected -> inprogress; same-status notes allowed. Pending cannot jump directly to resolved.
- `get_report_progress(p_report_id uuid)` returns a bounded public history array for verified citizens of an existing report, without actor IDs or request IDs. Public notes are intentionally visible with the public report.
- Security definer functions use empty search paths, explicit qualification, revoked PUBLIC execution and narrow grants. Membership changes must be serialized/locked for authority mutations to honor revocations.

## Frontend boundaries

- `features/authority/domain`: access/report version/page/progress contracts and transition labels.
- `features/authority/data`: RPC boundary, exact response validation, storage URL conversion, preview data and useful errors.
- `features/authority/application`: session-safe loading, pagination/filter state, stale response suppression and committed update refresh.
- `features/authority/presentation` and widgets: dedicated responsive workspace, metrics, queue table/cards and keyboard-usable report editor/history. No privileged keys in clients.
- Citizens gain a progress-history panel in report details. Demo mutations stay in memory and are explicitly labeled.

## Acceptance and verification

Exercise nonmember/anonymous/unverified/inactive access, department isolation, metadata spoofing, direct writes, invalid/null inputs, transitions, stale versions, retries and audit immutability. Test client filters/pagination and async races, access/error/empty/retry views, update validation, mobile/desktop/dark/large text, and preview isolation. Build Android and release web, inspect the real browser, deploy migration to the dedicated Supabase project, smoke-test synthetic staff/citizen accounts and leave the Android app and local web server available.
