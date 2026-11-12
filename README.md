# Message Board

Undergraduate Homework 02. This Flutter app uses Firebase Auth and Firestore against the local Firebase Emulator Suite. The submitted Android release build targets the Android emulator host alias, 10.0.2.2.

## Run and test

1. Run `flutter pub get` and `npm ci`.
2. Start Firebase with `firebase emulators:start --project demo-hw02-board --only auth,firestore`.
3. Start Android Studio's emulator and run `flutter run` or install the release APK built by `flutter build apk --release`. For a physical test device, supply the reachable host via `--dart-define=FIREBASE_HOST=<address>` and configure your emulator network appropriately.
4. Open the emulator dashboard at http://127.0.0.1:4100. Run `npm test` from a second terminal to verify Firestore rules and duplicate handling.

## Authentication and messages

The splash waits for Firebase setup. Auth state switches between the account form and the signed-in flow. Registration creates Users/{uid} with uid, firstName, lastName, role and registrationDateTime. The profile gate offers recovery if account creation succeeded but the profile write did not. Only the owner can read their profile, and the rules enforce the member role on creation.

The board listens to Messages in descending createdAt order. A post records authorUid, text, createdAt and updatedAt. All authenticated members can read the board. Only the author can edit or delete a message, and edits cannot change ownership or creation time. New posts use one document reference per attempt and a transaction that checks for an existing record before writing. The UI disables submission while a write is pending. The board stream is scoped to the active signed-in screen.

## Storage and spice choices

| Location | Key or path | Purpose |
| --- | --- | --- |
| Firestore | Users/{uid} | Private member profile |
| Firestore | Messages/{id} | Shared board messages and server timestamps |
| Device preferences | board.compact | Non-sensitive display preference |
| App memory | Composer and pending message ID | Unsaved text and same-session retry state |
| Firebase Auth SDK | Managed session | Sign-in persistence managed by Firebase |

The emulator workflow, rules tests, and idempotent write are Choice Spices 1, 2 and 4. The local project ID starts with demo- and both Firebase services explicitly target local ports, so the verification does not use a live project. Transactions require connectivity. The retained retry ID survives within the current composer session. Codex assisted with implementation and testing.
