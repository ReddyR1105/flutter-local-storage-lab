# Fall Festival Roster — Local Storage Lab, Activity 08

## Status and authorship

Flutter implementation prepared with OpenAI Codex assistance. Device checks and the evidence below are performed by Codex through the Android emulator; they are not represented as the student's personal observations. Review the code, rerun the required walkthrough yourself, add your name/course/pathway, and disclose assistance according to your course rules before submitting.

The pasted guide omitted the downloadable database helper, expanded prompts 2–4, assessment rubrics, and submission instructions. `lib/database_helper.dart` recreates the interface and exact version-1 schema described in the guide. Compare it with the instructor's helper and check the complete LMS submission requirements.

## Environment and running

- Windows host; Flutter 3.47.4 stable; Dart 3.13.3.
- Android application ID: `com.example.local_storage_lab`.
- Verified target: Pixel_4a emulator (`emulator-5554`), Android 17 / API 37.1, x86_64, 16 KB page image.
- Generated Dart constraint `^3.13.3` retained because it matches the installed Flutter SDK.
- Resolved versions: sqflite 2.4.4+1, path_provider 2.1.6, path 1.9.1.
- Guide dependency constraints retained: `sqflite: ^2.4.1`, `path_provider: ^2.1.5`, `path: ^1.9.0`. Exact resolved versions are in `pubspec.lock`.
- Android build memory limited to 2 GB/two Gradle workers; Kotlin compilation runs in process with incremental compilation disabled to avoid the Windows compiler cache failure seen during setup.

From the project directory:

```powershell
flutter pub get
flutter devices
flutter run -d <android-device-id>
flutter analyze 2>&1 | Tee-Object -FilePath .\evidence\analysis_output.txt
```

Choose Android on Windows. This project uses the lab's mobile `sqflite` setup. iOS source is included but requires macOS/Xcode and has not been verified here.

## Implementation

`main()` initializes Flutter bindings, creates one `DatabaseHelper`, awaits `init()`, and passes that same instance into `DirectoryApp` and `DirectoryScreen`. An initialization exception produces an explicit error screen and a diagnostic stack trace. The first roster read starts in `initState()`, never `build()`.

The database is `MyDatabase.db` in the application documents directory. Schema version 1 creates `my_table` with `_id INTEGER PRIMARY KEY`, `name TEXT NOT NULL`, and `age INTEGER NOT NULL`; there are no seeded guests. Insert omits `_id`, query explicitly orders IDs ascending, and update/delete bind the integer ID through `whereArgs`.

The shared Add/Edit form trims names and rejects empty names. It uses `int.tryParse()` to validate integer ages from 0 through 130, inclusive, before writing. Two guests may share a name because identity is the generated `_id`. Cancel edit writes nothing; deletion requires confirmation showing ID/name; canceling deletion writes nothing.

One busy flag disables Add/Save, Edit, Delete, Refresh, Cancel edit, and form editing during pending actions. Successful writes clear the appropriate form and reload both rows and count. One affected row means update/delete success; zero produces an explicit not-found message and a reload. Write failures preserve input; a successful write followed by a failed read reports the completed write and a refresh failure. Refresh retries only reads. Read errors retain and label the last successfully loaded data; only a successful empty read displays "No festival guests yet." Controllers are disposed, and asynchronous state updates check `mounted`.

The generated counter-app widget test was removed as directed by the guide. No replacement automated test suite or migrations were added; T1–T6 are the required verification.

## Verification results

The actual analyzer result is **No issues found** (`evidence/analysis_output.txt`). The Android debug APK built successfully (`evidence/build_output.txt`). All T1-T6 checks below were driven through the visible app with ADB; row snapshots and the T6 input/result log are included in `evidence/`. These are assistant-performed checks.

A = generated ID **1**; B = generated ID **2**. Both names are River.

| Test | Action/input | Expected | Observed rows/count | Result |
| --- | --- | --- | --- | --- |
| T1 | Refresh on initial empty installation | Count 0 and successful empty state | No rows; count 0; "No festival guests yet" | PASS |
| T2 | Add River 21, then River 34 | Two different generated integer IDs; count 2 | A=1 River 21, B=2 River 34; count 2; feedback reported each inserted ID | PASS |
| T3 | Edit B to 99, Cancel; edit B to 35, Save | Cancel preserves 34; Save affects one row and preserves A | Canceled input was exactly 99; B stayed 34. Saved input was exactly 35; "Updated 1 row"; A=1 River 21, B=2 River 35; count 2 | PASS |
| T4 | App info -> Force stop -> OK; reopen same installation from launcher icon | Same rows/IDs/ages/count with a new process | Before PID 2682, no PID after Force stop, after PID 8477; A=1 River 21, B=2 River 35; count 2 | PASS |
| T5 | Cancel Delete A; then confirm Delete A; Refresh | Cancel count 2; delete affects one row; B alone/count 1 | Cancel preserved both; "Deleted ID 1. Deleted 1 row"; after Refresh B=2 River 35 only; count 1 | PASS |
| T6 | Five rejected attempts, then two accepted boundary inserts (details below) | Invalid inputs preserve B/count 1; boundaries accepted; final count 3 | Actual individual results are recorded below and in `evidence/T6_results.json` | PASS (all seven attempts) |

