# Android 8.1 baseline — October 6, 2026

## Environment

Dedicated AVD: `FloatingVolume_QA_API27`, API 27 / Android 8.1.0, AOSP x86_64, emulator port 5582, 1024 MB RAM and 2 virtual CPU cores. Separate from MintDocx's existing API 36 AVD. Physical phones were not connected or modified.

Official Google image archive: `x86_64-27_r01.zip`, 491,675,204 bytes. SHA-1 matched Google's SDK repository metadata: `2878261011a59ca3de29dc5b457a495fdb268d60`.

The SDK download stalled; the same official archive was downloaded directly, verified and extracted. The attempt to disable encryption failed during Android's own startup; the final working emulator uses the default encryption behavior. Modern emulator configuration clamps the data partition to 6 GB despite a smaller requested size.

APK: fresh x86_64 debug build of 0.0.11 (12), without MONITORING_DEBUG or MONITORING_SELF_TEST defines; test AdMob units and disabled monitoring collection. No AAB generated for this test.

## Result: crash reproduced

Installed APK successfully and launched MainActivity. Ran `scripts/test_api27_startup.ps1` with 20 rapid direct calls to `am start-foreground-service`, followed by `am stopservice` after a nominal 100 ms host delay.

The log contains:

```text
FATAL EXCEPTION: main
android.app.RemoteServiceException: Context.startForegroundService() did not then call Service.startForeground()
```

The emulator displayed “Floating Volume has stopped.” The test intentionally failed its crash assertion. This is a reproduction of the same exception family on API 27, not a successful regression test.

Evidence: `docs/test-artifacts/api27/startup-crash.log` and `docs/test-artifacts/api27/crash.png`.

## Scope and limitations

- The AVD is not a Samsung/other OEM S7 hardware or firmware replica.
- Direct root/shell service calls stress lifecycle ordering but do not exercise Flutter's switch / ServiceStatusBloc start-stop event path.
- This reproduction supports fixing the promotion/stop ordering; it does not prove the user's original interaction or establish that Android 8.1 must be excluded.
- No startup fix was applied during the initial baseline. The follow-up below records the implementation and regression results separately.

## Follow-up implementation — October 6, 2026

Foreground promotion now runs synchronously in onCreate before settings/monitoring/coroutines, and again in onStartCommand before acknowledging startup. The service and BootReceiver can create the notification channel without MainActivity. ServiceStatusBloc waits for that acknowledgement before publishing On or processing a queued Stop; Toggle is resolved inside its own collector without recursive SharedFlow emission. Repeated starts no longer register duplicate observers. Notification permission gates updates only on API 33+, never the required foreground promotion. NativeApi bounds its success wait so a rejected start cannot leave its platform callback pending indefinitely.

Debug APK SHA-256: `FE3866AA71E6F5AD39BBE2FC83807A1E35AC207E3673E73CF01EF0BBA9B60B9E`. App version remains 0.0.11 (12); no release artifact or AAB was generated.

### Actual UI path: PASS

`scripts/test_api27_ui_startup.ps1 -Cycles 30` completed 30 On/Off cycles through the real Flutter switch, with 30 native foreground acknowledgements, final switch Off and no active FloatingVolumeService. No fatal foreground timeout occurred in this run. Evidence: `docs/test-artifacts/api27/ui-30-cycles.log`.

The script waits for each settled/enabled switch state: the UI disables taps while starting, so a tap attempted during that busy interval is not a completed stop request. Android 8 also retains a historical unstarred “Last ANR service” in dumpsys after process exit; the assertion checks starred active entries, not that historical snapshot. Initial test-script failures from those two assumptions were corrected rather than classified as an application crash.

### Unacknowledged external cancellation: FAIL, retained

Rerunning 50 nominal 100 ms shell start/stop cycles without waiting for promotion still triggered RemoteServiceException. The system log explicitly reports “Bringing down service while still waiting for start foreground” before the next onCreate/start acknowledgement. This demonstrates cancellation before Android delivers the service callback; promoting earlier inside that callback cannot precede an external stop already processed by the system.

Evidence: `docs/test-artifacts/api27/fixed-attempt1-crash.log`. The failed variant has not been removed or relabelled PASS. It bypasses the app's new start acknowledgement and does not by itself prove the production user's original trigger. Review this distinction and test all actual start/stop entry points before publishing.

### Acknowledged shell lifecycle: PASS

`scripts/test_api27_startup.ps1 -Cycles 50 -WaitForPromotion` completed 50 direct start/stop cycles after confirming foreground promotion, without the timeout. This is a separate controlled scenario, not a replacement for the failed adversarial cancellation above. Evidence: `docs/test-artifacts/api27/acknowledged-50-cycles.log`.

Ten further start intents on an active service yielded exactly one creation, ten acknowledgements and nine `observersStarted=true` guard hits, with no fatal exception; the service was stopped afterward. Evidence: `docs/test-artifacts/api27/repeated-10-starts.log`. This verifies the guard path; it does not inspect every collector's runtime object count.

### Code verification

- Flutter: 30 tests passed; analyze reported no issues.
- Kotlin: 7 IndicatorPlacement tests passed; native compilation succeeded. These geometry tests do not certify startup ordering by themselves.
- Emulator: dedicated API 27 only. No physical S7, other APIs, boot/recreation, notification denial or Play-installed release tested in this follow-up yet.

Remaining cross-version and physical-device work is defined in `docs/ANDROID_TEST_MATRIX.md`; do not extend API 27 results to untested systems.
