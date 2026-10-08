# In-Class Activity 09 / Card Catalogue

- **Student:** Rohan Reddy Gosangi
- **Course/section:** CSC MAD (Mobile Application Development)
- **Pathway:** Undergraduate
- **Date:** October 8, 2026
- **Repository:** https://github.com/ReddyR1105/flutter-local-storage-lab

## What the app does

This app extends the Part I guest roster with folders and cards. Each folder shows its card count. Opening it reads only cards with its integer folder ID. Folders and cards support Add, Edit, Cancel, and confirmed Delete. The people icon opens the original Part I roster; its table and records are still available.

The implementation and write-up were prepared with Codex assistance. Codex operated the emulator and collected the observations below. These are actual recorded checks, rather than a claim that the student personally operated them. Only fictional test records appear in the evidence.

## Environment and commands

- Flutter 3.47.4; Dart 3.13.3; Windows development host.
- Target: Pixel_4a Android emulator, Android 17 / API 37.1, x86_64, serial `emulator-5554`.
- Declared packages: sqflite ^2.4.1, path_provider ^2.1.5, path ^1.9.0. Locked versions: sqflite 2.4.4+1, path_provider 2.1.6, path 1.9.1.
- Android application ID: `com.example.local_storage_lab`; app version 2.0.0+2; minimum Android API 24, target API 36. Android release APK contains arm64-v8a, armeabi-v7a, and x86_64.
- iOS configuration is retained from Part I, but iOS was not tested.

Open a terminal in `local_storage_lab` with Flutter and Android platform-tools on PATH:

```powershell
flutter --version
flutter pub get
flutter emulators --launch Pixel_4a
flutter devices
flutter run -d emulator-5554
flutter analyze 2>&1 | Tee-Object -FilePath .\evidence\analysis_output.txt
flutter build apk --release
adb -s emulator-5554 install -r build/app/outputs/flutter-apk/app-release.apk
adb -s emulator-5554 shell am start -n com.example.local_storage_lab/.MainActivity
```

The final release file is copied and renamed to `Activity09_Gosangi_Rohan.apk`. The normal release build uses the existing Part I package, so an in-place update can retain its app data. Local coursework builds use the generated debug signing key for installation; no signing key is committed.

### Reproduce the version-1 upgrade

The original version-1 source is retained at commit `8d2db56`. On a disposable emulator, build/run that commit, add fictional guests, quit the attached Flutter run with `q`, then check out `main` and build/install version 2 over the same package. Keep the same development signing key. Do not uninstall the original package, clear storage, or change the database filename.

```powershell
git checkout 8d2db56
flutter pub get
flutter run -d emulator-5554
# Add fictional guest rows, then quit the attached run with q.
git checkout main
flutter pub get
flutter build apk --debug --target-platform android-x64
adb -s emulator-5554 install -r build/app/outputs/flutter-apk/app-debug.apk
adb -s emulator-5554 shell am start -n com.example.local_storage_lab/.MainActivity
```

### Reproduce the separate fresh-database check

An optional environment switch changes only the test package ID to `com.example.local_storage_lab.freshcheck`. It leaves the original package and its data alone. The fresh-check activity keeps the normal namespace:

```powershell
$env:ACTIVITY09_FRESH_INSTALL = '1'
flutter build apk --debug --target-platform android-x64
adb -s emulator-5554 install -r build/app/outputs/flutter-apk/app-debug.apk
adb -s emulator-5554 shell am start -n com.example.local_storage_lab.freshcheck/com.example.local_storage_lab.MainActivity
Remove-Item Env:ACTIVITY09_FRESH_INSTALL
```

## Database and architecture

