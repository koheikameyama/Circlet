import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';
import '../../models/event_model.dart';
import '../../models/payment_model.dart';
import '../../providers/event_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/payment_provider.dart';
import '../../providers/circle_provider.dart';
import '../../config/api_keys.dart';

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

                // 支払い管理
                if (event.fee != null && event.fee! > 0) ...[
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: _buildPaymentManagementSection(ref, event),
                  ),
                ],

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
                    debounceTime: 600,
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

  // 支払い管理セクション
  Widget _buildPaymentManagementSection(WidgetRef ref, EventModel event) {
    final paymentsAsync = ref.watch(eventPaymentsProvider(event.eventId));

    return paymentsAsync.when(
      data: (payments) {
        final paidCount = payments.where((p) => p.isPaid).length;
        final totalCount = event.confirmedCount;
        final totalAmount = event.fee! * totalCount;
        final paidAmount = payments.where((p) => p.isPaid).fold<int>(
              0,
              (sum, payment) => sum + payment.amount,
            );

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.payments, color: Colors.blue),
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
                    color: Colors.blue.shade50,
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
                        '¥${paidAmount.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (match) => '${match[1]},')} / ¥${totalAmount.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (match) => '${match[1]},')}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (error, stack) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('エラー: $error'),
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

  // 参加者一覧セクション
  Widget _buildParticipantsSection(BuildContext context, WidgetRef ref, EventModel event) {
    final paymentsAsync = ref.watch(eventPaymentsProvider(event.eventId));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '参加者一覧',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
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
              paymentsAsync.when(
                data: (payments) {
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
                        if (event.fee != null && event.fee! > 0)
                          DataColumn(
                            label: Expanded(
                              child: Center(
                                child: Text(
                                  '支払い済み',
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
                      rows: event.participants.map((participant) {
                        // この参加者の支払い情報を取得
                        final payment = payments.firstWhere(
                          (p) => p.userId == participant.userId,
                          orElse: () => PaymentModel(
                            paymentId: '',
                            userId: participant.userId,
                            eventId: event.eventId,
                            circleId: event.circleId,
                            amount: 0,
                            status: PaymentStatus.pending,
                            method: PaymentMethod.paypay,
                            createdAt: DateTime.now(),
                            updatedAt: DateTime.now(),
                          ),
                        );

                        return DataRow(
                          cells: [
                            // 名前
                            DataCell(
                              Center(
                                child: FutureBuilder<String>(
                                  future: _getUserName(ref, participant.userId),
                                  builder: (context, snapshot) {
                                    return Text(
                                      snapshot.data ?? participant.userId,
                                      style: const TextStyle(fontSize: 13),
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
                            // 支払いステータス（チェックボックス）
                            if (event.fee != null && event.fee! > 0)
                              DataCell(
                                Center(
                                  child: Checkbox(
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
                                ),
                              ),
                          ],
                        );
                      }).toList(),
                    ),
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
          amount: event.fee ?? 0,
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
}
