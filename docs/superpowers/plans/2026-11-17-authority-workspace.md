# Authority workspace implementation plan

**Design:** [Authority workspace](../specs/2026-11-17-authority-design.md). Existing explicit autonomous execution and push authorization apply. Main implements inline with a bounded database worker and fresh independent review.

## Run manifest

- Repository: fyp_civic_connect; branch main; base `810b261e9961364331b0e33fc8f38953e2512527`; only user-owned `.agents/` untracked before this task.
- Risk: S3 for new staff authorization and report mutations. Preserve citizen authentication, private identity data, submission idempotency and storage ownership.
- Main owns frontend, integration, cloud deployment, verification, docs and release. A single backend worker owns migration 006 and its SQL security tests; no cloud or private configuration access. Two fresh reviewers cover database security and client/UI independently after integration. No nested delegation.
- Agent model routing: AUTO inherited available model, as runtime requires inheritance unless the user requests a model override; high reasoning for bounded implementation/review. Worker tools: local source reads and assigned source writes only. Review tools: read-only frozen snapshots and test evidence. Concurrency cap 2; one initial review plus findings-only follow-up when needed.

## Tasks

- [x] Implement migration 006 and negative database authorization/concurrency tests against the documented RPC contract.
- [x] Add authority domain/service/controller with test-first coverage for filters, pagination, versions, session changes and uncertain writes.
- [x] Build responsive authority queue, metrics, report editor/history and entry/access states; add citizen progress history.
- [x] Run candidate and deployed security suites on the dedicated Supabase project (local PostgreSQL unavailable); provision isolated synthetic test staff through trusted administration.
- [x] Run analyzer/regression suite, Android and web builds; inspect browser and native layout/interactions.
- [x] Resolve independent security and frontend review findings and document setup/verification.
- [x] Prepare the reviewed release and leave both clients running.

Release procedure: commit the verified files, push to origin/main and confirm the remote commit matches the local HEAD.

## Review focus

Membership spoofing and revocation; cross-department access; stale concurrent updates and identical retries; public notes excluding private identity data; stale async data crossing sessions; ambiguous update failure; pagination/filter counts; narrow and large-text layouts; demo never writing hosted data.
