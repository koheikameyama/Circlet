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
import '../../config/api_keys.dart';
import 'admin_event_participants_screen.dart';
import 'admin_event_payments_screen.dart';

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
                _showEditEventDialog(context, ref, eventAsync.value!);
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
                      if (event.fee != null && event.fee! > 0) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.payments, color: Colors.white70, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              '参加費: ¥${event.fee}',
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.white70,
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
                          if (event.fee != null && event.fee! > 0) ...[
                            const Divider(height: 24),
                            Row(
                              children: [
                                const Icon(Icons.payments, color: Colors.green),
                                const SizedBox(width: 8),
                                const Text('参加費: ', style: TextStyle(fontSize: 16)),
                                Text(
                                  '¥${event.fee}',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ],
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

                // 支払い管理（参加費がある場合のみ表示）
                if (event.fee != null && event.fee! > 0)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: _buildPaymentManagementSection(context, ref, event),
                  ),

                // 参加者一覧と支払い状況
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildParticipantsSection(context, ref, event),
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
    final timeFormat = DateFormat('HH:mm', 'ja');

    if (endDateTime == null) {
      return dateFormat.format(startDateTime);
    }

    // 同じ日付かチェック
    final isSameDay = startDateTime.year == endDateTime.year &&
                      startDateTime.month == endDateTime.month &&
                      startDateTime.day == endDateTime.day;

    if (isSameDay) {
      // 同じ日の場合: "2025/10/22 (月) 14:00 ~ 16:00"
      return '${dateFormat.format(startDateTime)} ~ ${timeFormat.format(endDateTime)}';
    } else {
      // 異なる日の場合: "2025/10/22 (月) 14:00 ~ 2025/10/23 (火) 16:00"
      return '${dateFormat.format(startDateTime)} ~ ${dateFormat.format(endDateTime)}';
    }
  }

  Future<void> _openGoogleMaps(String location) async {
    final encodedLocation = Uri.encodeComponent(location);
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$encodedLocation');

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
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

  void _showEditEventDialog(BuildContext context, WidgetRef ref, EventModel event) {
    final nameController = TextEditingController(text: event.name);
    final descriptionController = TextEditingController(text: event.description ?? '');
    final locationController = TextEditingController(text: event.location ?? '');
    final maxParticipantsController = TextEditingController(text: event.maxParticipants.toString());
    final feeController = TextEditingController(text: (event.fee ?? 0).toString());
    DateTime? selectedDateTime = event.datetime;
    DateTime? selectedEndDateTime = event.endDatetime;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('イベント編集'),
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
                  // 開始日時選択
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      selectedDateTime == null
                          ? '開始日時を選択'
                          : DateFormat('yyyy/MM/dd (E) HH:mm', 'ja')
                              .format(selectedDateTime!),
                      style: TextStyle(
                        color: selectedDateTime == null ? Colors.grey : null,
                      ),
                    ),
                    leading: const Icon(Icons.event),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: selectedDateTime ?? DateTime.now(),
                        firstDate: DateTime.now().subtract(const Duration(days: 365)),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null && context.mounted) {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: selectedDateTime != null
                              ? TimeOfDay.fromDateTime(selectedDateTime!)
                              : TimeOfDay.now(),
                        );
                        if (time != null) {
                          setState(() {
                            selectedDateTime = DateTime(
                              date.year,
                              date.month,
                              date.day,
                              time.hour,
                              time.minute,
                            );
                          });
                        }
                      }
                    },
                  ),
                  // 終了日時選択
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      selectedEndDateTime == null
                          ? '終了日時を選択（任意）'
                          : DateFormat('yyyy/MM/dd (E) HH:mm', 'ja')
                              .format(selectedEndDateTime!),
                      style: TextStyle(
                        color: selectedEndDateTime == null ? Colors.grey : null,
                      ),
                    ),
                    leading: const Icon(Icons.event_available),
                    trailing: selectedEndDateTime != null
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () {
                              setState(() {
                                selectedEndDateTime = null;
                              });
                            },
                          )
                        : null,
                    onTap: () async {
                      if (selectedDateTime == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('先に開始日時を選択してください')),
                        );
                        return;
                      }

                      final date = await showDatePicker(
                        context: context,
                        initialDate: selectedDateTime!,
                        firstDate: selectedDateTime!,
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null && context.mounted) {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(selectedDateTime!),
                        );
                        if (time != null) {
                          setState(() {
                            selectedEndDateTime = DateTime(
                              date.year,
                              date.month,
                              date.day,
                              time.hour,
                              time.minute,
                            );
                          });
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  GooglePlaceAutoCompleteTextField(
                    textEditingController: locationController,
                    googleAPIKey: ApiKeys.googlePlacesApiKey,
                    inputDecoration: const InputDecoration(
                      labelText: '場所',
                      border: OutlineInputBorder(),
                      hintText: '場所を入力',
                    ),
                    debounceTime: 300,
                    countries: const ["jp"],
                    isLatLngRequired: false,
                    getPlaceDetailWithLatLng: (Prediction prediction) {
                      locationController.text = prediction.structuredFormatting?.mainText ?? prediction.description ?? '';
                    },
                    itemClick: (Prediction prediction) {
                      locationController.text = prediction.structuredFormatting?.mainText ?? prediction.description ?? '';
                    },
                    seperatedBuilder: const Divider(),
                    itemBuilder: (context, index, Prediction prediction) {
                      return Container(
                        padding: const EdgeInsets.all(10),
                        child: Row(
                          children: [
                            const Icon(Icons.location_on, color: Colors.grey),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    prediction.structuredFormatting?.mainText ?? prediction.description ?? "",
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (prediction.structuredFormatting?.secondaryText != null)
                                    Text(
                                      prediction.structuredFormatting!.secondaryText!,
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            )
                          ],
                        ),
                      );
                    },
                    isCrossBtnShown: true,
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
                onPressed: () => Navigator.pop(dialogContext),
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
                  if (selectedDateTime == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('開始日時を選択してください')),
                    );
                    return;
                  }
                  if (selectedEndDateTime != null &&
                      (selectedEndDateTime!.isBefore(selectedDateTime!) ||
                       selectedEndDateTime!.isAtSameMomentAs(selectedDateTime!))) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('終了日時は開始日時より後にしてください')),
                    );
                    return;
                  }

                  Navigator.pop(dialogContext);

                  try {
                    final updateEvent = ref.read(updateEventProvider);
                    await updateEvent(
                      eventId: event.eventId,
                      name: nameController.text,
                      description: descriptionController.text.isEmpty
                          ? null
                          : descriptionController.text,
                      datetime: selectedDateTime!,
                      endDatetime: selectedEndDateTime,
                      location: locationController.text.isEmpty
                          ? null
                          : locationController.text,
                      maxParticipants: int.parse(maxParticipantsController.text),
                      fee: int.parse(feeController.text),
                    );

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('「${nameController.text}」を更新しました'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('イベントの更新に失敗しました: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: const Text('保存'),
              ),
            ],
          );
        },
      ),
    );
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
            Row(
              children: [
                const Icon(Icons.payment, color: Colors.green),
                const SizedBox(width: 8),
                const Text(
                  '支払い管理',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            paymentsAsync.when(
              data: (payments) {
                final paidCount = payments.where((p) => p.isPaid).length;
                final totalCount = event.confirmedCount;
                final totalAmount = (event.fee ?? 0) * totalCount;
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
                            '支払い済み',
                            '$paidCount/$totalCount人',
                            Colors.green,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildPaymentStatusCard(
                            '未払い',
                            '${totalCount - paidCount}人',
                            Colors.orange,
                          ),
                        ),
                      ],
                    ),
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

  Widget _buildPaymentStatusCard(String label, String value, Color color) {
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
            Row(
              children: [
                Expanded(
                  child: _buildParticipantSummary(
                    '参加確定',
                    '${event.confirmedCount}人',
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildParticipantSummary(
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

  Widget _buildParticipantSummary(String label, String value, Color color) {
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
