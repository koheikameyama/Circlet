import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';
import 'package:share_plus/share_plus.dart';
import '../../providers/circle_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/event_provider.dart';
import '../../models/event_model.dart';
import '../../services/circle_service.dart';
import '../../config/api_keys.dart';
import 'admin_event_detail_screen.dart';

class AdminHomeScreen extends ConsumerStatefulWidget {
  final String circleId;

  const AdminHomeScreen({
    super.key,
    required this.circleId,
  });

  @override
  ConsumerState<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends ConsumerState<AdminHomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final circleAsync = ref.watch(circleProvider(widget.circleId));

    return Scaffold(
      appBar: AppBar(
        title: circleAsync.when(
          data: (circle) => Text(circle?.name ?? 'サークル (管理)'),
          loading: () => const Text('サークル (管理)'),
          error: (_, __) => const Text('サークル (管理)'),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/circles'),
        ),
        actions: [
          // 招待リンク生成ボタン
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () => _showInviteLinkDialog(context, widget.circleId),
          ),
          // 編集ボタン
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _showEditCircleDialog(context, circleAsync.value),
          ),
          // 削除ボタン
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _showDeleteCircleDialog(context, circleAsync.value),
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.event),
            label: 'イベント',
          ),
          NavigationDestination(
            icon: Icon(Icons.people),
            label: 'メンバー',
          ),
        ],
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () => _showCreateEventDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('イベント作成'),
            )
          : null,
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return _AdminEventListTab(circleId: widget.circleId);
      case 1:
        return _AdminMembersTab(circleId: widget.circleId);
      default:
        return const SizedBox.shrink();
    }
  }

  void _showCreateEventDialog(BuildContext context) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final locationController = TextEditingController();
    final maxParticipantsController = TextEditingController(text: '10');
    final feeController = TextEditingController(text: '0');
    DateTime? selectedDate;
    TimeOfDay? selectedTime;
    DateTime? selectedEndDateTime;
    bool isAllDay = false; // 終日フラグ
    bool participateAsCreator = true; // デフォルトで参加する
    final Set<String> selectedMemberIds = {}; // 選択されたメンバーのID

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('イベント作成'),
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
                  // 開始日選択
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      selectedDate == null
                          ? '開始日を選択'
                          : DateFormat('yyyy/MM/dd (E)', 'ja').format(selectedDate!),
                      style: TextStyle(
                        color: selectedDate == null ? Colors.grey : null,
                      ),
                    ),
                    leading: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) {
                        setState(() {
                          selectedDate = date;
                          // 開始日が設定されたら、終了日時にも同じ日付を設定
                          if (!isAllDay && selectedTime != null) {
                            selectedEndDateTime = DateTime(
                              date.year,
                              date.month,
                              date.day,
                              selectedTime!.hour,
                              selectedTime!.minute,
                            );
                          } else {
                            selectedEndDateTime = DateTime(
                              date.year,
                              date.month,
                              date.day,
                            );
                          }
                        });
                      }
                    },
                  ),
                  // 終日トグル
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('終日'),
                    value: isAllDay,
                    onChanged: (value) {
                      setState(() {
                        isAllDay = value;
                        if (isAllDay) {
                          // 終日にした場合、時刻をクリア
                          selectedTime = null;
                          // 終了日時も日付のみに更新
                          if (selectedDate != null) {
                            selectedEndDateTime = DateTime(
                              selectedDate!.year,
                              selectedDate!.month,
                              selectedDate!.day,
                            );
                          }
                        }
                      });
                    },
                  ),
                  // 開始時刻選択（終日でない場合のみ表示）
                  if (!isAllDay)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        selectedTime == null
                            ? '開始時刻を選択（任意）'
                            : '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          color: selectedTime == null ? Colors.grey : null,
                        ),
                      ),
                      leading: const Icon(Icons.access_time),
                      trailing: selectedTime != null
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 20),
                              onPressed: () {
                                setState(() {
                                  selectedTime = null;
                                  // 時刻をクリアしたら、終了日時も日付のみに更新
                                  if (selectedDate != null) {
                                    selectedEndDateTime = DateTime(
                                      selectedDate!.year,
                                      selectedDate!.month,
                                      selectedDate!.day,
                                    );
                                  }
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
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );
                        if (time != null) {
                          setState(() {
                            selectedTime = time;
                            // 時刻が設定されたら、終了日時にも同じ時刻を設定
                            selectedEndDateTime = DateTime(
                              selectedDate!.year,
                              selectedDate!.month,
                              selectedDate!.day,
                              time.hour,
                              time.minute,
                            );
                          });
                        }
                      },
                    ),
                  // 終了日時選択
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      selectedEndDateTime == null
                          ? '終了日時を選択'
                          : (isAllDay || selectedTime == null)
                              ? DateFormat('yyyy/MM/dd (E)', 'ja').format(selectedEndDateTime!)
                              : DateFormat('yyyy/MM/dd (E) HH:mm', 'ja').format(selectedEndDateTime!),
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
                      if (date != null && context.mounted) {
                        if (!isAllDay && selectedTime != null) {
                          // 終日でなく、時刻が設定されている場合は時刻も選択（任意）
                          final time = await showTimePicker(
                            context: context,
                            initialTime: selectedTime!,
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
                            // 時刻選択をキャンセルした場合は日付のみ
                            setState(() {
                              selectedEndDateTime = DateTime(
                                date.year,
                                date.month,
                                date.day,
                              );
                            });
                          }
                        } else {
                          // 終日または時刻が設定されていない場合は日付のみ
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
                      // 場所が選択された時の処理
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
                  const SizedBox(height: 16),
                  // 自分も参加するチェックボックス
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('自分も参加する'),
                    value: participateAsCreator,
                    onChanged: (value) {
                      setState(() {
                        participateAsCreator = value ?? true;
                      });
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  const Divider(),
                  // 参加メンバー選択ボタン
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.people),
                    title: const Text('参加メンバーを選択'),
                    subtitle: Text(
                      selectedMemberIds.isEmpty
                          ? '選択なし'
                          : '${selectedMemberIds.length}人選択中',
                      style: TextStyle(
                        color: selectedMemberIds.isEmpty ? Colors.grey : Colors.blue,
                        fontSize: 12,
                      ),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () async {
                      await _showMemberSelectionDialog(
                        context,
                        selectedMemberIds,
                      );
                      setState(() {}); // 選択数を更新
                    },
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
                  if (selectedDate == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('開始日を選択してください')),
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

                  // 終了日時が開始日時より前でないかチェック
                  if (selectedEndDateTime!.isBefore(startDateTime)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('終了日時は開始日時より後にしてください')),
                    );
                    return;
                  }

                  // 時刻が設定されている場合は同じ時刻でないかチェック
                  if (!isAllDay && selectedTime != null &&
                      selectedEndDateTime!.isAtSameMomentAs(startDateTime)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('終了日時は開始日時より後にしてください')),
                    );
                    return;
                  }

                  Navigator.pop(dialogContext);

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

                    if (context.mounted) {
                      final totalParticipants =
                          (participateAsCreator ? 1 : 0) + selectedMemberIds.length;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '「${nameController.text}」を作成しました（参加者: $totalParticipants人）'
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('イベントの作成に失敗しました: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: const Text('作成'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showMemberSelectionDialog(
    BuildContext context,
    Set<String> selectedMemberIds,
  ) async {
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
                      return const Center(
                        child: Text(
                          '他のメンバーがいません',
                          style: TextStyle(color: Colors.grey),
                        ),
                      );
                    }

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 全選択/全解除ボタン
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${selectedMemberIds.length}/${otherMembers.length}人選択',
                              style: const TextStyle(fontSize: 14, color: Colors.grey),
                            ),
                            Row(
                              children: [
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      selectedMemberIds.clear();
                                    });
                                  },
                                  child: const Text('全解除'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      selectedMemberIds.clear();
                                      selectedMemberIds.addAll(
                                        otherMembers.map((m) => m.userId),
                                      );
                                    });
                                  },
                                  child: const Text('全選択'),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const Divider(),
                        // メンバーリスト
                        Flexible(
                          child: ListView(
                            shrinkWrap: true,
                            children: otherMembers.map((member) {
                              return CheckboxListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                                title: FutureBuilder<String>(
                                  future: _getMemberName(ref, member.userId),
                                  builder: (context, snapshot) {
                                    return Text(
                                      snapshot.data ?? member.userId,
                                      style: const TextStyle(fontSize: 14),
                                    );
                                  },
                                ),
                                value: selectedMemberIds.contains(member.userId),
                                onChanged: (value) {
                                  setState(() {
                                    if (value == true) {
                                      selectedMemberIds.add(member.userId);
                                    } else {
                                      selectedMemberIds.remove(member.userId);
                                    }
                                  });
                                },
                                controlAffinity: ListTileControlAffinity.leading,
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    );
                  },
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (error, stack) => Center(
                    child: Text('エラー: $error'),
                  ),
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
  }

  Future<String> _getMemberName(WidgetRef ref, String userId) async {
    try {
      final authService = ref.read(authServiceProvider);
      final user = await authService.getUserData(userId);
      return user?.name ?? userId;
    } catch (e) {
      return userId;
    }
  }

  // 招待リンクダイアログを表示
  void _showInviteLinkDialog(BuildContext context, String circleId) async {
    final circleService = CircleService();
    final currentUser = ref.read(authStateProvider).value;

    if (currentUser == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ログインが必要です')),
      );
      return;
    }

    // ローディング表示
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // 招待リンクを作成（15秒でタイムアウト）
      final invite = await circleService.createInviteLink(
        circleId: circleId,
        createdBy: currentUser.uid,
        validDays: 7,
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('招待リンクの作成がタイムアウトしました。インターネット接続を確認してください。');
        },
      );

      final inviteUrl = circleService.generateInviteUrl(invite.inviteId);

      if (!context.mounted) return;

      Navigator.pop(context); // ローディングを閉じる

      // ダイアログを閉じた後、少し待ってから次のダイアログを表示
      await Future.delayed(const Duration(milliseconds: 300));

      if (!context.mounted) return;

      // 招待リンクダイアログを表示
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.link, color: Colors.blue),
                SizedBox(width: 8),
                Text('招待リンク'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '招待リンクを共有してメンバーを招待できます',
                  style: TextStyle(fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                // コピーリンク
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: inviteUrl));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('リンクをコピーしました'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.copy,
                          size: 20,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '招待リンクをコピー',
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '有効期限: ${DateFormat('yyyy/MM/dd HH:mm').format(invite.expiresAt)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            actionsAlignment: MainAxisAlignment.spaceBetween,
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('閉じる'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Share.share(
                    'サークルに招待します！\n$inviteUrl',
                    subject: 'サークル招待',
                  );
                },
                icon: Icon(Platform.isIOS ? Icons.ios_share : Icons.share),
                label: const Text('共有'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (!context.mounted) return;

      // ローディングダイアログを閉じる
      try {
        Navigator.pop(context);
      } catch (popError) {
        print('Error closing dialog: $popError');
      }

      // エラーメッセージを表示（詳細を含む）
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('招待リンクの作成に失敗しました\n\nエラー: $e'),
          duration: const Duration(seconds: 10),
          action: SnackBarAction(
            label: '閉じる',
            onPressed: () {},
          ),
        ),
      );
    }
  }

  void _showEditCircleDialog(BuildContext context, circle) {
    if (circle == null) return;

    final nameController = TextEditingController(text: circle.name);
    final descriptionController = TextEditingController(text: circle.description);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('サークル情報編集'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'サークル名',
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
                  const SnackBar(content: Text('サークル名を入力してください')),
                );
                return;
              }

              Navigator.pop(dialogContext);

              try {
                final updateCircle = ref.read(updateCircleProvider);
                await updateCircle(
                  circleId: widget.circleId,
                  name: nameController.text,
                  description: descriptionController.text,
                );

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('サークル情報を更新しました'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('更新に失敗しました: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _showDeleteCircleDialog(BuildContext context, circle) {
    if (circle == null) return;

    showDialog(
      context: context,
      builder: (confirmContext) => AlertDialog(
        title: const Text('サークル削除'),
        content: Text('「${circle.name}」を削除しますか？\nこの操作は取り消せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(confirmContext, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(confirmContext);

              try {
                final circleService = ref.read(circleServiceProvider);
                await circleService.deleteCircle(widget.circleId);

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('サークルを削除しました'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  // サークル選択画面に戻る
                  context.go('/circles');
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
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('削除'),
          ),
        ],
      ),
    );
  }
}

// 管理者用イベント一覧タブ
class _AdminEventListTab extends ConsumerWidget {
  final String circleId;

  const _AdminEventListTab({required this.circleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(circleEventsProvider(circleId));

    return eventsAsync.when(
      data: (events) {
        if (events.isEmpty) {
          return const Center(
            child: Text(
              'イベントがありません\n下の「+」ボタンからイベントを作成できます',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: events.length,
          itemBuilder: (context, index) {
            final event = events[index];
            return _AdminEventCard(
              event: event,
              ref: ref,
              circleId: circleId,
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('エラー: $error')),
    );
  }
}

// 管理者用イベントカード
class _AdminEventCard extends ConsumerWidget {
  final EventModel event;
  final WidgetRef ref;
  final String circleId;

  const _AdminEventCard({
    required this.event,
    required this.ref,
    required this.circleId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(authStateProvider).value;

    // 現在のユーザーが参加しているかチェック
    final isParticipating = currentUser != null &&
        event.participants.any((p) =>
            p.userId == currentUser.uid &&
            p.status != ParticipationStatus.cancelled);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => AdminEventDetailScreen(
                circleId: circleId,
                eventId: event.eventId,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // イベント情報
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.access_time, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Expanded(
                          child: _buildDateTimeText(event.datetime, event.endDatetime),
                        ),
                      ],
                    ),
                    if (event.location != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              event.location!,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[700],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        // 参加状況バッジ
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isParticipating
                                ? Colors.green.shade100
                                : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isParticipating ? Icons.check_circle : Icons.people,
                                size: 14,
                                color: isParticipating ? Colors.green : Colors.grey[700],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isParticipating
                                    ? '参加中'
                                    : '${event.confirmedCount}/${event.maxParticipants}人',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isParticipating ? Colors.green : Colors.grey[700],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // キャンセル待ちバッジ
                        if (event.waitlistCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.schedule,
                                  size: 14,
                                  color: Colors.orange,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '待ち${event.waitlistCount}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        // 参加費バッジ
                        if (event.fee != null && event.fee! > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '¥${event.fee}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateTimeText(DateTime startDateTime, DateTime? endDateTime) {
    final dateFormat = DateFormat('yyyy/MM/dd (E) HH:mm', 'ja');
    final dateOnlyFormat = DateFormat('yyyy/MM/dd (E)', 'ja');
    final timeFormat = DateFormat('HH:mm', 'ja');

    // 時刻が00:00かチェック
    final startHasTime = startDateTime.hour != 0 || startDateTime.minute != 0;
    final endHasTime = endDateTime != null && (endDateTime.hour != 0 || endDateTime.minute != 0);

    if (endDateTime == null) {
      return Text(
        startHasTime ? dateFormat.format(startDateTime) : dateOnlyFormat.format(startDateTime),
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey[700],
        ),
      );
    }

    // 同じ日付かチェック
    final isSameDay = startDateTime.year == endDateTime.year &&
                      startDateTime.month == endDateTime.month &&
                      startDateTime.day == endDateTime.day;

    if (!startHasTime && !endHasTime) {
      // 両方時刻なし
      if (isSameDay) {
        return Text(
          dateOnlyFormat.format(startDateTime),
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[700],
          ),
        );
      } else {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              dateOnlyFormat.format(startDateTime),
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700],
              ),
            ),
            Text(
              '~ ${dateOnlyFormat.format(endDateTime)}',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700],
              ),
            ),
          ],
        );
      }
    } else if (isSameDay) {
      // 同じ日の場合は1行で表示
      return Text(
        '${dateFormat.format(startDateTime)} ~ ${timeFormat.format(endDateTime)}',
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey[700],
        ),
      );
    } else {
      // 異なる日の場合は2行で表示
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            dateFormat.format(startDateTime),
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
            ),
          ),
          Text(
            '~ ${dateFormat.format(endDateTime)}',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
            ),
          ),
        ],
      );
    }
  }
}