No hot reload/hot restart, uninstall, Clear storage, app identifier change, or automatic seeding was used for T4. The installed debug APK had no attached Flutter debug session to stop. The launcher briefly stalled; disabling emulator animations and restarting only its launcher process recovered it, after which the lab's launcher icon opened the new process. `evidence/T4_restart_method.txt` records the exact method. iOS was not tested.

The initial ADB edit driver appended digits instead of replacing them. The app correctly rejected the resulting out-of-range age; the driver was corrected to clear the field, and T3 was rerun with captured exact inputs 99 and 35. This was an input-driver failure, not a database update failure.

Required screenshots:

- [T4_before.png](evidence/T4_before.png): A=1/21, B=2/35, count 2 before Force stop.
- [T4_after.png](evidence/T4_after.png): the same stored roster after cold launch.
- [T6_invalid.png](evidence/T6_invalid.png): space-only name rejected with field feedback, B=2/35 and count 1 unchanged.

| T6 attempt | Name / age input | Expected | Observed rows/count | Result |
| --- | --- | --- | --- | --- |
| Whitespace name | Three spaces / 21 | Reject empty trimmed name | "Enter a nonempty name"; ID 2 River 35 unchanged; count 1 | PASS |
| Nonnumeric age | Maple / abc | Reject noninteger | "Enter a whole-number age"; ID 2 River 35 unchanged; count 1 | PASS |
| Decimal age | Maple / 1.5 | Reject noninteger | "Enter a whole-number age"; ID 2 River 35 unchanged; count 1 | PASS |
| Below minimum | Maple / -1 | Reject out of range | "Age must be from 0 through 130"; ID 2 River 35 unchanged; count 1 | PASS |
| Above maximum | Maple / 131 | Reject out of range | "Age must be from 0 through 130"; ID 2 River 35 unchanged; count 1 | PASS |
| Minimum boundary | Acorn / 0 | Accept one insert | Generated ID 3, Acorn 0; ID 2 River 35 unchanged; count 2 | PASS |
| Maximum boundary | Oak / 130 | Accept one insert | Generated ID 4, Oak 130; ID 2 River 35 and ID 3 Acorn 0 unchanged; final count 3 | PASS |

All seven inputs were verified in the form before tapping Add. The emulator currently contains those three final fictional rows; the source project contains no database or seed data, so a new installation begins empty.

## Reflection notes to review and personalize

### 1. The disappearing-data mystery

The assistant prediction was recorded before T4 in `evidence/T4_prediction.txt`: IDs 1 and 2 (River ages 21 and 35), count 2, would survive because the writes completed to the same SQLite file; unsaved form state would not. On Android 17, App info > Force stop > OK followed by the launcher icon produced a new process (2682 to 8477) and restored exactly those values, as shown in `T4_before.png` and `T4_after.png`. The restore path is `main()` > awaited `helper.init()` > `DirectoryScreen.initState()` > `_refresh()` > `_loadRows()` > queried rows/count > `setState()` > list. Missing or changed rows after that same-installation restart, or evidence of automatic reinsertion instead of querying, would disprove the claimed restore.

### 2. Two Rivers, one wrong edit

The two Rivers were IDs 1 and 2; T3 canceled an unsaved age 99 for ID 2, leaving it at 34, then saved age 35 with one affected row while ID 1 remained age 21 (count 2). `_edit()` stores `_id`, and `_save()` passes it to `update()`, which binds `_id = ?` using `whereArgs: [id]`; targeting by name could change both rows. Cancel clears form/selection without calling the helper's update method, explaining why the unsaved age did not reach SQLite.

### 3. Your own usability walkthrough

In the assistant walkthrough, a space-only name with age 21 showed "Enter a nonempty name" while River ID 2 remained age 35 and count 1 (`T6_invalid.png`); canceling deletion also explicitly said no changes. The previous "Roster refreshed from local storage" message remained visible below the invalid form, which could distract from the new validation result. A small proposed improvement is to clear old action feedback whenever validation rejects an Add/Save attempt; the improvement is not implemented. Review this observation and replace or supplement it with your own walkthrough.

### 4. Defend the storage boundary (optional graduate notes)

The UI enforces trimmed names and integer ages 0–130 because `NOT NULL` alone does not prohibit whitespace-only names or negative ages. A future application with other writers should also enforce appropriate database `CHECK` constraints; for this lab, all writes pass through the validated screen. Changing only the version-1 `onCreate` SQL will not change an existing installation's table, so adding a required column would need a version increase and a migration/backfill; otherwise queries or inserts expecting that column could fail.

## References

- Supplied activity guide (pasted by the student).
- [Flutter: Persist data with SQLite](https://docs.flutter.dev/cookbook/persistence/sqlite).
- [sqflite package documentation](https://pub.dev/packages/sqflite).

## Before submission

1. Add your identity and pathway; confirm the full LMS rubric, expanded prompts, archive name, and upload requirements.
2. Review the implementation and compare the recreated helper with the instructor's downloadable helper.
3. Perform your own T1–T6 walkthrough with fictional data, a prediction before T4, and the specified actual stop/relaunch method. Use your own IDs/counts and screenshots if the course requires personally collected evidence.
4. Personalize the required reflections and retain the AI-assistance disclosure according to course policy.
5. Inspect the source ZIP and upload it to the LMS. The pasted guide lists October 6, 2026 at 8:00 pm as the deadline; it does not supply a timezone.
