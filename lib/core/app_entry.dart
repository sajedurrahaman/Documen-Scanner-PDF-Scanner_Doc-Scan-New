import 'package:flutter/material.dart';

import '../bottom_bar/bottom_bar.dart';
import '../core/local_storage.dart';
import '../localaization/language_constant.dart';
import '../settings_page/language_select_screen.dart';
import '../utils/app_constant.dart';

/// After splash: show language picker once on first launch, then home.
class AppEntry extends StatefulWidget {
  const AppEntry({super.key, required this.onLocaleChanged});

  final ValueChanged<Locale> onLocaleChanged;

  @override
  State<AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<AppEntry> {
  late bool _languageOnboardingDone;

  @override
  void initState() {
    super.initState();
    final storage = LocalStorage();
    // New installs only. Returning users who already saved a language skip it.
    _languageOnboardingDone = storage.getBoolOr(
          AppConstant.LANGUAGE_ONBOARDING_DONE_KEY,
          defaultValue: false,
        ) ||
        storage.containsKey(LAGUAGE_CODE);
  }

  @override
  Widget build(BuildContext context) {
    if (!_languageOnboardingDone) {
      return LanguageSelectScreen(
        isOnboarding: true,
        onLocaleChanged: widget.onLocaleChanged,
        onOnboardingCompleted: () {
          if (!mounted) return;
          setState(() => _languageOnboardingDone = true);
        },
      );
    }
    return const BottomBar();
  }
}
