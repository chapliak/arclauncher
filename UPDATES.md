# This fork (chapliak/arclauncher) — how it differs and how to take upstream updates

Upstream: https://github.com/meddouribadis/arclauncher (remote `upstream`). This fork never auto-updates: app id `com.chapliak.arc`,
own signing key, self-updater off. You decide when to merge a new upstream release.

## What the fork adds (all in separate files where possible)
- `lib/jw/` — daily text (wol.jw.org, English + Ukrainian) on the wallpaper, "New videos" row (public mediator API) that opens the video
  in Cedar TV (`cedartv://play?key=..&lang=E|K`), settings page "Daily text & videos".
- `assets/forest_wallpaper.jpg` + small edit in `lib/providers/wallpaper_service.dart`: fixed dark forest wallpaper.
- Android: `ClockScreensaverService.java` (picture + daily text on the screensaver), `MainActivity.java` (`launchUri`), `build.gradle`
  (app id, signing from env). Small edits: `main.dart`, `flauncher.dart`, `flauncher_channel.dart`, `settings_panel.dart`, `misc_panel_page.dart`.
- `tools/build.sh` builds the TV APK (armeabi-v7a) in Docker, key in `~/.arc-fork-key` (back it up, never commit).

## Take a new upstream release
    git fetch upstream --tags
    git log --oneline chapliak-custom..upstream/main      # read what changed first
    git checkout -b merge-<version> chapliak-custom
    git merge upstream/main                                 # or: git rebase upstream/main
    bash tools/build.sh                                     # dist/arc-fork-armeabi-v7a.apk
Fix conflicts (usually the small edits listed above), build, install with `adb install -r` (same key, keeps settings), test, then merge into `chapliak-custom`.

## Safety on the TV (Google TV Streamer, 2 GB RAM)
- Home role: `cmd role get-role-holders android.app.role.HOME`; change only while the new launcher is already running, never disable the current one.
- Google's `launcherx` and `tvlauncher` stay disabled (else Home goes to Google TV). Roll back: `pm enable com.google.android.apps.tv.launcherx`.
- Projectivy is disabled (`pm enable com.spocky.projengmenu` brings it back).
- Wireless debugging switches off at every reboot.
