import 'package:device_calendar/device_calendar.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/event_model.dart';

class CalendarService {
  final DeviceCalendarPlugin _deviceCalendarPlugin = DeviceCalendarPlugin();

  // カレンダー権限をリクエスト
  Future<bool> requestCalendarPermission() async {
    try {
      final permissionStatus = await Permission.calendar.request();
      return permissionStatus.isGranted;
    } catch (e) {
      print('Error requesting calendar permission: $e');
      return false;
    }
  }

  // デバイスのカレンダー一覧を取得
  Future<List<Calendar>> getCalendars() async {
    try {
      final hasPermission = await requestCalendarPermission();
      if (!hasPermission) {
        print('Calendar permission denied');
        return [];
      }

      final calendarsResult = await _deviceCalendarPlugin.retrieveCalendars();
      return calendarsResult.data ?? [];
    } catch (e) {
      print('Error getting calendars: $e');
      return [];
    }
  }

  // デフォルトカレンダーを取得
  Future<Calendar?> getDefaultCalendar() async {
    try {
      final calendars = await getCalendars();
      if (calendars.isEmpty) return null;

      // デフォルトのカレンダーを探す
      final defaultCalendar = calendars.firstWhere(
        (calendar) => calendar.isDefault ?? false,
        orElse: () => calendars.first,
      );

      return defaultCalendar;
    } catch (e) {
      print('Error getting default calendar: $e');
      return null;
    }
  }

  // イベントをカレンダーに追加
  Future<String?> addEventToCalendar({
    required EventModel event,
    String? calendarId,
  }) async {
    try {
      final hasPermission = await requestCalendarPermission();
      if (!hasPermission) {
        print('Calendar permission denied');
        return null;
      }

      // カレンダーIDが指定されていない場合はデフォルトカレンダーを使用
      String? targetCalendarId = calendarId;
      if (targetCalendarId == null) {
        final defaultCalendar = await getDefaultCalendar();
        if (defaultCalendar == null) {
          print('No calendar available');
          return null;
        }
        targetCalendarId = defaultCalendar.id;
      }

      final calendarEvent = Event(
        targetCalendarId,
        title: event.name,
        description: event.description,
        start: TZDateTime.from(event.datetime, local),
        end: TZDateTime.from(
          event.datetime.add(const Duration(hours: 2)), // デフォルト2時間
          local,
        ),
        location: event.location,
      );

      final createEventResult = await _deviceCalendarPlugin.createOrUpdateEvent(
        calendarEvent,
      );

      if (createEventResult?.isSuccess ?? false) {
        return createEventResult!.data;
      } else {
        print('Failed to create calendar event');
        return null;
      }
    } catch (e) {
      print('Error adding event to calendar: $e');
      return null;
    }
  }

  // カレンダーからイベントを削除
  Future<bool> deleteEventFromCalendar({
    required String calendarId,
    required String eventId,
  }) async {
    try {
      final hasPermission = await requestCalendarPermission();
      if (!hasPermission) {
        print('Calendar permission denied');
        return false;
      }

      final deleteResult = await _deviceCalendarPlugin.deleteEvent(
        calendarId,
        eventId,
      );

      return deleteResult?.isSuccess ?? false;
    } catch (e) {
      print('Error deleting event from calendar: $e');
      return false;
    }
  }

  // イベントをカレンダーで更新
  Future<bool> updateEventInCalendar({
    required String calendarId,
    required String eventId,
    required EventModel event,
  }) async {
    try {
      final hasPermission = await requestCalendarPermission();
      if (!hasPermission) {
        print('Calendar permission denied');
        return false;
      }

      final calendarEvent = Event(
        calendarId,
        eventId: eventId,
        title: event.name,
        description: event.description,
        start: TZDateTime.from(event.datetime, local),
        end: TZDateTime.from(
          event.datetime.add(const Duration(hours: 2)),
          local,
        ),
        location: event.location,
      );

      final updateResult = await _deviceCalendarPlugin.createOrUpdateEvent(
        calendarEvent,
      );

      return updateResult?.isSuccess ?? false;
    } catch (e) {
      print('Error updating event in calendar: $e');
      return false;
    }
  }

  // カレンダーイベントIDを保存するためのヘルパー
  // これは実際にはFirestoreに保存する必要がある
  final Map<String, Map<String, String>> _eventCalendarMapping = {};

  void saveEventCalendarMapping({
    required String eventId,
    required String calendarId,
    required String calendarEventId,
  }) {
    _eventCalendarMapping[eventId] = {
      'calendarId': calendarId,
      'calendarEventId': calendarEventId,
    };
  }

  Map<String, String>? getEventCalendarMapping(String eventId) {
    return _eventCalendarMapping[eventId];
  }

  void removeEventCalendarMapping(String eventId) {
    _eventCalendarMapping.remove(eventId);
  }
}

// タイムゾーンのヘルパー（device_calendarではtimezoneパッケージが必要）
final local = getLocation('Asia/Tokyo');

Location getLocation(String locationName) {
  // この実装は簡略化されています
  // 実際にはtimezoneパッケージを使用して適切なLocationを取得する必要があります
  return Location.fromJson({
    'name': locationName,
  });
}
