# Report comments and compact Explore delivery

Runtime source: `9302a33`; feature implementation: `3822733`. Supabase migration `20261117000800_report_comments.sql` is deployed. Independent client review and the security/data/concurrency gate passed. No blocking findings remain.

## Delivered behavior

- Citizen details and the authority editor share a public, verified-account discussion with display names, local timestamps, plain-text comments and own-only removal confirmation.
- Bodies use 1–1,000 Unicode code points. Posting preserves its UUID through uncertain outcomes; removal erases the body and prevents replay from resurrecting it. Preview writes remain in memory.
- Bounded keysets preserve exact server timestamp precision. Refresh, older pages, loading failures and stale-session handling are explicit.
- Explore uses a compact search/filter row, a sheet for category/status/sorting, staged apply/reset/cancel and small summaries of active choices.
- The real report sheet contracts above keyboard insets. Existing theme tokens, bundled typography, accessible labels and Material controls are reused.

## Verification

| Boundary | Observed evidence |
| --- | --- |
| Flutter | All **182 tests** passed; analyzer reported no issues. |
| UI recovery | Service/controller tests cover unknown post/delete outcomes, unchanged retry identities, terminal deleted replay, stale accounts/responses, exact cursors, malformed receipts, disposal and failed refresh after a confirmed post. |
| Phone layout | Actual 375×812 report sheet at 1.5× text with 320px keyboard inset: original viewport incorrectly ended at 812px; corrected viewport and Post end above 492px and posting succeeds. Filter reset/cancel/apply passes at 2× text. |
| SQL | Candidate008 and new security assertions passed in one rollback-only hosted transaction; deployed comment suite passed. Existing citizen and authority SQL suites also passed. |
| Real HTTP | Eight verification groups passed: anonymous denial, six concurrent identical retries producing one row, private projections, ownership/forgery rejection, idempotent removal and terminal 409, insertion-safe pagination, Unicode limits, and concurrent add/remove. |
| Account races | `report_comments_concurrency.py` observed real blocking in independent SQL sessions. Add-first completed without deadlock; delete-first rejected the pending post after deletion. Its random fixtures were cleaned up. |
| Web | Release build passed. Chromium desktop/phone checks passed for compact filters, preview discussion, persisted citizen post/refresh, removal cancel/confirm and a staff reply in the same discussion; no application page errors. |
| Android | Debug build installed and launched. Compact Explore, hosted comment posting and confirmed own removal passed on `emulator-5554`; the original keyboard preference was restored. |
| Migration state | Supabase dry run reports up to date with zero pending migrations. |
| Cleanup | The synthetic report, comments and photo were removed; its discussion then returned 403. Original report `MC00005` remains present. |

Command evidence is under `/tmp/civic-supabase/comments-*` and `/tmp/civic-browser/comments-*` for this session. Temporary logs and local credentials are not repository artifacts. README screenshots contain isolated sample data.

## Review resolutions

Client review identified keyboard overlap, reproduced and fixed before release. Security review prompted profile-before-report locking to match account cascades and a complete report foreign-key index covering tombstones.

The suggested letter-v corruption was **falsified** on hosted PostgreSQL 17.12: the original escape evaluates to code point 11, and the original candidate passed the supplied `v`/vertical-tab assertions. The reviewer withdrew that finding. Explicit U+000B is retained for clarity, with regression assertions. Pasted NUL characters are rejected before dispatch.

Plan review used inherited model/high effort; client review used inherited model/high; security review and the final runtime gate used inherited model/max. The runtime does not expose actual model identifiers. Reviewers were read-only, with no credential access, network requests, edits or nested delegation. One main writer integrated all code; reviews were pinned to source commits.

Optional coverage beyond this delivery includes sustained-load measurements, a dedicated concurrent add/direct-report-delete schedule, keyboard focus traversal and parent reload during uncertain mutations through widgets. Service/controller tests and stable keyed panels cover the corresponding state safeguards. Discussions refresh explicitly; realtime delivery and staff moderation are outside this feature.

## Operations

The emulator is left running the final Android build and the web release remains served on local port 8080. Supabase supplies the backend; there is no separate API process. Reverting the client changes hides the discussion UI without deleting database data; retain the schema rather than dropping posted comments. Apply future schema changes through forward migrations.
