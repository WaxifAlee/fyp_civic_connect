# CivicConnect

A Flutter application for reporting local issues in Fateh Jang, following their progress, and supporting community reports. Firebase provides authentication and report storage; Supabase Storage holds report and optional profile photos.

The interface uses a shared Material 3 design system with evergreen, warm neutral surfaces, locally bundled Public Sans, outlined icons, and matching light/dark themes. Navigation adapts from a labeled phone bar to a compact rail and a desktop sidebar.

## Run locally

Use a Flutter SDK compatible with Dart `^3.5.4`. This revision was verified with Flutter 3.47.1 and Dart 3.13.1.

```bash
flutter pub get
flutter run -d chrome --dart-define=PREVIEW_MODE=true
```

Preview mode requires no account or backend initialization. It uses clearly labeled sample reports; support and deletion affect only in-memory demo records. Report confirmation is simulated and explicitly says nothing was submitted. You can also enter the demo from the welcome screen in a normal build.

To run the real application:

```bash
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLIC_KEY
```

The existing Firebase platform settings live in `lib/firebase_options.dart`. Configure your own project with FlutterFire when using a different backend. Enable email/password authentication and provide the existing Firestore collections and security rules. The app handles connection failures with retry and demo entry.

Only pass a public Supabase anonymous/publishable client key. Storage access policies must enforce the intended permissions. The old client contained a privileged Supabase key and a compression API credential; those have been removed from the source and must be rotated in their provider consoles because they remain in Git history. No remote configuration or credentials were changed by this redesign.

Storage initialization is optional for browsing and account access. Without storage configuration, the report form explains that uploads are unavailable and retains its draft. Photos are read as bytes on web and native, validated as JPEG/PNG/WebP, and limited to 1–3 files of up to 8 MB each. The app no longer sends photos to an external compression service.

## Location selection

The coordinate picker works without a Maps SDK. It validates the existing Fateh Jang service polygon for manual coordinates, map taps, and GPS positions. GPS permission is requested only after choosing **Use current location**.

To enable the interactive map, configure the Google Maps SDK/key on the target platform and pass:

```bash
flutter run --dart-define=GOOGLE_MAPS_ENABLED=true
```

Android uses the Maps metadata in `android/app/src/main/AndroidManifest.xml`; iOS needs its platform SDK setup. Web needs the Google Maps JavaScript SDK loaded with your restricted public API key before Flutter starts. Keep coordinate entry available when maps cannot load.

## Code organization

```text
lib/
  app/                         Bootstrap, routes, responsive shell, session/theme state
  core/
    theme/                     Semantic light/dark theme and motion tokens
    widgets/                   Shared brand, panels, page layout, feedback and buttons
  features/
    auth/                      Welcome, sign-in, registration, verification, reset
    dashboard/                 Personal report overview and reporting guidance
    reports/
      application/             Report loading and mutation state
      data/                    Submission, photo validation, geographic boundary, demo data
      domain/                  Status/category taxonomy and composed filters
      presentation/            Explore, My Reports, report form, location picker
      widgets/                 Reusable report cards, details, image picker
    account/                   Profile editing, appearance, security, notifications
  models/                      Persisted report and citizen contracts
  services/                    Firebase reads/mutations and Supabase initialization
  screens/                     Compatibility exports for former screen imports
  themes/                      Compatibility export for the former theme import
  utils/                       Existing identity/contact validators
```

Feature screens use the same theme and application shell. Report fetching failures are propagated into recoverable error states. Status aliases (`solved`, `done`, `resolved`, `in_progress`) are normalized in one place, and query/category/status/sort filters compose without replacing one another. Older records with missing images or dates remain readable.

Authentication preserves passwords exactly, supports autofill and visibility controls, and uses progressive registration sections. Verified pending profiles are moved to the existing user collection in a transaction. Password confirmation is never persisted. Account changes retain the existing identity fields and require reauthentication for password updates.

Report creation allocates a reference code and writes the report in a transaction after photos upload. Failed submissions retain the form and attempt to remove unfinished uploads. The legacy category value `Municipal Corportaion` is intentionally preserved in storage while the UI displays readable labels.

Notifications currently provide an honest empty state and a link to My Reports. This repository does not have a live notification feed, push delivery service, or authority/admin application.

## Verification

```bash
flutter analyze
flutter test
flutter build web --release
flutter build apk --debug --dart-define=PREVIEW_MODE=true
```

The 40 tests cover report parsing, composed filters, status aliases, preview write isolation, committed support counts, deletion cancellation, photo rejection, geographic boundaries, theme contrast, navigation, authentication recovery, form validation, reduced motion, and 375px layouts with 2x text in dark mode. Both release web configurations and an Android debug preview APK were compiled successfully. The delivery record in `docs/superpowers/2026-11-17-redesign-delivery.md` captures the checks and review fixes.

Optional screenshot review renders application views with the bundled text/icon fonts:

```bash
flutter test test/widget_test.dart --dart-define=CAPTURE_UI=true
```

Screenshots are written to `/tmp/civic-connect-previews/` and are not committed. For a runnable release preview:

```bash
flutter build web --release --dart-define=PREVIEW_MODE=true
python3 -m http.server 8080 --bind 127.0.0.1 --directory build/web
```

Android uses JDK 17, Gradle 8.14.3, Android Gradle Plugin 8.11.1, and Kotlin 2.2.20 to meet the installed Flutter SDK’s supported minimums. The obsolete parallel Kotlin-DSL Gradle files were removed so there is one authoritative native build configuration. The platform files include foreground location and photo/camera usage descriptions; Android does not request background location.

Live authentication, storage policies, native permission prompts, and configured Google Maps must also be checked against the deployment environment; automated preview tests never write remote records.

Design audit and implementation plan are recorded under `docs/superpowers/`. Public Sans is bundled under the SIL Open Font License in `assets/fonts/OFL.txt`.
