import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../providers/circle_provider.dart';
import '../../providers/event_provider.dart';
import '../../models/event_model.dart';

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
          data: (circle) => Text('${circle?.name ?? 'サークル'} (管理)'),
          loading: () => const Text('読み込み中...'),
          error: (_, __) => const Text('エラー'),
        ),
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
    DateTime selectedDate = DateTime.now().add(const Duration(days: 7));

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
            onPressed: () async {
              if (nameController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('イベント名を入力してください')),
                );
                return;
              }

              final createEvent = ref.read(createEventProvider);
              try {
                await createEvent(
                  circleId: widget.circleId,
                  name: nameController.text,
                  description: descriptionController.text.isEmpty
                      ? null
                      : descriptionController.text,
                  datetime: selectedDate,
                  location: locationController.text.isEmpty
                      ? null
                      : locationController.text,
                  maxParticipants: int.parse(maxParticipantsController.text),
                  fee: int.tryParse(feeController.text),
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('イベントを作成しました')),
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

// 管理者用イベント一覧タブ
class _AdminEventListTab extends ConsumerWidget {
  final String circleId;

  const _AdminEventListTab({required this.circleId});

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
            return _AdminEventCard(event: event);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('エラー: $error')),
    );
  }
}

// 管理者用イベントカード
class _AdminEventCard extends ConsumerWidget {
  final EventModel event;

  const _AdminEventCard({required this.event});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFormat = DateFormat('yyyy/MM/dd (E) HH:mm', 'ja');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: const Icon(Icons.event),
        title: Text(
          event.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(dateFormat.format(event.datetime)),
            Text('参加: ${event.confirmedCount}/${event.maxParticipants}人'),
            if (event.waitlistCount > 0)
              Text('待ち: ${event.waitlistCount}人',
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
                ...event.participants
                    .where((p) => p.status == ParticipationStatus.confirmed)
                    .map((p) => ListTile(
                          dense: true,
                          leading: const Icon(Icons.person),
                          title: Text('User ${p.userId.substring(0, 8)}'),
                          trailing: const Chip(
                            label: Text('参加確定'),
                            backgroundColor: Colors.green,
                          ),
                        )),
                if (event.waitlistCount > 0) ...[
                  const Divider(),
                  const Text(
                    'キャンセル待ち',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...event.participants
                      .where((p) => p.status == ParticipationStatus.waitlist)
                      .map((p) => ListTile(
                            dense: true,
                            leading: const Icon(Icons.person_outline),
                            title: Text('User ${p.userId.substring(0, 8)}'),
                            trailing: Chip(
                              label: Text('待ち${p.waitingNumber}'),
                              backgroundColor: Colors.orange,
                            ),
                          )),
                ],
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
    final circleService = ref.watch(circleServiceProvider);

    return circleAsync.when(
      data: (circle) {
        if (circle == null) {
          return const Center(child: Text('サークル情報がありません'));
        }

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
                        data: circleService.generateInviteToken(circleId),
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
                itemCount: circle.members.length,
                itemBuilder: (context, index) {
                  final member = circle.members[index];
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: member.role == 'admin'
                            ? Colors.blue
                            : Colors.grey,
                        child: Icon(
                          member.role == 'admin'
                              ? Icons.admin_panel_settings
                              : Icons.person,
                          color: Colors.white,
                        ),
                      ),
                      title: Text('User ${member.userId.substring(0, 8)}'),
                      subtitle: Text(member.role),
                      trailing: member.role != 'admin'
                          ? IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                final removeMember =
                                    ref.read(removeMemberProvider);
                                try {
                                  await removeMember(
                                    circleId: circleId,
                                    userId: member.userId,
                                  );
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text('メンバーを削除しました')),
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
