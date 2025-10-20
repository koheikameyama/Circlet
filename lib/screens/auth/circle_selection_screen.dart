import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
// import '../../providers/auth_provider.dart'; // Temporarily disabled
// import '../../providers/circle_provider.dart'; // Temporarily disabled
// import '../../models/circle_model.dart'; // Temporarily disabled

class CircleSelectionScreen extends ConsumerWidget {
  const CircleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Temporarily using mock data instead of Firebase
    final mockCircles = [
      {'id': '1', 'name': 'テニスサークル', 'members': 15, 'isAdmin': true},
      {'id': '2', 'name': 'フットサル部', 'members': 20, 'isAdmin': false},
      {'id': '3', 'name': 'ランニングクラブ', 'members': 8, 'isAdmin': false},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('サークル選択'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              // Temporarily disabled Firebase logout
              context.go('/login');
            },
          ),
        ],
      ),
      body: mockCircles.isEmpty
          ? _buildEmptyState(context)
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: mockCircles.length,
              itemBuilder: (context, index) {
                final circle = mockCircles[index];
                final isAdmin = circle['isAdmin'] as bool;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.groups),
                    ),
                    title: Text(
                      circle['name'] as String,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      '${circle['members']}人 • ${isAdmin ? '管理者' : 'メンバー'}',
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      final route = isAdmin
                          ? '/admin/${circle['id']}'
                          : '/participant/${circle['id']}';
                      context.go(route);
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showCreateCircleDialog(context);
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

  void _showCreateCircleDialog(BuildContext context) {
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
            onPressed: () {
              if (nameController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('サークル名を入力してください')),
                );
                return;
              }

              // Temporarily disabled Firebase circle creation
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content:
                        Text('「${nameController.text}」を作成しました (デモモード)')),
              );
            },
            child: const Text('作成'),
          ),
        ],
      ),
    );
  }
}
