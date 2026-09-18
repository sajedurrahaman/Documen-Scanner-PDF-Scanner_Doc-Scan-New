import 'package:flutter/material.dart';
import 'package:upgrader/upgrader.dart';

/// Soft update dialog on Home (BottomBar).
/// Shown when Play Store / App Store has a newer version.
/// User can skip with "SKIP NOW" and keep using the current version.
class ForceUpdateWrapper extends StatefulWidget {
  const ForceUpdateWrapper({super.key, required this.child});

  final Widget child;

  @override
  State<ForceUpdateWrapper> createState() => _ForceUpdateWrapperState();
}

class _ForceUpdateWrapperState extends State<ForceUpdateWrapper> {
  Upgrader? _upgrader;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _upgrader ??= Upgrader(
      // After skip, don't show again until this duration passes.
      durationUntilAlertAgain: const Duration(days: 1),
      messages: SkipNowUpgraderMessages(context: context),
    );
  }

  @override
  Widget build(BuildContext context) {
    final upgrader = _upgrader;
    if (upgrader == null) return widget.child;

    return UpgradeAlert(
      upgrader: upgrader,
      showIgnore: false,
      showLater: true,
      barrierDismissible: false,
      shouldPopScope: () => true,
      dialogStyle: UpgradeDialogStyle.material,
      child: widget.child,
    );
  }
}

class SkipNowUpgraderMessages extends UpgraderMessages {
  SkipNowUpgraderMessages({super.code, super.context});

  @override
  String get buttonTitleLater => 'SKIP NOW';
}
