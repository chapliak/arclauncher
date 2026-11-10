/* Arc Launcher fork (chapliak): home-screen widgets for the JW content. */

import 'package:flauncher/actions.dart';
import 'package:flauncher/jw/jw_service.dart';
import 'package:flauncher/providers/launcher_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

/// Today's text on the wallpaper (top left, under the status bar). Fades out while the app grid is focused.
class DailyTextOverlay extends StatelessWidget {
  const DailyTextOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final jw = context.watch<JwService>();
    final hidden = context.select<LauncherState, bool>((s) => s.appGridFocused);
    final cur = jw.current;
    final width = MediaQuery.sizeOf(context).width;
    return Positioned(
      left: 48,
      top: 70,
      width: width * 0.5,
      child: IgnorePointer(
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: hidden || cur == null ? 0 : 1,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 700),
            child: cur == null
                ? const SizedBox.shrink()
                : Material(
                    key: ValueKey(cur.$1),
                    type: MaterialType.transparency,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [Colors.black.withValues(alpha: 0.45), Colors.transparent]),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 24, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              cur.$2 == 'UA' ? 'ТЕКСТ ДНЯ' : 'DAILY TEXT',
                              style: const TextStyle(fontSize: 10, letterSpacing: 2, color: Colors.white70, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              cur.$1,
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 17,
                                height: 1.3,
                                color: Colors.white,
                                shadows: [Shadow(blurRadius: 6, color: Colors.black87)],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Horizontal row of the newest videos; OK opens the video in Cedar TV.
class JwVideosRow extends StatelessWidget {
  final VoidCallback? onItemFocused;
  const JwVideosRow({super.key, this.onItemFocused});

  static const double height = 215;

  @override
  Widget build(BuildContext context) {
    final jw = context.watch<JwService>();
    if (!jw.showVideos || jw.videos.isEmpty) return const SizedBox.shrink();
    final accent = Theme.of(context).colorScheme.primary;
    return SizedBox(
      height: height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(48, 0, 48, 6),
            child: Text(
              jw.videoLang == 'K' ? 'Нові відео' : 'New videos',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                shadows: const [Shadow(blurRadius: 6, color: Colors.black87)],
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 6),
              itemCount: jw.videos.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (context, i) => _VideoCard(
                video: jw.videos[i],
                accent: accent,
                onFocused: onItemFocused,
                onOpen: () async {
                  final ok = await jw.play(jw.videos[i]);
                  if (!ok && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Cedar TV is not installed or too old')),
                    );
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoCard extends StatelessWidget {
  final JwVideo video;
  final Color accent;
  final VoidCallback onOpen;
  final VoidCallback? onFocused;
  const _VideoCard({required this.video, required this.accent, required this.onOpen, this.onFocused});

  static final _select = {LogicalKeyboardKey.select, LogicalKeyboardKey.enter, LogicalKeyboardKey.numpadEnter, LogicalKeyboardKey.gameButtonA};

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (f) {
        if (f) {
          onFocused?.call();
          Scrollable.ensureVisible(context, alignment: 0.5, duration: const Duration(milliseconds: 150));
        }
      },
      onKeyEvent: (node, e) {
        if (e is KeyDownEvent && _select.contains(e.logicalKey)) {
          onOpen();
          return KeyEventResult.handled;
        }
        // Up from this row goes to the top bar (settings, Wi-Fi), like the other home rows.
        if (e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.arrowUp) {
          Actions.invoke(node.context!, const MoveFocusToSettingsIntent());
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Builder(builder: (context) {
        final focused = Focus.of(context).hasFocus;
        return GestureDetector(
          onTap: onOpen,
          child: AnimatedScale(
            scale: focused ? 1.06 : 1,
            duration: const Duration(milliseconds: 120),
            child: SizedBox(
              width: 200,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 112,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: focused ? accent : Colors.transparent, width: 3),
                      color: Colors.black38,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(video.imageUrl, fit: BoxFit.cover, cacheWidth: 400, errorBuilder: (_, __, ___) => const SizedBox()),
                        if (video.minutes > 0)
                          Positioned(
                            right: 6,
                            bottom: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(4)),
                              child: Text('${video.minutes} min', style: const TextStyle(fontSize: 10, color: Colors.white)),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.2,
                      color: focused ? Colors.white : Colors.white70,
                      shadows: const [Shadow(blurRadius: 4, color: Colors.black87)],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}
