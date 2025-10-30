import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../main.dart';
import '../../services/circle_service.dart';
import '../../services/deep_link_service.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _isLoading = false;

  Future<void> _handleLineLogin() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authService = ref.read(authServiceProvider);
      final credential = await authService.signInWithLine();

      if (credential != null && mounted) {
        // 保留中の招待があるかチェック
        final pendingInviteId = ref.read(pendingInviteProvider);

        if (pendingInviteId != null) {
          // 保留中の招待をクリア
          ref.read(pendingInviteProvider.notifier).state = null;

          // 招待確認ダイアログを表示
          await _showInviteConfirmationDialog(pendingInviteId);
        } else {
          // 招待がない場合は通常通りサークル選択画面へ
          context.go('/circles');
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ログインに失敗しました'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラーが発生しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 招待確認ダイアログを表示
  Future<void> _showInviteConfirmationDialog(String inviteId) async {
    final circleService = CircleService();
    final deepLinkService = ref.read(deepLinkServiceProvider);

    // ローディング表示
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // 招待情報を取得
      final details = await circleService.getInviteDetails(inviteId);

      if (!mounted) return;
      Navigator.pop(context); // ローディングを閉じる

      if (details == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('招待リンクが無効または期限切れです')),
        );
        context.go('/circles');
        return;
      }

      final circle = details['circle'];
      final circleName = circle?.name ?? '不明なサークル';

      // 確認ダイアログを表示
      final confirmed = await showDialog<bool>(
        context: context,
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

      if (!mounted) return;

      if (confirmed == true) {
        // 参加処理を実行
        final success = await deepLinkService.handleInviteLink(inviteId);

        if (!mounted) return;

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$circleNameに参加しました')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('サークルへの参加に失敗しました')),
          );
        }
      }

      // どちらの場合もサークル選択画面へ
      context.go('/circles');
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // ローディングを閉じる（もし残っていれば）
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラーが発生しました: $e')),
      );
      context.go('/circles');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // アプリロゴ
                Icon(
                  Icons.groups,
                  size: 100,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 24),

                // アプリ名
                Text(
                  'Circlet',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
                const SizedBox(height: 8),

                // サブタイトル
                Text(
                  'サークル管理をもっと簡単に',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
                const SizedBox(height: 48),

                // LINE ログインボタン
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _handleLineLogin,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.login),
                    label: Text(
                      _isLoading ? 'ログイン中...' : 'LINEでログイン',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF06C755), // LINE green
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 説明文
                Text(
                  'LINEアカウントでログインすると、\nサークルの管理や参加が可能になります',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
