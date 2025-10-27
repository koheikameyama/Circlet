import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';
import 'package:share_plus/share_plus.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../providers/circle_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/event_provider.dart';
import '../../models/event_model.dart';
import '../../services/circle_service.dart';
import '../../config/api_keys.dart';
import 'admin_event_detail_screen.dart';
import 'admin_event_create_screen.dart';

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
          NavigationDestination(
            icon: Icon(Icons.person),
            label: 'プロフィール',
          ),
        ],
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => AdminEventCreateScreen(
                      circleId: widget.circleId,
                    ),
                  ),
                );
              },
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
        return _AdminProfileTab(circleId: widget.circleId);
      default:
        return const SizedBox.shrink();
    }
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
class _AdminEventListTab extends ConsumerStatefulWidget {
  final String circleId;

  const _AdminEventListTab({required this.circleId});

  @override
  ConsumerState<_AdminEventListTab> createState() => _AdminEventListTabState();
}

class _AdminEventListTabState extends ConsumerState<_AdminEventListTab> {
  bool _isCalendarView = false;
  bool _showUpcoming = true; // true: 予定, false: 終了
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  List<EventModel> _filterEvents(List<EventModel> events) {
    final now = DateTime.now();
    if (_showUpcoming) {
      // 予定：終了していないイベント
      return events.where((event) {
        final endTime = event.endDatetime ?? event.datetime;
        return endTime.isAfter(now);
      }).toList();
    } else {
      // 終了：終了したイベント
      return events.where((event) {
        final endTime = event.endDatetime ?? event.datetime;
        return endTime.isBefore(now);
      }).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(circleEventsProvider(widget.circleId));

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

        return Column(
          children: [
            // 表示切り替えボタン
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: false,
                        icon: Icon(Icons.list, size: 18),
                        label: Text('リスト'),
                      ),
                      ButtonSegment(
                        value: true,
                        icon: Icon(Icons.calendar_month, size: 18),
                        label: Text('カレンダー'),
                      ),
                    ],
                    selected: {_isCalendarView},
                    onSelectionChanged: (Set<bool> selection) {
                      setState(() {
                        _isCalendarView = selection.first;
                      });
                    },
                  ),
                ],
              ),
            ),
            // 予定/終了フィルター（リスト表示時のみ）
            if (!_isCalendarView)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    DropdownButton<bool>(
                      value: _showUpcoming,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(
                          value: true,
                          child: Row(
                            children: [
                              Icon(Icons.schedule, size: 18),
                              SizedBox(width: 8),
                              Text('予定'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: false,
                          child: Row(
                            children: [
                              Icon(Icons.history, size: 18),
                              SizedBox(width: 8),
                              Text('終了'),
                            ],
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _showUpcoming = value;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
            // リスト表示またはカレンダー表示
            Expanded(
              child: _isCalendarView
                  ? _buildCalendarView(events)
                  : _buildListView(_filterEvents(events)),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('エラー: $error')),
    );
  }

  Widget _buildListView(List<EventModel> events) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        return _AdminEventCard(
          event: event,
          ref: ref,
          circleId: widget.circleId,
        );
      },
    );
  }

  Widget _buildCalendarView(List<EventModel> events) {
    return _AdminCalendarView(
      circleId: widget.circleId,
      events: events,
      focusedDay: _focusedDay,
      selectedDay: _selectedDay,
      onDaySelected: (selectedDay, focusedDay) {
        setState(() {
          _selectedDay = selectedDay;
          _focusedDay = focusedDay;
        });
      },
      onPageChanged: (focusedDay) {
        setState(() {
          _focusedDay = focusedDay;
        });
      },
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
                  final currentUser = ref.watch(authStateProvider).value;
                  final isCurrentUser = currentUser?.uid == member.userId;

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
                          // サークル内の表示名を優先、なければグローバル名
                          final displayName = member.displayName ?? snapshot.data ?? member.userId;
                          return Row(
                            children: [
                              Flexible(
                                child: Text(
                                  displayName,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isCurrentUser) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'あなた',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue.shade800,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                      subtitle: Text(isAdmin ? '管理者' : 'メンバー'),
                      onTap: isCurrentUser
                          ? () async {
                              final userName = await _getUserName(ref, member.userId);
                              final displayName = member.displayName ?? userName;
                              if (context.mounted) {
                                _showEditNameDialog(context, ref, circleId, member.userId, displayName);
                              }
                            }
                          : null,
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

  void _showEditNameDialog(
    BuildContext context,
    WidgetRef ref,
    String circleId,
    String userId,
    String currentName,
  ) {
    final nameController = TextEditingController(text: currentName);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('表示名の変更'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: '表示名',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
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
                  const SnackBar(content: Text('表示名を入力してください')),
                );
                return;
              }

              Navigator.pop(dialogContext);

              try {
                final circleService = CircleService();
                await circleService.updateMemberDisplayName(
                  circleId: circleId,
                  userId: userId,
                  displayName: nameController.text,
                );

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('表示名を変更しました'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('変更に失敗しました: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('変更'),
          ),
        ],
      ),
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

// 管理者用プロフィールタブ
class _AdminProfileTab extends ConsumerWidget {
  final String circleId;

  const _AdminProfileTab({required this.circleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(authStateProvider).value;
    final userDataAsync = currentUser != null
        ? ref.watch(userDataProvider(currentUser.uid))
        : null;
    final circleAsync = ref.watch(circleProvider(circleId));

    if (currentUser == null) {
      return const Center(
        child: Text('ユーザー情報を取得できませんでした'),
      );
    }

    return userDataAsync?.when(
      data: (userData) {
        final profileImageUrl = userData?.profileImageUrl;

        // サークル情報から表示名を取得
        final circle = circleAsync.value;
        final members = circle?.members.where((m) => m.userId == currentUser.uid);
        final member = (members?.isEmpty ?? true) ? null : members!.first;
        final displayName = member?.displayName ?? userData?.name ?? '名前未設定';

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // プロフィールカード
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      // プロフィール画像
                      CircleAvatar(
                        radius: 50,
                        backgroundImage: profileImageUrl != null
                            ? NetworkImage(profileImageUrl)
                            : null,
                        child: profileImageUrl == null
                            ? const Icon(Icons.person, size: 50)
                            : null,
                      ),
                      const SizedBox(height: 16),
                      // 表示名
                      Text(
                        displayName,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),
                      // 編集ボタン
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            _showEditNameDialog(
                              context,
                              ref,
                              circleId,
                              currentUser.uid,
                              displayName,
                            );
                          },
                          icon: const Icon(Icons.edit),
                          label: const Text('表示名を編集'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text('エラーが発生しました: $error'),
      ),
    ) ?? const Center(child: CircularProgressIndicator());
  }

  void _showEditNameDialog(
    BuildContext context,
    WidgetRef ref,
    String circleId,
    String userId,
    String currentName,
  ) {
    final nameController = TextEditingController(text: currentName);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('表示名の変更'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: '表示名',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
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
                  const SnackBar(content: Text('表示名を入力してください')),
                );
                return;
              }

              Navigator.pop(dialogContext);

              try {
                final circleService = CircleService();
                await circleService.updateMemberDisplayName(
                  circleId: circleId,
                  userId: userId,
                  displayName: nameController.text,
                );

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('表示名を変更しました'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('変更に失敗しました: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('変更'),
          ),
        ],
      ),
    );
  }
}

// カレンダービュー
class _AdminCalendarView extends ConsumerWidget {
  final String circleId;
  final List<EventModel> events;
  final DateTime focusedDay;
  final DateTime? selectedDay;
  final void Function(DateTime selectedDay, DateTime focusedDay) onDaySelected;
  final void Function(DateTime focusedDay) onPageChanged;

  const _AdminCalendarView({
    required this.circleId,
    required this.events,
    required this.focusedDay,
    required this.selectedDay,
    required this.onDaySelected,
    required this.onPageChanged,
  });

  List<EventModel> _getEventsForDay(DateTime day) {
    return events.where((event) {
      final eventDate = DateTime(
        event.datetime.year,
        event.datetime.month,
        event.datetime.day,
      );
      final checkDate = DateTime(day.year, day.month, day.day);

      // 終了日がある場合は範囲チェック
      if (event.endDatetime != null) {
        final endDate = DateTime(
          event.endDatetime!.year,
          event.endDatetime!.month,
          event.endDatetime!.day,
        );
        return !checkDate.isBefore(eventDate) && !checkDate.isAfter(endDate);
      }

      return eventDate.isAtSameMomentAs(checkDate);
    }).toList();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsForSelectedDay = selectedDay != null ? _getEventsForDay(selectedDay!) : [];

    return Column(
      children: [
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: focusedDay,
            selectedDayPredicate: (day) {
              return selectedDay != null && isSameDay(selectedDay, day);
            },
            eventLoader: _getEventsForDay,
            calendarFormat: CalendarFormat.month,
            startingDayOfWeek: StartingDayOfWeek.sunday,
            locale: 'ja_JP',
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                color: Colors.blue.shade200,
                shape: BoxShape.circle,
              ),
              selectedDecoration: const BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
              markerDecoration: const BoxDecoration(
                color: Colors.orange,
                shape: BoxShape.circle,
              ),
              markersMaxCount: 3,
            ),
            onDaySelected: onDaySelected,
            onPageChanged: onPageChanged,
          ),
        ),
        const SizedBox(height: 8),
        // 選択された日のイベント一覧
        Expanded(
          child: selectedDay == null
              ? const Center(
                  child: Text(
                    '日付を選択してください',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : eventsForSelectedDay.isEmpty
                  ? Center(
                      child: Text(
                        '${selectedDay!.month}/${selectedDay!.day}にイベントはありません',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: eventsForSelectedDay.length,
                      itemBuilder: (context, index) {
                        return _AdminEventCard(
                          event: eventsForSelectedDay[index],
                          ref: ref,
                          circleId: circleId,
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
