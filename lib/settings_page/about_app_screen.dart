import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../localaization/language_constant.dart';
import '../utils/app_assets.dart';
import 'widgets/settings_ui.dart';

class AboutAppScreen extends StatefulWidget {
  const AboutAppScreen({super.key});
  @override
  State<AboutAppScreen> createState() => _AboutAppScreenState();
}

class _AboutAppScreenState extends State<AboutAppScreen> {
  late final Future<PackageInfo> _packageInfo = PackageInfo.fromPlatform();

  Widget _card(Widget child, {EdgeInsets padding = const EdgeInsets.all(16)}) =>
      Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(15)),
        child: child,
      );

  @override
  Widget build(BuildContext context) {
    final labels = translation(context);
    final features = [
      labels.featureScanPdf,
      labels.featureClearCopies,
      labels.featureAutoCrop,
      labels.featureMultiPage,
      labels.featureManageShare,
      labels.featureFastScan
    ];
    const numbers = ['one', 'two', 'three', 'four', 'five', 'six'];
    const colors = [
      Color(0xFFE4EFFF),
      Color(0xFFF0E7FF),
      Color(0xFFE3F7EC),
      Color(0xFFFFF0DE),
      Color(0xFFE4EFFF),
      Color(0xFFF0E7FF)
    ];
    return SettingsScaffold(
      title: Text(labels.aboutApp),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _card(Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            SvgPicture.asset(AppAssets.homeAppBarIcon, width: 62, height: 62),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(labels.documentScanner,
                      style: const TextStyle(
                          color: settingsInk,
                          fontSize: 18,
                          height: 1.2,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(labels.scanSaveShare,
                      style: const TextStyle(
                          color: settingsMuted, fontSize: 14, height: 1.2)),
                  const SizedBox(height: 5),
                  FutureBuilder<PackageInfo>(
                    future: _packageInfo,
                    builder: (_, snapshot) => snapshot.hasData
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                                color: const Color(0xFFE3EEFF),
                                borderRadius: BorderRadius.circular(20)),
                            child: Text(
                                '${labels.appVersionLabel} ${snapshot.data!.version}',
                                style: const TextStyle(
                                    color: settingsBlue,
                                    fontSize: 12,
                                    height: 1.2,
                                    fontWeight: FontWeight.w700)),
                          )
                        : const SizedBox.shrink(),
                  ),
                ])),
          ])),
          SettingsSectionLabel(labels.aboutSection),
          _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(labels.aboutAppDescription,
                style: const TextStyle(
                    color: Color(0xFF3D5073), fontSize: 14, height: 1.4)),
            const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(height: 1, color: Color(0xFFE4EBF7))),
            Text(labels.worksWith,
                style: const TextStyle(
                    color: settingsMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
                spacing: 8,
                runSpacing: 7,
                children: [
                  labels.document,
                  labels.receiptsTag,
                  labels.notesTag,
                  labels.idCard,
                  labels.certificatesTag,
                  labels.photosTag
                ]
                    .map((label) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                              color: const Color(0xFFE3EEFF),
                              borderRadius: BorderRadius.circular(20)),
                          child: Text(label,
                              style: const TextStyle(
                                  color: settingsBlue,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ))
                    .toList()),
          ])),
          SettingsSectionLabel(labels.keyFeatures),
          for (var row = 0; row < 3; row++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: IntrinsicHeight(
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                    for (var col = 0; col < 2; col++) ...[
                      if (col == 1) const SizedBox(width: 8),
                      Expanded(
                          child: _card(
                        Row(children: [
                          SettingsIcon(
                              'about_app_key_features_${numbers[row * 2 + col]}_icon.svg',
                              background: colors[row * 2 + col],
                              size: 44),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Text(features[row * 2 + col],
                                  style: const TextStyle(
                                      color: settingsInk,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700))),
                        ]),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 14),
                      )),
                    ],
                  ])),
            ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: settingsBlue, borderRadius: BorderRadius.circular(13)),
            child: Row(children: [
              const SettingsIcon('about_app_check_icon.svg',
                  background: Color(0xFF4379CD), size: 44),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(labels.goPaperless,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(labels.keepDocumentsOrganized,
                        style: const TextStyle(
                            color: Color(0xFFDDEAFF), fontSize: 12)),
                  ])),
            ]),
          ),
        ],
      ),
    );
  }
}
