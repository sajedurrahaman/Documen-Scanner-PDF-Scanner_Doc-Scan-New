import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/local_storage.dart';
import '../localaization/language_constant.dart';
import '../utils/app_constant.dart';
import 'widgets/settings_ui.dart';

class LanguageSelectScreen extends StatefulWidget {
  const LanguageSelectScreen({
    super.key,
    required this.onLocaleChanged,
    this.isOnboarding = false,
    this.onOnboardingCompleted,
  });

  final ValueChanged<Locale> onLocaleChanged;

  /// First-launch flow after splash: no back button, Next CTA at bottom.
  final bool isOnboarding;

  /// Called after Next saves the onboarding flag (onboarding only).
  final VoidCallback? onOnboardingCompleted;

  @override
  State<LanguageSelectScreen> createState() => _LanguageSelectScreenState();
}

class _LanguageSelectScreenState extends State<LanguageSelectScreen> {
  bool _saving = false;
  late String _selected;

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

  @override
  void initState() {
    super.initState();
    _selected = ENGLISH;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!widget.isOnboarding) {
      _selected = Localizations.localeOf(context).languageCode;
    }
  }

  Future<void> _select(String code) async {
    if (_saving) return;
    setState(() {
      _selected = code;
      _saving = true;
    });
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

  Future<void> _onNext() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      widget.onLocaleChanged(Locale(_selected));
      await setLocale(_selected);
      await LocalStorage()
          .setBool(AppConstant.LANGUAGE_ONBOARDING_DONE_KEY, true);
      if (!mounted) return;
      widget.onOnboardingCompleted?.call();
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
    final active = widget.isOnboarding
        ? _selected
        : Localizations.localeOf(context).languageCode;

    final scaffold = SettingsScaffold(
      // Onboarding is the root of the post-splash stack → no back chevron.
      root: widget.isOnboarding,
      title: Text(labels.language),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                16,
                widget.isOnboarding ? 18 : 18,
                16,
                widget.isOnboarding ? 12 : 16,
              ),
              children: [
                if (!widget.isOnboarding) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5EFFF),
                      border: Border.all(color: const Color(0xFFD1E2FF)),
                      borderRadius: BorderRadius.circular(14),
                    ),
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
                          ],
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 14),
                ],
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
                            width: 1.8,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          key: ValueKey('language-${language.$1}'),
                          onTap: _saving ? null : () => _select(language.$1),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            child: Row(children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(5),
                                child: SvgPicture.asset(
                                  '$settingsAssetRoot${language.$4}',
                                  width: language.$1 == 'en' ? 40 : 44,
                                  height: language.$1 == 'en' ? 28 : 32,
                                  fit: BoxFit.cover,
                                ),
                              ),
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
                                  ],
                                ),
                              ),
                              Icon(
                                active == language.$1
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_off,
                                size: 24,
                                color: active == language.$1
                                    ? settingsBlue
                                    : const Color(0xFFB5C5E0),
                              ),
                            ]),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (widget.isOnboarding)
            _NextBar(
              saving: _saving,
              onNext: _onNext,
              nextLabel: labels.next,
              hint: labels.languageChangeLaterHint,
            ),
        ],
      ),
    );

    if (!widget.isOnboarding) return scaffold;
    return PopScope(canPop: false, child: scaffold);
  }
}

class _NextBar extends StatelessWidget {
  const _NextBar({
    required this.saving,
    required this.onNext,
    required this.nextLabel,
    required this.hint,
  });

  final bool saving;
  final VoidCallback onNext;
  final String nextLabel;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 8,
      shadowColor: Colors.black26,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: saving ? null : onNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: settingsBlue,
                    disabledBackgroundColor: settingsBlue.withValues(alpha: 0.6),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: const StadiumBorder(),
                  ),
                  child: saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              nextLabel,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_rounded, size: 20),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                hint,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: settingsInk,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
