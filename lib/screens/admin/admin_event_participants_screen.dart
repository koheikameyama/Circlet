import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/event_model.dart';
import '../../providers/event_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/circle_provider.dart';

class AdminEventParticipantsScreen extends ConsumerWidget {
  final String circleId;
  final String eventId;

  const AdminEventParticipantsScreen({
    super.key,
    required this.circleId,
    required this.eventId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventAsync = ref.watch(eventProvider(eventId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('参加者一覧'),
      ),
      body: eventAsync.when(
        data: (event) {
          if (event == null) {
            return const Center(child: Text('イベントが見つかりません'));
          }

          return SingleChildScrollView(
            child: Column(
              children: [
                // イベント情報サマリー
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: Colors.blue.shade50,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.people, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            '参加確定: ${event.confirmedCount}/${event.maxParticipants}人',
                            style: const TextStyle(fontSize: 14),
                          ),
                          if (event.waitlistCount > 0) ...[
                            const SizedBox(width: 16),
                            const Icon(Icons.schedule, size: 16, color: Colors.orange),
                            const SizedBox(width: 4),
                            Text(
                              '待機: ${event.waitlistCount}人',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // 参加者一覧
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildParticipantsSection(context, ref, event),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('エラーが発生しました: $error'),
        ),
      ),
    );
  }

  Widget _buildParticipantsSection(BuildContext context, WidgetRef ref, EventModel event) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '参加者 (${event.participants.length}人)',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    // ゲスト追加ボタン
                    TextButton.icon(
                      onPressed: () => _showAddGuestDialog(context, ref, event),
                      icon: const Icon(Icons.person_add_alt, size: 16),
                      label: const Text('ゲスト追加', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                    ),
                    const SizedBox(width: 4),
                    // デバッグ用：ダミー参加者追加ボタン
                    TextButton.icon(
                      onPressed: () => _addDummyParticipant(context, ref, event),
                      icon: const Icon(Icons.person_add, size: 16),
                      label: const Text('ダミー追加', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (event.participants.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    '参加者がいません',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              _buildParticipantsTable(context, ref, event),
          ],
        ),
      ),
    );
  }

  Widget _buildParticipantsTable(BuildContext context, WidgetRef ref, EventModel event) {
    // 参加者をステータス順にソート（参加確定 → キャンセル待ち）
    final sortedParticipants = List<EventParticipant>.from(event.participants)
      ..sort((a, b) {
        // 参加確定を先に、キャンセル待ちを後に
        if (a.status == ParticipationStatus.confirmed && b.status != ParticipationStatus.confirmed) {
          return -1;
        } else if (a.status != ParticipationStatus.confirmed && b.status == ParticipationStatus.confirmed) {
          return 1;
        }
        // 同じステータスの場合は登録日時順
        return a.registeredAt.compareTo(b.registeredAt);
      });

    return SizedBox(
      width: double.infinity,
      child: DataTable(
        headingRowHeight: 36,
        dataRowHeight: 48,
        columnSpacing: 16,
        horizontalMargin: 0,
        headingRowColor: MaterialStateProperty.all(Colors.blue.shade50),
        columns: [
          DataColumn(
            label: Expanded(
              child: Center(
                child: Text(
                  '名前',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Colors.blue.shade900,
                  ),
                ),
              ),
            ),
          ),
          DataColumn(
            label: Expanded(
              child: Center(
                child: Text(
                  '参加ステータス',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Colors.blue.shade900,
                  ),
                ),
              ),
            ),
          ),
          DataColumn(
            label: Expanded(
              child: Center(
                child: Text(
                  '操作',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Colors.blue.shade900,
                  ),
                ),
              ),
            ),
          ),
        ],
        rows: sortedParticipants.map((participant) {
          return DataRow(
            cells: [
              // 名前
              DataCell(
                Center(
                  child: FutureBuilder<String>(
                    future: _getUserName(ref, participant.userId),
                    builder: (context, snapshot) {
                      final isGuest = participant.userId.startsWith('guest_');
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              snapshot.data ?? participant.userId,
                              style: const TextStyle(fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isGuest) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.purple.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'ゲスト',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.purple.shade800,
                                ),
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ),
              // 参加ステータス
              DataCell(
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: participant.status ==
                              ParticipationStatus.confirmed
                          ? Colors.green.shade100
                          : Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      participant.status ==
                              ParticipationStatus.confirmed
                          ? '参加確定'
                          : 'キャンセル待ち',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: participant.status ==
                                ParticipationStatus.confirmed
                            ? Colors.green.shade800
                            : Colors.orange.shade800,
                      ),
                    ),
                  ),
                ),
              ),
              // 操作メニュー
              DataCell(
                Center(
                  child: PopupMenuButton<ParticipationStatus>(
                    icon: const Icon(Icons.more_vert, size: 20),
                    onSelected: (status) {
                      _updateParticipantStatus(
                        context,
                        ref,
                        event.eventId,
                        participant.userId,
                        status,
                      );
                    },
                    itemBuilder: (BuildContext context) => [
                      if (participant.status != ParticipationStatus.confirmed)
                        const PopupMenuItem<ParticipationStatus>(
                          value: ParticipationStatus.confirmed,
                          child: Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.green, size: 18),
                              SizedBox(width: 8),
                              Text('参加確定に変更'),
                            ],
                          ),
                        ),
                      // 定員以上の場合のみキャンセル待ちに変更を表示
                      if (participant.status != ParticipationStatus.waitlist &&
                          event.confirmedCount >= event.maxParticipants)
                        const PopupMenuItem<ParticipationStatus>(
                          value: ParticipationStatus.waitlist,
                          child: Row(
                            children: [
                              Icon(Icons.schedule, color: Colors.orange, size: 18),
                              SizedBox(width: 8),
                              Text('キャンセル待ちに変更'),
                            ],
                          ),
                        ),
                      const PopupMenuItem<ParticipationStatus>(
                        value: ParticipationStatus.cancelled,
                        child: Row(
                          children: [
                            Icon(Icons.cancel, color: Colors.red, size: 18),
                            SizedBox(width: 8),
                            Text('キャンセル（削除）', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ),
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

  // 参加者のステータスを更新
  Future<void> _updateParticipantStatus(
    BuildContext context,
    WidgetRef ref,
    String eventId,
    String userId,
    ParticipationStatus newStatus,
  ) async {
    final userName = await _getUserName(ref, userId);
    final statusText = newStatus == ParticipationStatus.confirmed
        ? '参加確定'
        : newStatus == ParticipationStatus.waitlist
            ? 'キャンセル待ち'
            : 'キャンセル';

    if (!context.mounted) return;

    // 確認ダイアログを表示
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ステータス変更'),
        content: Text('$userName を$statusText に変更しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: newStatus == ParticipationStatus.cancelled
                  ? Colors.red
                  : Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('変更'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        final updateStatus = ref.read(updateParticipantStatusProvider);
        await updateStatus(
          eventId: eventId,
          userId: userId,
          newStatus: newStatus,
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$userName のステータスを$statusText に変更しました'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('ステータス変更に失敗しました: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // デバッグ用：ダミー参加者を追加
  Future<void> _addDummyParticipant(
    BuildContext context,
    WidgetRef ref,
    EventModel event,
  ) async {
    try {
      // サークル情報を取得
      final circleService = ref.read(circleServiceProvider);
      final circle = await circleService.getCircle(event.circleId);

      if (circle == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('サークル情報が取得できませんでした'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // すでに参加しているメンバーのIDリストを取得
      final participantUserIds = event.participants.map((p) => p.userId).toSet();

      // まだ参加していないメンバーをフィルタリング
      final availableMembers = circle.members
          .where((m) => !participantUserIds.contains(m.userId))
          .toList();

      String userId;
      String userName;

      if (availableMembers.isEmpty) {
        // 利用可能なメンバーがいない場合、新しくダミーメンバーを作成
        final now = DateTime.now();
        userId = 'dummy_${now.millisecondsSinceEpoch}';
        userName = 'ダミーメンバー${circle.members.length + 1}';

        // Firestoreにダミーユーザーを作成
        await ref.read(authServiceProvider).createDummyUser(
          userId: userId,
          name: userName,
        );

        // サークルにメンバーとして追加
        await circleService.addMember(
          circleId: event.circleId,
          userId: userId,
          role: 'member',
        );
      } else {
        // 既存のメンバーから選択
        final selectedMember = availableMembers[0];
        userId = selectedMember.userId;
        userName = await _getUserName(ref, userId);
      }

      // イベントに参加
      final joinEvent = ref.read(joinEventProvider);
      await joinEvent(
        eventId: event.eventId,
        userId: userId,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$userNameを追加しました'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラーが発生しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ゲスト追加ダイアログ
  Future<void> _showAddGuestDialog(
    BuildContext context,
    WidgetRef ref,
    EventModel event,
  ) async {
    final nameController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ゲストを追加'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'サークルメンバー以外の参加者を追加できます。',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'ゲスト名',
                hintText: '例: 田中太郎',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text('ゲスト名を入力してください'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              Navigator.of(dialogContext).pop(true);
            },
            child: const Text('追加'),
          ),
        ],
      ),
    );

    if (result == true && context.mounted) {
      await _addGuestParticipant(context, ref, event, nameController.text.trim());
    }
  }

  // ゲスト参加者を追加
  Future<void> _addGuestParticipant(
    BuildContext context,
    WidgetRef ref,
    EventModel event,
    String guestName,
  ) async {
    try {
      // ゲストユーザーIDを生成
      final now = DateTime.now();
      final guestUserId = 'guest_${now.millisecondsSinceEpoch}';

      // Firestoreにゲストユーザーを作成
      await ref.read(authServiceProvider).createDummyUser(
        userId: guestUserId,
        name: guestName,
      );

      // イベントに参加
      final joinEvent = ref.read(joinEventProvider);
      await joinEvent(
        eventId: event.eventId,
        userId: guestUserId,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$guestNameを追加しました'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラーが発生しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
