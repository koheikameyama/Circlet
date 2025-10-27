import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';
import '../../providers/auth_provider.dart';
import '../../providers/event_provider.dart';
import '../../config/api_keys.dart';

class AdminEventCreateScreen extends ConsumerStatefulWidget {
  final String circleId;

  const AdminEventCreateScreen({
    super.key,
    required this.circleId,
  });

  @override
  ConsumerState<AdminEventCreateScreen> createState() =>
      _AdminEventCreateScreenState();
}

class _AdminEventCreateScreenState
    extends ConsumerState<AdminEventCreateScreen> {
  final nameController = TextEditingController();
  final descriptionController = TextEditingController();
  final locationController = TextEditingController();
  final maxParticipantsController = TextEditingController(text: '10');
  final feeController = TextEditingController(text: '0');

  DateTime? selectedDate;
  TimeOfDay? selectedTime;
  DateTime? selectedEndDateTime;
  DateTime? selectedPublishDateTime;
  DateTime? selectedCancellationDeadline;
  bool isAllDay = false;
  bool participateAsCreator = true;

  @override
  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    locationController.dispose();
    maxParticipantsController.dispose();
    feeController.dispose();
    super.dispose();
  }

  String? _getEndDateTimeWarning() {
    if (selectedDate == null || selectedEndDateTime == null) {
      return null;
    }

    final DateTime startDateTime;
    if (!isAllDay && selectedTime != null) {
      startDateTime = DateTime(
        selectedDate!.year,
        selectedDate!.month,
        selectedDate!.day,
        selectedTime!.hour,
        selectedTime!.minute,
      );
    } else {
      startDateTime = DateTime(
        selectedDate!.year,
        selectedDate!.month,
        selectedDate!.day,
      );
    }

    if (selectedEndDateTime!.isBefore(startDateTime)) {
      return '終了日時は開始日時より後にしてください';
    }

    if (!isAllDay && selectedTime != null && selectedEndDateTime!.isAtSameMomentAs(startDateTime)) {
      return '終了日時は開始日時より後にしてください';
    }

    return null;
  }

  Future<void> _createEvent() async {
    if (nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('イベント名を入力してください')),
      );
      return;
    }
    if (selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('開始日を選択してください')),
      );
      return;
    }
    if (!isAllDay && selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('開始時刻を選択してください')),
      );
      return;
    }
    if (selectedEndDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('終了日時を選択してください')),
      );
      return;
    }

    // 開始日時を構築
    final DateTime startDateTime;
    if (!isAllDay && selectedTime != null) {
      startDateTime = DateTime(
        selectedDate!.year,
        selectedDate!.month,
        selectedDate!.day,
        selectedTime!.hour,
        selectedTime!.minute,
      );
    } else {
      startDateTime = DateTime(
        selectedDate!.year,
        selectedDate!.month,
        selectedDate!.day,
      );
    }

    // 現在時刻
    final now = DateTime.now();

    // 開始日時が現在時刻より前の場合、確認ダイアログを表示
    if (startDateTime.isBefore(now)) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('確認'),
          content: const Text('開始日が現在時刻以前になっています。よろしいですか？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('OK'),
            ),
          ],
        ),
      );

      if (confirmed != true) {
        return;
      }
    }

    // 終了日時が開始日時より前でないかチェック
    if (selectedEndDateTime!.isBefore(startDateTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('終了日時は開始日時より後にしてください')),
      );
      return;
    }

    // 時刻が設定されている場合は同じ時刻でないかチェック
    if (!isAllDay &&
        selectedTime != null &&
        selectedEndDateTime!.isAtSameMomentAs(startDateTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('終了日時は開始日時より後にしてください')),
      );
      return;
    }

    try {
      // イベントを作成
      final createEvent = ref.read(createEventProvider);
      final eventId = await createEvent(
        circleId: widget.circleId,
        name: nameController.text,
        description: descriptionController.text.isEmpty
            ? null
            : descriptionController.text,
        datetime: startDateTime,
        endDatetime: selectedEndDateTime,
        publishDatetime: selectedPublishDateTime,
        cancellationDeadline: selectedCancellationDeadline,
        location: locationController.text.isEmpty
            ? null
            : locationController.text,
        maxParticipants: int.parse(maxParticipantsController.text),
        fee: feeController.text.isEmpty ? null : feeController.text,
      );

      final joinEvent = ref.read(joinEventProvider);

      // 作成者が参加する場合、イベントに参加
      if (participateAsCreator) {
        final currentUser = ref.read(authStateProvider).value;
        if (currentUser != null) {
          await joinEvent(
            eventId: eventId,
            userId: currentUser.uid,
          );
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('「${nameController.text}」を作成しました'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('イベントの作成に失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('イベント作成'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: FilledButton.icon(
              onPressed: _createEvent,
              icon: const Icon(Icons.check, size: 20),
              label: const Text('作成'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'イベント名',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: '説明',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            // 開始日選択
            Card(
              child: ListTile(
                title: Text(
                  selectedDate == null
                      ? '開始日を選択'
                      : DateFormat('yyyy/MM/dd (E)', 'ja')
                          .format(selectedDate!),
                  style: TextStyle(
                    color: selectedDate == null ? Colors.grey : null,
                  ),
                ),
                leading: const Icon(Icons.calendar_today),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: selectedDate ?? DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) {
                    setState(() {
                      selectedDate = date;
                    });
                  }
                },
              ),
            ),
            // 終日トグル
            SwitchListTile(
              title: const Text('終日'),
              value: isAllDay,
              onChanged: (value) {
                setState(() {
                  isAllDay = value;
                  if (isAllDay) {
                    selectedTime = null;
                  }
                });
              },
            ),
            // 開始時刻選択
            if (!isAllDay)
              Card(
                child: ListTile(
                  title: Text(
                    selectedTime == null
                        ? '開始時刻を選択'
                        : '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      color: selectedTime == null ? Colors.grey : null,
                    ),
                  ),
                  leading: const Icon(Icons.access_time),
                  onTap: () async {
                    if (selectedDate == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('先に開始日を選択してください')),
                      );
                      return;
                    }
                    final time = await showTimePicker(
                      context: context,
                      initialTime: selectedTime ?? TimeOfDay.now(),
                    );
                    if (time != null) {
                      setState(() {
                        selectedTime = time;
                      });
                    }
                  },
                ),
              ),
            // 終了日時選択
            Card(
              child: ListTile(
                title: Text(
                  selectedEndDateTime == null
                      ? '終了日時を選択'
                      : (isAllDay || selectedTime == null)
                          ? DateFormat('yyyy/MM/dd (E)', 'ja')
                              .format(selectedEndDateTime!)
                          : DateFormat('yyyy/MM/dd (E) HH:mm', 'ja')
                              .format(selectedEndDateTime!),
                  style: TextStyle(
                    color: selectedEndDateTime == null ? Colors.grey : null,
                  ),
                ),
                leading: const Icon(Icons.event_available),
                onTap: () async {
                  if (selectedDate == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('先に開始日を選択してください')),
                    );
                    return;
                  }

                  final date = await showDatePicker(
                    context: context,
                    initialDate: selectedEndDateTime ?? selectedDate!,
                    firstDate: selectedDate!,
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null && mounted) {
                    if (!isAllDay && selectedTime != null) {
                      final initialTime = selectedEndDateTime != null
                          ? TimeOfDay.fromDateTime(selectedEndDateTime!)
                          : selectedTime!;
                      final time = await showTimePicker(
                        context: context,
                        initialTime: initialTime,
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
                      } else {
                        setState(() {
                          selectedEndDateTime = DateTime(
                            date.year,
                            date.month,
                            date.day,
                          );
                        });
                      }
                    } else {
                      setState(() {
                        selectedEndDateTime = DateTime(
                          date.year,
                          date.month,
                          date.day,
                        );
                      });
                    }
                  }
                },
              ),
            ),
            // 終了日時の警告メッセージ
            if (_getEndDateTimeWarning() != null)
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, top: 8),
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _getEndDateTimeWarning()!,
                        style: const TextStyle(
                          color: Colors.orange,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            // 公開日時選択
            Card(
              child: ListTile(
                title: Text(
                  selectedPublishDateTime == null
                      ? '公開日時を選択（任意）'
                      : DateFormat('yyyy/MM/dd (E) HH:mm', 'ja')
                          .format(selectedPublishDateTime!),
                  style: TextStyle(
                    color: selectedPublishDateTime == null ? Colors.grey : null,
                  ),
                ),
                leading: const Icon(Icons.public),
                trailing: selectedPublishDateTime != null
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            selectedPublishDateTime = null;
                          });
                        },
                      )
                    : null,
                onTap: () async {
                  // 終日の場合は開始日の前日まで、時刻がある場合は開始日時まで
                  DateTime lastDate;
                  if (selectedDate != null) {
                    if (isAllDay) {
                      // 終日の場合は開始日の前日まで
                      lastDate = DateTime(
                        selectedDate!.year,
                        selectedDate!.month,
                        selectedDate!.day,
                      ).subtract(const Duration(days: 1));
                    } else {
                      // 時刻がある場合は1年後まで
                      lastDate = DateTime.now().add(const Duration(days: 365));
                    }
                  } else {
                    lastDate = DateTime.now().add(const Duration(days: 365));
                  }

                  final date = await showDatePicker(
                    context: context,
                    initialDate: selectedPublishDateTime ?? DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: lastDate,
                  );
                  if (date != null && mounted) {
                    final initialTime = selectedPublishDateTime != null
                        ? TimeOfDay.fromDateTime(selectedPublishDateTime!)
                        : TimeOfDay.now();
                    final time = await showTimePicker(
                      context: context,
                      initialTime: initialTime,
                    );
                    if (time != null) {
                      setState(() {
                        selectedPublishDateTime = DateTime(
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
            ),
            const SizedBox(height: 16),
            // キャンセル期限選択
            Card(
              child: ListTile(
                title: Text(
                  selectedCancellationDeadline == null
                      ? 'キャンセル期限を選択（任意）'
                      : DateFormat('yyyy/MM/dd (E) HH:mm', 'ja')
                          .format(selectedCancellationDeadline!),
                  style: TextStyle(
                    color: selectedCancellationDeadline == null ? Colors.grey : null,
                  ),
                ),
                leading: const Icon(Icons.event_busy),
                trailing: selectedCancellationDeadline != null
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            selectedCancellationDeadline = null;
                          });
                        },
                      )
                    : null,
                onTap: () async {
                  if (selectedDate == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('先に開始日を選択してください')),
                    );
                    return;
                  }

                  // 開始日時を取得
                  final DateTime startDateTime;
                  if (!isAllDay && selectedTime != null) {
                    startDateTime = DateTime(
                      selectedDate!.year,
                      selectedDate!.month,
                      selectedDate!.day,
                      selectedTime!.hour,
                      selectedTime!.minute,
                    );
                  } else {
                    startDateTime = DateTime(
                      selectedDate!.year,
                      selectedDate!.month,
                      selectedDate!.day,
                    );
                  }

                  // 日付選択（公開日時が設定されていれば公開日時以降、なければ現在時刻以降）
                  final DateTime firstDate;
                  if (selectedPublishDateTime != null) {
                    firstDate = selectedPublishDateTime!;
                  } else {
                    firstDate = DateTime.now();
                  }

                  // 終日の場合は開始日の前日まで、時刻がある場合は開始日時まで
                  final DateTime lastDate;
                  if (isAllDay) {
                    lastDate = startDateTime.subtract(const Duration(days: 1));
                  } else {
                    lastDate = startDateTime;
                  }

                  final date = await showDatePicker(
                    context: context,
                    initialDate: selectedCancellationDeadline ?? firstDate,
                    firstDate: firstDate,
                    lastDate: lastDate,
                  );
                  if (date != null && mounted) {
                    final initialTime = selectedCancellationDeadline != null
                        ? TimeOfDay.fromDateTime(selectedCancellationDeadline!)
                        : TimeOfDay.now();
                    final time = await showTimePicker(
                      context: context,
                      initialTime: initialTime,
                    );
                    if (time != null) {
                      setState(() {
                        selectedCancellationDeadline = DateTime(
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
            ),
            const SizedBox(height: 16),
            TextField(
              controller: locationController,
              decoration: InputDecoration(
                labelText: '場所',
                border: const OutlineInputBorder(),
                hintText: '場所を入力',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.map),
                  tooltip: 'Google Mapsで確認',
                  onPressed: () => _openGoogleMaps(locationController.text),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: maxParticipantsController,
              decoration: const InputDecoration(
                labelText: '定員',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: feeController,
              decoration: const InputDecoration(
                labelText: '参加費（数値または文字列）',
                hintText: '例: 500 または 各自負担',
                border: OutlineInputBorder(),
                helperText: '数値の場合は支払い管理で合計金額を計算します',
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            // 自分も参加するチェックボックス
            CheckboxListTile(
              title: const Text('自分も参加する'),
              value: participateAsCreator,
              onChanged: (value) {
                setState(() {
                  participateAsCreator = value ?? true;
                });
              },
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Future<void> _openGoogleMaps(String location) async {
    if (location.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('場所を入力してください')),
      );
      return;
    }

    final encodedLocation = Uri.encodeComponent(location);
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$encodedLocation');

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Google Mapsを開けませんでした')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e')),
        );
      }
    }
  }
}
