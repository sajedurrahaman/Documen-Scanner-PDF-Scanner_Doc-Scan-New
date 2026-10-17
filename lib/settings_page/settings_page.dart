import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/local_storage.dart';
import '../localaization/language.dart';
import '../localaization/language_constant.dart';
import '../main.dart';
import '../utils/app_assets.dart';
import '../utils/app_constant.dart';
import '../utils/helper.dart';
import 'about_app_screen.dart';
import 'language_select_screen.dart';
import 'web_view_page.dart';
import 'widgets/settings_ui.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late bool vibration;
  late bool beep;
  @override
  void initState() {
    super.initState();
    vibration = LocalStorage().getBool(AppConstant.VIBRATION_KEY);
    beep = LocalStorage().getBool(AppConstant.BEEP_KEY);
  }

  String get _storeUrl => Platform.isIOS
      ? 'https://apps.apple.com/app/id6472610820'
      : 'https://play.google.com/store/apps/details?id=com.documentscannerpdfscanner_';

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(translation(context).somethingWentWrong)));
    }
  }

  Future<void> _openExternal(String url) async {
    if (!await launchUrl(Uri.parse(url),
        mode: LaunchMode.externalApplication)) {
      throw StateError('Cannot open link');
    }
  }

  void _web(String title, String url) => Navigator.of(context).push(
        MaterialPageRoute(
            builder: (_) => WebViewPage(appBarTitleName: title, url: url)),
      );

  Widget _switch(bool value, ValueChanged<bool> change) => Switch.adaptive(
        value: value,
        onChanged: change,
        activeTrackColor: settingsBlue,
        activeThumbColor: Colors.white,
        inactiveTrackColor: const Color(0xFFD5DFEF),
        inactiveThumbColor: Colors.white,
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      );

  @override
  Widget build(BuildContext context) {
    final labels = translation(context);
    final selectedLanguage = Language.languageList().firstWhere(
      (language) =>
          language.languageCode == Localizations.localeOf(context).languageCode,
      orElse: () => Language.languageList()
          .firstWhere((language) => language.languageCode == ENGLISH),
    );
    return SettingsScaffold(
      root: true,
      title: Row(children: [
        SvgPicture.asset(
          AppAssets.homeAppBarIcon,
          width: AppHelper.isIpad(context) ? 70 : 46,
          height: AppHelper.isIpad(context) ? 70 : 46,
        ),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(labels.documentScanner,
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                  letterSpacing: 0.4)),
          const SizedBox(height: 4),
          Text(labels.scanSaveShare,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.6)),
        ])),
      ]),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          SettingsSectionLabel(labels.appSettingsSection),
          SettingsCard(children: [
            SettingsRow(
              key: const ValueKey('settings-language'),
              icon: const SettingsIcon('settings_language_icon.svg',
                  background: Color(0xFF176BEB)),
              title: labels.language,
              subtitle: selectedLanguage.name,
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(selectedLanguage.name,
                    key: const ValueKey('settings-active-language'),
                    style: const TextStyle(fontSize: 12, color: settingsMuted)),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right, color: settingsMuted, size: 24),
              ]),
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => LanguageSelectScreen(
                            onLocaleChanged: (locale) =>
                                MyApp.setLocale(context, locale),
                          ))),
            ),
            SettingsRow(
              icon: const SettingsIcon('settings_vibration_icon.svg',
                  background: Color(0xFFF0E7FF)),
              title: labels.vibration,
              subtitle: labels.vibrateDuringScanning,
              trailing: _switch(vibration, (value) {
                setState(() => vibration = value);
                LocalStorage().setBool(AppConstant.VIBRATION_KEY, value);
              }),
            ),
            SettingsRow(
              icon: const SettingsIcon('settings_beep_icon.svg',
                  background: Color(0xFFE3F7EC)),
              title: labels.beep,
              subtitle: labels.soundDuringScanning,
              trailing: _switch(beep, (value) {
                setState(() => beep = value);
                LocalStorage().setBool(AppConstant.BEEP_KEY, value);
              }),
            ),
          ]),
          SettingsSectionLabel(labels.supportSection),
          SettingsCard(children: [
            SettingsRow(
              icon: const SettingsIcon('settings_share_icon.svg'),
              title: labels.shareWithFriend,
              subtitle: labels.recommendApp,
              onTap: () => _run(() async {
                final box = context.findRenderObject() as RenderBox?;
                await SharePlus.instance.share(ShareParams(
                  text: _storeUrl,
                  sharePositionOrigin: box == null
                      ? null
                      : box.localToGlobal(Offset.zero) & box.size,
                ));
              }),
            ),
            SettingsRow(
              icon: const SettingsIcon('settings_rate_us_icon.svg',
                  background: Color(0xFFFFF3DF)),
              title: labels.rateUs,
              subtitle: labels.leaveStoreReview,
              onTap: () => _run(() => _openExternal(_storeUrl)),
            ),
            SettingsRow(
              icon: const SettingsIcon('settings_privacy_and_policy_icon.svg',
                  background: Color(0xFFE3F7EC)),
              title: labels.privacyPolicy,
              subtitle: labels.howDataHandled,
              onTap: () => _web(
                  labels.privacyPolicy,
                  Platform.isIOS
                      ? 'https://sites.google.com/view/docum-scanner/home'
                      : 'https://sites.google.com/view/docum-scanne'),
            ),
            SettingsRow(
              icon: const SettingsIcon('settings_terms_and_conditions_icon.svg',
                  background: Color(0xFFF0E7FF)),
              title: labels.termsAndConditions,
              subtitle: labels.termsOfUseSubtitle,
              onTap: () => _web(
                  labels.termsAndConditions,
                  Platform.isIOS
                      ? 'https://sites.google.com/view/docum-scanner/home'
                      : 'https://sites.google.com/view/docu-scanne'),
            ),
            SettingsRow(
              icon: const SettingsIcon('settings_more_app_icon.svg'),
              title: labels.moreApps,
              subtitle: labels.exploreOtherApps,
              onTap: () => _run(() => _openExternal(Platform.isIOS
                  ? 'https://apps.apple.com/us/developer/md-sajedur-rahaman/id1586019019'
                  : 'https://play.google.com/store/apps/dev?id=6584495725981374366')),
            ),
          ]),
          SettingsSectionLabel(labels.aboutSection),
          SettingsCard(children: [
            SettingsRow(
              icon: const SettingsIcon('settings_about_icons.svg',
                  background: settingsInk),
              title: labels.aboutApp,
              subtitle: labels.appInfoSubtitle,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AboutAppScreen())),
            )
          ]),
        ],
      ),
    );
  }
}
