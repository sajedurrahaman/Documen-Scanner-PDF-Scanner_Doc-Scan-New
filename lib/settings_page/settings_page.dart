import 'dart:developer';
import 'dart:io';

import 'package:doc_scanner/main.dart';
import 'package:doc_scanner/settings_page/web_view_page.dart';
import 'package:doc_scanner/settings_page/widgets/switch_item.dart';
import 'package:doc_scanner/utils/app_constant.dart';
import 'package:doc_scanner/utils/helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/local_storage.dart';
import '../localaization/language.dart';
import '../localaization/language_constant.dart';
import '../utils/app_assets.dart';
import 'dart:developer' as developer;

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool vibration = true;
  bool beep = true;
  Language _selectedLanguage = Language(4, 'English', 'en');

  @override
  void initState() {
    vibration = LocalStorage().getBool(AppConstant.VIBRATION_KEY);
    beep = LocalStorage().getBool(AppConstant.BEEP_KEY);

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      Locale locale = await getLocale();
      _selectedLanguage = Language.languageList()
          .firstWhere((element) => element.languageCode == locale.languageCode);
      setState(() {});
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          translation(context).settings,
          style:  TextStyle(
            fontSize:AppHelper.isIpad(context)?25: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
        child: Column(
          children: [
            Container(
              width: MediaQuery.sizeOf(context).width,
              height: MediaQuery.sizeOf(context).height * 0.058,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  SvgPicture.asset(
                    AppAssets.languageIcon,
                    height:AppHelper.isIpad(context)?35: 20,
                    width:AppHelper.isIpad(context)?35: 20,
                  ),
                  SizedBox(
                    width: MediaQuery.sizeOf(context).width * 0.015,
                  ),
                  Text(
                    translation(context).language,
                    style:  TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize:AppHelper.isIpad(context)?20: 17,
                    ),
                  ),
                  Expanded(
                    child: DropdownButton<Language>(
                      underline: const SizedBox.shrink(),
                      alignment: AlignmentDirectional.centerEnd,
                      isExpanded: true,
                      isDense: true,
                      icon: const SizedBox.shrink(),
                      value: _selectedLanguage,
                      onChanged: (Language? newValue) async {
                        setState(() {
                          _selectedLanguage = newValue!;
                        });
                        Locale locale = await setLocale(newValue!.languageCode);
                        MyApp.setLocale(context, locale);
                      },
                      selectedItemBuilder: (BuildContext context) {
                        return Language.languageList()
                            .map<Widget>((Language language) {
                          return Text(
                            _selectedLanguage.name,
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 14,
                            ),
                          );
                        }).toList();
                      },
                      items: Language.languageList()
                          .map<DropdownMenuItem<Language>>((Language language) {
                        return DropdownMenuItem<Language>(
                          value: language,
                          child: ListTile(
                            title: Text(language.name),
                            titleAlignment: ListTileTitleAlignment.center,
                            trailing: _selectedLanguage.name == language.name
                                ? const Icon(Icons.done)
                                : const SizedBox.shrink(),
                          ),
                        );
                      }).toList(),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                   Icon(
                    Icons.arrow_forward_ios,
                    size:AppHelper.isIpad(context)?20: 15,
                  ),
                ],
              ),
            ),
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.015,
            ),
            Container(
              // height: 120,
              width: MediaQuery.sizeOf(context).width,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SwitchItem(
                    iconPath: AppAssets.vibration,
                    title: translation(context).vibration,
                    onChanged: (value) {
                      log(value.toString());
                      setState(() {
                        vibration = value;
                      });
                      LocalStorage().setBool(AppConstant.VIBRATION_KEY, value);
                    },
                    value: vibration,
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  SwitchItem(
                      iconPath: AppAssets.beep,
                      title: translation(context).beep,
                      onChanged: (value) {
                        setState(() {
                          beep = value;
                        });
                        LocalStorage().setBool(AppConstant.BEEP_KEY, value);
                      },
                      value: beep),
                ],
              ),
            ),
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.015,
            ),
            Container(
              width: MediaQuery.sizeOf(context).width,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                children: [
                  Builder(
                    builder: (context) => GestureDetector(
                      onTap: () async {



                        // Prepare share content
                        final shareUrl = Platform.isAndroid
                            ? 'https://play.google.com/store/apps/details?id=com.documentscannerpdfscanner_'
                            : 'https://apps.apple.com/app/id6472610820';

                        final shareText = 'Check out this awesome app: $shareUrl';

                        try {
                          // Get position for iPad share sheet anchor
                          final box = context.findRenderObject() as RenderBox?;
                          final position = box!.localToGlobal(Offset.zero) & box.size;

                          if (Platform.isIOS || Platform.isMacOS) {
                            await Share.share(
                              shareText,
                              sharePositionOrigin: position,
                              subject: 'Check out this app!',
                            );
                          } else {
                            await Share.share(shareText);
                          }
                        } catch (e) {
                          debugPrint('Sharing error: $e');
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to share: ${e.toString()}')),
                          );
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                        decoration: BoxDecoration(

                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            SvgPicture.asset(
                              AppAssets.shareWithFriend,
                              height:AppHelper.isIpad(context)?35: 20,
                              width:AppHelper.isIpad(context)?35: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(
                                translation(context).shareWithFriend,
                              style:  TextStyle(
                                fontWeight: FontWeight.w600,
                                 fontSize: AppHelper.isIpad(context)?20: 17,
                              )

                            ),
                            const Spacer(),
                             Icon(Icons.arrow_forward_ios,
                              size:AppHelper.isIpad(context)?20: 15,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),


                  SizedBox(
                    height: MediaQuery.sizeOf(context).height * 0.012,
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () async {
                        try {
                          if (Platform.isIOS) {
                            final url = Uri.parse(
                              "https://apps.apple.com/app/id6472610820",
                            );
                            await launchUrl(
                              url,
                              mode: LaunchMode.externalApplication,
                            );
                          } else {
                            final url = Uri.parse(
                              "https://play.google.com/store/apps/details?id=com.documentscannerpdfscanner_",
                            );
                            await launchUrl(
                              url,
                              mode: LaunchMode.externalApplication,
                            );
                          }

                          // if (Platform.isAndroid || Platform.isIOS) {
                          //   final appId = Platform.isAndroid
                          //       ? ''
                          //       : 'com.documentscannerpdfscanner';
                          //   final url = Uri.parse(
                          //     Platform.isAndroid
                          //         ? "market://details?id=$appId"
                          //         : "https://apps.apple.com/app/id6472610820",
                          //   );
                          //   await launchUrl(
                          //     url,
                          //     mode: LaunchMode.externalApplication,
                          //   );
                          // }
                        } catch (e) {
                          developer.log(e.toString());
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          children: [
                            SvgPicture.asset(
                              AppAssets.rateUs,
                              height:AppHelper.isIpad(context)?35: 20,
                              width:AppHelper.isIpad(context)?35: 20,
                            ),
                            SizedBox(
                              width: MediaQuery.sizeOf(context).width * 0.015,
                            ),
                            Text(
                              translation(context).rateUs,
                              style:  TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: AppHelper.isIpad(context)?20: 17,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const Spacer(),
                             Icon(
                              Icons.arrow_forward_ios,
                              size:AppHelper.isIpad(context)?20: 15,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: MediaQuery.sizeOf(context).height * 0.012,
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () {
                        if (Platform.isIOS) {
                          if (mounted) {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => WebViewPage(
                                  appBarTitleName:
                                      translation(context).privacyPolicy,
                                  url:
                                      "https://sites.google.com/view/docum-scanner/home",
                                ),
                              ),
                            );
                          }
                        } else if (Platform.isAndroid) {
                          if (mounted) {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => WebViewPage(
                                  appBarTitleName:
                                      translation(context).privacyPolicy,
                                  url:
                                      "https://sites.google.com/view/docum-scanne",
                                ),
                              ),
                            );
                          }
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          children: [
                            SvgPicture.asset(
                              AppAssets.privacyPolicy,
                              height:AppHelper.isIpad(context)?35: 20,
                              width:AppHelper.isIpad(context)?35: 20,
                            ),
                            SizedBox(
                              width: MediaQuery.sizeOf(context).width * 0.015,
                            ),
                            Text(
                              translation(context).privacyPolicy,
                              style:  TextStyle(
                                fontWeight: FontWeight.w600,
                              fontSize: AppHelper.isIpad(context)?20: 17,
                              ),
                            ),
                            const Spacer(),
                             Icon(
                              Icons.arrow_forward_ios,
                              size:AppHelper.isIpad(context)?20: 15,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: MediaQuery.sizeOf(context).height * 0.012,
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () {
                        if (Platform.isIOS) {
                          if (mounted) {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => WebViewPage(
                                  appBarTitleName:
                                      translation(context).termsAndConditions,
                                  url:
                                      "https://sites.google.com/view/docum-scanner/home",
                                ),
                              ),
                            );
                          }
                        } else if (Platform.isAndroid) {
                          if (mounted) {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => WebViewPage(
                                  appBarTitleName:
                                      translation(context).termsAndConditions,
                                  url:
                                      "https://sites.google.com/view/docu-scanne",
                                ),
                              ),
                            );
                          }
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          children: [
                            SvgPicture.asset(
                              AppAssets.termsCondition,
                              height:AppHelper.isIpad(context)?35: 20,
                              width:AppHelper.isIpad(context)?35: 20,
                            ),
                            SizedBox(
                              width: MediaQuery.sizeOf(context).width * 0.015,
                            ),
                            Text(
                              translation(context).termsAndConditions,
                              style:  TextStyle(
                                fontWeight: FontWeight.w600,
                                  fontSize: AppHelper.isIpad(context)?20: 17
                              ),
                            ),
                            const Spacer(),
                             Icon(
                              Icons.arrow_forward_ios,
                              size:AppHelper.isIpad(context)?20: 15,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: MediaQuery.sizeOf(context).height * 0.012,
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () async {
                        try {
                          if (Platform.isAndroid) {
                            final url = Uri.parse(
                              "https://play.google.com/store/apps/dev?id=6584495725981374366",
                            );
                            await launchUrl(
                              url,
                              mode: LaunchMode.externalApplication,
                            );
                          } else if (Platform.isIOS) {
                            final url = Uri.parse(
                              "https://apps.apple.com/us/developer/md-sajedur-rahaman/id1586019019",
                            );
                            await launchUrl(
                              url,
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        } catch (e) {
                          developer.log(e.toString());
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          children: [
                            SvgPicture.asset(
                              AppAssets.moreApps,
                              height: AppHelper.isIpad(context) ? 35 : 20,
                              width: AppHelper.isIpad(context) ? 35 : 20,
                            ),
                            SizedBox(
                              width: MediaQuery.sizeOf(context).width * 0.012,
                            ),
                            Text(
                              translation(context).moreApps,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 17,
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              Icons.arrow_forward_ios,
                              size: AppHelper.isIpad(context) ? 20 : 15,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
