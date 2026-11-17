# CivicConnect: Supabase backend design

Date: November 17, 2026. Scope approved by the user: move authentication, accounts, reporting, and photos from the mixed Firebase/Supabase integration to a new Supabase project. Existing remote projects are left untouched; importing historical Firebase records is outside this migration.

## Application boundaries

The Flutter client uses Supabase Auth and authenticated PostgreSQL RPCs. Initialization requires a project URL and public client key; preview mode skips initialization. Server migrations run with the CLI before the application starts. The client never provisions database objects or receives privileged keys.

Citizen identity is stored in an owner-only profile created by an authentication trigger. Confirmation is checked against Supabase Auth's server-owned `email_confirmed_at`, rather than editable user metadata. Phone and CNIC uniqueness are database constraints. The report feed exposes a deliberate projection of report details, citizen display name, and avatar; identity and contact fields remain private.

## Consistency and permissions

Report creation validates content, department, location polygon, owned photo paths, and existing storage objects. A database transaction allocates a department reference and inserts the report. A caller-supplied request UUID serializes concurrent retries and returns the original reference only for the same owner and payload. The client retains uncertain requests across restarts and never deletes photos while a request may still commit.

Support uses a separate unique citizen/report relation and a locked report row, keeping the displayed count consistent with committed support. Clients see their own support state, not other supporters' identities. Report deletion requires ownership and returns authoritative object paths for subsequent cleanup. Status changes and direct manipulation of counters, authors, or support counts are unavailable to citizen clients.

Storage writes require a verified session and an object path under the authenticated UUID. Public buckets intentionally serve community photos. Referenced files cannot be deleted by a citizen while the report or profile still uses them. Upload compensation is best-effort; ambiguous responses favor retaining an object over breaking a saved report. Maintenance must identify unreferenced objects conservatively.

## Authentication and native behavior

Unconfirmed registration does not grant data access or attempt photo upload. Avatars are added from Account after confirmation. Verification and recovery links use `io.supabase.civicconnect://auth-callback/` on mobile and the configured origin on web. The application registers auth navigation before exchanging callback codes so a cold-start recovery event can reach the password form. Password changes reauthenticate with the current password, preserve password text exactly, and require a fresh sign-in afterward.

## Delivery checks

Verification covers Flutter unit/widget tests, static analysis, normal/preview web builds, a live Android build, SQL permission and transaction tests, and real authenticated API/storage requests against the new project. Independent review focuses on authentication, private identity, storage references, retry outcomes, and database concurrency. Deployment evidence and remaining operational setup are recorded separately.
