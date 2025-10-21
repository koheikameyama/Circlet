import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../providers/circle_provider.dart';
import '../../providers/auth_provider.dart';
// import '../../providers/event_provider.dart'; // Temporarily disabled
// import '../../models/event_model.dart'; // Temporarily disabled

class AdminHomeScreen extends ConsumerStatefulWidget {
  final String circleId;

  const AdminHomeScreen({
    super.key,
    required this.circleId,
  });

  @override
  ConsumerState<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends ConsumerState<AdminHomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final circleAsync = ref.watch(circleProvider(widget.circleId));

    return Scaffold(
      appBar: AppBar(
        title: circleAsync.when(
          data: (circle) => Text(circle?.name ?? 'サークル (管理)'),
          loading: () => const Text('サークル (管理)'),
          error: (_, __) => const Text('サークル (管理)'),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/circles'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showEditCircleDialog(context, circleAsync.value),
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.event),
            label: 'イベント',
          ),
          NavigationDestination(
            icon: Icon(Icons.people),
            label: 'メンバー',
          ),
          NavigationDestination(
            icon: Icon(Icons.payment),
            label: '支払い',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications),
            label: '通知',
          ),
        ],
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () => _showCreateEventDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('イベント作成'),
            )
          : null,
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return _AdminEventListTab(circleId: widget.circleId);
      case 1:
        return _AdminMembersTab(circleId: widget.circleId);
      case 2:
        return _AdminPaymentsTab(circleId: widget.circleId);
      case 3:
        return _AdminNotificationsTab(circleId: widget.circleId);
      default:
        return const SizedBox.shrink();
    }
  }

  void _showCreateEventDialog(BuildContext context) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final locationController = TextEditingController();
    final maxParticipantsController = TextEditingController(text: '10');
    final feeController = TextEditingController(text: '0');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('イベント作成'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'イベント名',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: '説明',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: locationController,
                decoration: const InputDecoration(
                  labelText: '場所',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: maxParticipantsController,
                decoration: const InputDecoration(
                  labelText: '定員',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: feeController,
                decoration: const InputDecoration(
                  labelText: '参加費',
                  border: OutlineInputBorder(),
                  prefixText: '¥',
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
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
                  const SnackBar(content: Text('イベント名を入力してください')),
                );
                return;
              }

              // Temporarily disabled Firebase event creation
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

  void _showEditCircleDialog(BuildContext context, circle) {
    if (circle == null) return;

    final nameController = TextEditingController(text: circle.name);
    final descriptionController = TextEditingController(text: circle.description);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('サークル情報編集'),
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
            onPressed: () => Navigator.pop(dialogContext),
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

              Navigator.pop(dialogContext);

              try {
                final updateCircle = ref.read(updateCircleProvider);
                await updateCircle(
                  circleId: widget.circleId,
                  name: nameController.text,
                  description: descriptionController.text,
                );

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('サークル情報を更新しました'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('更新に失敗しました: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}

// 管理者用イベント一覧タブ
class _AdminEventListTab extends StatelessWidget {
  final String circleId;

  const _AdminEventListTab({required this.circleId});

  @override
  Widget build(BuildContext context) {
    // Mock event data
    final mockEvents = [
      {
        'name': '週末テニス練習',
        'date': DateTime.now().add(const Duration(days: 3)),
        'confirmed': 8,
        'max': 12,
        'waitlist': 2,
        'participants': [
          {'name': '山田太郎', 'status': 'confirmed'},
          {'name': '佐藤花子', 'status': 'confirmed'},
          {'name': '鈴木一郎', 'status': 'waitlist'},
        ],
      },
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: mockEvents.length,
      itemBuilder: (context, index) {
        final event = mockEvents[index];
        return _AdminEventCard(event: event);
      },
    );
  }
}

// 管理者用イベントカード
class _AdminEventCard extends StatelessWidget {
  final Map<String, dynamic> event;

  const _AdminEventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy/MM/dd (E) HH:mm', 'ja');
    final date = event['date'] as DateTime;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: const Icon(Icons.event),
        title: Text(
          event['name'] as String,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(dateFormat.format(date)),
            Text('参加: ${event['confirmed']}/${event['max']}人'),
            if ((event['waitlist'] as int) > 0)
              Text('待ち: ${event['waitlist']}人',
                  style: const TextStyle(color: Colors.orange)),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '参加者一覧',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...(event['participants'] as List).map((p) {
                  final participant = p as Map<String, dynamic>;
                  final status = participant['status'] as String;
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.person),
                    title: Text(participant['name'] as String),
                    trailing: Chip(
                      label: Text(status == 'confirmed' ? '参加確定' : 'キャンセル待ち'),
                      backgroundColor: status == 'confirmed'
                          ? Colors.green
                          : Colors.orange,
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// 管理者用メンバータブ
class _AdminMembersTab extends ConsumerWidget {
  final String circleId;

  const _AdminMembersTab({required this.circleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final circleAsync = ref.watch(circleProvider(circleId));

    return circleAsync.when(
      data: (circle) {
        if (circle == null) {
          return const Center(child: Text('サークルが見つかりません'));
        }

        return Column(
          children: [
            // サークル情報
            if (circle.description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.info_outline, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'サークル説明',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          circle.description,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // 招待QRコード
            Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text(
                        '招待用QRコード',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      QrImageView(
                        data: 'invite://circle/$circleId',
                        version: QrVersions.auto,
                        size: 200,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // デバッグ用：ダミーメンバー追加ボタン
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                color: Colors.orange.shade50,
                child: ListTile(
                  leading: const Icon(Icons.bug_report, color: Colors.orange),
                  title: const Text('デバッグ: テストメンバー追加'),
                  trailing: ElevatedButton.icon(
                    onPressed: () => _addDummyMembers(context, ref, circleId),
                    icon: const Icon(Icons.person_add),
                    label: const Text('追加'),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // メンバーリスト
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: circle.members.length,
                itemBuilder: (context, index) {
                  final member = circle.members[index];
                  final isAdmin = member.role == 'admin';
                  final isDummy = member.userId.startsWith('dummy_');

                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isAdmin ? Colors.blue : Colors.grey,
                        child: Icon(
                          isAdmin ? Icons.admin_panel_settings : Icons.person,
                          color: Colors.white,
                        ),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: FutureBuilder<String>(
                              future: _getUserName(ref, member.userId),
                              builder: (context, snapshot) {
                                return Text(snapshot.data ?? member.userId);
                              },
                            ),
                          ),
                          if (isDummy)
                            const Chip(
                              label: Text('テスト', style: TextStyle(fontSize: 10)),
                              backgroundColor: Colors.orange,
                              padding: EdgeInsets.symmetric(horizontal: 4),
                            ),
                        ],
                      ),
                      subtitle: Text(isAdmin ? '管理者' : 'メンバー'),
                      trailing: !isAdmin
                          ? IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (dialogContext) => AlertDialog(
                                    title: const Text('メンバー削除'),
                                    content: const Text('このメンバーを削除しますか？'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(dialogContext).pop(false),
                                        child: const Text('キャンセル'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () => Navigator.of(dialogContext).pop(true),
                                        child: const Text('削除'),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirmed == true && context.mounted) {
                                  try {
                                    final removeMember = ref.read(removeMemberProvider);
                                    await removeMember(
                                      circleId: circleId,
                                      userId: member.userId,
                                    );
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('メンバーを削除しました'),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('削除に失敗しました: $e'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                }
                              },
                            )
                          : null,
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('エラー: $error')),
    );
  }

  Future<String> _getUserName(WidgetRef ref, String userId) async {
    try {
      final authService = ref.read(authServiceProvider);
      final user = await authService.getUserData(userId);
      return user?.name ?? userId;
    } catch (e) {
      return userId;
    }
  }

  Future<void> _addDummyMembers(BuildContext context, WidgetRef ref, String circleId) async {
    final dummyNames = ['田中太郎', '佐藤花子', '鈴木一郎', '高橋次郎', '伊藤美咲'];

    try {
      final circleService = ref.read(circleServiceProvider);

      for (final name in dummyNames) {
        await circleService.addDummyMember(
          circleId: circleId,
          name: name,
        );
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${dummyNames.length}人のテストメンバーを追加しました'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('追加に失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// 管理者用支払いタブ
class _AdminPaymentsTab extends StatelessWidget {
  final String circleId;

  const _AdminPaymentsTab({required this.circleId});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('支払い管理機能は準備中です'),
    );
  }
}

// 管理者用通知タブ
class _AdminNotificationsTab extends StatelessWidget {
  final String circleId;

  const _AdminNotificationsTab({required this.circleId});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('通知管理機能は準備中です'),
    );
  }
}
