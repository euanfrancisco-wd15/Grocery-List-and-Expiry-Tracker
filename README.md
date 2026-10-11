# GroPanda

GroPanda is a Flutter grocery inventory and expiry tracker. It helps users
manage groceries, get expiry reminders, and track spending against monthly
budgets. Firebase Authentication handles sign-in, and Cloud Firestore stores
user-scoped profiles and records.

## Quick start

Requirements: Flutter with Dart 3.12.2 or later and a configured Firebase
project. From the repository root:

```sh
flutter pub get
flutter devices
flutter run -d <device-id>
```

The generated Firebase configuration targets the existing project
`grocery-list-and-expiry-track`. See the
[complete setup guide](docs/SETUP.md) for Firebase configuration, platform
prerequisites, testing, and troubleshooting.

## Documentation

- [Complete setup and troubleshooting guide](docs/SETUP.md)
- [System architecture, Firestore schema, and wireframes](docs/SYSTEM_DESIGN.md)
- [Detailed system architecture visualization](docs/architecture.svg)
- [System design PDF](docs/SYSTEM_DESIGN.pdf)
