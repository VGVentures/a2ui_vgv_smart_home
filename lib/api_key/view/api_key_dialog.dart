import 'package:a2ui_vgv_smart_home/api_key/gemini_key_store.dart';
import 'package:a2ui_vgv_smart_home/l10n/l10n.dart';
import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Asks for the person's own Gemini API key and keeps it in [keys].
///
/// With [dismissible] false the dialog stays until a key is entered, which is
/// how the app opens. Otherwise it can be cancelled, which leaves the key as it
/// was.
Future<void> showApiKeyDialog(
  BuildContext context, {
  required GeminiKeyStore keys,
  required bool dismissible,
}) async {
  final entered = await showDialog<String>(
    context: context,
    barrierDismissible: dismissible,
    builder: (_) => ApiKeyDialog(dismissible: dismissible),
  );
  if (entered != null) keys.save(entered);
}

final Uri _aiStudioKeys = Uri.parse('https://aistudio.google.com/apikey');

/// {@template api_key_dialog}
/// The dialog [showApiKeyDialog] shows. It pops with the key as entered.
/// {@endtemplate}
class ApiKeyDialog extends StatefulWidget {
  /// {@macro api_key_dialog}
  const ApiKeyDialog({required this.dismissible, super.key});

  /// Whether the dialog can be cancelled instead of answered.
  final bool dismissible;

  @override
  State<ApiKeyDialog> createState() => _ApiKeyDialogState();
}

/// Holds the key being typed.
class _ApiKeyDialogState extends State<ApiKeyDialog> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _hasKey => _controller.text.trim().isNotEmpty;

  void _submit() {
    if (_hasKey) Navigator.of(context).pop(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopScope(
      canPop: widget.dismissible,
      child: AlertDialog(
        title: Text(l10n.apiKeyTitle),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSpacing.formWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.apiKeyBody),
              const SizedBox(height: AppSpacing.s2),
              const _AiStudioLink(),
              const SizedBox(height: AppSpacing.s4),
              TextField(
                controller: _controller,
                autofocus: true,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(labelText: l10n.apiKeyLabel),
              ),
            ],
          ),
        ),
        actions: [
          if (widget.dismissible)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.cancelButton),
            ),
          FilledButton(
            onPressed: _hasKey ? _submit : null,
            child: Text(l10n.continueButton),
          ),
        ],
      ),
    );
  }
}

/// The link to Google AI Studio, where the person gets a key.
class _AiStudioLink extends StatelessWidget {
  const _AiStudioLink();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: Theme.of(context).colorScheme.primary,
      decoration: TextDecoration.underline,
    );
    return Semantics(
      link: true,
      child: InkWell(
        onTap: () => launchUrl(_aiStudioKeys),
        child: Text(context.l10n.apiKeyLink, style: style),
      ),
    );
  }
}
