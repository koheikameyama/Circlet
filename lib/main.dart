import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// 条件付きインポート: Web版ではスタブを使用
import 'services/line_sdk_stub.dart'
    if (dart.library.io) 'package:flutter_line_sdk/flutter_line_sdk.dart';
import 'firebase_options.dart';
import 'config/firebase_emulator_config.dart';
import 'providers/auth_provider.dart';
import 'services/deep_link_service.dart';
import 'services/circle_service.dart';
import 'services/logger_service.dart';
import 'services/notification_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/email_login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/circle_selection_screen.dart';
import 'screens/participant/participant_home_screen.dart';
import 'screens/admin/admin_home_screen.dart';

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

      // 認証不要なページのリスト
      final authPages = ['/login', '/email-login', '/register'];

      // 認証不要なページへのアクセス
      if (authPages.contains(state.matchedLocation)) {
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
        path: '/email-login',
        builder: (context, state) => const EmailLoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
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

  try {
    // .envファイルを読み込む（Web版以外）
    try {
      await dotenv.load(fileName: ".env");
    } catch (e) {
      AppLogger.info('.env file not found or cannot be loaded (this is normal for web): $e');
    }

    // Initialize Japanese locale for date formatting
    await initializeDateFormatting('ja');
    await initializeDateFormatting('ja_JP');

    // LINE SDK初期化（Web版以外）
    if (!kIsWeb) {
      await LineSDK.instance.setup('2008326126');
    }

    // Firebase初期化
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // デバッグモードの場合、Emulatorに接続
    FirebaseEmulatorConfig.connectToEmulator();

    runApp(
      const ProviderScope(
        child: CircletApp(),
      ),
    );
  } catch (e, stackTrace) {
    AppLogger.error('Failed to initialize app: $e');
    AppLogger.error('Stack trace: $stackTrace');

    // エラー画面を表示
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 64,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'アプリの初期化に失敗しました',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'エラー: $e',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CircletApp extends ConsumerStatefulWidget {
  const CircletApp({super.key});

  @override
  ConsumerState<CircletApp> createState() => _CircletAppState();
}

class _CircletAppState extends ConsumerState<CircletApp> {
  DeepLinkService? _deepLinkService;
  final NotificationService _notificationService = NotificationService();
  bool _isNotificationInitialized = false;

  @override
  void initState() {
    super.initState();
    // ウィジェットツリーが構築された後にディープリンクを初期化（Web版以外）
    if (!kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initDeepLinks();
      });

      // フォアグラウンド通知のハンドリングを設定
      _notificationService.setupForegroundNotificationHandling();
    }
  }

  void _initDeepLinks() {
    _deepLinkService = ref.read(deepLinkServiceProvider);
    _deepLinkService?.initDeepLinks(
      onInviteLink: (inviteId) async {
        AppLogger.info('Invite link received: $inviteId');

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
        AppLogger.error('Deep link error: $error');
      },
    );
  }

  // 招待確認ダイアログを表示
  void _showInviteConfirmationDialog(String inviteId) async {
    final circleService = CircleService();
    final navContext = navigatorKey.currentContext;

    if (navContext == null || !navContext.mounted) {
      AppLogger.warning('Navigator context not available');
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
      final circleId = circle?.circleId ?? '';

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

          // 表示名編集ダイアログを表示
          final currentUser = _deepLinkService?.authService.currentUser;
          if (currentUser != null &&
              navContext.mounted &&
              circleId.isNotEmpty) {
            await _showEditNameDialog(navContext, circleId, currentUser.uid);
          }

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

  Future<void> _showEditNameDialog(
    BuildContext context,
    String circleId,
    String userId,
  ) async {
    final authService = ref.read(authServiceProvider);
    final userData = await authService.getUserData(userId);
    final currentName = userData?.name ?? '';

    if (!context.mounted) return;

    final nameController = TextEditingController(text: currentName);

    await showDialog(
      context: context,
      barrierDismissible: false, // ダイアログ外タップで閉じないようにする
      builder: (dialogContext) => AlertDialog(
        title: const Text('表示名の設定'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('サークル内で使用する表示名を設定してください'),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: '表示名',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              // スキップした場合は現在の名前のまま
              Navigator.pop(dialogContext);
            },
            child: const Text('スキップ'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('表示名を入力してください')),
                );
                return;
              }

              try {
                final circleService = CircleService();
                await circleService.updateMemberDisplayName(
                  circleId: circleId,
                  userId: userId,
                  displayName: nameController.text,
                );
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('変更に失敗しました: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('設定'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _deepLinkService?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final authState = ref.watch(authStateProvider);

    // ログイン状態を監視して通知を初期化（Web版以外）
    if (!kIsWeb) {
      ref.listen(authStateProvider, (previous, next) {
        if (next.value != null && previous?.value == null) {
          // ログインしたとき
          _notificationService.initializeNotifications(next.value!.uid);
          _isNotificationInitialized = true;
        } else if (next.value == null) {
          // ログアウトしたとき
          _isNotificationInitialized = false;
        }
      });

      // 既にログイン済みで、まだ初期化していない場合
      if (authState.value != null && !_isNotificationInitialized) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_isNotificationInitialized) {
            _notificationService.initializeNotifications(authState.value!.uid);
            _isNotificationInitialized = true;
          }
        });
      }
    }

    return MaterialApp.router(
      title: 'Circlet - サークル管理',
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
