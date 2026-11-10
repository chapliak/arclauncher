/* Arc Launcher fork (chapliak): settings for the JW daily text and new-videos row. */

import 'package:flauncher/jw/jw_service.dart';
import 'package:flauncher/providers/wallpaper_service.dart';
import 'package:flauncher/widgets/rounded_switch_list_tile.dart';
import 'package:flauncher/widgets/settings/focusable_settings_tile.dart';
import 'package:flauncher/widgets/settings/settings_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class JwSettingsPage extends StatelessWidget {
  static const String routeName = "jw_settings";
  const JwSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final jw = context.watch<JwService>();
    final wp = context.watch<WallpaperService>();
    final body = Theme.of(context).textTheme.bodyMedium;
    String langName(JwTextLang l) => switch (l) { JwTextLang.en => 'English', JwTextLang.uk => 'Українська', JwTextLang.both => 'Both (alternate)' };
    return Column(
      children: [
        const SettingsPageHeader(title: 'Daily text & videos'),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              RoundedSwitchListTile(
                autofocus: true,
                value: jw.showDailyText,
                onChanged: jw.setShowDailyText,
                title: Text('Daily text on wallpaper and screensaver', style: body),
                secondary: const Icon(Icons.menu_book_outlined),
              ),
              FocusableSettingsTile(
                leading: const Icon(Icons.translate),
                title: Text('Text language: ${langName(jw.textLang)}', style: body),
                onPressed: () => jw.setTextLang(JwTextLang.values[(jw.textLang.index + 1) % JwTextLang.values.length]),
              ),
              RoundedSwitchListTile(
                value: jw.showVideos,
                onChanged: jw.setShowVideos,
                title: Text('New videos row (opens in Cedar TV)', style: body),
                secondary: const Icon(Icons.video_library_outlined),
              ),
              FocusableSettingsTile(
                leading: const Icon(Icons.language),
                title: Text('Video language: ${jw.videoLang == 'K' ? 'Українська' : 'English'}', style: body),
                onPressed: () => jw.setVideoLang(jw.videoLang == 'K' ? 'E' : 'K'),
              ),
              RoundedSwitchListTile(
                value: wp.natureEnabled,
                onChanged: wp.setNatureEnabled,
                title: Text('Dark forest wallpaper (fixed picture)', style: body),
                secondary: const Icon(Icons.landscape_outlined),
              ),
              FocusableSettingsTile(
                leading: const Icon(Icons.refresh),
                title: Text('Refresh now', style: body),
                onPressed: jw.refresh,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
