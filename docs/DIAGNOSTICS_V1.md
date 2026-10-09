# Structured technical diagnostics — 2026-10-09

## Implementation

1. **Contract/privacy:** fixed operation/phase enums, allowlisted fields and
   categories, process-local operation counters, monotonic timestamps, a maximum
   of 30 recent events per Flutter/Android layer. Nonfatal repeats have a 60-second
   cooldown and deduplication maps hold at most 64 fingerprints. Fatal Flutter
   events are not suppressed. No user ID, new installation ID, raw exception
   message, URL, file path, form text, image or audio is added by this feature.
2. **Permissions/channels:** permission operation traces, before/after status,
   Settings opening, app lifecycle and classified plugin failures. Settings
   requests, service start/stop/show/hide and support-report submission get
   operation context. The support wrapper does not inspect report payloads.
   Recoverable service failures show a localized retry notice; streams are owned
   and cancelled at bloc close. Stop acknowledgement is bounded to 12 seconds.
3. **Native overlays/service:** created/foreground-ready/destroyed states,
   foreground promotion and start acknowledgement timing, attached/removing window
   context, menu counts, window add/remove outcomes, snap start/end/cancellation
   and peek transitions. No per-animation-frame telemetry was added.
4. **Performance:** `flutter_first_frame`, `diag_permissionOverlay`,
   `diag_permissionNotification`, `diag_permissionBattery`, `diag_serviceStart`,
   `diag_serviceStop`, `diag_nativeChannel`, `diag_settingsUpdate`,
   `diag_reportSubmit`, native volume traces and native service timing traces.
   `native_service_ready` and `native_foreground_promotion` expose the real
   elapsed time as the custom **duration_ms** metric, not their upload/trace
   duration. Operation IDs belong to each layer; they are not persistent user
   identifiers or a guaranteed cross-layer distributed trace ID.
5. **Release preparation:** privacy policy source and in-app English/Spanish copy
   updated, inventory reviewed. No AAB, version bump, Play submission, public
   website deployment or Firebase Console setting change is included.

## Where to look in Firebase

Select the appropriate Android app: **Floating Volume Debug** for the opt-in APK,
production for a future release that includes this code. In Crashlytics open an
event and inspect reason, stack/information, logs and keys (`diagnostic_schema=1`,
`permission_overlay`, `permission_notification`, `permission_battery`,
`last_operation`, `last_operation_ms`, `flutter_error_category`, `native_error_category`, `window_kind`,
`window_attached`, `activity_state`, `quick_menu_count`, service/style/volume keys).
Flutter operation-specific context is attached to the event; global keys describe
the latest state and can change during concurrent operations.

In Performance inspect the custom traces above and result attributes. Traces
and reports are buffered by Firebase; absence of an immediate console update is
not itself proof that collection failed. Custom logs accompany errors, not a
separate analytics/usage dashboard. Google Analytics remains disabled.

References: https://firebase.google.com/docs/crashlytics/customize-crash-reports
and https://firebase.google.com/docs/perf-mon/custom-code-traces .

## Verification and remaining acceptance checks

Automated regression tests cover privacy allowlists, bounded history, cooldown,
fatal bypass, original result/error preservation, permission races/recovery,
service start/show/stop failures, repeated transitions, settings/report/UI
regressions. Native journal tests do not require a device or Firebase account.

Validation results: 57 Flutter tests pass; 19 native JUnit tests pass (including
4 new diagnostic-journal tests). Flutter analysis reports no issues. The debug
APK compiles. These are automated/build checks, not a claim of console receipt
or measured physical-device performance.

The opt-in debug is built with:

```text
flutter build apk --debug --no-pub --dart-define=MONITORING_DEBUG=true --dart-define=MONITORING_SELF_TEST=true
```

It records synthetic **nonfatal** Flutter StateError/PlatformException and native
IllegalStateException events at startup. It does not deliberately terminate the
app. Self-tests are guarded by debug mode and explicit opt-in; never include the
self-test flags in a release. Ordinary debug collection remains disabled.

Prepared artifact: `build/app/outputs/flutter-apk/FloatingVolume-diagnostics-debug.apk`
(177,418,449 bytes; package `com.fixbyte.floatingvolume.debug`, version 0.0.13+14,
not a new Play release). SHA256:
`6762774DD2C278E51A3E03765F20084CA4744D40F016A6E80657AA0BC9C88BFA`.

Pending device/console validation:

- Install/open the opt-in debug, restart once to allow buffered nonfatal reports
  to upload, then verify synthetic events/context in Firebase Debug.
- Grant/deny permissions, open/return from Settings, drag/open/hide menus, rotate
  and rapidly toggle controls. Check recoverability and native window state.
- Compare physical startup/interaction responsiveness against the prior debug.
- Confirm original OEM failures after release through observability; passing
  mocks/AOSP tests does not certify Motorola, Huawei or Vivo firmware.
- Review Google Play data-safety declarations for crash logs/diagnostics/other
  performance data and deploy the updated privacy webpage before publishing.

ADB found no connected device. Available RAM was low during compilation; no new
emulator was started and no other project's processes were stopped. Receipt in
the Firebase Console and physical-device performance are not yet verified.
