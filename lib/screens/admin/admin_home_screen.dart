import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';
import '../../providers/circle_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/event_provider.dart';
import '../../models/event_model.dart';
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
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showEditCircleDialog(context, circleAsync.value),
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
          NavigationDestination(
            icon: Icon(Icons.notifications),
            label: '通知',
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
      case 2:
        return _AdminNotificationsTab(circleId: widget.circleId);
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
    DateTime? selectedDateTime;
    DateTime? selectedEndDateTime;
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
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null && context.mounted) {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
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
                      // 場所が選択された時の処理
                      locationController.text = prediction.description ?? '';
                    },
                    itemClick: (Prediction prediction) {
                      locationController.text = prediction.description ?? '';
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
                              child: Text(
                                prediction.description ?? "",
                                style: const TextStyle(fontSize: 14),
                                overflow: TextOverflow.ellipsis,
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
                    // イベントを作成
                    final createEvent = ref.read(createEventProvider);
                    final eventId = await createEvent(
                      circleId: widget.circleId,
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
    final dateFormat = DateFormat('yyyy/MM/dd (E) HH:mm', 'ja');
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
              // イベントアイコン
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.event,
                  color: Colors.blue,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
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
                      children: [
                        const Icon(Icons.access_time, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          dateFormat.format(event.datetime),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                          ),
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
                    Row(
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
                        const SizedBox(width: 8),
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
                            margin: const EdgeInsets.only(left: 8),
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
            // サークル情報
            if (circle.description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.info_outline, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'サークル説明',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          circle.description,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // 招待QRコード
            Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text(
                        '招待用QRコード',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      QrImageView(
                        data: 'invite://circle/$circleId',
                        version: QrVersions.auto,
                        size: 200,
                      ),
                    ],
                  ),
                ),
              ),
            ),

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
                  final isDummy = member.userId.startsWith('dummy_');

                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isAdmin ? Colors.blue : Colors.grey,
                        child: Icon(
                          isAdmin ? Icons.admin_panel_settings : Icons.person,
                          color: Colors.white,
                        ),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: FutureBuilder<String>(
                              future: _getUserName(ref, member.userId),
                              builder: (context, snapshot) {
                                return Text(snapshot.data ?? member.userId);
                              },
                            ),
                          ),
                          if (isDummy)
                            const Chip(
                              label: Text('テスト', style: TextStyle(fontSize: 10)),
                              backgroundColor: Colors.orange,
                              padding: EdgeInsets.symmetric(horizontal: 4),
                            ),
                        ],
                      ),
                      subtitle: Text(isAdmin ? '管理者' : 'メンバー'),
                      trailing: !isAdmin
                          ? IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
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
                              },
                            )
                          : null,
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
}

// 管理者用支払いタブ
class _AdminPaymentsTab extends StatelessWidget {
  final String circleId;

  const _AdminPaymentsTab({required this.circleId});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('支払い管理機能は準備中です'),
    );
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
