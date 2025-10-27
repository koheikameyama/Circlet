import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/event_model.dart';
import '../../models/payment_model.dart';
import '../../models/cancellation_request_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/event_provider.dart';
import '../../providers/payment_provider.dart';
import '../../providers/circle_provider.dart';
import '../../providers/cancellation_request_provider.dart';
import 'participant_event_participants_screen.dart';

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
    final circleAsync = ref.watch(circleProvider(circleId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('イベント詳細'),
      ),
      body: circleAsync.when(
        data: (circle) {
          return eventAsync.when(
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
          final hasCapacity = event.confirmedCount < event.maxParticipants;
          final canJoin = event.isPublished && hasCapacity;

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
                  hasCapacity,
                  userParticipation,
                ),

                // Fee and Payment Status（参加費が設定されている場合）
                if (event.fee != null && event.fee!.isNotEmpty && isParticipating)
                  _buildPaymentStatus(ref, event, currentUser?.uid ?? ''),

                const Divider(height: 32),

                // Participant List
                _buildParticipantList(context, ref, event),
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
          if (event.description != null && event.description!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              event.description!,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white70,
              ),
            ),
          ],
          const SizedBox(height: 16),
          _buildInfoRow(Icons.event, _formatEventDateTime(event.datetime, event.endDatetime)),
          if (event.location != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: InkWell(
                onTap: () => _openGoogleMaps(event.location!),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, size: 18, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        event.location!,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    const Icon(Icons.open_in_new, size: 14, color: Colors.white),
                  ],
                ),
              ),
            ),
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
          if (event.fee != null && event.fee!.isNotEmpty)
            _buildInfoRow(
              Icons.payments,
              event.isFeeNumeric ? '参加費: ¥${event.fee}' : '参加費: ${event.fee}',
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
    bool hasCapacity,
    EventParticipant userParticipation,
  ) {
    String getButtonText() {
      if (!event.isPublished) {
        return 'まだ公開されていません';
      } else if (!hasCapacity) {
        return '定員に達しています';
      } else {
        return '参加する';
      }
    }

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
            // キャンセルボタンまたは申請ボタン
            if (event.canCancel)
              // キャンセル期限内：通常のキャンセルボタン
              ElevatedButton(
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('参加をキャンセル'),
                      content: const Text('参加をキャンセルしますか？'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          child: const Text('いいえ'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(dialogContext, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          child: const Text('キャンセル'),
                        ),
                      ],
                    ),
                  );

                  if (confirmed == true && context.mounted) {
                    await _cancelParticipation(context, ref, event.eventId, userId);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: const Text('参加をキャンセル'),
              )
            else
              // キャンセル期限過ぎ：申請ボタンまたは申請状況表示
              Consumer(
                builder: (context, ref, child) {
                  final requestAsync = ref.watch(
                    userPendingRequestProvider((
                      eventId: event.eventId,
                      userId: userId,
                    )),
                  );

                  return requestAsync.when(
                    data: (request) {
                      if (request != null) {
                        // 申請済み
                        return Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.orange),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.hourglass_empty, color: Colors.orange),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      'キャンセル申請中',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '理由: ${request.reason}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        );
                      } else {
                        // 未申請：申請ボタン表示
                        return Column(
                          children: [
                            ElevatedButton(
                              onPressed: () => _showCancellationRequestDialog(context, ref, event.eventId, userId),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(double.infinity, 48),
                              ),
                              child: const Text('キャンセルを申請'),
                            ),
                            const SizedBox(height: 8),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                'キャンセル期限を過ぎています。管理者に申請してください',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        );
                      }
                    },
                    loading: () => const CircularProgressIndicator(),
                    error: (_, __) => ElevatedButton(
                      onPressed: () => _showCancellationRequestDialog(context, ref, event.eventId, userId),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                      ),
                      child: const Text('キャンセルを申請'),
                    ),
                  );
                },
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
              child: Text(getButtonText()),
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
            amount: event.feeAsInt ?? 0,
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
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: userPayment.isPaid ? Colors.green : Colors.orange,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        userPayment.isPaid ? '済' : '未',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        event.isFeeNumeric ? '参加費: ¥${event.fee}' : '参加費: ${event.fee}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
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

  Widget _buildParticipantList(BuildContext context, WidgetRef ref, EventModel event) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '参加者',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${event.participants.length}人',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildParticipantSummary(
                      context,
                      '参加確定',
                      '${event.confirmedCount}人',
                      Colors.green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildParticipantSummary(
                      context,
                      'キャンセル待ち',
                      '${event.waitlistCount}人',
                      Colors.orange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => ParticipantEventParticipantsScreen(
                          circleId: circleId,
                          eventId: eventId,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.people),
                  label: const Text('参加者一覧を見る'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildParticipantSummary(BuildContext context, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _formatEventDateTime(DateTime startDateTime, DateTime? endDateTime) {
    final dateFormat = DateFormat('yyyy/MM/dd (E) HH:mm', 'ja');
    final dateOnlyFormat = DateFormat('yyyy/MM/dd (E)', 'ja');
    final timeFormat = DateFormat('HH:mm', 'ja');

    // 時刻が00:00かチェック
    final startHasTime = startDateTime.hour != 0 || startDateTime.minute != 0;
    final endHasTime = endDateTime != null && (endDateTime.hour != 0 || endDateTime.minute != 0);

    if (endDateTime == null) {
      return startHasTime ? dateFormat.format(startDateTime) : dateOnlyFormat.format(startDateTime);
    }

    // 同じ日付かチェック
    final isSameDay = startDateTime.year == endDateTime.year &&
                      startDateTime.month == endDateTime.month &&
                      startDateTime.day == endDateTime.day;

    if (!startHasTime && !endHasTime) {
      // 両方時刻なし
      if (isSameDay) {
        return dateOnlyFormat.format(startDateTime);
      } else {
        return '${dateOnlyFormat.format(startDateTime)} ~ ${dateOnlyFormat.format(endDateTime)}';
      }
    } else if (isSameDay) {
      // 同じ日の場合: "2025/10/22 (月) 14:00 ~ 16:00"
      return '${dateFormat.format(startDateTime)} ~ ${timeFormat.format(endDateTime)}';
    } else {
      // 異なる日の場合: "2025/10/22 (月) 14:00 ~ 2025/10/23 (火) 16:00"
      return '${dateFormat.format(startDateTime)} ~ ${dateFormat.format(endDateTime)}';
    }
  }

  Future<void> _openGoogleMaps(String location) async {
    final encodedLocation = Uri.encodeComponent(location);

    // 1. Google Mapsアプリを試す
    final googleMapsAppUrl = Uri.parse('comgooglemaps://?q=$encodedLocation');
    try {
      if (await canLaunchUrl(googleMapsAppUrl)) {
        await launchUrl(googleMapsAppUrl, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (e) {
      // Google Mapsアプリがない場合、次の処理に進む
    }

    // 2. ブラウザでGoogle Mapsを開く
    final webUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$encodedLocation');
    try {
      if (await canLaunchUrl(webUrl)) {
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      // エラーは無視
    }
  }

  Future<String> _getUserName(WidgetRef ref, String userId, dynamic circle) async {
    try {
      // サークルメンバーからdisplayNameを取得
      if (circle != null) {
        final members = circle.members.where((m) => m.userId == userId);
        final member = members.isEmpty ? null : members.first;
        if (member?.displayName != null) {
          return member!.displayName!;
        }
      }

      // displayNameがない場合はグローバル名を取得
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

  Future<void> _showCancellationRequestDialog(
    BuildContext context,
    WidgetRef ref,
    String eventId,
    String userId,
  ) async {
    final reasonController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('キャンセル申請'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'キャンセル理由を入力してください',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  hintText: '理由を記入',
                  border: OutlineInputBorder(),
                ),
                maxLines: 5,
                autofocus: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('理由を入力してください')),
                );
                return;
              }
              Navigator.pop(dialogContext, true);
            },
            child: const Text('申請'),
          ),
        ],
      ),
    );

    if (result == true && context.mounted) {
      try {
        final createRequest = ref.read(createCancellationRequestProvider);
        await createRequest(
          eventId: eventId,
          userId: userId,
          reason: reasonController.text.trim(),
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('キャンセル申請を送信しました'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('申請の送信に失敗しました: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }

    reasonController.dispose();
  }
}
