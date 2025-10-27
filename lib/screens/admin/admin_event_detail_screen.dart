import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';
import '../../models/event_model.dart';
import '../../providers/event_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/payment_provider.dart';
import '../../providers/cancellation_request_provider.dart';
import '../../config/api_keys.dart';
import 'admin_event_participants_screen.dart';
import 'admin_event_payments_screen.dart';
import 'admin_event_edit_screen.dart';

class AdminEventDetailScreen extends ConsumerWidget {
  final String circleId;
  final String eventId;

  const AdminEventDetailScreen({
    super.key,
    required this.circleId,
    required this.eventId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventAsync = ref.watch(eventProvider(eventId));
    final currentUser = ref.watch(authStateProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('イベント詳細'),
        actions: [
          // 編集ボタン
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              if (eventAsync.value != null) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => AdminEventEditScreen(
                      event: eventAsync.value!,
                    ),
                  ),
                );
              }
            },
          ),
          // 削除ボタン
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _showDeleteDialog(context, ref),
          ),
        ],
      ),
      body: eventAsync.when(
        data: (event) {
          if (event == null) {
            return const Center(child: Text('イベントが見つかりません'));
          }

          final dateFormat = DateFormat('yyyy年MM月dd日 (E) HH:mm', 'ja');
          final isParticipating = currentUser != null &&
              event.participants.any((p) =>
                  p.userId == currentUser.uid &&
                  p.status != ParticipationStatus.cancelled);

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // イベントヘッダー
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade400, Colors.blue.shade600],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
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
                      Row(
                        children: [
                          const Icon(Icons.event, color: Colors.white70, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _formatEventDateTime(event.datetime, event.endDatetime),
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (event.location != null) ...[
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () => _openGoogleMaps(event.location!),
                          child: Row(
                            children: [
                              const Icon(Icons.location_on, color: Colors.white70, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  event.location!,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.white70,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.open_in_new, color: Colors.white70, size: 14),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.people, color: Colors.white70, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            '定員: ${event.confirmedCount}/${event.maxParticipants}人',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                      if (event.waitlistCount > 0) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.hourglass_empty, color: Colors.orange.shade200, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              '待機中: ${event.waitlistCount}人',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.orange.shade200,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (event.fee != null && event.fee!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.payments, color: Colors.white70, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                event.isFeeNumeric ? '参加費: ¥${event.fee}' : '参加費: ${event.fee}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // 参加状況カード
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '参加状況',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatusItem(
                                  '参加確定',
                                  '${event.confirmedCount}/${event.maxParticipants}人',
                                  Colors.green,
                                  Icons.check_circle,
                                ),
                              ),
                              if (event.waitlistCount > 0)
                                Expanded(
                                  child: _buildStatusItem(
                                    'キャンセル待ち',
                                    '${event.waitlistCount}人',
                                    Colors.orange,
                                    Icons.schedule,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // 参加ボタン
                if (currentUser != null) ...[
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: isParticipating
                          ? OutlinedButton.icon(
                              onPressed: () => _cancelEvent(context, ref, event.eventId, currentUser.uid),
                              icon: const Icon(Icons.cancel),
                              label: const Text('参加をキャンセル'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.orange,
                                side: const BorderSide(color: Colors.orange, width: 2),
                              ),
                            )
                          : ElevatedButton.icon(
                              onPressed: () => _joinEvent(context, ref, event.eventId, currentUser.uid),
                              icon: const Icon(Icons.check_circle),
                              label: const Text('参加する'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                textStyle: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                    ),
                  ),
                ],

                // 参加者一覧と支払い状況
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildParticipantsSection(context, ref, event),
                ),

                // 支払い管理（参加費が設定されている場合表示）
                if (event.fee != null && event.fee!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: _buildPaymentManagementSection(context, ref, event),
                  ),

                const SizedBox(height: 16),
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

  Widget _buildStatusItem(String label, String value, Color color, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
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

  Future<String> _getUserName(WidgetRef ref, String userId) async {
    try {
      final authService = ref.read(authServiceProvider);
      final user = await authService.getUserData(userId);
      return user?.name ?? userId;
    } catch (e) {
      return userId;
    }
  }

  Future<void> _joinEvent(BuildContext context, WidgetRef ref, String eventId, String userId) async {
    try {
      final joinEvent = ref.read(joinEventProvider);
      await joinEvent(
        eventId: eventId,
        userId: userId,
      );
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

  Future<void> _cancelEvent(BuildContext context, WidgetRef ref, String eventId, String userId) async {
    try {
      final cancelEvent = ref.read(cancelEventProvider);
      await cancelEvent(
        eventId: eventId,
        userId: userId,
      );
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

  Future<void> _showDeleteDialog(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('イベント削除'),
        content: const Text('このイベントを削除しますか？\n参加者への通知は行われません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        final deleteEvent = ref.read(deleteEventProvider);
        await deleteEvent(eventId);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('イベントを削除しました'),
              backgroundColor: Colors.green,
            ),
          );
          context.pop(); // 詳細画面を閉じる
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('削除に失敗しました: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // 支払い管理サマリーセクション
  Widget _buildPaymentManagementSection(BuildContext context, WidgetRef ref, EventModel event) {
    final paymentsAsync = ref.watch(eventPaymentsProvider(event.eventId));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '支払い管理',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            paymentsAsync.when(
              data: (payments) {
                final paidCount = payments.where((p) => p.isPaid).length;
                final totalCount = event.confirmedCount;
                final totalAmount = (event.feeAsInt ?? 0) * totalCount;
                final paidAmount = payments.where((p) => p.isPaid).fold<int>(
                  0,
                  (sum, payment) => sum + payment.amount,
                );

                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildPaymentStatusCard(
                            context,
                            '支払い済み',
                            '$paidCount/$totalCount人',
                            Colors.green,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildPaymentStatusCard(
                            context,
                            '未払い',
                            '${totalCount - paidCount}人',
                            Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    if (event.isFeeNumeric) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
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
                              '¥$paidAmount / ¥$totalAmount',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => AdminEventPaymentsScreen(
                                circleId: circleId,
                                eventId: eventId,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.payment),
                        label: const Text('支払状況を見る'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
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

  Widget _buildPaymentStatusCard(BuildContext context, String label, String value, Color color) {
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

  // 参加者一覧セクション（簡略版）
  Widget _buildParticipantsSection(BuildContext context, WidgetRef ref, EventModel event) {
    return Card(
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
            Consumer(
              builder: (context, ref, child) {
                final requestsAsync = ref.watch(eventCancellationRequestsProvider(event.eventId));
                final pendingRequestCount = requestsAsync.when(
                  data: (requests) => requests.where((r) => r.isPending).length,
                  loading: () => 0,
                  error: (_, __) => 0,
                );

                return Column(
                  children: [
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
                    if (pendingRequestCount > 0) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.pending_actions, size: 16, color: Colors.red),
                          const SizedBox(width: 4),
                          Text(
                            'キャンセル申請: $pendingRequestCount人',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => AdminEventParticipantsScreen(
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

}
