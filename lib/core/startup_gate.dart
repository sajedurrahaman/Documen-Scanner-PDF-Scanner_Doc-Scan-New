import 'package:flutter/material.dart';

/// Shows a frame before starting local setup; opens the app as soon as it is ready.
class StartupGate extends StatefulWidget {
  const StartupGate({
    super.key,
    required this.initialize,
    required this.loading,
    required this.child,
    this.onReady,
  });

  final Future<void> Function() initialize;
  final Widget loading;
  final Widget child;
  final VoidCallback? onReady;

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  Future<void> _initialize() async {
    if (!mounted) return;
    try {
      await widget.initialize();
      if (!mounted) return;
      setState(() => _ready = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onReady?.call();
      });
    } catch (error, stack) {
      debugPrint('Local startup failed: $error\n$stack');
      if (mounted) setState(() => _failed = true);
    }
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
    return widget.loading;
  }
}
