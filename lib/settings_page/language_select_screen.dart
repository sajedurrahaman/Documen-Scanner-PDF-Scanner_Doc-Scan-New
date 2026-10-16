import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../localaization/language_constant.dart';
import 'widgets/settings_ui.dart';

class LanguageSelectScreen extends StatefulWidget {
  const LanguageSelectScreen({super.key, required this.onLocaleChanged});
  final ValueChanged<Locale> onLocaleChanged;
  @override
  State<LanguageSelectScreen> createState() => _LanguageSelectScreenState();
}

class _LanguageSelectScreenState extends State<LanguageSelectScreen> {
  bool _saving = false;
  static const _languages = [
    ('en', 'English', 'English', 'us.svg'),
    ('bn', 'বাংলা', 'Bengali', 'bd.svg'),
    ('hi', 'हिन्दी', 'Hindi', 'ind.svg'),
    ('ar', 'العربية', 'Arabic', 'as.svg'),
    ('es', 'Español', 'Spanish', 'sp.svg'),
    ('fr', 'Français', 'French', 'fr.svg'),
    ('ru', 'Русский', 'Russian', 'ru.svg'),
    ('id', 'Bahasa Indonesia', 'Indonesian', 'id.svg'),
    ('zh', '中文', 'Chinese', 'ch.svg'),
    ('ja', '日本語', 'Japanese', 'jp.svg'),
    ('ko', '한국어', 'Korean', 'kr.svg'),
    ('tr', 'Türkçe', 'Turkish', 'tr.svg'),
  ];

  Future<void> _choose(String code) async {
    if (_saving) return;
    setState(() => _saving = true);
    // Active locale changes first, preserving the no-English-flash behavior.
    widget.onLocaleChanged(Locale(code));
    try {
      await setLocale(code);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(translation(context).somethingWentWrong)),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final labels = translation(context);
    final active = Localizations.localeOf(context).languageCode;
    return SettingsScaffold(
      title: Text(labels.language),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: const Color(0xFFE5EFFF),
                border: Border.all(color: const Color(0xFFD1E2FF)),
                borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              const SettingsIcon('settings_language_icon.svg',
                  background: Color(0xFF176BEB), size: 44),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(labels.chooseAppLanguage,
                        style: const TextStyle(
                            color: settingsInk,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(labels.changeAppLanguage,
                        style: const TextStyle(
                            color: settingsMuted, fontSize: 12)),
                  ])),
            ]),
          ),
          const SizedBox(height: 14),
          for (final language in _languages)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Semantics(
                selected: active == language.$1,
                button: true,
                child: Material(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                        color: active == language.$1
                            ? settingsBlue
                            : Colors.transparent,
                        width: 1.8),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    key: ValueKey('language-${language.$1}'),
                    onTap: _saving ? null : () => _choose(language.$1),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      child: Row(children: [
                        ClipRRect(
                            borderRadius: BorderRadius.circular(5),
                            child: SvgPicture.asset(
                              '$settingsAssetRoot${language.$4}',
                              width: 44,
                              height: 32,
                              fit: BoxFit.cover,
                            )),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(language.$2,
                                  style: const TextStyle(
                                      color: settingsInk,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text(language.$3,
                                  style: const TextStyle(
                                      color: settingsMuted, fontSize: 12)),
                            ])),
                        Icon(
                            active == language.$1
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                            size: 24,
                            color: active == language.$1
                                ? settingsBlue
                                : const Color(0xFFB5C5E0)),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
