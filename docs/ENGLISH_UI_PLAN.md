# English and Spanish UI migration

## Objective

Offer the complete app in English and Spanish. Default to the system language, while allowing the user to select either language in the header. Keep Flutter screens, permission guidance, privacy information, accessibility labels, rewards, notification controls, and native overlays in sync. Preserve behavior and stored setting keys.

## Sprints

1. **Inventory and edge position:** locate visible Spanish strings and every horizontal edge calculation; make expanded controls flush with the closest edge while retaining a reachable partial-hide target.
2. **Language selection:** persist System default / English / Español, react to system-locale changes, and localize framework widgets.
3. **Flutter UI:** localize onboarding, home, settings, reward flow, help, and in-app privacy policy. Keep brand/style names and identifiers unchanged.
4. **Native Android UI:** localize mixer labels, accessibility descriptions, and runtime messages; retain platform permission constants.
5. **Verification:** test both selected languages and system default; format and analyze; run tests; build/install debug APK; check both edge positions and auto-hide on device. Do not generate an AAB.

The linked public website policy is a separate deployment; its language must be checked independently before claiming the external website is English.

## Verification status

- Flutter UI, permission guidance, in-app privacy policy, and native mixer/overlay strings support both languages.
- Language selection persists; System default follows the device locale. Flutter tests cover all three choices and the policy in English and Spanish.
- The final debug APK builds and was installed on the connected phone. An earlier bilingual build showed the selector in the home header and the right-side partial-hide control flush with the edge. The final build additionally refreshes the native notification when changing language. Interactive checks of that final build were stopped when the phone became occupied.
- The public website linked from the policy is outside this app build and still needs its own bilingual deployment decision.
