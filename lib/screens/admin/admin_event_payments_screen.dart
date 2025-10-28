import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/event_model.dart';
import '../../models/payment_model.dart';
import '../../providers/event_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/payment_provider.dart';
import '../../providers/circle_provider.dart';

class AdminEventPaymentsScreen extends ConsumerWidget {
  final String circleId;
  final String eventId;

  const AdminEventPaymentsScreen({
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
        title: const Text('支払い管理'),
      ),
      body: circleAsync.when(
        data: (circle) {
          return eventAsync.when(
            data: (event) {
              if (event == null) {
                return const Center(child: Text('イベントが見つかりません'));
              }

              if (event.fee == null || event.fee!.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    '参加費が設定されていません',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            );
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
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          event.isFeeNumeric ? '参加費: ¥${event.fee}' : '参加費: ${event.fee}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 支払い管理セクション
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildPaymentsSection(context, ref, event, circle),
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

  Widget _buildPaymentsSection(BuildContext context, WidgetRef ref, EventModel event, dynamic circle) {
    final paymentsAsync = ref.watch(eventPaymentsProvider(event.eventId));
    final confirmedParticipants = event.participants
        .where((p) => p.status == ParticipationStatus.confirmed)
        .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '支払い状況',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (confirmedParticipants.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    '参加予定者がいません',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              paymentsAsync.when(
                data: (payments) {
                  final paidCount = payments.where((p) => p.isPaid).length;
                  final totalAmount = paidCount * (event.feeAsInt ?? 0);

                  return Column(
                    children: [
                      // サマリー
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '支払い済み',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$paidCount/${confirmedParticipants.length}人',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade800,
                                  ),
                                ),
                              ],
                            ),
                            if (event.isFeeNumeric)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '合計金額',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '¥$totalAmount',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green.shade800,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 参加者リスト
                      const Divider(),
                      const SizedBox(height: 8),
                      const Text(
                        '参加者',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...confirmedParticipants.map((participant) {
                        final payment = payments.firstWhere(
                          (p) => p.userId == participant.userId,
                          orElse: () => PaymentModel(
                            paymentId: '',
                            userId: participant.userId,
                            eventId: event.eventId,
                            circleId: circleId,
                            amount: 0,
                            status: PaymentStatus.pending,
                            method: PaymentMethod.cash,
                            createdAt: DateTime.now(),
                            updatedAt: DateTime.now(),
                          ),
                        );

                        return _PaymentParticipantRow(
                          participant: participant,
                          payment: payment,
                          event: event,
                          circle: circle,
                        );
                      }),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Text('エラー: $error'),
              ),
          ],
        ),
      ),
    );
  }
}

// 参加者ごとの支払い行
class _PaymentParticipantRow extends ConsumerWidget {
  final EventParticipant participant;
  final PaymentModel payment;
  final EventModel event;
  final dynamic circle;

  const _PaymentParticipantRow({
    required this.participant,
    required this.payment,
    required this.event,
    required this.circle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<String>(
      future: _getUserName(ref, participant.userId, circle),
      builder: (context, nameSnapshot) {
        final userName = nameSnapshot.data ?? participant.userId;

        return FutureBuilder<String?>(
          future: _getUserProfileImageUrl(ref, participant.userId, circle),
          builder: (context, imageSnapshot) {
            final profileImageUrl = imageSnapshot.data;

            return InkWell(
          onTap: () {
            if (!payment.isPaid) {
              _markAsPaidOrCreate(
                context,
                ref,
                payment.paymentId,
                participant.userId,
                event,
              );
            } else {
              _markAsUnpaid(
                context,
                ref,
                payment.paymentId,
              );
            }
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: payment.isPaid ? Colors.green.shade50 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: payment.isPaid ? Colors.green.shade200 : Colors.grey.shade300,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Checkbox(
                  value: payment.isPaid,
                  activeColor: Colors.green,
                  onChanged: (value) {
                    if (value == true) {
                      _markAsPaidOrCreate(
                        context,
                        ref,
                        payment.paymentId,
                        participant.userId,
                        event,
                      );
                    } else {
                      _markAsUnpaid(
                        context,
                        ref,
                        payment.paymentId,
                      );
                    }
                  },
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.grey,
                  backgroundImage: profileImageUrl != null && profileImageUrl.isNotEmpty
                      ? CachedNetworkImageProvider(profileImageUrl)
                      : null,
                  child: profileImageUrl == null || profileImageUrl.isEmpty
                      ? const Icon(
                          Icons.person,
                          size: 16,
                          color: Colors.white,
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          userName,
                          style: const TextStyle(fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (participant.userId.startsWith('guest_')) ...[
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
                ),
                if (payment.isPaid)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '支払済',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                      ),
                    ),
                  ),
              ],
            ),
          ),
            );
          },
        );
      },
    );
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
      return user?.name ?? userId;
    } catch (e) {
      return userId;
    }
  }

  Future<String?> _getUserProfileImageUrl(WidgetRef ref, String userId, dynamic circle) async {
    try {
      // サークル用のプロフィール画像をチェック
      if (circle != null) {
        final members = circle.members.where((m) => m.userId == userId);
        final member = members.isEmpty ? null : members.first;
        if (member?.profileImageUrl != null) {
          return member!.profileImageUrl;
        }
      }

      // なければグローバルなプロフィール画像を取得
      final authService = ref.read(authServiceProvider);
      final user = await authService.getUserData(userId);
      return user?.profileImageUrl;
    } catch (e) {
      return null;
    }
  }

  // 支払い済みにする（レコードがなければ作成）
  Future<void> _markAsPaidOrCreate(
    BuildContext context,
    WidgetRef ref,
    String paymentId,
    String userId,
    EventModel event,
  ) async {
    try {
      if (paymentId.isEmpty) {
        // 支払いレコードが存在しない場合、新規作成
        final createPayment = ref.read(createPaymentProvider);
        final newPaymentId = await createPayment(
          userId: userId,
          eventId: event.eventId,
          circleId: event.circleId,
          amount: event.feeAsInt ?? 0,
          method: PaymentMethod.cash, // デフォルトは現金
        );

        // 作成したレコードを即座に支払い済みにする
        final updateStatus = ref.read(updatePaymentStatusProvider);
        await updateStatus(
          paymentId: newPaymentId,
          status: PaymentStatus.completed,
        );
      } else {
        // 既存のレコードを更新
        final updateStatus = ref.read(updatePaymentStatusProvider);
        await updateStatus(
          paymentId: paymentId,
          status: PaymentStatus.completed,
        );
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('支払い済みにしました'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
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

  // 未払いに戻す
  Future<void> _markAsUnpaid(
    BuildContext context,
    WidgetRef ref,
    String paymentId,
  ) async {
    try {
      if (paymentId.isEmpty) {
        // 支払いレコードが存在しない場合は何もしない
        return;
      }

      final updateStatus = ref.read(updatePaymentStatusProvider);
      await updateStatus(
        paymentId: paymentId,
        status: PaymentStatus.pending,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('支払いを取り消しました'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 1),
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
