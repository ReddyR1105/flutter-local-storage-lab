# In-Class 08 / Fall Festival Roster

- **Student:** Rohan Reddy
- **Course/section:** CSC MAD (Mobile Application Development)
- **Pathway:** Undergraduate
- **Date:** October 6, 2026
- **Repository:** https://github.com/ReddyR1105/flutter-local-storage-lab

## Assistance

I used Codex to help prepare the Flutter app and this write-up. Codex ran the recorded emulator checks, so the screenshots and observations below come from those checks.

## About the app

The app keeps a small guest list for a Fall Festival. Each guest has a name, an age, and an ID assigned by SQLite. The screen supports Add, Edit, Cancel edit, Delete, and Refresh, and it displays the saved records and their count.

## Storage notes

- **Schema and initialization:** `MyDatabase.db` is stored in the app's documents directory. Version 1 creates `my_table`; `main()` initializes one helper and waits for `init()` before the first read. The columns are listed below.
- **Input policy, IDs, and CRUD:** names are trimmed and must be nonempty; ages must be integers from 0 to 130. SQLite generates the IDs, and update/delete bind the selected ID. CRUD methods are in [database_helper.dart](lib/database_helper.dart); form validation, confirmation, and screen refresh are in [main.dart](lib/main.dart).

| Column | Type | Purpose |
| --- | --- | --- |
| `_id` | `INTEGER PRIMARY KEY` | Identifies a guest, even when names match |
| `name` | `TEXT NOT NULL` | Stores the guest's name |
| `age` | `INTEGER NOT NULL` | Stores the guest's age |

**Storage examples:** the unsaved text in the form, selected edit ID, and loading flag are memory state. A small theme choice could use key-value preferences; this app does not implement that optional setting. Guest records such as River, ID 2, age 35 belong in SQLite. The first read runs from `initState()`, and successful writes are followed by fresh row/count queries. No guests are seeded at startup.

The form trims the name and rejects an empty result. Ages must be whole numbers from 0 to 130. Edits and deletions use the selected ID, and deletion asks for confirmation showing the ID and name. The app disables controls while an operation is pending and shows loading, empty, error, and affected-row feedback. Failed writes preserve the form input; a completed write followed by a failed refresh has a separate message.

## Setup and running

The recorded checks used Windows, Flutter 3.47.4, Dart 3.13.3, and the Pixel_4a Android emulator (`emulator-5554`, Android 17 / API 37.1). iOS files are included, but iOS was not tested.

The guide's dependency constraints were kept:

```yaml
sqflite: ^2.4.1
path_provider: ^2.1.5
path: ^1.9.0
```

The resolved versions are sqflite 2.4.4+1, path_provider 2.1.6, and path 1.9.1. `pubspec.lock` is included. The generated Dart constraint, `^3.13.3`, matches the installed SDK.

On the recorded Windows setup, open a terminal in `local_storage_lab`, start the existing emulator, and run:

```powershell
flutter emulators --launch Pixel_4a
flutter pub get
flutter devices
flutter run -d emulator-5554
```

To run the analyzer and save its output:

```powershell
flutter analyze 2>&1 | Tee-Object -FilePath .\evidence\analysis_output.txt
```

## Test results

The analyzer reported **No issues found**, and the Android debug APK built successfully. The saved outputs are [analysis_output.txt](evidence/analysis_output.txt) and [build_output.txt](evidence/build_output.txt). The table below records the checks performed through the app on the emulator.

**A = ID 1** and **B = ID 2**. Both guests were named River.

| Test | Action/input | Expected | Observed rows/count | Pass/fail |
| --- | --- | --- | --- | --- |
| T1 - Empty | Refresh the empty roster | Count 0 and an empty-state message | Count 0; "No festival guests yet" | Pass |
| T2 - Create | Add River, 21 and River, 34 | Different generated IDs; count 2 | ID 1: River, 21; ID 2: River, 34; count 2 | Pass |
| T3 - Identity | Change B's age to 99 and Cancel; then change it to 35 and Save | Cancel keeps 34; Save updates one row and leaves A unchanged | Cancel kept ID 2 at 34. Save reported 1 updated row. ID 1 stayed 21; ID 2 became 35; count 2 | Pass |
| T4 - Restart | Force stop the app and reopen the same installation from its launcher icon | Same IDs, names, ages, and count | ID 1: River, 21; ID 2: River, 35; count 2 before and after | Pass |
| T5 - Delete | Cancel deletion of A; then confirm it and Refresh | Cancel keeps both rows; confirm deletes one row | Cancel kept count 2. Confirm reported 1 deleted row. Only ID 2: River, 35 remained; count 1 | Pass |
| T6 - Validation | Try the five invalid inputs and two boundary ages listed below | Invalid inputs write nothing; ages 0 and 130 are accepted | All invalid attempts kept count 1. Acorn and Oak were accepted; final count 3 | Pass |

### T6: individual attempts

