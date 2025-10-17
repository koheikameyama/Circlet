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
    final currentUser = ref.watch(currentUserProvider);
    final userId = ref.watch(currentUserIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('サークル選択'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final signOut = ref.read(signOutProvider);
              await signOut();
              if (context.mounted) {
                context.go('/login');
              }
            },
          ),
        ],
      ),
      body: currentUser.when(
        data: (user) {
          if (user == null || userId == null) {
            return const Center(
              child: Text('ユーザー情報が見つかりません'),
            );
          }

          if (user.circleIds.isEmpty) {
            return _buildEmptyState(context);
          }

          return _buildCircleList(context, ref, user.circleIds, userId);
        },
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stack) => Center(
          child: Text('エラーが発生しました: $error'),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // TODO: サークル作成画面へ遷移
          _showCreateCircleDialog(context, ref, userId ?? '');
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

  Widget _buildCircleList(
    BuildContext context,
    WidgetRef ref,
    List<String> circleIds,
    String userId,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: circleIds.length,
      itemBuilder: (context, index) {
        final circleId = circleIds[index];
        final circleAsync = ref.watch(circleProvider(circleId));

        return circleAsync.when(
          data: (circle) {
            if (circle == null) return const SizedBox.shrink();

            final isAdmin = circle.isAdmin(userId);

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundImage: circle.iconUrl != null
                      ? NetworkImage(circle.iconUrl!)
                      : null,
                  child: circle.iconUrl == null
                      ? const Icon(Icons.groups)
                      : null,
                ),
                title: Text(
                  circle.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  '${circle.members.length}人 • ${isAdmin ? '管理者' : 'メンバー'}',
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  ref.read(selectedCircleIdProvider.notifier).state = circleId;
                  final route = isAdmin
                      ? '/admin/$circleId'
                      : '/participant/$circleId';
                  context.go(route);
                },
              ),
            );
          },
          loading: () => const Card(
            child: ListTile(
              leading: CircularProgressIndicator(),
              title: Text('読み込み中...'),
            ),
          ),
          error: (error, stack) => Card(
            child: ListTile(
              leading: const Icon(Icons.error, color: Colors.red),
              title: Text('エラー: $error'),
            ),
          ),
        );
      },
    );
  }

  void _showCreateCircleDialog(
    BuildContext context,
    WidgetRef ref,
    String userId,
  ) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('サークル作成'),
        content: Column(
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
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

              final createCircle = ref.read(createCircleProvider);
              try {
                await createCircle(
                  name: nameController.text,
                  description: descriptionController.text,
                  adminId: userId,
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('サークルを作成しました')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('エラー: $e')),
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