- **Preservation:** the same `MyDatabase.db` in the app documents directory moves from version 1 to 2. `onUpgrade` adds the new tables and index when `oldVersion < 2`; it never changes or recreates `my_table`. `onCreate` builds the original table plus the same new schema for a fresh installation.
- **Relationship:** `folders(id, name, created_at)` is the parent of `cards(id, title, suit, notes, image_ref, folder_id)`. A card has a required foreign key to a folder with `ON DELETE CASCADE`. `idx_cards_folder_id` indexes the child lookup. `onConfigure` enables foreign keys for each connection. sqflite already wraps create/upgrade callbacks in a transaction, so the callbacks do not start a nested transaction ([sqflite documentation](https://pub.dev/packages/sqflite)).
- **Policy:** folder names are trimmed, nonempty, and unique with SQLite's default case-sensitive uniqueness. Card titles are trimmed/nonempty; supported suits are spades, hearts, diamonds, and clubs. Notes are optional, and a blank image reference becomes SQL NULL. SQL CHECK constraints also protect nonempty names/titles and supported suits. IDs come from insert results, never folder names or list positions. A deleted/missing parent is rejected by the foreign key.
- **Initialization:** there is no automatic seeding. Test folders/cards were added through the form, so reopening or rebuilding a screen cannot add duplicates.

| File | Responsibility |
| --- | --- |
| [database_helper.dart](lib/database_helper.dart) | Same database location, schema version, create/upgrade hooks, connection configuration, and original roster CRUD |
| [models.dart](lib/models.dart) | Immutable Folder and CatalogueCard models with fromMap/toMap conversions |
| [card_repository.dart](lib/card_repository.dart) | Folder counts, filtered card reads, insert/update/delete, bound ID parameters; no SQL in screens |
| [catalogue_screens.dart](lib/catalogue_screens.dart) | Folder/card screens, shared add/edit forms, validation, confirmation, image fallback, and async feedback |
| [legacy_roster.dart](lib/legacy_roster.dart) | Original Part I roster screen retained |
| [main.dart](lib/main.dart) | Await database initialization and start the app; opening failure is visible and does not erase data |

A busy flag blocks repeated submissions during writes. Controllers are disposed, and mounted checks guard UI updates after awaits. A successful write followed by a failed read says that the write completed and asks for a Refresh retry; it does not repeat the write. Failed writes keep the form input. A zero-row update/delete is reported as missing data instead of a successful change. Lists distinguish loading, empty, and failed/stale reads.

## Image-reference choice

The default is a nullable reference and a suit-symbol placeholder. The app also recognizes `asset:` references and valid HTTPS URLs. Missing assets, malformed/unsupported references, and network errors use the same stable placeholder; HTTPS loading also shows it. Card title, suit, notes, IDs, and controls remain useful when an image fails. There is no gallery picker, image BLOB, or app-private-file image loader.

No image assets or third-party pictures are bundled. The missing paths in the tests are intentional failure cases. If adding a real asset, include the file and declare it in `pubspec.yaml`. The URI/file lifecycle alternatives are discussed in the reflection DOCX as design reasoning; unrun cases are labeled accordingly.

## Actual tests

Predictions were recorded before the upgrade in [predictions.txt](evidence/predictions.txt). SQLite snapshots in this folder are JSON/text observations; binary database backups remain outside the repository.

| Test | Action / expected | Actual IDs, values and counts | Result / evidence |
| --- | --- | --- | --- |
| T1 Upgrade preservation | Install version 2 over the existing version-1 package; keep every guest | Version 1 → 2; River ID 2 age 35, Acorn ID 3 age 0, Oak ID 4 age 130; guest count 3 before/after. New folders/cards/index exist, catalogue starts empty | Pass; T1_before.png, T1_after.png, T1_baseline.json, T1_upgrade.json |
| T2 Parent-child create | Create Practice and Keep; put two cards in Practice and one in Keep | Practice ID 1: Ace ID 1 and King ID 2, count 2. Keep ID 2: Queen ID 3, count 1. Each view is filtered by its returned folder ID | Pass; T2_cards.png, T2_after.json, T2_result.json |
| T3 Edit identity | Save one card's title/notes, then cancel an edit of another card | Card ID 1 became Ace revised / Edited only this card; feedback: Updated 1 row. King ID 2 and Queen ID 3 unchanged. King unsaved was canceled; counts remain 2 and 1 | Pass; T3_saved.json, T3_cancel.json, T3_result.json |
| T4 Restart persistence | Force stop without clearing data, then reopen the installed app | Same folder IDs 1/2 and counts 2/1; same card IDs 1/2/3, titles, notes, suits, references, timestamps and folder links; same 3 guests. PID 4822 → 6817 | Pass; T4_after.png, T4_before_restart.json, T4_after_restart.json, T4_result.json |
| T5 Delete behavior | Cancel Practice deletion, then confirm the disposable folder's cascade | Cancel: identical records. Confirm: folder ID 1 and child card IDs 1/2 removed. Keep ID 2 and Queen ID 3 remain, count 1; all Part I guests unchanged; no foreign-key violations | Pass; T5_cancel.json, T5_after.json, T5_result.json |
| T6 Validation and image fallback | Display null, missing-asset, malformed references; reject empty/space-only title | Queen ID 3 remains in folder ID 2, count 1, with suit fallback in each image case. Empty title and three spaces both show Enter a card title; saved rows identical before/after | Pass; T6_fallback.png, T6_invalid.png, T6_result.json |

T4 stop/relaunch commands, with no attached Flutter debug session:

```powershell
adb -s emulator-5554 shell am force-stop com.example.local_storage_lab
adb -s emulator-5554 shell am start -n com.example.local_storage_lab/.MainActivity
```

No process remained after force stop; the reopened process had a different PID. Storage was not cleared, the package was not uninstalled, and the database was not renamed.

### Additional checks

- Folder ID 2 was renamed from Keep to Keepers with one updated row and the same ID. Temporary card ID 4 was created under disposable Scratch folder ID 3, moved to Keepers through the folder selector, then deleted by ID. Canceling that card's deletion made no changes. Scratch's empty state and confirmed deletion were checked. Final main-install state: Keepers ID 2, Queen ID 3, card count 1, original guest count 3 ([additional_CRUD_result.json](evidence/additional_CRUD_result.json)).
- Fresh package: version 2 created from scratch; schema exactly matched the upgraded schema; initial guests/folders/cards were 0/0/0. Fresh sample folder ID 1 and Fresh card ID 1 were then created and linked successfully. The original app's data was untouched ([fresh_result.json](evidence/fresh_result.json), [fresh_install.png](evidence/fresh_install.png)).
- Analyzer: `flutter analyze` reported **No issues found** ([analysis_output.txt](evidence/analysis_output.txt)).
- The exact named release APK was signature-verified, installed over the upgraded main app, opened, checked for the retained folder/card and original guests, tested for blank-title rejection and fallback, and force-stopped/reopened successfully ([release_smoke_result.json](evidence/release_smoke_result.json), [release_smoke.png](evidence/release_smoke.png)).

Release APK: `Activity09_Gosangi_Rohan.apk`; 51,066,448 bytes. SHA-256: `c3930022a22a3dd7262dc0352be6180cdada8ee0b4d705e30ff18c2eb741d92b`. Its source build log is [release_build_output.txt](evidence/release_build_output.txt). Local path prefixes were redacted and trailing whitespace normalized; warnings and the build result are retained.

## Rubric map

| Criterion | Source / evidence |
| --- | --- |
| Schema and preservation (25) | database_helper.dart; T1; fresh_result.json; T5 cascade |
| Models, repository and CRUD (25) | models.dart; card_repository.dart; catalogue_screens.dart; T2/T3/T5/T6; additional CRUD |
| Image handling and usability (10) | CardImage and form/screen states; T2/T6 screenshots; empty-state and delete checks |
| Testing and evidence (20) | T1–T6 table and JSON results; three required named screenshots; analyzer; installed release smoke test |
| Critical thinking and AI Lab (15) | Individual DOCX submitted separately; reflection prompts 1–3; exactly two official U questions required |
| README and delivery (5) | This README, dependency/platform files; github_link.txt, release APK and DOCX submitted separately; iCollege receipt checked by the student |

## Limitations and submission

Only the documented Android emulator was tested; no physical Android device or iOS test was run. A successful HTTPS download/network-outage scenario and app-private-file loading were not tested. Missing-asset and malformed-reference fallbacks were observed without relying on a network. Zero-row write and read-after-write failure messages exist, but those failure branches were not deliberately injected. Folder names differing only in case are allowed by the chosen UNIQUE policy.

An initial emulator session had a stuck display and unavailable UI hierarchy; it was restarted without wiping storage, then awakened/unlocked. Readable screenshots were verified after recovery. No Part I records were erased during recovery or migration. The Android build emitted native-access/SDK-tool warnings; the APK built, signature verification passed, and the exact release file was installed and tested.

The official U1–U4 claim text was absent from the supplied companion notes. The individual reflection draft remains incomplete until exactly two official undergraduate questions are supplied and addressed. Student identity details belong in the separate DOCX; the student ID is not in this public repository.

Submit three separate files to the correct Activity 09 iCollege folder: `github_link.txt`, `Activity09_Gosangi_Rohan.apk`, and the completed `Gosangi_Rohan_CriticalThinking.docx`. A source ZIP is not a substitute. Reopen/download the three uploads and retain the receipt; those iCollege actions are not claimed as completed here. The supplied notes list October 8, 2026 at 11:59 pm; the official assignment controls the cutoff/timezone and AI-use rules.

## Attribution and resources

Part I's helper/interface and roster were recreated from the supplied Activity 08 guide with Codex assistance; the instructor's downloadable helper was not supplied. Activity 09's migration, models, repository, catalogue UI, image handling, tests and documentation were added with Codex assistance. The original write-up/evidence are retained under [docs/activity08](docs/activity08/README.md), and original source is in Git history at `8d2db56`.

- Supplied Activity 09 Local Storage Part II companion notes: requirements and rubric summary; official instructions remain the source of truth.
- [sqflite package documentation](https://pub.dev/packages/sqflite): bound queries, schema callbacks and transaction behavior.
- [SQLite foreign keys](https://www.sqlite.org/foreignkeys.html): connection enforcement and delete actions.
- [Flutter Android release guide](https://docs.flutter.dev/deployment/android): release build and installation.
- Flutter Material widgets and suit characters are used; no external image assets/licenses are required.