| Input | Expected | Observed rows/count | Pass/fail |
| --- | --- | --- | --- |
| Three spaces as the name; age 21 | Reject the empty trimmed name | "Enter a nonempty name"; River ID 2, age 35 unchanged; count 1 | Pass |
| Maple; age abc | Reject a nonnumber | "Enter a whole-number age"; River ID 2 unchanged; count 1 | Pass |
| Maple; age 1.5 | Reject a decimal | "Enter a whole-number age"; River ID 2 unchanged; count 1 | Pass |
| Maple; age -1 | Reject an age below 0 | "Age must be from 0 through 130"; River ID 2 unchanged; count 1 | Pass |
| Maple; age 131 | Reject an age above 130 | "Age must be from 0 through 130"; River ID 2 unchanged; count 1 | Pass |
| Acorn; age 0 | Accept the minimum age | Acorn received ID 3; River ID 2 unchanged; count 2 | Pass |
| Oak; age 130 | Accept the maximum age | Oak received ID 4; River ID 2 and Acorn ID 3 unchanged; count 3 | Pass |

The final saved rows were River (ID 2, age 35), Acorn (ID 3, age 0), and Oak (ID 4, age 130). The source archive does not contain the emulator's database; a new installation starts empty. The individual T6 observations are also saved in [T6_results.json](evidence/T6_results.json).

### Restart method and screenshots

The prediction was recorded before T4 in [T4_prediction.txt](evidence/T4_prediction.txt). It predicted that IDs 1 and 2, ages 21 and 35, and count 2 would survive because they had been saved to SQLite.

The installed debug APK had no attached Flutter debug session. Android App info was opened, Force stop was selected, and the confirmation was accepted. The app had no running process after that. It was reopened by tapping `local_storage_lab` in the launcher, without clearing storage or uninstalling it. The process ID changed from 2682 to 8477. The exact method is saved in [T4_restart_method.txt](evidence/T4_restart_method.txt).

| Screenshot | What it shows |
| --- | --- |
| [T4_before.png](evidence/T4_before.png) | ID 1: River, 21 and ID 2: River, 35; count 2 before stopping |
| [T4_after.png](evidence/T4_after.png) | The same two saved records and count 2 after reopening |
| [T6_invalid.png](evidence/T6_invalid.png) | A space-only name rejected while River ID 2 and count 1 stayed unchanged |

## Reflection answers

### 1. The disappearing-data mystery

The recorded prediction was that the saved rows would survive because SQLite stores them in a file, while unsaved form input stays in memory. After Force stop and a launcher restart, IDs 1 and 2 still had ages 21 and 35, and the count was still 2; the before and after screenshots show this. The restore path is `main()` waiting for `init()`, followed by `initState()`, `_refresh()`, `_loadRows()`, the row/count queries, and `setState()` displaying the results. Missing or changed rows after the same-installation restart, or automatic reinsertion instead of a database read, would undermine this explanation.

### 2. Two Rivers, one wrong edit

The two guests have the same name, so the ID is the reliable way to choose which one to change. The update uses `_id = ?` with `whereArgs: [id]`; using the name could change both rows. In the recorded test, canceling the age 99 edit kept ID 2 at 34, and saving age 35 updated one row while ID 1 stayed at 21. Cancel only clears the form and selection, so it does not write to the database.

### 3. Usability walkthrough

The recorded walkthrough showed clear field feedback when a space-only name was entered, and the unchanged count helped confirm that nothing was saved. However, the earlier "Roster refreshed from local storage" message remained below the invalid form. I would clear the old action message whenever validation rejects Add or Save, so the current result is easier to understand. This is a proposed improvement and has not been added.

## Development notes

- The downloadable instructor helper was not included in the supplied material. `database_helper.dart` recreates the described interface and schema. The form and its CRUD interaction code were added for this project with Codex assistance. The expanded wording of prompts 2-4 and the grading rubric were not supplied.
- The initial ADB input driver appended digits during an edit. The app rejected the invalid age; the driver was corrected, and T3 was rerun with the exact inputs 99 and 35.
- Android's launcher briefly stalled during T4. Restarting its process and temporarily disabling animations recovered it; no app data was cleared. Normal animation settings were restored afterward.
- The Windows build encountered a Kotlin cache problem. Gradle memory/workers were limited, and Kotlin incremental compilation was disabled. The original counter-app widget test was removed as instructed in the guide.

## Before submitting

The final source archive is `Reddy_Rohan_InClass08.zip` and contains one `local_storage_lab` folder. Upload this ZIP to the course's In-Class 08 / Local Storage Part 1 entry, then reopen or download it and check the submission receipt. The posted cutoff is October 6, 2026 at 8:00 pm in the course/iCollege timezone. The guide asks for a personal prediction and walkthrough, so complete your own T1-T6 run and update the evidence and reflections as required. Keep the assistance disclosure consistent with your course rules.

## Attribution and references

- Starter basis: the supplied Local Storage Lab activity guide, including the described database helper interface/schema and dependency constraints. The actual starter helper file was not supplied.
- Assistance: Codex helped write the implementation and documentation and performed the recorded emulator checks. Those observations are not presented as a student-performed test run.
- [Flutter SQLite cookbook](https://docs.flutter.dev/cookbook/persistence/sqlite).
- [sqflite documentation](https://pub.dev/packages/sqflite).
