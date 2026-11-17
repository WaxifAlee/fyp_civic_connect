# Report map pin implementation plan

> **For agentic workers:** Use superpowers:executing-plans to implement this plan inline.

**Goal:** Let citizens optionally select and adjust the exact report location on a map.

**Architecture:** Extend the existing Google Maps picker, whose native configuration was verified on the Android emulator. Keep the current `LatLng` navigation result, server polygon validation, manual entry, and permission-on-demand GPS. Enable maps by default on supported native platforms; web remains an explicit opt-in after its Maps SDK is configured. Preview stays offline.

**Tech stack:** Flutter, existing `google_maps_flutter`, `geolocator`, Material 3.

## Design and constraints

- The report form opens the map with a clear **Choose on map** action; editing restores the chosen pin.
- Tapping or long-pressing places one pin. Holding and dragging adjusts it. Map gestures must not scroll the surrounding form.
- Pin position and displayed coordinates always describe the same candidate, including invalid drags. Preserve full coordinate precision in the result.
- A pin outside the existing Fateh Jang polygon remains visible with an error; confirmation is unavailable until corrected.
- Keep confirmation reachable below the scrollable content. Manual entry and GPS remain optional alternatives; opening the map never requests location permission.
- Keep the existing palette, outlined controls, large touch targets, reduced motion, and small-screen/text-scale behavior.
- This change does not alter SQL, report submission, authentication, or storage.

## Implementation

- [x] Add focused widget tests using a fake native map view: default availability, tap/drag precision, invalid drag recovery, cancellation, manual-mode round trip, and offline preview.
- [x] Observe failures, then implement selection behavior and sticky confirmation in `map_location_picker.dart`; clarify the action in `report_issue_screen.dart`.
- [x] Enable maps in the active local Android configuration and document platform defaults and required provider configuration in the README.
- [x] Run analysis, the regression suite, configured Android/web builds, and inspect native tap/drag/confirm/edit behavior in the emulator.
- [x] Review the complete change, commit/push under the existing authorization, and leave the application running for testing.

## Review focus

Invalid drags must never confirm old coordinates; changing modes must not lose precision; cancellation must not replace a prior report location; preview must never instantiate a remote map; native gestures and sticky controls must remain usable at large text sizes.

## Verification and delivery

- `flutter analyze`: clean; `flutter test`: all 139 tests pass, including eight focused map picker tests.
- Configured Android debug APK and release web build with maps disabled both compile successfully.
- Android emulator: real map tiles render; tapping places a pin; holding and dragging disables confirmation until release and updates coordinates; confirmation returns full precision to the report; editing restores the pin at street zoom; cancelling preserves the previously confirmed location.
- A fresh read-only review found no concrete regression in the changed flow. Web Maps and iOS native interaction were not exercised.
- The configured Android application remains installed and running against the hosted Supabase backend.
