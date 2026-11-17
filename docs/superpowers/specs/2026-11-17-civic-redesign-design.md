# CivicConnect experience redesign

## Intent and audit

Make the existing Flutter citizen application easier to navigate, report local problems with, and track community progress. The user explicitly requested autonomous analysis, restructuring, implementation, and verification; design choices below are implementation decisions under that authorization.

The baseline has roughly 5,000 lines of presentation code in flat screen/widget folders. It repeats hardcoded purple/Poppins styling, device-percentage layout sizes, navigation widgets, and status definitions. Firebase and Supabase are accessed directly by screens. Fetch errors are converted into empty results, date/image parsing assumes complete records, the map can accept an out-of-area current position, and the checked-in tests refer to a nonexistent counter. The upload path imports dart:io and relies on embedded privileged credentials and a third-party compression service.

## Direction

Use a restrained public-service identity: evergreen (#174D3C), warm paper (#F6F7F2), ink (#202B26), off-white panels, ochre for attention, and matching dark surfaces. Use locally bundled humanist sans typography, Material outlined icons, clear status labels, and consistent 4/8-point spacing. Reserve animation for short entrances, expanding details, and meaningful state changes; honor reduced motion.

The UI/UX Pro Max search recommends an accessible, inclusive government/service interface. Its public landing-page composition is not appropriate to the authenticated dashboard, so use a task-focused application shell instead.

## Approach and boundaries

Retain Flutter and existing Firebase report/user schemas. A styling-only patch would leave duplicated navigation and state errors; a complete platform/backend rewrite would needlessly risk existing integration. Adopt a feature-first presentation structure with shared theme, components, navigation, and data adapters, incrementally retaining compatibility exports for former imports.

At >=1100px use a persistent sidebar, at >=760px use a compact navigation rail, and on phones use a labeled bottom navigation bar. Large text switches the sidebar to the more compact navigation layout. Keep content within a readable width. All primary journeys must have meaningful loading, empty, error, success, and busy states. Search, status/category filters, ordering, upvotes, and deletion must compose correctly. Keep destructive deletion confirmation.

Build explicit sample-data preview mode for offline UI review, visibly labeled and isolated from production writes. Default startup retains real authentication. Preserve onboarding, sign-in, registration, verification, reset/change password, report creation with 1–3 images, location boundaries, issue browsing, reports, notifications, and profile. Do not invent government analytics or notification events.

Remove embedded service-role and compression credentials from the client. Read public Supabase configuration using dart-defines; explain missing setup in the upload flow without blocking unrelated functionality. Do not migrate database records or change remote security policies.

## Structure and contracts

- `lib/app/`: app bootstrap, routes, responsive shell, preview/session state.
- `lib/core/theme/`: light/dark themes and semantic tokens.
- `lib/core/widgets/`: shared brand, panels, buttons, page layout, states, entrance motion.
- `lib/features/{auth,dashboard,reports,account}/`: feature screens and focused components.
- `lib/models/`, `lib/services/`: existing backend contracts with resilient adapters.

Shared component contracts: `AppShell(currentIndex: int, child: Widget)`; `CivicPage(title: String, description: String?, actions: List<Widget>, children: List<Widget>, maxWidth: double = 1160)`; `AppPanel(child: Widget, padding: EdgeInsetsGeometry)`; `SectionHeading(title: String, subtitle: String?, action: Widget?)`; `EmptyState(icon: IconData, title: String, message: String, actionLabel: String?, onAction: VoidCallback?)`; `AsyncButton(label: String, onPressed: VoidCallback?, isLoading: bool = false, icon: IconData?)`; `BrandMark(compact: bool = false, inverse: bool = false)`; `Entrance(child: Widget)`.

All derive colors/text from `Theme.of(context)`; `AppTheme` is available at `core/theme/app_theme.dart`. `AppSession.instance` is a ChangeNotifier exposing `isPreview`, `themeMode`, `setThemeMode(ThemeMode)`, `enterPreview()`, and `leavePreview()`. Named routes remain `/welcome`, `/login`, `/signUp`, `/reset_password`, `/dashboard`, `/explore`, `/report_issue`, `/my_reports`, `/profile`, `/notifications`, `/change_password`, `/verification`.

## Acceptance and verification

Run Flutter analysis, meaningful model/filter and widget tests, a web release build, and visual checks where feasible. Exercise 375px phone, tablet, and desktop layouts; large text, both themes, and reduced motion. Verify combined report filters, preview isolation, form validation, empty states, and navigation without Firebase initialization. Report live-backend verification limits explicitly.

## Work manifest

Base: `337b08080d16cbe4df1280aa32edfa7e2dd5df90`, branch main. Existing untracked `.agents/` is user-owned and preserved. Scope S2: cross-module presentation and integration reliability, no backend migration. Main worker owns shared foundations, browsing, tests, configuration, and final integration. Three bounded workers own auth, report composition, and account presentation in isolated `/tmp/civic-*` source copies; only the main worker integrates into the repository. Agents inherit the runtime model intentionally (AUTO: runtime requires model inheritance unless the user requests an override), effort high, workspace-write sandbox restricted to `/tmp`, no nested delegation, no remote writes or commits. Independent final review is read-only. Concurrency cap 3; maximum 3 review rounds.
