# PlotShot

A private GLP-1 jab tracker for Android, built with Flutter. It logs jabs and
weight, and estimates how much medication is in your system over time.
Everything is stored on the phone. There are no accounts and no servers.

## Features

- **Estimated medication level.** Each jab is modelled with first-order
  absorption and elimination, and the curves are added together. Shown on
  Summary (chart with a "now" marker, a dashed projection and
  drag-to-inspect), as the "Est. level" stat, and per day in the Calendar.
- **Jabs.** A Next Jab card shows when you're due, the planned dose (tap ✎ to
  step up) and the next site in your rotation. History is grouped by month.
- **Results.** A weight chart coloured by dose, with 1/3/6 month and all-time
  ranges. Stats for total change, BMI, current weight, percent change, weekly
  average and distance to goal. A per-dose table and the weight log.
- **Calendar.** A month view. Each day records the jab, est. level, weight,
  calories, protein, side effects and notes.
- **Summary.** Sections you can reorder and hide: Jab History, Levels,
  Next Jab, Today, Results, Journey.
- **Reminders.** A notification on jab day, plus up to 3 daily follow-ups if
  you miss it.
- **Health Connect.** Reads weight, calories and protein. Values you type in
  are never overwritten.
- **Backup.** JSON export through the share sheet, and import.
- **Units.** kg, lb or st+lb for weight; cm or ft+in for height.

## Medication model

Amount in body after a dose *D* given *t* days ago:

    A(t) = D · ka / (ka − ke) · (e^(−ke·t) − e^(−ka·t))

`ke = ln 2 / half-life`. `ka` is solved so the curve peaks at the medication's
*time to peak*. Built-in defaults (all editable in Settings → Medications):

| Medication  | Half-life | Time to peak |
|-------------|-----------|--------------|
| Retatrutide | 6 days    | 1.5 days     |
| Tirzepatide | 5 days    | 1 day        |
| Semaglutide | 7 days    | 2 days       |

These are estimates for interest only, not medical advice.

## Getting the app

Every push runs **Build APK** in GitHub Actions. Open the run, download the
`plotshot-N` artifact, unzip it and install `app-release.apk` on your phone.
You'll need to allow installs from your browser or file manager.

### Signing

Updates only install over an existing copy when they are signed with the same
key. By default builds use `android/app/plotshot-shared.keystore`, which is
committed so every CI build is consistent. Anyone with access to this repo
could sign an APK with that key. To use a private key instead, add the
`KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS` and `KEY_PASSWORD`
repository secrets. Switching keys means uninstalling first, so export a
backup before you do.

## Development

    flutter pub get
    flutter analyze
    flutter test
    flutter run

Project layout:

- `lib/logic/`: pure Dart (PK model, stats, schedule, units, sites), unit tested
- `lib/data/`: SQLite storage, settings, backup format, `AppState`
- `lib/services/`: notifications and Health Connect
- `lib/screens/`, `lib/widgets/`: UI, including custom-painted charts
