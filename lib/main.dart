import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router.dart';
import 'shared/services/backend_api_service.dart';

void main() {
  debugPrint(
    '[AudioApp] Starting with Backend Base URL: $kDefaultBackendBaseUrl '
    '(custom override: $kHasCustomBackendBaseUrl)',
  );
  runApp(
    const ProviderScope(
      child: AudioApp(),
    ),
  );
}

class AudioApp extends ConsumerWidget {
  const AudioApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'AudioLearner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A56DB),
        ),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
