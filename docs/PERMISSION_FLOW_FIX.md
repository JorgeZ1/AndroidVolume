# Permission flow hardening — 2026-10-09

## Scope

Firebase event: 0.0.13 (14), Android 12, Moto G22. The supplied stack reaches
`PermissionActions.request` and reports an unhandled PlatformException, but does
not contain its original message/code. Concurrent requests and an unavailable
Android Activity are supported hypotheses, not a confirmed device-specific cause.

## Implemented

- One global request gate across overlay, notification and battery permissions;
  duplicate/cross-permission taps are ignored while a request is active.
- Both permission screens disable actions and show the active request progress.
- Exceptions preserve the last known permission status, show a localized retry
  hint and release the gate in finally. Denial is not treated as an exception.
- Bounded initialization handlers replace infinite streams. One owned polling
  timer and lifecycle refresh reread actual permission state after Settings;
  the timer and observer are removed on close.
- Status-read failures do not leave startup permanently on a spinner and never
  fabricate a grant. Future refresh/retry can recover.
- Handled failures are nonfatal monitoring events with fixed permission,
  operation, category and lifecycle names. No raw exception message, plugin
  details, code or report content is uploaded by this flow.
- No new permission, Android exclusion, SDK dependency or release version change.

## Verification

Eight automated regression tests cover concurrent taps, crossed permissions,
plugin pending-request/no-Activity errors and recovery, denial, Settings resume,
close during a pending request or initialization, status/monitoring failures, privacy sanitization,
and UI disabling/re-enabling. See `test/permission_flow_test.dart`.

Final verification: `flutter analyze --no-pub` has no issues; the full Flutter
suite passes 46 tests. `flutter build apk --debug --no-pub` succeeds. Both source
and packaged debug manifests contain SYSTEM_ALERT_WINDOW, POST_NOTIFICATIONS
and REQUEST_IGNORE_BATTERY_OPTIMIZATIONS. No camera/microphone permission added.

Artifact: `build/app/outputs/flutter-apk/FloatingVolume-permissions-fix-debug.apk`
(debug package, still version 0.0.13+14; not a new Play release).
SHA256: `024D89A812B0B763054FF9E51EABE6B0BC63D8D77D0C6DF49A75A59CC2EFB191`.

Debug compilation is separate from the published AAB. No AAB or Play upload is
part of this change. ADB did not detect a connected phone during this work;
physical Moto G22 / Motorola Android 12 verification remains pending.

## Device acceptance checklist

1. Fresh debug install or test-device permission reset (not production data).
2. Rapidly tap one permission, then another while its system screen opens:
   only one native request should run.
3. Deny, return to the app, retry and grant. The app must remain usable.
4. Permanently deny, open Settings, grant there and return: reread the actual
   status without claiming success before the user grants it.
5. Switch Home/app while the request is open, then return. No crash or duplicate
   dialog; no pending indicator after the native request has completed.
6. Verify handled events in an explicitly monitoring-enabled debug build;
   ordinary debug disables monitoring. Check fixed categories and no raw text.
7. After release with a new version code, monitor Crashlytics for recurrence;
   passing mocks does not certify the original OEM failure as reproduced/fixed.
