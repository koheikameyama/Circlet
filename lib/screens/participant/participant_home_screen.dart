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
    final circleAsync = ref.watch(circleProvider(widget.circleId));

    return Scaffold(
      appBar: AppBar(
        title: circleAsync.when(
          data: (circle) => Text(circle?.name ?? 'サークル'),
          loading: () => const Text('読み込み中...'),
          error: (_, __) => const Text('サークル'),
        ),
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
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return _EventListTab(circleId: widget.circleId);
      case 1:
        return _MembersTab(circleId: widget.circleId);
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
class _MembersTab extends ConsumerWidget {
  final String circleId;

  const _MembersTab({
    required this.circleId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final circleAsync = ref.watch(circleProvider(circleId));

    return circleAsync.when(
      data: (circle) {
        if (circle == null) {
          return const Center(
            child: Text('サークル情報を取得できませんでした'),
          );
        }

        if (circle.members.isEmpty) {
          return const Center(
            child: Text('メンバーがいません'),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: circle.members.length,
          itemBuilder: (context, index) {
            final member = circle.members[index];
            return _MemberCard(
              circleId: circleId,
              member: member,
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

// メンバーカード
class _MemberCard extends ConsumerWidget {
  final String circleId;
  final dynamic member;

  const _MemberCard({
    required this.circleId,
    required this.member,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userDataAsync = ref.watch(userDataProvider(member.userId));

    return userDataAsync.when(
      data: (userData) {
        final displayName = userData?.name ?? '名前未設定';
        final profileImageUrl = userData?.profileImageUrl;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundImage: profileImageUrl != null
                  ? NetworkImage(profileImageUrl)
                  : null,
              child: profileImageUrl == null
                  ? const Icon(Icons.person)
                  : null,
            ),
            title: Text(
              displayName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              member.role == 'admin' ? '管理者' : 'メンバー',
              style: TextStyle(
                color: member.role == 'admin' ? Colors.blue : Colors.grey[700],
                fontWeight: member.role == 'admin' ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            trailing: member.tags.isNotEmpty
                ? Wrap(
                    spacing: 4,
                    children: member.tags
                        .map<Widget>((tag) => Chip(
                              label: Text(
                                tag as String,
                                style: const TextStyle(fontSize: 12),
                              ),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ))
                        .toList(),
                  )
                : null,
          ),
        );
      },
      loading: () => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          leading: const CircleAvatar(
            child: Icon(Icons.person),
          ),
          title: const Text('読み込み中...'),
          subtitle: Text(
            member.role == 'admin' ? '管理者' : 'メンバー',
          ),
        ),
      ),
      error: (error, stack) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          leading: const CircleAvatar(
            child: Icon(Icons.person),
          ),
          title: Text('User ID: ${member.userId}'),
          subtitle: Text(
            member.role == 'admin' ? '管理者' : 'メンバー',
          ),
        ),
      ),
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
