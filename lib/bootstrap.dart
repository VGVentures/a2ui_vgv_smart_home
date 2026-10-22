import 'dart:async';
import 'dart:developer';

import 'package:app_ui/app_ui.dart';
import 'package:bloc/bloc.dart';
import 'package:flutter/widgets.dart';

/// {@template app_bloc_observer}
/// Logs the changes and errors of every bloc and cubit.
/// {@endtemplate}
class AppBlocObserver extends BlocObserver {
  /// {@macro app_bloc_observer}
  const AppBlocObserver();

  @override
  void onChange(BlocBase<dynamic> bloc, Change<dynamic> change) {
    super.onChange(bloc, change);
    log('onChange(${bloc.runtimeType}, $change)');
  }

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    log('onError(${bloc.runtimeType}, $error, $stackTrace)');
    super.onError(bloc, error, stackTrace);
  }
}

/// Sets up error logging, the [AppBlocObserver] and the kitchen light, then
/// runs the app the [builder] returns.
Future<void> bootstrap(FutureOr<Widget> Function() builder) async {
  FlutterError.onError = (details) {
    log(details.exceptionAsString(), stackTrace: details.stack);
  };

  Bloc.observer = const AppBlocObserver();

  // Add app-wide configuration here

  WidgetsFlutterBinding.ensureInitialized();
  // Held back by the page's own loading screen, so the first frame already has
  // its kitchen.
  await KitchenLight.preload();

  runApp(await builder());
}
