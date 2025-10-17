import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/circle_provider.dart';
import '../../providers/event_provider.dart';
import '../../models/event_model.dart';

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
    final circleAsync = ref.watch(circleProvider(widget.circleId));
    final userId = ref.watch(currentUserIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: circleAsync.when(
          data: (circle) => Text(circle?.name ?? 'サークル'),
          loading: () => const Text('読み込み中...'),
          error: (_, __) => const Text('エラー'),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/circles'),
        ),
      ),
      body: _buildBody(userId),
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

  Widget _buildBody(String? userId) {
    if (userId == null) {
      return const Center(child: Text('ユーザー情報がありません'));
    }

    switch (_selectedIndex) {
      case 0:
        return _EventListTab(circleId: widget.circleId, userId: userId);
      case 1:
        return _MembersTab(circleId: widget.circleId);
      case 2:
        return _PaymentsTab(userId: userId);
      case 3:
        return _NotificationsTab(userId: userId);
      default:
        return const SizedBox.shrink();
    }
  }
}

// イベント一覧タブ
class _EventListTab extends ConsumerWidget {
  final String circleId;
  final String userId;

  const _EventListTab({
    required this.circleId,
    required this.userId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(circleEventsProvider(circleId));

    return eventsAsync.when(
      data: (events) {
        if (events.isEmpty) {
          return const Center(
            child: Text('イベントがありません'),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: events.length,
          itemBuilder: (context, index) {
            final event = events[index];
            return _EventCard(event: event, userId: userId);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('エラー: $error')),
    );
  }
}

// イベントカード
class _EventCard extends ConsumerWidget {
  final EventModel event;
  final String userId;

  const _EventCard({
    required this.event,
    required this.userId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = event.getUserStatus(userId);
    final dateFormat = DateFormat('yyyy/MM/dd (E) HH:mm', 'ja');

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
                    event.name,
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
                Text(dateFormat.format(event.datetime)),
              ],
            ),
            if (event.location != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16),
                  const SizedBox(width: 8),
                  Text(event.location!),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Text('参加: ${event.confirmedCount}/${event.maxParticipants}人'),
                if (event.waitlistCount > 0) ...[
                  const SizedBox(width: 16),
                  Text('待ち: ${event.waitlistCount}人'),
                ],
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: _buildActionButton(context, ref, status),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(ParticipationStatus status) {
    Color color;
    String label;

    switch (status) {
      case ParticipationStatus.confirmed:
        color = Colors.green;
        label = '参加確定';
        break;
      case ParticipationStatus.waitlist:
        color = Colors.orange;
        label = 'キャンセル待ち';
        break;
      case ParticipationStatus.cancelled:
        color = Colors.grey;
        label = 'キャンセル済み';
        break;
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
    WidgetRef ref,
    ParticipationStatus? status,
  ) {
    if (status == null) {
      // 未参加
      return ElevatedButton(
        onPressed: () async {
          final joinEvent = ref.read(joinEventProvider);
          try {
            await joinEvent(eventId: event.eventId, userId: userId);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('参加登録しました')),
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
        child: const Text('参加する'),
      );
    } else if (status == ParticipationStatus.confirmed ||
        status == ParticipationStatus.waitlist) {
      return OutlinedButton(
        onPressed: () async {
          final cancelEvent = ref.read(cancelEventProvider);
          try {
            await cancelEvent(eventId: event.eventId, userId: userId);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('キャンセルしました')),
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
class _MembersTab extends ConsumerWidget {
  final String circleId;

  const _MembersTab({required this.circleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final circleAsync = ref.watch(circleProvider(circleId));

    return circleAsync.when(
      data: (circle) {
        if (circle == null) {
          return const Center(child: Text('サークル情報がありません'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: circle.members.length,
          itemBuilder: (context, index) {
            final member = circle.members[index];
            return Card(
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.person),
                ),
                title: Text('User ${member.userId.substring(0, 8)}'),
                subtitle: Text(member.role),
                trailing: member.tags.isNotEmpty
                    ? Wrap(
                        spacing: 4,
                        children: member.tags
                            .map((tag) => Chip(
                                  label: Text(tag),
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
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('エラー: $error')),
    );
  }
}

// 支払いタブ
class _PaymentsTab extends StatelessWidget {
  final String userId;

  const _PaymentsTab({required this.userId});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('支払い機能は準備中です'),
    );
  }
}

// 通知タブ
class _NotificationsTab extends StatelessWidget {
  final String userId;

  const _NotificationsTab({required this.userId});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('通知機能は準備中です'),
    );
  }
}
