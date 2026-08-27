import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'environment/bootstrap.dart';
import 'environment/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final container = await bootstrapContainer();
  runApp(ProviderScope(
    overrides: [dropContainerProvider.overrideWithValue(container)],
    child: const DropApp(),
  ));
}
