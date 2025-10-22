import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/circle_provider.dart';
import '../../providers/event_provider.dart';
import '../../models/event_model.dart';
import 'participant_event_detail_screen.dart';

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
    final currentUser = ref.watch(authStateProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('テニスサークル'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/circles'),
        ),
        actions: [
          // デバッグ用：イベント自動作成ボタン
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'イベント自動作成（デバッグ）',
            onPressed: () => _autoCreateEvent(context),
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
        return const _NotificationsTab();
      default:
        return const SizedBox.shrink();
    }
  }

  Future<void> _autoCreateEvent(BuildContext context) async {
    final now = DateTime.now();
    final eventName = 'テストイベント_${now.hour}${now.minute}${now.second}';
    final eventDate = now.add(const Duration(days: 3));

    try {
      final createEvent = ref.read(createEventProvider);
      await createEvent(
        circleId: widget.circleId,
        name: eventName,
        description: 'デバッグ用に自動作成されたイベント',
        datetime: eventDate,
        location: 'テスト会場',
        maxParticipants: 10,
        fee: 1000,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('「$eventName」を作成しました'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('イベントの作成に失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// イベント一覧タブ
class _EventListTab extends ConsumerWidget {
  final String circleId;

  const _EventListTab({
    required this.circleId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(circleEventsProvider(circleId));

    return eventsAsync.when(
      data: (events) {
        if (events.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.event_busy,
                    size: 80,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'イベントがありません',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '右上の+ボタンからテストイベントを作成できます',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: events.length,
          itemBuilder: (context, index) {
            final event = events[index];
            return _ParticipantEventCard(
              event: event,
              circleId: circleId,
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text('エラーが発生しました: $error'),
      ),
    );
  }
}

// 参加者用イベントカード
class _ParticipantEventCard extends ConsumerWidget {
  final EventModel event;
  final String circleId;

  const _ParticipantEventCard({
    required this.event,
    required this.circleId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFormat = DateFormat('yyyy/MM/dd (E) HH:mm', 'ja');
    final currentUser = ref.watch(authStateProvider).value;

    // 現在のユーザーが参加しているかチェック
    final isParticipating = currentUser != null &&
        event.participants.any((p) =>
            p.userId == currentUser.uid &&
            p.status != ParticipationStatus.cancelled);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ParticipantEventDetailScreen(
                circleId: circleId,
                eventId: event.eventId,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // イベントアイコン
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.event,
                  color: Colors.blue,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              // イベント情報
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.access_time, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          dateFormat.format(event.datetime),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                    if (event.location != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              event.location!,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[700],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        // 参加状況バッジ
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isParticipating
                                ? Colors.green.shade100
                                : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isParticipating ? Icons.check_circle : Icons.people,
                                size: 14,
                                color: isParticipating ? Colors.green : Colors.grey[700],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isParticipating
                                    ? '参加中'
                                    : '${event.confirmedCount}/${event.maxParticipants}人',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isParticipating ? Colors.green : Colors.grey[700],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // キャンセル待ちバッジ
                        if (event.waitlistCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.schedule,
                                  size: 14,
                                  color: Colors.orange,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '待ち${event.waitlistCount}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        // 参加費バッジ
                        if (event.fee != null && event.fee! > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            margin: const EdgeInsets.only(left: 8),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '¥${event.fee}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
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
