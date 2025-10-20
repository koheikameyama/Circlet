import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
// import '../../providers/auth_provider.dart'; // Temporarily disabled
// import '../../providers/circle_provider.dart'; // Temporarily disabled
// import '../../providers/event_provider.dart'; // Temporarily disabled
// import '../../models/event_model.dart'; // Temporarily disabled

class ParticipantHomeScreen extends ConsumerStatefulWidget {
  final String circleId;

  const ParticipantHomeScreen({
    super.key,
    required this.circleId,
  });

  @override
  ConsumerState<ParticipantHomeScreen> createState() =>
      _ParticipantHomeScreenState();
}

class _ParticipantHomeScreenState
    extends ConsumerState<ParticipantHomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('テニスサークル'),
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
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return _EventListTab(circleId: widget.circleId);
      case 1:
        return const _MembersTab();
      case 2:
        return const _PaymentsTab();
      case 3:
        return const _NotificationsTab();
      default:
        return const SizedBox.shrink();
    }
  }
}

// イベント一覧タブ
class _EventListTab extends StatelessWidget {
  final String circleId;

  const _EventListTab({
    required this.circleId,
  });

  @override
  Widget build(BuildContext context) {
    // Mock event data
    final mockEvents = [
      {
        'name': '週末テニス練習',
        'date': DateTime.now().add(const Duration(days: 3)),
        'location': '市民体育館',
        'confirmed': 8,
        'max': 12,
        'waitlist': 2,
        'status': 'confirmed',
      },
      {
        'name': 'ダブルストーナメント',
        'date': DateTime.now().add(const Duration(days: 10)),
        'location': 'テニスコートA',
        'confirmed': 12,
        'max': 16,
        'waitlist': 0,
        'status': null,
      },
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: mockEvents.length,
      itemBuilder: (context, index) {
        final event = mockEvents[index];
        return _EventCard(event: event);
      },
    );
  }
}

// イベントカード
class _EventCard extends StatelessWidget {
  final Map<String, dynamic> event;

  const _EventCard({
    required this.event,
  });

  @override
  Widget build(BuildContext context) {
    final status = event['status'] as String?;
    final dateFormat = DateFormat('yyyy/MM/dd (E) HH:mm', 'ja');
    final date = event['date'] as DateTime;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    event['name'] as String,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (status != null) _buildStatusChip(status),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16),
                const SizedBox(width: 8),
                Text(dateFormat.format(date)),
              ],
            ),
            if (event['location'] != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16),
                  const SizedBox(width: 8),
                  Text(event['location'] as String),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Text('参加: ${event['confirmed']}/${event['max']}人'),
                if ((event['waitlist'] as int) > 0) ...[
                  const SizedBox(width: 16),
                  Text('待ち: ${event['waitlist']}人'),
                ],
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: _buildActionButton(context, status),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String label;

    switch (status) {
      case 'confirmed':
        color = Colors.green;
        label = '参加確定';
        break;
      case 'waitlist':
        color = Colors.orange;
        label = 'キャンセル待ち';
        break;
      case 'cancelled':
        color = Colors.grey;
        label = 'キャンセル済み';
        break;
      default:
        color = Colors.grey;
        label = '不明';
    }

    return Chip(
      label: Text(label),
      backgroundColor: color.withOpacity(0.2),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.bold),
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    String? status,
  ) {
    if (status == null) {
      // 未参加
      return ElevatedButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('参加登録しました (デモモード)')),
          );
        },
        child: const Text('参加する'),
      );
    } else if (status == 'confirmed' || status == 'waitlist') {
      return OutlinedButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('キャンセルしました (デモモード)')),
          );
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red,
        ),
        child: const Text('キャンセル'),
      );
    }

    return const SizedBox.shrink();
  }
}

// メンバータブ
class _MembersTab extends StatelessWidget {
  const _MembersTab();

  @override
  Widget build(BuildContext context) {
    // Mock member data
    final mockMembers = [
      {'name': '山田太郎', 'role': '管理者', 'tags': ['レギュラー']},
      {'name': '佐藤花子', 'role': 'メンバー', 'tags': []},
      {'name': '鈴木一郎', 'role': 'メンバー', 'tags': ['初心者']},
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: mockMembers.length,
      itemBuilder: (context, index) {
        final member = mockMembers[index];
        return Card(
          child: ListTile(
            leading: const CircleAvatar(
              child: Icon(Icons.person),
            ),
            title: Text(member['name'] as String),
            subtitle: Text(member['role'] as String),
            trailing: (member['tags'] as List).isNotEmpty
                ? Wrap(
                    spacing: 4,
                    children: (member['tags'] as List)
                        .map((tag) => Chip(
                              label: Text(tag as String),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ))
                        .toList(),
                  )
                : null,
          ),
        );
      },
    );
  }
}

// 支払いタブ
class _PaymentsTab extends StatelessWidget {
  const _PaymentsTab();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('支払い機能は準備中です'),
    );
  }
}

// 通知タブ
class _NotificationsTab extends StatelessWidget {
  const _NotificationsTab();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('通知機能は準備中です'),
    );
  }
}