// 管理者用メンバータブ
class _AdminMembersTab extends ConsumerWidget {
  final String circleId;

  const _AdminMembersTab({required this.circleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final circleAsync = ref.watch(circleProvider(circleId));

    return circleAsync.when(
      data: (circle) {
        if (circle == null) {
          return const Center(child: Text('サークルが見つかりません'));
        }

        return Column(
          children: [
            // デバッグ用：ダミーメンバー追加ボタン
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                color: Colors.orange.shade50,
                child: ListTile(
                  leading: const Icon(Icons.bug_report, color: Colors.orange),
                  title: const Text('デバッグ: テストメンバー追加'),
                  trailing: ElevatedButton.icon(
                    onPressed: () => _addDummyMembers(context, ref, circleId),
                    icon: const Icon(Icons.person_add),
                    label: const Text('追加'),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // メンバーリスト
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: circle.members.length,
                itemBuilder: (context, index) {
                  final member = circle.members[index];
                  final isAdmin = member.role == 'admin';

                  // 管理者の数をカウント
                  final adminCount = circle.members.where((m) => m.role == 'admin').length;
                  // 管理者が1人だけで、かつこのメンバーが管理者の場合は権限変更を禁止
                  final canChangeRole = !(isAdmin && adminCount <= 1);

                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isAdmin ? Colors.blue : Colors.grey,
                        child: Icon(
                          isAdmin ? Icons.admin_panel_settings : Icons.person,
                          color: Colors.white,
                        ),
                      ),
                      title: FutureBuilder<String>(
                        future: _getUserName(ref, member.userId),
                        builder: (context, snapshot) {
                          return Text(snapshot.data ?? member.userId);
                        },
                      ),
                      subtitle: Text(isAdmin ? '管理者' : 'メンバー'),
                      trailing: PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert),
                        onSelected: (value) async {
                          switch (value) {
                            case 'change_role':
                              final newRole = isAdmin ? 'member' : 'admin';
                              _showRoleChangeDialog(
                                context,
                                ref,
                                circleId,
                                member.userId,
                                newRole,
                              );
                              break;
                            case 'delete':
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (dialogContext) => AlertDialog(
                                  title: const Text('メンバー削除'),
                                  content: const Text('このメンバーを削除しますか？'),
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
                                  final removeMember = ref.read(removeMemberProvider);
                                  await removeMember(
                                    circleId: circleId,
                                    userId: member.userId,
                                  );
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('メンバーを削除しました'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
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
                              break;
                          }
                        },
                        itemBuilder: (BuildContext context) => [
                          if (canChangeRole)
                            PopupMenuItem<String>(
                              value: 'change_role',
                              child: Row(
                                children: [
                                  Icon(
                                    isAdmin ? Icons.person : Icons.admin_panel_settings,
                                    color: Colors.blue,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(isAdmin ? 'メンバーに変更' : '管理者に変更'),
                                ],
                              ),
                            ),
                          if (!canChangeRole && isAdmin)
                            const PopupMenuItem<String>(
                              enabled: false,
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline, color: Colors.grey, size: 20),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      '少なくとも1人の管理者が必要です',
                                      style: TextStyle(color: Colors.grey, fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (!isAdmin)
                            const PopupMenuItem<String>(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete, color: Colors.red, size: 20),
                                  SizedBox(width: 12),
                                  Text('削除', style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('エラー: $error')),
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

  Future<void> _addDummyMembers(BuildContext context, WidgetRef ref, String circleId) async {
    final dummyNames = ['田中太郎', '佐藤花子', '鈴木一郎', '高橋次郎', '伊藤美咲'];

    try {
      final circleService = ref.read(circleServiceProvider);

      for (final name in dummyNames) {
        await circleService.addDummyMember(
          circleId: circleId,
          name: name,
        );
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${dummyNames.length}人のテストメンバーを追加しました'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('追加に失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showRoleChangeDialog(
    BuildContext context,
    WidgetRef ref,
    String circleId,
    String userId,
    String newRole,
  ) async {
    final userName = await _getUserName(ref, userId);
    final roleText = newRole == 'admin' ? '管理者' : 'メンバー';

    if (!context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('権限変更'),
        content: Text('$userName を$roleText に変更しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('変更'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        final updateMemberRole = ref.read(updateMemberRoleProvider);
        await updateMemberRole(
          circleId: circleId,
          userId: userId,
          role: newRole,
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$userName の権限を$roleText に変更しました'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('権限変更に失敗しました: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

// 管理者用通知タブ
class _AdminNotificationsTab extends StatelessWidget {
  final String circleId;

  const _AdminNotificationsTab({required this.circleId});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('通知管理機能は準備中です'),
    );
  }
}
