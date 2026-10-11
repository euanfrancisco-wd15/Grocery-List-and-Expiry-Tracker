# GroPanda Setup Guide

This guide explains how to prepare, configure, run, and verify the complete
GroPanda application from a fresh checkout. The app is built with Flutter and
uses Firebase Authentication and Cloud Firestore.

## 1. Requirements

Install the tools for the platform you plan to run:

- Flutter SDK with Dart **3.12.2 or later** (see the SDK constraint in
  [`pubspec.yaml`](../pubspec.yaml)).
- Git and an editor such as Visual Studio Code or Android Studio.
- For Android: Android Studio, Android SDK/platform tools, and a JDK compatible
  with the configured Java 17 toolchain. Install an Android emulator or connect
  an Android device with USB debugging enabled.
- For iOS or macOS: a Mac with Xcode installed. Accept the Xcode license and
  install the Xcode command-line tools before building.
- For Windows desktop: Windows, Visual Studio with the **Desktop development
  with C++** workload, and the Windows SDK.
- A Firebase project with permission to configure Authentication, Firestore,
  and app registrations.
- To deploy Firestore rules from the command line: the
  [Firebase CLI](https://firebase.google.com/docs/cli). With Node.js/npm
  installed, it can be installed using `npm install -g firebase-tools`.

Check the local Flutter installation and connected targets:

```sh
flutter doctor -v
flutter devices
```

Resolve any required toolchain issues reported by `flutter doctor` before
building a native target.

## 2. Get the source and install dependencies

From a terminal:

```sh
git clone https://github.com/euanfrancisco-wd15/Grocery-List-and-Expiry-Tracker.git
cd Grocery-List-and-Expiry-Tracker
flutter pub get
```

Open the repository root (the directory containing `pubspec.yaml`) in your
editor.

## 3. Configure Firebase services

This checkout is associated with Firebase project
`grocery-list-and-expiry-track`. The generated Flutter configuration is in
[`lib/firebase_options.dart`](../lib/firebase_options.dart), Android's Google
Services configuration is in `android/app/google-services.json`, and the
Firebase CLI project alias is in `.firebaserc`. If setting up a different
Firebase project, register each target app there and regenerate these
configuration files rather than copying the existing project's settings.

To configure a different Firebase project, first register the required platform
apps in its Firebase Console. Install and authenticate the
[Firebase CLI](https://firebase.google.com/docs/cli) and
[FlutterFire CLI](https://firebase.google.com/docs/flutter/setup):

```sh
npm install -g firebase-tools
firebase login
dart pub global activate flutterfire_cli
flutterfire configure --project=<your-firebase-project-id> --platforms=android,ios,macos,web,windows
```

Run `flutterfire configure` from the repository root and select only platforms
you intend to support. Review the generated `lib/firebase_options.dart` and
native configuration files before building. Recheck each platform's OAuth
configuration and deploy the Firestore rules to the selected project.

### Authentication

In Firebase Console:

1. Open **Authentication → Sign-in method**.
2. Enable **Email/Password**.
3. Enable **Google** if Google sign-in is required.
4. For web deployments, add the deployed host under
   **Authentication → Settings → Authorized domains**.

Email/password registration and login use Firebase Authentication. A new
account receives a Firestore user profile. After sign-in, the app requests a
username before opening the main screens.

### Firestore

1. Create a Cloud Firestore database for the selected Firebase project.
2. Select the desired production region carefully; database location cannot
   readily be changed after creation.
3. From the repository root, deploy the included owner-scoped rules using the
   Firebase CLI:

   ```sh
   firebase login
   firebase use grocery-list-and-expiry-track
   firebase deploy --only firestore:rules
   ```

   The checked-in `firebase.json` maps Firestore rules to
   [`firestore.rules`](../firestore.rules). For a different project, select its
   alias or configure the Firebase CLI project before deployment.
4. Confirm successful account creation and that each account's profile and
   records are stored only below `users/{uid}`. See
   [SYSTEM_DESIGN.md](SYSTEM_DESIGN.md) for collections, document fields, and
   current access rules.

The rules currently allow a signed-in user to read and write their own profile
and subcollections. They do not validate each field's type or value. Review and
test the rules before deploying to a production environment.

## 4. Platform setup

### Android

The configured Android application ID is
`com.school.grocerytracker.grocery_tracker`.

- The Android Google Services Gradle plugin is already declared in the Android
  Gradle configuration. Keep `android/app/google-services.json` registered for
  the same Firebase Android app ID.
- For native Google sign-in, register the package in Firebase, add the SHA-1
  and SHA-256 fingerprints for each signing key in use, and download the
  refreshed `google-services.json`. It must include the OAuth web client needed
  for an ID token.
- To retrieve local signing fingerprints, run from the repository root:

  ```sh
  cd android
  ./gradlew signingReport
  cd ..
  ```

- Android notification permissions and scheduled-notification receivers are
  configured in the manifest. On Android versions that prompt for notification
  permission, grant it in the app or device settings to receive reminders.

### iOS

The iOS bundle identifier currently configured in Flutter Firebase options is
`com.school.grocerytracker.groceryTracker`.

- Firebase's generated Dart options initialize Firebase for the configured iOS
  app.
- For native Google sign-in, register this bundle identifier in Firebase, add
  its iOS OAuth client configuration to the Runner target, and configure the
  OAuth reversed client ID as a URL scheme. If the native sign-in flow requires
  `GoogleService-Info.plist`, download the file for this Firebase app and add it
  to `ios/Runner/` and the Runner Xcode target.
- Install Xcode and its command-line tools. If Xcode reports an unaccepted
  license, accept it locally, then retry the build.
- Approve the notification permission prompt on the device to receive local
  reminders.

The iOS Google service plist is not currently present in the repository; native
Google sign-in will not work until the matching Firebase/OAuth setup is
completed.

### Web

- Web Firebase initialization uses the generated web options in
  `lib/firebase_options.dart`.
- Add the deployed domain to Firebase Authentication's authorized domains.
- Google authentication uses Firebase Auth's web popup and requires Google to
  be enabled in the Firebase project.
- Run locally with:

  ```sh
  flutter run -d chrome
  ```

Device local notifications are not scheduled on web. Browser notification
behavior is not implemented by this app.

### macOS

macOS Firebase options are currently mapped in
`lib/firebase_options.dart`. Build and run on a Mac with Xcode:

```sh
flutter run -d macos
```

Test Firebase authentication with the target app registration and credentials
used by the local build. Native Google sign-in configuration may require
additional Firebase/Google OAuth setup. Local notifications are platform
permission dependent.

### Windows

Windows Firebase options are mapped in `lib/firebase_options.dart`. Install
Visual Studio with its C++ desktop workload and Windows SDK, then run:

```sh
flutter run -d windows
```

Verify Firebase access and any platform-specific notification behavior on the
target machine. Native Google sign-in and local notifications should not be
assumed to work identically to Android/iOS.

### Linux

Linux is **not currently a supported Firebase target**. The
`DefaultFirebaseOptions.currentPlatform` getter throws for Linux because no
Linux configuration is generated. Do not use `flutter run -d linux` until Linux
Firebase configuration and platform testing are added.

## 5. Run the app

See available device IDs with `flutter devices`, then run on the target:

```sh
flutter run -d <device-id>
```

Examples:

```sh
flutter run -d chrome
```

For a phone or emulator, pass the device ID shown by `flutter devices`.

The first launch needs access to the configured Firebase project. If Firebase
initialization fails, the app displays its Firebase setup/error screen instead
of the sign-in flow.

## 6. First-use walkthrough

1. Select **Get Started** to register, or **Log In** for an existing account.
2. Use email/password, or Google after completing its platform setup.
3. On first sign-in, choose a username (3–20 letters, numbers, or underscores).
4. Use the bottom navigation to open Dashboard, Inventory, Add, Reports, or
   Settings.
5. Add a grocery with a name, category, quantity, purchase date, and expiry
   date. Unit price is optional; the expiration date cannot be earlier than the
   purchase date.
6. Set a monthly budget in Dashboard or Reports. Reports can also record manual
   expenses.
7. In Settings, grant notification permission and choose the reminder time and
   expiry/budget alert types.
8. Export a JSON backup from Settings if needed. Restoring merges records with
   matching IDs and is restricted to the account that created the backup.

## 7. Verify the setup

Run the analyzer and automated tests from the repository root:

```sh
flutter analyze
flutter test
```

The focused budget alert unit test can be run with:

```sh
flutter test test/budget_alert_rules_test.dart
```

Then smoke-test a real target:

- Create an account and verify the username onboarding flow.
- Add, edit, and delete a grocery; confirm its linked expense is retained after
  deleting the inventory record.
- Add a manual expense and confirm Reports updates.
- Configure a budget and notification preferences.
- On Android/iOS, allow notifications and check scheduled reminder delivery.
- Sign in with a second test account and verify it cannot read the first
  account's Firestore records.

Successful analysis and unit tests do not verify live Firebase rules, OAuth,
or real notification delivery. Those require the Firebase project and target
devices to be configured.

## 8. Notes and limitations

- To regenerate the printable system design, install Google Chrome and run
  `python3 docs/export_system_design_pdf.py` from the repository root. The
  exporter uses local tools and requires no Python packages or online service.
- User profiles, groceries, expenses, budgets, and notification history are
  stored in Cloud Firestore under the signed-in UID.
- Grocery photo bytes are stored in app-private local storage, not Firebase.
  Photos do not sync across devices and are not included in the JSON backup.
- Expiry reminders apply to grocery inventory items. The app has no reservation
  feature.
- New grocery purchases create expense records. Older inventory items do not
  automatically have historical expense entries.
- Keep OAuth client configuration and signing credentials managed through the
  appropriate Firebase/Google and platform tooling. Never put service-account
  private keys in the Flutter client.

## Troubleshooting

| Symptom | Checks |
| --- | --- |
| Firebase setup/error screen on launch | Check network access, Firebase project settings, and the target's generated Firebase app configuration. |
| `permission-denied` when saving | Deploy `firestore.rules`; verify the user is signed in and writes target their own `users/{uid}` paths. |
| Google sign-in does not return an ID token on Android | Confirm the Firebase Android package ID and signing SHA fingerprints; download the refreshed Google Services file with a web OAuth client. |
| Google sign-in fails on iOS | Confirm the bundle identifier, add the iOS OAuth client configuration, and configure the reversed client ID URL scheme in the Runner target. |
| Web Google popup is blocked or rejected | Use an authorized HTTPS/local domain and add the deployed host to Firebase Authentication's authorized domains. |
| No scheduled notification appears | Check the OS permission, app notification settings, selected reminder preference, item expiry date, and device time zone. Web notification scheduling is not implemented. |
| Linux build throws `UnsupportedError` | Linux Firebase options have not been configured; use Android, iOS, web, macOS, or Windows instead. |
| Xcode build refuses to run | Install Xcode command-line tools and accept the Xcode license, then rerun Flutter setup/build commands. |
| Photo is missing after moving to a different device | Photos are local-only and are not part of Firestore sync or JSON backup. |
