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
import 'services/deep_link_service.dart';
import 'services/circle_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/circle_selection_screen.dart';
import 'screens/participant/participant_home_screen.dart';
import 'screens/admin/admin_home_screen.dart';
import 'screens/profile/profile_edit_screen.dart';

// 保留中の招待IDを管理するProvider
final pendingInviteProvider = StateProvider<String?>((ref) => null);

// グローバルナビゲーターキー
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// GoRouterのProvider
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    navigatorKey: navigatorKey,
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
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileEditScreen(),
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

class GrumaneApp extends ConsumerStatefulWidget {
  const GrumaneApp({super.key});

  @override
  ConsumerState<GrumaneApp> createState() => _GrumaneAppState();
}

class _GrumaneAppState extends ConsumerState<GrumaneApp> {
  DeepLinkService? _deepLinkService;

  @override
  void initState() {
    super.initState();
    // ウィジェットツリーが構築された後にディープリンクを初期化
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initDeepLinks();
    });
  }

  void _initDeepLinks() {
    _deepLinkService = ref.read(deepLinkServiceProvider);
    _deepLinkService?.initDeepLinks(
      onInviteLink: (inviteId) async {
        print('Invite link received: $inviteId');

        // ログインしているかチェック
        final currentUser = _deepLinkService?.authService.currentUser;
        if (currentUser != null) {
          // ログイン済みの場合、確認ダイアログを表示
          if (mounted) {
            // 少し遅延させて、MaterialAppが完全に構築されるのを待つ
            await Future.delayed(const Duration(milliseconds: 100));
            if (mounted) {
              _showInviteConfirmationDialog(inviteId);
            }
          }
        } else {
          // 未ログインの場合、招待IDを保存してログイン画面へ
          ref.read(pendingInviteProvider.notifier).state = inviteId;
          ref.read(routerProvider).go('/login');
        }
      },
      onError: (error) {
        // エラーはコンソールにのみ出力（UIは使わない）
        print('Deep link error: $error');
      },
    );
  }

  // 招待確認ダイアログを表示
  void _showInviteConfirmationDialog(String inviteId) async {
    final circleService = CircleService();
    final navContext = navigatorKey.currentContext;

    if (navContext == null || !navContext.mounted) {
      print('Navigator context not available');
      return;
    }

    // ローディング表示
    showDialog(
      context: navContext,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // 招待情報を取得
      final details = await circleService.getInviteDetails(inviteId);

      if (!navContext.mounted) return;
      Navigator.pop(navContext); // ローディングを閉じる

      if (details == null) {
        ScaffoldMessenger.of(navContext).showSnackBar(
          const SnackBar(content: Text('招待リンクが無効または期限切れです')),
        );
        return;
      }

      final circle = details['circle'];
      final circleName = circle?.name ?? '不明なサークル';

      // 確認ダイアログを表示
      final confirmed = await showDialog<bool>(
        context: navContext,
        builder: (context) => AlertDialog(
          title: const Text('サークルへの招待'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('以下のサークルに参加しますか？'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.group, color: Colors.blue, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            circleName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (circle?.description?.isNotEmpty ?? false)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                circle!.description,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('参加する'),
            ),
          ],
        ),
      );

      if (confirmed == true && navContext.mounted) {
        // 参加処理を実行
        final success = await _deepLinkService?.handleInviteLink(inviteId);

        if (!navContext.mounted) return;

        if (success == true) {
          ScaffoldMessenger.of(navContext).showSnackBar(
            SnackBar(content: Text('$circleNameに参加しました')),
          );
          ref.read(routerProvider).go('/circles');
        } else {
          ScaffoldMessenger.of(navContext).showSnackBar(
            const SnackBar(content: Text('サークルへの参加に失敗しました')),
          );
        }
      }
    } catch (e) {
      if (!navContext.mounted) return;
      Navigator.pop(navContext); // ローディングを閉じる（もし残っていれば）
      ScaffoldMessenger.of(navContext).showSnackBar(
        SnackBar(content: Text('エラーが発生しました: $e')),
      );
    }
  }

  @override
  void dispose() {
    _deepLinkService?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
      themeMode: ThemeMode.light, // 常にライトモード
      routerConfig: router,
    );
  }
}
