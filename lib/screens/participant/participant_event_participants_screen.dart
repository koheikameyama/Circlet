import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/event_model.dart';
import '../../providers/event_provider.dart';
import '../../providers/auth_provider.dart';

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
                  child: _buildParticipantList(context, ref, event),
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

  Widget _buildParticipantList(BuildContext context, WidgetRef ref, EventModel event) {
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
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: event.participants.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final participant = event.participants[index];
                  return _buildParticipantItem(ref, participant);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildParticipantItem(WidgetRef ref, EventParticipant participant) {
    return FutureBuilder<String>(
      future: _getUserName(ref, participant.userId),
      builder: (context, snapshot) {
        final name = snapshot.data ?? participant.userId;

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
          title: Text(
            name,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
            ),
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

  Future<String> _getUserName(WidgetRef ref, String userId) async {
    try {
      final authService = ref.read(authServiceProvider);
      final user = await authService.getUserData(userId);
      return user?.name ?? userId;
    } catch (e) {
      return userId;
    }
  }
}
