import 'package:a2ui_vgv_smart_home/l10n/l10n.dart';
import 'package:a2ui_vgv_smart_home/voice/cubit/voice_cubit.dart';
import 'package:a2ui_vgv_smart_home/voice/view/microphone_button.dart';
import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// {@template voice_input}
/// The ask bar: the hint, and a microphone to tap. Needs a [VoiceCubit] above
/// it, and a `VoiceLayer` for the card that opens from it.
/// {@endtemplate}
class VoiceInput extends StatelessWidget {
  /// {@macro voice_input}
  const VoiceInput({required this.hint, super.key});

  /// The text shown in the bar before anything is said.
  final String hint;

  @override
  Widget build(BuildContext context) {
    return AskBar(
      text: hint,
      trailing: MicrophoneButton(
        tooltip: context.l10n.voiceStartTooltip,
        onPressed: () => context.read<VoiceCubit>().start(),
      ),
    );
  }
}

/// {@template microphone_permission_dialog}
/// Warns that the browser is about to ask for the microphone. Pops `true` to
/// go on.
/// {@endtemplate}
class MicrophonePermissionDialog extends StatelessWidget {
  /// {@macro microphone_permission_dialog}
  const MicrophonePermissionDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.microphonePermissionTitle),
      content: Text(l10n.microphonePermissionBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.cancelButton),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.continueButton),
        ),
      ],
    );
  }
}
