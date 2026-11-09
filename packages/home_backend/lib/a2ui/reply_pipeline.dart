import 'package:a2ui_agent/a2ui_agent.dart';
import 'package:a2ui_core/a2ui_core.dart';
import 'package:home_backend/a2ui/reply_outcome.dart';
import 'package:home_backend/devices/device_binder.dart';
import 'package:home_backend/devices/device_filler.dart';
import 'package:home_backend/devices/device_readings.dart';
import 'package:home_backend/validation/layout_composer.dart';
import 'package:home_backend/validation/layout_validator.dart';
import 'package:home_catalog/home_catalog.dart';

const _noMessageError =
    'Your response contained no A2UI message. Every response must include '
    'the dashboard as A2UI messages inside `<a2ui-json>` tags. Present all '
    'information, including tool results, as A2UI components rather than '
    'plain text.';

/// {@template reply_pipeline}
/// Turns the model's reply into the A2UI 1.0 messages the panel applies, or
/// into the errors that send it back to the model.
/// {@endtemplate}
///
/// The reply is parsed and checked by `a2ui_agent` against the catalog and the
/// state of the panel: an unknown component, a dangling child or a reply with
/// no A2UI in it is rejected there. What passes is then put right by code:
///
/// 1. the cards are laid out on the panel grid and the cells they leave are
///    filled with devices (`LayoutComposer`, `DeviceFiller`), and a screen
///    still off the grid is rejected (`LayoutValidator`);
/// 2. the device cards are bound to the data model (`bindDevices`);
/// 3. the whole dashboard is written as one batch for the one surface:
///    a `createSurface` that carries the components and the data model, or,
///    when the panel already shows the surface, the `updateDataModel` messages
///    and the `updateComponents` that replace it. The batch is checked again
///    against the panel's state, so it is applied whole or not at all.
///
/// One pipeline is built for each visitor's world, because the readings and
/// the fill are those of that visitor's home.
class ReplyPipeline {
  /// {@macro reply_pipeline}
  ///
  /// Creates a pipeline that parses with a processor and works on the devices
  /// of one visitor's home.
  ReplyPipeline({
    required this._processor,
    required this._composer,
    required this._layout,
    required this._readings,
    required this._filler,
  });

  final A2uiRequestProcessor _processor;
  final LayoutComposer _composer;
  final LayoutValidator _layout;
  final DeviceReadings _readings;
  final DeviceFiller _filler;

  /// Processes [reply]. [surfaceExists] says whether the panel already shows
  /// the dashboard surface, and [userId] is the person the screen is for, when
  /// it is known.
  ReplyOutcome process(
    String reply, {
    required bool surfaceExists,
    String? userId,
  }) {
    try {
      final messages = _parse(reply, surfaceExists);
      if (messages.isEmpty) {
        return const ReplyOutcome.rejected([_noMessageError]);
      }

      final components = _components(messages);
      final laid =
          _composer.compose(
            components,
            fill: (shown) => _filler.cards(shown, userId: userId),
          ) ??
          components;
      final repaired = _layout.repair(laid);
      final errors = _layout.validate(repaired);
      if (errors != null) return ReplyOutcome.rejected(errors);

      final bound = bindDevices(repaired, _readings);
      final batch = _batch(
        bound,
        messages: messages,
        surfaceExists: surfaceExists,
      );
      // The batch is code's work, but it is what the panel applies: check it
      // the way the panel will.
      final state = _stateFor(surfaceExists);
      state.checkTopology(state.apply(_messages(batch)));
      return ReplyOutcome.accepted(batch);
    } on A2uiError catch (error) {
      return ReplyOutcome.rejected(_lines(error));
    }
  }

  RendererState _stateFor(bool surfaceExists) {
    final state = _processor.createState();
    if (surfaceExists) {
      state.apply([
        CreateSurfaceMessage(
          version: a2uiVersion,
          surfaceId: dashboardSurfaceId,
          catalogId: genUiCatalogId,
          sendDataModel: true,
        ),
      ]);
    }
    return state;
  }

  List<AgentToRendererMessage> _parse(String reply, bool surfaceExists) => [
    for (final part in _processor.parseResponse(
      reply,
      state: _stateFor(surfaceExists),
    ))
      if (part is A2uiPart) ...part.a2ui,
  ];

  /// The components the reply defines, an id's last definition winning, in the
  /// order they first appeared.
  List<Map<String, Object?>> _components(
    List<AgentToRendererMessage> messages,
  ) {
    final byId = <String, Map<String, Object?>>{};
    for (final message in messages) {
      final list = switch (message) {
        CreateSurfaceMessage(:final components) => components,
        UpdateComponentsMessage(:final components) => components,
        _ => null,
      };
      for (final component in list ?? const <Map<String, Object?>>[]) {
        final id = component['id'];
        if (id is String) byId[id] = {...component};
      }
    }
    return byId.values.toList();
  }

  /// The batch for the panel: the whole dashboard, with the values the device
  /// cards are bound to.
  List<Map<String, Object?>> _batch(
    BoundDevices bound, {
    required List<AgentToRendererMessage> messages,
    required bool surfaceExists,
  }) {
    if (!surfaceExists) {
      final dataModel = <String, Object?>{
        for (final message in messages)
          if (message is CreateSurfaceMessage) ...?message.dataModel,
        if (bound.seeds.isNotEmpty) 'devices': bound.seeds,
      };
      return [
        {
          'version': a2uiVersion,
          'createSurface': {
            'surfaceId': dashboardSurfaceId,
            'catalogId': genUiCatalogId,
            'sendDataModel': true,
            'components': bound.components,
            if (dataModel.isNotEmpty) 'dataModel': dataModel,
          },
        },
      ];
    }
    return [
      for (final MapEntry(:key, :value) in bound.seeds.entries)
        {
          'version': a2uiVersion,
          'updateDataModel': {
            'surfaceId': dashboardSurfaceId,
            'path': devicePath(key),
            'value': value,
          },
        },
      {
        'version': a2uiVersion,
        'updateComponents': {
          'surfaceId': dashboardSurfaceId,
          'components': bound.components,
        },
      },
    ];
  }

  List<AgentToRendererMessage> _messages(List<Map<String, Object?>> batch) => [
    for (final json in batch) AgentToRendererMessage.fromJson(json),
  ];

  /// The lines of [error] for the retry prompt: each problem a validation error
  /// lists, or its message.
  List<String> _lines(A2uiError error) {
    if (error is A2uiValidationError && error.errors.isNotEmpty) {
      return [
        for (final detail in error.errors)
          if (detail.path.isEmpty)
            detail.message
          else
            '${detail.path}: ${detail.message}',
      ];
    }
    return [error.message];
  }
}
