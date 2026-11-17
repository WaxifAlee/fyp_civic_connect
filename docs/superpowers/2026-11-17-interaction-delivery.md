# Familiar interaction delivery — November 17, 2026

## Revision and scope

Implementation: `557c44eaa3e68437d73b56274f14ac76f40a5f15`; reviewed fixes: `3eeb6b47657723cb2a5e3fd53114ae901ee00c79`. Base: `aafaf52a94781d3a934c9af9acf83def4de11092`.

The user requested familiar modern app behavior, explicitly including pulling down to refresh, and authorized autonomous gap fixing. This increment uses the existing Material 3 theme, Public Sans and evergreen palette. It introduces no package, schema, credential or backend deployment changes.

## Acceptance evidence

| Behavior | Implementation | Observed verification |
| --- | --- | --- |
| Pull down to refresh | CivicPage with adaptive RefreshIndicator, always-scrollable main surface; Overview, Explore, My Reports and authority queue opt in | Gesture test on short/empty content; each screen exposes refresh; Android screenshot captures refresh above the existing report |
| Keep reports visible | Initial loading is separate from refreshing; failed refresh displays feedback with the last snapshot | Citizen controller failure regression; authority workspace held-response/error regression; native existing report remains visible during hosted refresh |
| Safe refresh concurrency | Coalesced citizen reads; mutation revision checks; support receipts update current models by ID | Both refresh/support completion orders, delayed delete response and account-change tests |
| Matching authority snapshots | Successful queue snapshots carry all five query criteria and account identity; membership changes notify before the next queue finishes | Five failed-criteria regressions; held queue with changed department verifies immediate notification |
| Predictable navigation and keyboard | Current destination scrolls to top; scrolling/search dismisses keyboard; first invalid form field is revealed and focused | Phone navigation/search widget tests; small-screen signup focus test; real browser active-tab and Enter checks |
| Reachable report controls | Fixed header and Close; body scrolls above keyboard inset | Phone enlarged-text/keyboard tests; Android long-discussion inspection; browser phone screenshots |
| Safe draft departure | Shared LeaveGuard covers Back, modal dismissal and AppShell replacement; header drag uses guarded dismissal | Report/account/comment/staff draft tests; barrier, Back, header-drag and root-platform-exit tests; real browser and native cancellation/discard |
| Preserve retry identity | Citizen/staff dialogs own their discussion controllers; unresolved comments/service updates remain open for the original retry | Unknown comment close/Back and staff Close regressions verify the same request ID; reattached controller test verifies visible text matches its draft |

## Automated checks

- `flutter test --no-pub --reporter expanded`: **210 tests passed**. Includes existing authentication, account reconciliation, report submission recovery, storage, map, comments and authority workflows.
- `flutter analyze --no-pub`: **No issues found**.
- Configured release web build with `GOOGLE_MAPS_ENABLED=false`: **passed**, including Wasm compatibility dry run.
- Configured Android debug APK: **passed**. Existing Gradle/Kotlin future-support notices remain unchanged.
- `git diff --check`: **passed**.

Regression cases were observed failing before fixes: overlapping refresh requests; delayed reads overwriting deletion/support; report/account draft loss; offscreen detail Close; unfocused first signup error; unsafe root dismissal; mismatched authority criteria; delayed scope notification; hidden reattached comment drafts; and the opposite support/refresh ordering.

## Browser and Android

The final release web build is served at `http://localhost:8080`. Playwright exercised sample-data refresh controls, compact filters, search Enter, active-tab scroll-to-top, fixed phone detail controls, comment post/removal, and comment/report/staff draft cancellation and deliberate discard. Browser checks reported zero page errors. Screenshots in the README contain isolated sample data.

The final debug APK is installed and launched in `emulator-5554`. Native checks verified the actual Supabase report feed, pulling to refresh while retaining the existing `MC00005`, a report draft retained after Keep editing, and a comment draft retained after Keep editing using the fixed Close control while the keyboard was open. Both synthetic unposted drafts were deliberately discarded. No hosted report, support, comment, photo or account was modified for these checks.

Supabase continues to provide the hosted backend; a separate application API process is unnecessary. Existing local configuration remains ignored and unchanged.

## Review and limits

A read-only scout identified draft, dismissal and focus gaps. An independent reviewer inspected the fixed source revisions. Its first pass found three actionable state transitions; each received failing regression coverage and a focused fix. A fourth vote/refresh ordering was independently reproduced and fixed as well. Final focused review at `3eeb6b4`: **PASS**, no remaining concrete blockers. The resident confirmed completed final builds and runtime evidence after that source review.

Agent models inherited the parent per runtime policy; exact identities are not exposed. Both review roles requested high reasoning effort, shared the managed workspace sandbox and were restricted to read-only source inspection without backend access or further delegation. The resident performed implementation, tests and runtime verification.

Unsubmitted form and discussion drafts live only while the application remains open. Leave protection does not restore them after process termination or browser reload. Interrupted report submissions retain their existing persistent journal. Retained lists show a last-loaded snapshot after a connection failure; automatic realtime updates and durable offline caching are outside this increment.

Rollback is a normal source revert followed by rebuilding the clients. No database rollback or migration is necessary.
