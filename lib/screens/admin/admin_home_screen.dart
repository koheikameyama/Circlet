import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
// import '../../providers/circle_provider.dart'; // Temporarily disabled
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('テニスサークル (管理)'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/circles'),
        ),
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
class _AdminMembersTab extends StatelessWidget {
  final String circleId;

  const _AdminMembersTab({required this.circleId});

  @override
  Widget build(BuildContext context) {
    // Mock member data
    final mockMembers = [
      {'name': '山田太郎', 'role': 'admin'},
      {'name': '佐藤花子', 'role': 'member'},
      {'name': '鈴木一郎', 'role': 'member'},
    ];

    return Column(
      children: [
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
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: mockMembers.length,
            itemBuilder: (context, index) {
              final member = mockMembers[index];
              final isAdmin = member['role'] == 'admin';
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isAdmin ? Colors.blue : Colors.grey,
                    child: Icon(
                      isAdmin ? Icons.admin_panel_settings : Icons.person,
                      color: Colors.white,
                    ),
                  ),
                  title: Text(member['name'] as String),
                  subtitle: Text(member['role'] as String),
                  trailing: !isAdmin
                      ? IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('メンバーを削除しました (デモモード)')),
                            );
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
