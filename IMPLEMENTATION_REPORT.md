# Grocery Tracker Feature Implementation Report

**Report date:** 8 October 2026  
**Project:** Grocery List and Expiry Tracker

## Summary

The requested onboarding, profile, notification, and budget work has been integrated into the existing Flutter/Firebase app. Static analysis passes, and the budget threshold rule tests pass. The full Flutter/native build and live Firebase account flows still need verification on a machine with the Xcode license accepted and the platform OAuth configuration installed.

## Implemented

| Area | Implementation |
| --- | --- |
| Username onboarding | Authenticated users without a username are routed through a setup screen. Usernames are trimmed and validated, saved under the Firebase UID, and reflected in the Firebase display name. |
| Email authentication | Existing Firebase email/password sign-in remains in place. New users receive a UID-keyed profile with notification defaults. |
| Google authentication | Web uses Firebase Auth’s Google popup. Android/iOS use Google Sign-In and Firebase credentials. Missing native OAuth setup produces a user-facing configuration error. |
| Profile and preferences | The existing Profile tab shows username/email and stores notification enablement, preferred local time, expiry reminder options, budget alert options, and monthly budget in `users/{uid}`. |
| Expiry reminders | Device notifications are scheduled for 7, 3, and 1 day before expiry and on/after the expiry date. Schedules use the device timezone and preferred notification time. Reminder records are stored under `users/{uid}/notifications/{notificationId}` and deduplicated by stable IDs. |
| Budget tracking | Grocery entries support an optional unit price. Purchase totals are written to a user-scoped expense ledger so deleting an inventory item does not remove its purchase from budget totals. The dashboard shows monthly spending against the saved budget. |
| Budget alerts | The app evaluates the 70%, 90%, 100%, and over-budget thresholds, respects each preference, schedules alerts at the preferred notification time, and stores a record to prevent duplicate alerts. |
| Firestore access | Profile, groceries, expenses, and notifications are scoped to the authenticated user UID in `firestore.rules`. |

## Verification

- `dart analyze` — passed with no issues.
- `dart run test test/budget_alert_rules_test.dart` — passed, 4 tests.
- `dart pub get` — dependencies resolved using the Dart SDK directly.
- `flutter test` and Android build — attempted, but Flutter exits because the host requires acceptance of the Xcode license (`sudo xcodebuild -license`). The Android build reached Flutter compilation before stopping for the same reason.
- Live Firebase sign-up/sign-in, Google OAuth, Firestore rules, and device notification delivery have not been tested against a running Firebase project/device.

## Remaining setup and limits

1. **Native Google OAuth:** Enable Google in Firebase Authentication. Add Android SHA-1/SHA-256 fingerprints and install the refreshed `google-services.json` with its web OAuth client. For iOS, install `GoogleService-Info.plist` and configure its reversed client ID URL scheme. Details are in [README.md](README.md).
2. **Flutter/native verification:** Accept the Xcode license on the host, then run `flutter test`, `flutter analyze`, and `flutter run` on target devices. Test notification permission prompts, scheduled delivery, reboot behavior, and timezone changes.
3. **Reservations:** This repository has no reservation model or reservation workflow, so reservation expiry reminders are not connected. Current reminders cover grocery inventory items.
4. **Existing purchase history:** The ledger records new grocery purchases and updates. Older grocery documents do not have historical expense entries; edit an older item and add its price to begin tracking it.

