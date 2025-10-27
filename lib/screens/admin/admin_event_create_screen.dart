import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';
import '../../providers/auth_provider.dart';
import '../../providers/circle_provider.dart';
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
  bool isAllDay = false;
  bool participateAsCreator = true;
  final Set<String> selectedMemberIds = {};

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
        location: locationController.text.isEmpty
            ? null
            : locationController.text,
        maxParticipants: int.parse(maxParticipantsController.text),
        fee: int.parse(feeController.text),
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

      // 選択されたメンバーをイベントに追加
      for (final memberId in selectedMemberIds) {
        await joinEvent(
          eventId: eventId,
          userId: memberId,
        );
      }

      if (mounted) {
        final totalParticipants =
            (participateAsCreator ? 1 : 0) + selectedMemberIds.length;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('「${nameController.text}」を作成しました（参加者: $totalParticipants人）'),
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

  Future<void> _showMemberSelectionDialog() async {
    await showDialog(
      context: context,
      builder: (dialogContext) {
        final circleAsync = ref.watch(circleProvider(widget.circleId));

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('参加メンバーを選択'),
              content: SizedBox(
                width: double.maxFinite,
                child: circleAsync.when(
                  data: (circle) {
                    if (circle == null) {
                      return const Text('サークル情報が読み込めません');
                    }

                    final currentUser = ref.read(authStateProvider).value;
                    final otherMembers = circle.members
                        .where((m) => m.userId != currentUser?.uid)
                        .toList();

                    if (otherMembers.isEmpty) {
                      return const Text('他のメンバーがいません');
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: otherMembers.length,
                      itemBuilder: (context, index) {
                        final member = otherMembers[index];
                        final userAsync = ref.watch(
                            userDataProvider(member.userId));

                        return userAsync.when(
                          data: (userData) {
                            final displayName = member.displayName ??
                                userData?.name ??
                                member.userId;
                            final isSelected =
                                selectedMemberIds.contains(member.userId);

                            return CheckboxListTile(
                              title: Text(displayName),
                              value: isSelected,
                              onChanged: (bool? value) {
                                setState(() {
                                  if (value == true) {
                                    selectedMemberIds.add(member.userId);
                                  } else {
                                    selectedMemberIds.remove(member.userId);
                                  }
                                });
                              },
                            );
                          },
                          loading: () => const ListTile(
                            title: Text('読み込み中...'),
                          ),
                          error: (_, __) => ListTile(
                            title: Text(member.userId),
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  error: (error, _) => Text('エラー: $error'),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('閉じる'),
                ),
              ],
            );
          },
        );
      },
    );
    setState(() {}); // 選択数を更新
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
                locationController.text =
                    prediction.structuredFormatting?.mainText ??
                        prediction.description ??
                        '';
              },
              itemClick: (Prediction prediction) {
                locationController.text =
                    prediction.structuredFormatting?.mainText ??
                        prediction.description ??
                        '';
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
                              prediction.structuredFormatting?.mainText ??
                                  prediction.description ??
                                  "",
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (prediction.structuredFormatting?.secondaryText !=
                                null)
                              Text(
                                prediction
                                    .structuredFormatting!.secondaryText!,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600),
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
                labelText: '参加費',
                border: OutlineInputBorder(),
                prefixText: '¥',
              ),
              keyboardType: TextInputType.number,
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
            // 参加メンバー選択
            Card(
              child: ListTile(
                leading: const Icon(Icons.people),
                title: const Text('参加メンバーを選択'),
                subtitle: Text(
                  selectedMemberIds.isEmpty
                      ? '選択なし'
                      : '${selectedMemberIds.length}人選択中',
                  style: TextStyle(
                    color:
                        selectedMemberIds.isEmpty ? Colors.grey : Colors.blue,
                    fontSize: 12,
                  ),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: _showMemberSelectionDialog,
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
