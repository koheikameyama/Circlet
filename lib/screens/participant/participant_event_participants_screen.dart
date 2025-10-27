import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/event_model.dart';
import '../../providers/event_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/circle_provider.dart';

class ParticipantEventParticipantsScreen extends ConsumerWidget {
  final String circleId;
  final String eventId;

  const ParticipantEventParticipantsScreen({
    super.key,
    required this.circleId,
    required this.eventId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventAsync = ref.watch(eventProvider(eventId));
    final circleAsync = ref.watch(circleProvider(circleId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('参加者一覧'),
      ),
      body: circleAsync.when(
        data: (circle) {
          return eventAsync.when(
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
                  child: _buildParticipantList(context, ref, event, circle),
                ),
              ],
            ),
          );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
              child: Text('エラーが発生しました: $error'),
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

  Widget _buildParticipantList(BuildContext context, WidgetRef ref, EventModel event, dynamic circle) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '参加者 (${event.participants.length}人)',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (event.participants.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    '参加者がいません',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              Builder(
                builder: (context) {
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

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: sortedParticipants.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      final participant = sortedParticipants[index];
                      return _buildParticipantItem(ref, participant, circle);
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildParticipantItem(WidgetRef ref, EventParticipant participant, dynamic circle) {
    return FutureBuilder<String>(
      future: _getUserName(ref, participant.userId, circle),
      builder: (context, snapshot) {
        final name = snapshot.data ?? participant.userId;
        final isGuest = participant.userId.startsWith('guest_');

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 4),
          leading: CircleAvatar(
            backgroundColor: participant.status == ParticipationStatus.confirmed
                ? Colors.green.shade100
                : Colors.orange.shade100,
            child: Icon(
              participant.status == ParticipationStatus.confirmed
                  ? Icons.check_circle
                  : Icons.schedule,
              color: participant.status == ParticipationStatus.confirmed
                  ? Colors.green
                  : Colors.orange,
            ),
          ),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isGuest) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: participant.status == ParticipationStatus.confirmed
                  ? Colors.green.shade100
                  : Colors.orange.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              participant.status == ParticipationStatus.confirmed
                  ? '参加確定'
                  : 'キャンセル待ち',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: participant.status == ParticipationStatus.confirmed
                    ? Colors.green.shade800
                    : Colors.orange.shade800,
              ),
            ),
          ),
        );
      },
    );
  }

  Future<String> _getUserName(WidgetRef ref, String userId, dynamic circle) async {
    try {
      print('[DEBUG PARTICIPANT] _getUserName called for userId: $userId');
      print('[DEBUG PARTICIPANT] circle is null: ${circle == null}');

      // サークルメンバーからdisplayNameを取得
      if (circle != null) {
        print('[DEBUG PARTICIPANT] circle.members count: ${circle.members.length}');
        final members = circle.members.where((m) => m.userId == userId);
        final member = members.isEmpty ? null : members.first;
        print('[DEBUG PARTICIPANT] member found: ${member != null}');
        if (member != null) {
          print('[DEBUG PARTICIPANT] member.displayName: ${member.displayName}');
        }
        if (member?.displayName != null) {
          print('[DEBUG PARTICIPANT] Returning circle displayName: ${member!.displayName}');
          return member!.displayName!;
        }
      }

      // displayNameがない場合はグローバル名を取得
      print('[DEBUG PARTICIPANT] Fetching global user data...');
      final authService = ref.read(authServiceProvider);
      final user = await authService.getUserData(userId);
      print('[DEBUG PARTICIPANT] user found: ${user != null}');
      print('[DEBUG PARTICIPANT] user?.name: ${user?.name}');
      final result = user?.name ?? userId;
      print('[DEBUG PARTICIPANT] Returning: $result');
      return result;
    } catch (e) {
      print('[DEBUG PARTICIPANT] Error in _getUserName: $e');
      return userId;
    }
  }
}
