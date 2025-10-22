import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/event_model.dart';
import '../services/event_service.dart';

// EventServiceのProvider
final eventServiceProvider = Provider<EventService>((ref) => EventService());

// イベント情報のProvider
final eventProvider = StreamProvider.family<EventModel?, String>((ref, eventId) {
  final eventService = ref.watch(eventServiceProvider);
  return eventService.getEventStream(eventId);
});

// サークルのイベント一覧のProvider
final circleEventsProvider = StreamProvider.family<List<EventModel>, String>((ref, circleId) {
  final eventService = ref.watch(eventServiceProvider);
  return eventService.getCircleEvents(circleId);
});

// ユーザーが参加するイベント一覧のProvider
final userEventsProvider = StreamProvider.family<List<EventModel>, String>((ref, userId) {
  final eventService = ref.watch(eventServiceProvider);
  return eventService.getUserEvents(userId);
});

// イベント作成のProvider
final createEventProvider = Provider<Future<String> Function({
  required String circleId,
  required String name,
  String? description,
  required DateTime datetime,
  DateTime? endDatetime,
  String? location,
  required int maxParticipants,
  int? fee,
})>((ref) {
  return ({
    required String circleId,
    required String name,
    String? description,
    required DateTime datetime,
    DateTime? endDatetime,
    String? location,
    required int maxParticipants,
    int? fee,
  }) async {
    final eventService = ref.read(eventServiceProvider);
    return await eventService.createEvent(
      circleId: circleId,
      name: name,
      description: description,
      datetime: datetime,
      endDatetime: endDatetime,
      location: location,
      maxParticipants: maxParticipants,
      fee: fee,
    );
  };
});

// イベント更新のProvider
final updateEventProvider = Provider<Future<void> Function({
  required String eventId,
  String? name,
  String? description,
  DateTime? datetime,
  DateTime? endDatetime,
  String? location,
  int? maxParticipants,
  int? fee,
})>((ref) {
  return ({
    required String eventId,
    String? name,
    String? description,
    DateTime? datetime,
    DateTime? endDatetime,
    String? location,
    int? maxParticipants,
    int? fee,
  }) async {
    final eventService = ref.read(eventServiceProvider);
    await eventService.updateEvent(
      eventId: eventId,
      name: name,
      description: description,
      datetime: datetime,
      endDatetime: endDatetime,
      location: location,
      maxParticipants: maxParticipants,
      fee: fee,
    );
  };
});

// イベント参加のProvider
final joinEventProvider = Provider<Future<void> Function({
  required String eventId,
  required String userId,
})>((ref) {
  return ({
    required String eventId,
    required String userId,
  }) async {
    final eventService = ref.read(eventServiceProvider);
    await eventService.joinEvent(
      eventId: eventId,
      userId: userId,
    );
  };
});

// イベントキャンセルのProvider
final cancelEventProvider = Provider<Future<void> Function({
  required String eventId,
  required String userId,
})>((ref) {
  return ({
    required String eventId,
    required String userId,
  }) async {
    final eventService = ref.read(eventServiceProvider);
    await eventService.cancelEvent(
      eventId: eventId,
      userId: userId,
    );
  };
});

// イベント削除のProvider
final deleteEventProvider = Provider<Future<void> Function(String eventId)>((ref) {
  return (String eventId) async {
    final eventService = ref.read(eventServiceProvider);
    await eventService.deleteEvent(eventId);
  };
});
