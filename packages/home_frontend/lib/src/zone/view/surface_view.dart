import 'package:flutter/widgets.dart';
import 'package:home_frontend/src/a2ui/a2ui.dart';
import 'package:home_frontend/src/widgets/rebuild.dart';

/// {@template surface_view}
/// Draws [surface] with `A2uiSurface` once it has a root component.
///
/// The renderer draws nothing until `root` exists, and the first reply is
/// applied a message at a time, so a [placeholder] (a skeleton, say) can stand
/// in until the whole screen is there.
/// {@endtemplate}
class SurfaceView extends StatefulWidget {
  /// {@macro surface_view}
  const SurfaceView({required this.surface, this.placeholder, super.key});

  /// The surface to draw.
  final SurfaceModel<ComponentImplementation> surface;

  /// What stands in until the surface has a root. Nothing when null.
  final Widget? placeholder;

  @override
  State<SurfaceView> createState() => _SurfaceViewState();
}

class _SurfaceViewState extends State<SurfaceView> {
  void Function()? _unsubscribe;
  late bool _hasRoot;

  @override
  void initState() {
    super.initState();
    _attach();
  }

  @override
  void didUpdateWidget(SurfaceView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.surface, widget.surface)) {
      _detach();
      _attach();
    }
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  void _attach() {
    final surface = widget.surface;
    _hasRoot = surface.componentsModel.get(surface.rootId) != null;
    if (_hasRoot) return;
    _unsubscribe = surface.componentsModel.onCreated.subscribe((component) {
      if (component.id != surface.rootId) return;
      _hasRoot = true;
      rebuild(this);
    }).unsubscribe;
  }

  void _detach() {
    _unsubscribe?.call();
    _unsubscribe = null;
  }

  @override
  Widget build(BuildContext context) => _hasRoot
      ? A2uiSurface(surface: widget.surface)
      : widget.placeholder ?? const SizedBox.shrink();
}
