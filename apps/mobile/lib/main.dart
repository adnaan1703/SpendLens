import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app/spend_lens_app.dart';
import 'src/core/bootstrap/app_bootstrap.dart';
import 'src/core/config/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = AppConfig.fromEnvironment();
  final bootstrap = await AppBootstrap.initialize(config);

  runApp(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(config),
        appBootstrapProvider.overrideWithValue(bootstrap),
      ],
      child: const SpendLensApp(),
    ),
  );
}
