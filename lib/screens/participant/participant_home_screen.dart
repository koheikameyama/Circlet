import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../providers/auth_provider.dart';
import '../../providers/circle_provider.dart';
import '../../providers/event_provider.dart';
import '../../models/event_model.dart';
import '../../services/circle_service.dart';
import 'participant_event_detail_screen.dart';

class ParticipantHomeScreen extends ConsumerStatefulWidget {
  final String circleId;

  const ParticipantHomeScreen({
    super.key,
    required this.circleId,
  });

  @override
  ConsumerState<ParticipantHomeScreen> createState() =>
      _ParticipantHomeScreenState();
}

class _ParticipantHomeScreenState extends ConsumerState<ParticipantHomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final circleAsync = ref.watch(circleProvider(widget.circleId));

    return Scaffold(
      appBar: AppBar(
        title: circleAsync.when(
          data: (circle) => Text(circle?.name ?? 'サークル'),
          loading: () => const Text('読み込み中...'),
          error: (_, __) => const Text('サークル'),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/circles'),
        ),
        actions: [
          // デバッグ用：イベント自動作成ボタン
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'イベント自動作成（デバッグ）',
            onPressed: () => _autoCreateEvent(context),
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
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return _EventListTab(circleId: widget.circleId);
      case 1:
        return _MembersTab(circleId: widget.circleId);
      case 2:
        return _ProfileTab(circleId: widget.circleId);
      default:
        return const SizedBox.shrink();
    }
  }

  Future<void> _autoCreateEvent(BuildContext context) async {
    final now = DateTime.now();
    final eventName = 'テストイベント_${now.hour}${now.minute}${now.second}';
    final eventDate = now.add(const Duration(days: 3));

    try {
      final createEvent = ref.read(createEventProvider);
      await createEvent(
        circleId: widget.circleId,
        name: eventName,
        description: 'デバッグ用に自動作成されたイベント',
        datetime: eventDate,
        location: 'テスト会場',
        maxParticipants: '10',
        fee: '1000',
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('「$eventName」を作成しました'),
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
  }
}

// イベント一覧タブ
class _EventListTab extends ConsumerStatefulWidget {
  final String circleId;

  const _EventListTab({
    required this.circleId,
  });

  @override
  ConsumerState<_EventListTab> createState() => _EventListTabState();
}

class _EventListTabState extends ConsumerState<_EventListTab> {
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
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.event_busy,
                    size: 80,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'イベントがありません',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '右上の+ボタンからテストイベントを作成できます',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
      error: (error, stack) => Center(
        child: Text('エラーが発生しました: $error'),
      ),
    );
  }

  Widget _buildListView(List<EventModel> events) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        return _ParticipantEventCard(
          event: event,
          circleId: widget.circleId,
        );
      },
    );
  }

  Widget _buildCalendarView(List<EventModel> events) {
    return _ParticipantCalendarView(
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

// 参加者用イベントカード
class _ParticipantEventCard extends ConsumerWidget {
  final EventModel event;
  final String circleId;

  const _ParticipantEventCard({
    required this.event,
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

    return Opacity(
      opacity: event.isPublished ? 1.0 : 0.5,
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => ParticipantEventDetailScreen(
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
                          const Icon(Icons.access_time,
                              size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Expanded(
                            child: _buildDateTimeText(
                                event.datetime, event.endDatetime),
                          ),
                        ],
                      ),
                      if (event.location != null) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.location_on,
                                size: 14, color: Colors.grey),
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
                                  isParticipating
                                      ? Icons.check_circle
                                      : Icons.people,
                                  size: 14,
                                  color: isParticipating
                                      ? Colors.green
                                      : Colors.grey[700],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isParticipating
                                      ? '参加中'
                                      : '${event.confirmedCount}/${event.maxParticipants}${event.isMaxParticipantsNumeric ? "人" : ""}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isParticipating
                                        ? Colors.green
                                        : Colors.grey[700],
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
                          if (event.fee != null && event.fee!.isNotEmpty)
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
                                event.isFeeNumeric ? '¥${event.fee}' : event.fee!,
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
      ),
    );
  }

  Widget _buildDateTimeText(DateTime startDateTime, DateTime? endDateTime) {
    final dateFormat = DateFormat('yyyy/MM/dd (E) HH:mm', 'ja');
    final dateOnlyFormat = DateFormat('yyyy/MM/dd (E)', 'ja');
    final timeFormat = DateFormat('HH:mm', 'ja');

    // 時刻が00:00かチェック
    final startHasTime = startDateTime.hour != 0 || startDateTime.minute != 0;
    final endHasTime = endDateTime != null &&
        (endDateTime.hour != 0 || endDateTime.minute != 0);

    if (endDateTime == null) {
      return Text(
        startHasTime
            ? dateFormat.format(startDateTime)
            : dateOnlyFormat.format(startDateTime),
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

// メンバータブ
class _MembersTab extends ConsumerWidget {
  final String circleId;

  const _MembersTab({
    required this.circleId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final circleAsync = ref.watch(circleProvider(circleId));

    return circleAsync.when(
      data: (circle) {
        if (circle == null) {
          return const Center(
            child: Text('サークル情報を取得できませんでした'),
          );
        }

        if (circle.members.isEmpty) {
          return const Center(
            child: Text('メンバーがいません'),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: circle.members.length,
          itemBuilder: (context, index) {
            final member = circle.members[index];
            return _MemberCard(
              circleId: circleId,
              member: member,
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text('エラーが発生しました: $error'),
      ),
    );
  }
}

// メンバーカード
class _MemberCard extends ConsumerWidget {
  final String circleId;
  final dynamic member;

  const _MemberCard({
    required this.circleId,
    required this.member,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userDataAsync = ref.watch(userDataProvider(member.userId));
    final currentUser = ref.watch(authStateProvider).value;
    final isCurrentUser = currentUser?.uid == member.userId;

    return userDataAsync.when(
      data: (userData) {
        // サークル固有の表示名を優先
        final displayName = member.displayName ?? userData?.name ?? '名前未設定';
        final profileImageUrl = userData?.profileImageUrl;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundImage: profileImageUrl != null
                  ? NetworkImage(profileImageUrl)
                  : null,
              child: profileImageUrl == null ? const Icon(Icons.person) : null,
            ),
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    displayName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isCurrentUser) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
            ),
            subtitle: Text(
              member.role == 'admin' ? '管理者' : 'メンバー',
              style: TextStyle(
                color: member.role == 'admin' ? Colors.blue : Colors.grey[700],
                fontWeight: member.role == 'admin'
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
            trailing: member.tags.isNotEmpty
                ? Wrap(
                    spacing: 4,
                    children: member.tags
                        .map<Widget>((tag) => Chip(
                              label: Text(
                                tag as String,
                                style: const TextStyle(fontSize: 12),
                              ),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                            ))
                        .toList(),
                  )
                : null,
            onTap: () {
              if (isCurrentUser) {
                _showEditNameDialog(
                    context, ref, circleId, member.userId, displayName);
              } else {
                _showMemberProfileDialog(context, ref, member, userData);
              }
            },
          ),
        );
      },
      loading: () => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          leading: const CircleAvatar(
            child: Icon(Icons.person),
          ),
          title: const Text('読み込み中...'),
          subtitle: Text(
            member.role == 'admin' ? '管理者' : 'メンバー',
          ),
        ),
      ),
      error: (error, stack) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          leading: const CircleAvatar(
            child: Icon(Icons.person),
          ),
          title: Text('User ID: ${member.userId}'),
          subtitle: Text(
            member.role == 'admin' ? '管理者' : 'メンバー',
          ),
        ),
      ),
    );
  }

  void _showEditNameDialog(BuildContext context, WidgetRef ref, String circleId,
      String userId, String currentName) {
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

  void _showMemberProfileDialog(
    BuildContext context,
    WidgetRef ref,
    dynamic member,
    dynamic userData,
  ) {
    final displayName = member.displayName ?? userData?.name ?? '名前未設定';
    final profileImageUrl = userData?.profileImageUrl;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
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
            const SizedBox(height: 8),
            // 役割
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: member.role == 'admin'
                    ? Colors.blue.shade100
                    : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                member.role == 'admin' ? '管理者' : 'メンバー',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: member.role == 'admin'
                      ? Colors.blue.shade800
                      : Colors.grey.shade800,
                ),
              ),
            ),
            // タグ
            if (member.tags.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: member.tags
                    .map<Widget>((tag) => Chip(
                          label: Text(tag as String),
                          backgroundColor: Colors.grey.shade200,
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }
}

// プロフィールタブ
class _ProfileTab extends ConsumerWidget {
  final String circleId;

  const _ProfileTab({
    required this.circleId,
  });

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
            final members =
                circle?.members.where((m) => m.userId == currentUser.uid);
            final member = (members?.isEmpty ?? true) ? null : members!.first;
            final displayName =
                member?.displayName ?? userData?.name ?? '名前未設定';

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
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
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
        ) ??
        const Center(child: CircularProgressIndicator());
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
class _ParticipantCalendarView extends ConsumerWidget {
  final String circleId;
  final List<EventModel> events;
  final DateTime focusedDay;
  final DateTime? selectedDay;
  final void Function(DateTime selectedDay, DateTime focusedDay) onDaySelected;
  final void Function(DateTime focusedDay) onPageChanged;

  const _ParticipantCalendarView({
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
    final eventsForSelectedDay =
        selectedDay != null ? _getEventsForDay(selectedDay!) : [];

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
                        return _ParticipantEventCard(
                          event: eventsForSelectedDay[index],
                          circleId: circleId,
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
