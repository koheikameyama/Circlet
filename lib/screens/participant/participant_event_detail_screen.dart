import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/event_model.dart';
import '../../models/payment_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/event_provider.dart';
import '../../providers/payment_provider.dart';

class ParticipantEventDetailScreen extends ConsumerWidget {
  final String circleId;
  final String eventId;

  const ParticipantEventDetailScreen({
    super.key,
    required this.circleId,
    required this.eventId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(authStateProvider).value;
    final eventAsync = ref.watch(eventProvider(eventId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('イベント詳細'),
      ),
      body: eventAsync.when(
        data: (event) {
          if (event == null) {
            return const Center(child: Text('イベントが見つかりません'));
          }

          // Check if current user is participating
          final userParticipation = event.participants.firstWhere(
            (p) => p.userId == currentUser?.uid,
            orElse: () => EventParticipant(
              userId: '',
              status: ParticipationStatus.waitlist,
              registeredAt: DateTime.now(),
            ),
          );
          final isParticipating = userParticipation.userId.isNotEmpty;
          final canJoin = event.confirmedCount < event.maxParticipants;

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildEventHeader(event),
                const SizedBox(height: 16),

                // Join/Cancel Button
                _buildJoinButton(
                  context,
                  ref,
                  event,
                  currentUser?.uid ?? '',
                  isParticipating,
                  canJoin,
                  userParticipation,
                ),

                // Description
                if (event.description != null && event.description!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '説明',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              event.description!,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Fee and Payment Status
                if (event.fee != null && event.fee! > 0 && isParticipating)
                  _buildPaymentStatus(ref, event, currentUser?.uid ?? ''),

                const Divider(height: 32),

                // Participant List
                _buildParticipantList(ref, event),
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

  Widget _buildEventHeader(EventModel event) {
    final dateFormat = DateFormat('yyyy年MM月dd日 (E) HH:mm', 'ja');

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blue.shade400, Colors.blue.shade600],
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            event.name,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoRow(Icons.calendar_today, dateFormat.format(event.datetime)),
          if (event.location != null)
            _buildInfoRow(Icons.location_on, event.location!),
          _buildInfoRow(
            Icons.people,
            '定員: ${event.confirmedCount}/${event.maxParticipants}人',
          ),
          if (event.waitlistCount > 0)
            _buildInfoRow(
              Icons.hourglass_empty,
              '待機中: ${event.waitlistCount}人',
              color: Colors.orange.shade200,
            ),
          if (event.fee != null && event.fee! > 0)
            _buildInfoRow(
              Icons.payments,
              '参加費: ¥${event.fee}',
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color ?? Colors.white),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: color ?? Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJoinButton(
    BuildContext context,
    WidgetRef ref,
    EventModel event,
    String userId,
    bool isParticipating,
    bool canJoin,
    EventParticipant userParticipation,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          if (isParticipating) ...[
            // Show participation status
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: userParticipation.status == ParticipationStatus.confirmed
                    ? Colors.green.shade50
                    : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: userParticipation.status == ParticipationStatus.confirmed
                      ? Colors.green
                      : Colors.orange,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    userParticipation.status == ParticipationStatus.confirmed
                        ? Icons.check_circle
                        : Icons.hourglass_empty,
                    color: userParticipation.status == ParticipationStatus.confirmed
                        ? Colors.green
                        : Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    userParticipation.status == ParticipationStatus.confirmed
                        ? '参加確定しています'
                        : 'キャンセル待ちです',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: userParticipation.status == ParticipationStatus.confirmed
                          ? Colors.green.shade800
                          : Colors.orange.shade800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => _cancelParticipation(context, ref, event.eventId, userId),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
              ),
              child: const Text('参加をキャンセル'),
            ),
          ] else ...[
            // Show join button
            ElevatedButton(
              onPressed: canJoin
                  ? () => _joinEvent(context, ref, event.eventId, userId)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
              ),
              child: Text(canJoin ? '参加する' : '定員に達しています'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentStatus(WidgetRef ref, EventModel event, String userId) {
    final paymentsAsync = ref.watch(eventPaymentsProvider(event.eventId));

    return paymentsAsync.when(
      data: (payments) {
        final userPayment = payments.firstWhere(
          (p) => p.userId == userId,
          orElse: () => PaymentModel(
            paymentId: '',
            userId: userId,
            eventId: event.eventId,
            circleId: circleId,
            amount: event.fee ?? 0,
            method: PaymentMethod.paypay,
            status: PaymentStatus.pending,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: userPayment.isPaid ? Colors.green.shade50 : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: userPayment.isPaid ? Colors.green : Colors.orange,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      userPayment.isPaid ? Icons.check_circle : Icons.payment,
                      color: userPayment.isPaid ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '参加費: ¥${event.fee}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  userPayment.isPaid ? '支払い済み' : '未払い',
                  style: TextStyle(
                    fontSize: 14,
                    color: userPayment.isPaid
                        ? Colors.green.shade800
                        : Colors.orange.shade800,
                  ),
                ),
                if (!userPayment.isPaid) ...[
                  const SizedBox(height: 8),
                  const Text(
                    '管理者に支払いを確認してもらってください',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ],
            ),
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text('エラー: $error'),
      ),
    );
  }

  Widget _buildParticipantList(WidgetRef ref, EventModel event) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '参加者一覧 (${event.participants.length}人)',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          if (event.participants.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('まだ参加者がいません'),
              ),
            )
          else
            ...event.participants.map((participant) {
              return FutureBuilder(
                future: _getUserName(ref, participant.userId),
                builder: (context, snapshot) {
                  final userName = snapshot.data ?? '読み込み中...';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      leading: const CircleAvatar(
                        radius: 18,
                        child: Icon(Icons.person, size: 18),
                      ),
                      title: Text(
                        userName,
                        style: const TextStyle(fontSize: 14),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: participant.status == ParticipationStatus.confirmed
                              ? Colors.green.shade100
                              : Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          participant.status == ParticipationStatus.confirmed ? '確定' : '待ち',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: participant.status == ParticipationStatus.confirmed
                                ? Colors.green.shade800
                                : Colors.orange.shade800,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            }).toList(),
        ],
      ),
    );
  }

  Future<String> _getUserName(WidgetRef ref, String userId) async {
    try {
      final authService = ref.read(authServiceProvider);
      final user = await authService.getUserData(userId);
      return user?.name ?? 'ユーザー';
    } catch (e) {
      return 'ユーザー';
    }
  }

  Future<void> _joinEvent(
    BuildContext context,
    WidgetRef ref,
    String eventId,
    String userId,
  ) async {
    try {
      final joinEvent = ref.read(joinEventProvider);
      await joinEvent(eventId: eventId, userId: userId);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('イベントに参加しました'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('参加に失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _cancelParticipation(
    BuildContext context,
    WidgetRef ref,
    String eventId,
    String userId,
  ) async {
    try {
      final cancelEvent = ref.read(cancelEventProvider);
      await cancelEvent(eventId: eventId, userId: userId);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('参加をキャンセルしました'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('キャンセルに失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
