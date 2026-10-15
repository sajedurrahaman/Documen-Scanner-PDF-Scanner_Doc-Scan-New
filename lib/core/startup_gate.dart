import 'dart:async';

import 'package:flutter/material.dart';

/// Builds the loading UI. Call [onShown] once the loading content (for example
/// a splash animation) is actually visible; [StartupGate.minimumDuration] is
/// counted from that moment, not from the first blank frame.
typedef StartupLoadingBuilder = Widget Function(
    BuildContext context, VoidCallback onShown);

/// Opens the app after local setup and the minimum splash duration both finish.
class StartupGate extends StatefulWidget {
  const StartupGate({
    super.key,
    required this.initialize,
    required this.loadingBuilder,
    required this.child,
    this.onReady,
    this.minimumDuration = Duration.zero,
  });

  final Future<void> Function() initialize;
  final StartupLoadingBuilder loadingBuilder;
  final Widget child;
  final VoidCallback? onReady;

  /// Minimum time the loading UI stays visible after it reports being shown.
  final Duration minimumDuration;

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  bool _ready = false;
  bool _failed = false;
  bool _initialized = false;
  bool _minimumElapsed = false;
  Timer? _minimumTimer;

  @override
  void initState() {
    super.initState();
    _minimumElapsed = widget.minimumDuration == Duration.zero;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _initialize();
    });
  }

  /// Starts the minimum-duration countdown the first time the loading UI
  /// reports that its content is visible. Later calls are ignored.
  void _onLoadingShown() {
    if (!mounted || _minimumElapsed || _minimumTimer != null) return;
    _minimumTimer = Timer(widget.minimumDuration, () {
      _minimumElapsed = true;
      _openWhenReady();
    });
  }

  Future<void> _initialize() async {
    if (!mounted) return;
    try {
      await widget.initialize();
      if (!mounted) return;
      _initialized = true;
      _openWhenReady();
    } catch (error, stack) {
      debugPrint('Local startup failed: $error\n$stack');
      if (mounted) setState(() => _failed = true);
    }
  }

  void _openWhenReady() {
    if (!mounted || _ready || !_initialized || !_minimumElapsed) return;
    setState(() => _ready = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onReady?.call();
    });
  }

  @override
  void dispose() {
    _minimumTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return widget.child;
    if (_failed) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Unable to open your documents. Please try again.'),
              TextButton(
                onPressed: () {
                  setState(() => _failed = false);
                  _initialize();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    return widget.loadingBuilder(context, _onLoadingShown);
  }
}
