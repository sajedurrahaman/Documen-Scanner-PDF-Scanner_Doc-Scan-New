import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../utils/app_color.dart';
import '../../utils/helper.dart';

const settingsBlue = Color(0xFF1C58BE);
const settingsInk = Color(0xFF102E68);
const settingsMuted = Color(0xFF7284A3);
const settingsSurface = Color(0xFFF4F7FC);
const settingsAssetRoot = 'assets/settings_screen_icon/';

class SettingsScaffold extends StatelessWidget {
  const SettingsScaffold(
      {super.key, required this.title, required this.child, this.root = false});
  final Widget title;
  final Widget child;
  final bool root;

  @override
  Widget build(BuildContext context) {
    final isIpad = AppHelper.isIpad(context);
    return Scaffold(
        backgroundColor: AppColor.headerBlue,
        appBar: AppBar(
          automaticallyImplyLeading: !root,
          backgroundColor: AppColor.headerBlue,
          foregroundColor: Colors.white,
          iconTheme: const IconThemeData(color: Colors.white),
          actionsIconTheme: const IconThemeData(color: Colors.white),
          surfaceTintColor: Colors.transparent,
          systemOverlayStyle: SystemUiOverlayStyle.light,
          elevation: 0,
          scrolledUnderElevation: 0,
          toolbarHeight: root
              ? (isIpad ? 96 : 72)
              : (isIpad ? 72 : 64),
          titleSpacing: root ? 16 : 0,
          title: root
              ? Padding(
                  padding: EdgeInsets.only(bottom: isIpad ? 14 : 10),
                  child: title,
                )
              : title,
          titleTextStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontSize: 22, fontWeight: FontWeight.w600, color: Colors.white),
        ),
        body: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: ColoredBox(
            color: settingsSurface,
            child: SafeArea(top: false, child: SizedBox.expand(child: child)),
          ),
        ),
      );
  }
}

class SettingsIcon extends StatelessWidget {
  const SettingsIcon(this.asset,
      {super.key, this.background = const Color(0xFFE4EFFF), this.size = 44});
  final String asset;
  final Color background;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: background, shape: BoxShape.circle),
        padding: EdgeInsets.all(size * 0.24),
        child: SvgPicture.asset('$settingsAssetRoot$asset'),
      );
}

class SettingsCard extends StatelessWidget {
  const SettingsCard({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0)
                const Padding(
                  padding: EdgeInsetsDirectional.only(start: 72, end: 16),
                  child: Divider(height: 1, color: Color(0xFFE4EBF7)),
                ),
              children[i],
            ],
          ]),
        ),
      );
}

class SettingsRow extends StatelessWidget {
  const SettingsRow(
      {super.key,
      required this.icon,
      required this.title,
      required this.subtitle,
      this.trailing,
      this.onTap});
  final Widget icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            icon,
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: settingsInk)),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style:
                          const TextStyle(fontSize: 12, color: settingsMuted)),
                ])),
            const SizedBox(width: 8),
            trailing ??
                const Icon(Icons.chevron_right, color: settingsMuted, size: 24),
          ]),
        ),
      );
}

class SettingsSectionLabel extends StatelessWidget {
  const SettingsSectionLabel(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 14),
        child: Text(text,
            style: const TextStyle(
                color: settingsInk, fontSize: 20, fontWeight: FontWeight.w600)),
      );
}
