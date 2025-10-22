import 'package:cloud_firestore/cloud_firestore.dart';

enum ParticipationStatus {
  confirmed,
  waitlist,
  cancelled,
}

class EventParticipant {
  final String userId;
  final ParticipationStatus status;
  final int? waitingNumber;
  final DateTime registeredAt;

  EventParticipant({
    required this.userId,
    required this.status,
    this.waitingNumber,
    required this.registeredAt,
  });

  factory EventParticipant.fromMap(Map<String, dynamic> data) {
    return EventParticipant(
      userId: data['userId'] ?? '',
      status: ParticipationStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => ParticipationStatus.confirmed,
      ),
      waitingNumber: data['waitingNumber'],
      registeredAt: (data['registeredAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'status': status.name,
      'waitingNumber': waitingNumber,
      'registeredAt': Timestamp.fromDate(registeredAt),
    };
  }

  EventParticipant copyWith({
    String? userId,
    ParticipationStatus? status,
    int? waitingNumber,
    DateTime? registeredAt,
  }) {
    return EventParticipant(
      userId: userId ?? this.userId,
      status: status ?? this.status,
      waitingNumber: waitingNumber ?? this.waitingNumber,
      registeredAt: registeredAt ?? this.registeredAt,
    );
  }
}

class EventModel {
  final String eventId;
  final String circleId;
  final String name;
  final String? description;
  final DateTime datetime;
  final DateTime? endDatetime;
  final String? location;
  final int maxParticipants;
  final int? fee;
  final List<EventParticipant> participants;
  final DateTime createdAt;
  final DateTime updatedAt;

  EventModel({
    required this.eventId,
    required this.circleId,
    required this.name,
    this.description,
    required this.datetime,
    this.endDatetime,
    this.location,
    required this.maxParticipants,
    this.fee,
    required this.participants,
    required this.createdAt,
    required this.updatedAt,
  });

  factory EventModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return EventModel(
      eventId: doc.id,
      circleId: data['circleId'] ?? '',
      name: data['name'] ?? '',
      description: data['description'],
      datetime: (data['datetime'] as Timestamp).toDate(),
      endDatetime: data['endDatetime'] != null
          ? (data['endDatetime'] as Timestamp).toDate()
          : null,
      location: data['location'],
      maxParticipants: data['maxParticipants'] ?? 0,
      fee: data['fee'],
      participants: (data['participants'] as List<dynamic>?)
              ?.map((p) => EventParticipant.fromMap(p as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'circleId': circleId,
      'name': name,
      'description': description,
      'datetime': Timestamp.fromDate(datetime),
      'endDatetime': endDatetime != null ? Timestamp.fromDate(endDatetime!) : null,
      'location': location,
      'maxParticipants': maxParticipants,
      'fee': fee,
      'participants': participants.map((p) => p.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  EventModel copyWith({
    String? eventId,
    String? circleId,
    String? name,
    String? description,
    DateTime? datetime,
    DateTime? endDatetime,
    String? location,
    int? maxParticipants,
    int? fee,
    List<EventParticipant>? participants,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EventModel(
      eventId: eventId ?? this.eventId,
      circleId: circleId ?? this.circleId,
      name: name ?? this.name,
      description: description ?? this.description,
      datetime: datetime ?? this.datetime,
      endDatetime: endDatetime ?? this.endDatetime,
      location: location ?? this.location,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      fee: fee ?? this.fee,
      participants: participants ?? this.participants,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  int get confirmedCount =>
      participants.where((p) => p.status == ParticipationStatus.confirmed).length;

  int get waitlistCount =>
      participants.where((p) => p.status == ParticipationStatus.waitlist).length;

  bool get isFull => confirmedCount >= maxParticipants;

  bool isUserParticipating(String userId) =>
      participants.any((p) => p.userId == userId && p.status == ParticipationStatus.confirmed);

  bool isUserOnWaitlist(String userId) =>
      participants.any((p) => p.userId == userId && p.status == ParticipationStatus.waitlist);

  ParticipationStatus? getUserStatus(String userId) {
    final participant = participants.where((p) => p.userId == userId).firstOrNull;
    return participant?.status;
  }
}
