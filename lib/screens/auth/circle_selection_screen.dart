import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/circle_provider.dart';
import '../../models/circle_model.dart';

class CircleSelectionScreen extends ConsumerWidget {
  const CircleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(authStateProvider).value;

    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final circlesAsync = ref.watch(userCirclesProvider(currentUser.uid));

    return Scaffold(
      appBar: AppBar(
        title: const Text('サークル選択'),
        actions: [
          // デバッグ用：テストサークル作成（メンバーとして参加）
          IconButton(
            icon: const Icon(Icons.bug_report),
            tooltip: 'テストサークル作成（メンバー）',
            onPressed: () async {
              try {
                final circleService = ref.read(circleServiceProvider);
                final now = DateTime.now();

                print('Step 1: Creating circle...');
                // サークルを作成（最初は自分が管理者として作成される）
                final circleId = await circleService.createCircle(
                  name: 'テストサークル_${now.hour}${now.minute}${now.second}',
                  description: 'デバッグ用に自動作成されたサークル（メンバー参加）',
                  creatorUserId: currentUser.uid,
                );
                print('Circle created: $circleId');

                print('Step 2: Adding dummy admin...');
                // ダミーの管理者を追加
                await circleService.addDummyMember(
                  circleId: circleId,
                  name: '管理者（ダミー）',
                  role: 'admin',
                );
                print('Dummy admin added');

                // 少し待機してFirestoreの更新を確実にする
                await Future.delayed(const Duration(milliseconds: 500));

                print('Step 3: Changing user role to member...');
                // 自分の役割を一般メンバーに変更
                await circleService.updateMemberRole(
                  circleId: circleId,
                  userId: currentUser.uid,
                  role: 'member',
                );
                print('User role changed to member');

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('テストサークルを作成しました（メンバーとして参加）'),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 1),
                    ),
                  );

                  // 少し待ってから、作成したサークルを開く
                  await Future.delayed(const Duration(milliseconds: 500));

                  // メンバーとして参加しているので、participant画面を開く
                  if (context.mounted) {
                    context.go('/participant/$circleId');
                  }
                }
              } catch (e, stackTrace) {
                print('Error creating test circle: $e');
                print('Stack trace: $stackTrace');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('作成に失敗: $e'),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 4),
                    ),
                  );
                }
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              // 元のcontextを保存
              final navigator = Navigator.of(context);
              final scaffoldMessenger = ScaffoldMessenger.of(context);

              // ログアウト確認ダイアログ
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('ログアウト'),
                  content: const Text('ログアウトしますか？'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      child: const Text('キャンセル'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      child: const Text('ログアウト'),
                    ),
                  ],
                ),
              );

              if (confirmed == true) {
                try {
                  // ログアウト処理
                  final authService = ref.read(authServiceProvider);
                  await authService.signOut();

                  // ログイン画面に遷移（スタックをクリア）
                  if (context.mounted) {
                    // すべての履歴をクリアしてログイン画面へ
                    while (context.canPop()) {
                      context.pop();
                    }
                    context.pushReplacement('/login');
                  }
                } catch (e) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text('ログアウトに失敗しました: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: circlesAsync.when(
        data: (circles) {
          if (circles.isEmpty) {
            return _buildEmptyState(context);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: circles.length,
            itemBuilder: (context, index) {
              final circle = circles[index];

              // メンバーリストから現在のユーザーを検索してroleをチェック
              final currentMember = circle.members.firstWhere(
                (member) => member.userId == currentUser.uid,
                orElse: () => circle.members.first,
              );
              final isAdmin = currentMember.role == 'admin';

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.groups),
                  ),
                  title: Text(
                    circle.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${circle.members.length}人 • ${isAdmin ? '管理者' : 'メンバー'}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      if (circle.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          circle.description,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    final route = isAdmin
                        ? '/admin/${circle.circleId}'
                        : '/participant/${circle.circleId}';
                    context.go(route);
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('エラーが発生しました: $error'),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showCreateCircleDialog(context, ref, currentUser.uid);
        },
        icon: const Icon(Icons.add),
        label: const Text('サークル作成'),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.groups_outlined,
            size: 100,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'サークルがありません',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '新しいサークルを作成するか、\n招待リンクから参加してください',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[500],
                ),
          ),
        ],
      ),
    );
  }

  void _showCreateCircleDialog(BuildContext context, WidgetRef ref, String userId) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('サークル作成'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'サークル名',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: '説明',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('サークル名を入力してください')),
                );
                return;
              }

              Navigator.of(dialogContext).pop();

              try {
                final createCircle = ref.read(createCircleProvider);
                await createCircle(
                  name: nameController.text,
                  description: descriptionController.text,
                  creatorUserId: userId,
                );

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('「${nameController.text}」を作成しました'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('サークルの作成に失敗しました: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('作成'),
          ),
        ],
      ),
    );
  }
}
