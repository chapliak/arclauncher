/*
 * Arc Launcher fork (chapliak): JW daily text + latest videos.
 * Own file on purpose, so merging upstream releases stays easy.
 * Data: wol.jw.org (daily text, English + Ukrainian) and the public mediator API (latest videos).
 * Texts are also stored in SharedPreferences (Android side "flutter.jw_*") for the native screensaver.
 */

import 'dart:async';
import 'dart:convert';

import 'package:flauncher/flauncher_channel.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class JwVideo {
  final String key; // languageAgnosticNaturalKey
  final String title;
  final String imageUrl;
  final int minutes;
  const JwVideo({required this.key, required this.title, required this.imageUrl, required this.minutes});

  Map<String, dynamic> toJson() => {'k': key, 't': title, 'i': imageUrl, 'm': minutes};
  static JwVideo fromJson(Map<String, dynamic> j) =>
      JwVideo(key: j['k'] as String, title: j['t'] as String, imageUrl: j['i'] as String, minutes: (j['m'] as num).toInt());
}

enum JwTextLang { en, uk, both }

class JwService extends ChangeNotifier {
  static const _ua = 'Mozilla/5.0 (compatible; ArcLauncherFork/1.0)';
  static final _theme = RegExp(r'<p[^>]*class="[^"]*themeScrp[^"]*"[^>]*>(.*?)</p>', dotAll: true);

  final SharedPreferences _p;
  final FLauncherChannel _channel;
  final http.Client _client;

  String? textEn;
  String? textUk;
  List<JwVideo> videos = const [];
  bool _showUk = false;
  Timer? _refreshTimer;
  Timer? _rotateTimer;

  JwService(this._p, this._channel, {http.Client? client}) : _client = client ?? http.Client() {
    textEn = _p.getString('jw_text_en');
    textUk = _p.getString('jw_text_uk');
    _loadCachedVideos();
    refresh();
    // Re-check every 30 minutes: picks up the new day's text and new videos.
    _refreshTimer = Timer.periodic(const Duration(minutes: 30), (_) => refresh());
    _rotateTimer = Timer.periodic(const Duration(seconds: 40), (_) {
      if (textLang == JwTextLang.both && textEn != null && textUk != null) {
        _showUk = !_showUk;
        notifyListeners();
      }
    });
  }

  // ---- settings (own keys, not in SettingsService, to keep merges clean) ----
  bool get showDailyText => _p.getBool('jw_show_text') ?? true;
  bool get showVideos => _p.getBool('jw_show_videos') ?? true;
  JwTextLang get textLang => switch (_p.getString('jw_text_lang')) {
    'en' => JwTextLang.en,
    'uk' => JwTextLang.uk,
    _ => JwTextLang.both,
  };

  /// Mediator language code for the videos row: "E" (English) or "K" (Ukrainian).
  String get videoLang => _p.getString('jw_video_lang') == 'K' ? 'K' : 'E';

  Future<void> setShowDailyText(bool v) async { await _p.setBool('jw_show_text', v); notifyListeners(); }
  Future<void> setShowVideos(bool v) async { await _p.setBool('jw_show_videos', v); notifyListeners(); }
  Future<void> setTextLang(JwTextLang v) async { await _p.setString('jw_text_lang', v.name); notifyListeners(); }
  Future<void> setVideoLang(String v) async {
    await _p.setString('jw_video_lang', v);
    videos = const [];
    notifyListeners();
    await _loadVideos();
  }

  /// The text to show right now (rotates every 40 s when both languages are on) and its small label.
  (String text, String label)? get current {
    if (!showDailyText) return null;
    final en = textEn, uk = textUk;
    switch (textLang) {
      case JwTextLang.en:
        return en == null ? null : (en, 'EN');
      case JwTextLang.uk:
        return uk == null ? null : (uk, 'UA');
      case JwTextLang.both:
        if (en != null && uk != null) return _showUk ? (uk, 'UA') : (en, 'EN');
        if (en != null) return (en, 'EN');
        if (uk != null) return (uk, 'UA');
        return null;
    }
  }

  // ---- fetching ----
  Future<void> refresh() async {
    await Future.wait([_loadDaily(), _loadVideos()]);
  }

