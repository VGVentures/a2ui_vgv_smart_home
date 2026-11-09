import 'dart:async';

import 'package:a2ui_vgv_smart_home/api_key/gemini_key_store.dart';
import 'package:a2ui_vgv_smart_home/api_key/view/api_key_dialog.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// {@template api_key_gate}
/// Shows [child] and, the first time the app opens, a dialog asking for the
/// person's own Gemini API key on top of it.
/// {@endtemplate}
class ApiKeyGate extends StatefulWidget {
  /// {@macro api_key_gate}
  const ApiKeyGate({required this.child, super.key});

  /// The content shown behind the dialog.
  final Widget child;

  @override
  State<ApiKeyGate> createState() => _ApiKeyGateState();
}

/// Asks for the Gemini key once, when the app opens without one.
class _ApiKeyGateState extends State<ApiKeyGate> {
  @override
  void initState() {
    super.initState();
    final keys = context.read<GeminiKeyStore>();
    if (keys.hasKey) return;
    // The dialog needs the navigator, which is not ready during the first
    // build.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => unawaited(
        showApiKeyDialog(context, keys: keys, dismissible: false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
