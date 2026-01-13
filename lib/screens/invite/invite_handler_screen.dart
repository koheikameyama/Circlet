import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../services/circle_service.dart';
import '../../providers/auth_provider.dart';
import '../../main.dart';

/// 招待リンク処理用の画面
/// Web版の招待URLからアクセスされたときに表示される
class InviteHandlerScreen extends ConsumerStatefulWidget {
  final String inviteId;

  const InviteHandlerScreen({
    super.key,
    required this.inviteId,
  });

  @override
  ConsumerState<InviteHandlerScreen> createState() => _InviteHandlerScreenState();
}

class _InviteHandlerScreenState extends ConsumerState<InviteHandlerScreen> {
  @override
  void initState() {
    super.initState();
    // 画面が表示された直後に招待処理を実行
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleInvite();
    });
  }

  Future<void> _handleInvite() async {
    final authState = ref.read(authStateProvider);
    final currentUser = authState.value;

    // 未ログインの場合、招待IDを保存してログイン画面へ
    if (currentUser == null) {
      ref.read(pendingInviteProvider.notifier).state = widget.inviteId;
      if (mounted) {
        context.go('/login');
      }
      return;
    }

    // ログイン済みの場合、招待情報を取得して確認ダイアログを表示
    await _showInviteConfirmationDialog();
  }

  Future<void> _showInviteConfirmationDialog() async {
    final circleService = CircleService();

    if (!mounted) return;

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
      final details = await circleService.getInviteDetails(widget.inviteId);

      if (!mounted) return;
      Navigator.pop(context); // ローディングを閉じる

      if (details == null) {
        _showErrorAndRedirect('招待リンクが無効または期限切れです');
        return;
      }

      final circle = details['circle'];
      final circleName = circle?.name ?? '不明なサークル';
      final circleId = circle?.circleId ?? '';

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

      if (confirmed == true && mounted) {
        await _joinCircle(circleId, circleName);
      } else if (mounted) {
        context.go('/circles');
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // ローディングを閉じる（もし残っていれば）
      _showErrorAndRedirect('エラーが発生しました: $e');
    }
  }

  Future<void> _joinCircle(String circleId, String circleName) async {
    if (!mounted) return;

    // ローディング表示
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final circleService = CircleService();
      final currentUser = ref.read(authStateProvider).value;

      if (currentUser == null) {
        throw Exception('ログインが必要です');
      }

      // サークルに参加
      await circleService.joinCircleWithInvite(
        inviteId: widget.inviteId,
        userId: currentUser.uid,
      );

      if (!mounted) return;
      Navigator.pop(context); // ローディングを閉じる

      // 表示名編集ダイアログを表示
      await _showEditNameDialog(circleId, currentUser.uid);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$circleNameに参加しました')),
      );

      context.go('/circles');
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // ローディングを閉じる
      _showErrorAndRedirect('サークルへの参加に失敗しました: $e');
    }
  }

  Future<void> _showEditNameDialog(String circleId, String userId) async {
    if (!mounted) return;

    final authService = ref.read(authServiceProvider);
    final userData = await authService.getUserData(userId);
    final currentName = userData?.name ?? '';

    if (!mounted) return;

    final nameController = TextEditingController(text: currentName);

    await showDialog(
      context: context,
      barrierDismissible: false,
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
            onPressed: () => Navigator.pop(dialogContext),
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

  void _showErrorAndRedirect(String message) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('エラー'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (mounted) {
                context.go('/circles');
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