  String _today() {
    final d = DateTime.now();
    return '${d.year}-${d.month}-${d.day}';
  }

  Future<void> _loadDaily() async {
    final today = _today();
    var changed = false;
    for (final (locale, rsrc, key) in const [('en', 'r1/lp-e', 'en'), ('uk', 'r15/lp-k', 'uk')]) {
      if (_p.getString('jw_text_${key}_date') == today && _p.getString('jw_text_$key') != null) continue;
      try {
        final d = DateTime.now();
        final r = await _client
            .get(Uri.parse('https://wol.jw.org/$locale/wol/dt/$rsrc/${d.year}/${d.month}/${d.day}'),
                headers: {'User-Agent': _ua})
            .timeout(const Duration(seconds: 20));
        if (r.statusCode != 200) continue;
        final m = _theme.firstMatch(utf8.decode(r.bodyBytes));
        if (m == null) continue;
        final text = _clean(m.group(1)!);
        if (text.isEmpty) continue;
        await _p.setString('jw_text_$key', text);
        await _p.setString('jw_text_${key}_date', today);
        if (key == 'en') { textEn = text; } else { textUk = text; }
        changed = true;
      } catch (e) {
        debugPrint('JW daily text ($locale): $e');
      }
    }
    if (changed) notifyListeners();
  }

  static String _clean(String html) {
    var s = html.replaceAll(RegExp(r'<[^>]+>'), '');
    s = s
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&quot;', '"')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (m) => String.fromCharCode(int.parse(m.group(1)!, radix: 16)))
        .replaceAllMapped(RegExp(r'&#(\d+);'), (m) => String.fromCharCode(int.parse(m.group(1)!)))
        .replaceAll('&amp;', '&')
        .replaceAll('​', '')
        .replaceAll(' ', ' ');
    return s.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  void _loadCachedVideos() {
    final raw = _p.getString('jw_videos_$videoLang');
    if (raw == null) return;
    try {
      videos = (jsonDecode(raw) as List).map((e) => JwVideo.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {}
  }

  static String? _image(dynamic images) {
    if (images is! Map) return null;
    for (final (ratio, sizes) in const [('wss', ['md', 'lg', 'sm']), ('lsr', ['md', 'lg', 'sm']), ('wsr', ['md', 'lg'])]) {
      final o = images[ratio];
      if (o is! Map) continue;
      for (final s in sizes) {
        final u = o[s];
        if (u is String && u.isNotEmpty) return u;
      }
    }
    return null;
  }

  Future<void> _loadVideos() async {
    final lang = videoLang;
    try {
      final r = await _client
          .get(Uri.parse('https://b.jw-cdn.org/apis/mediator/v1/categories/$lang/LatestVideos?detailed=1'),
              headers: {'User-Agent': _ua})
          .timeout(const Duration(seconds: 20));
      if (r.statusCode != 200) return;
      final media = (jsonDecode(utf8.decode(r.bodyBytes))['category']['media'] as List).cast<Map<String, dynamic>>();
      final list = <JwVideo>[];
      for (final m in media) {
        final key = m['languageAgnosticNaturalKey'] as String?;
        final title = (m['title'] as String?)?.trim();
        final img = _image(m['images']);
        if (key == null || key.isEmpty || title == null || title.isEmpty || img == null) continue;
        if ((m['files'] as List?)?.isEmpty ?? true) continue;
        list.add(JwVideo(key: key, title: title, imageUrl: img, minutes: ((m['duration'] as num?) ?? 0) ~/ 60));
        if (list.length >= 12) break;
      }
      if (list.isEmpty || lang != videoLang) return;
      videos = list;
      await _p.setString('jw_videos_$lang', jsonEncode(list.map((v) => v.toJson()).toList()));
      notifyListeners();
    } catch (e) {
      debugPrint('JW videos: $e');
    }
  }

  /// Opens the video in Cedar TV (deep link handled by that app).
  Future<bool> play(JwVideo v) async {
    try {
      await _channel.launchUri('cedartv://play?key=${Uri.encodeComponent(v.key)}&lang=$videoLang');
      return true;
    } catch (e) {
      debugPrint('Cedar TV launch failed: $e');
      return false;
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _rotateTimer?.cancel();
    super.dispose();
  }
}
