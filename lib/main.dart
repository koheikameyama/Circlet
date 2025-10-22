import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_line_sdk/flutter_line_sdk.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'config/firebase_emulator_config.dart';
import 'providers/auth_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/circle_selection_screen.dart';
import 'screens/participant/participant_home_screen.dart';
import 'screens/admin/admin_home_screen.dart';

// GoRouterのProvider
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final isLoggedIn = authState.value != null;

      // ログイン画面へのアクセス
      if (state.matchedLocation == '/login') {
        return isLoggedIn ? '/circles' : null;
      }

      // 認証が必要なページへのアクセス
      if (!isLoggedIn) {
        return '/login';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/circles',
        builder: (context, state) => const CircleSelectionScreen(),
      ),
      GoRoute(
        path: '/participant/:circleId',
        builder: (context, state) {
          final circleId = state.pathParameters['circleId']!;
          return ParticipantHomeScreen(circleId: circleId);
        },
      ),
      GoRoute(
        path: '/admin/:circleId',
        builder: (context, state) {
          final circleId = state.pathParameters['circleId']!;
          return AdminHomeScreen(circleId: circleId);
        },
      ),
    ],
  );
});

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // .envファイルを読み込む
  await dotenv.load(fileName: ".env");

  // Initialize Japanese locale for date formatting
  await initializeDateFormatting('ja');

  // LINE SDK初期化
  await LineSDK.instance.setup('2008326126');

  // Firebase初期化
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // デバッグモードの場合、Emulatorに接続
  FirebaseEmulatorConfig.connectToEmulator();

  runApp(
    const ProviderScope(
      child: GrumaneApp(),
    ),
  );
}

class GrumaneApp extends ConsumerWidget {
  const GrumaneApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Grumane - サークル管理',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
      ),
      routerConfig: router,
    );
  }
}
