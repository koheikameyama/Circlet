import 'package:cloud_firestore/cloud_firestore.dart';

enum PaymentStatus {
  pending,
  completed,
  failed,
  refunded,
}

enum PaymentMethod {
  paypay,
  cash,
  other,
}

class PaymentModel {
  final String paymentId;
  final String userId;
  final String eventId;
  final String circleId;
  final int amount;
  final PaymentStatus status;
  final PaymentMethod method;
  final String? transactionId; // PayPay等の外部決済IDを保存
  final DateTime? paidAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  PaymentModel({
    required this.paymentId,
    required this.userId,
    required this.eventId,
    required this.circleId,
    required this.amount,
    required this.status,
    required this.method,
    this.transactionId,
    this.paidAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PaymentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PaymentModel(
      paymentId: doc.id,
      userId: data['userId'] ?? '',
      eventId: data['eventId'] ?? '',
      circleId: data['circleId'] ?? '',
      amount: data['amount'] ?? 0,
      status: PaymentStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => PaymentStatus.pending,
      ),
      method: PaymentMethod.values.firstWhere(
        (e) => e.name == data['method'],
        orElse: () => PaymentMethod.paypay,
      ),
      transactionId: data['transactionId'],
      paidAt: data['paidAt'] != null
          ? (data['paidAt'] as Timestamp).toDate()
          : null,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'eventId': eventId,
      'circleId': circleId,
      'amount': amount,
      'status': status.name,
      'method': method.name,
      'transactionId': transactionId,
      'paidAt': paidAt != null ? Timestamp.fromDate(paidAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  PaymentModel copyWith({
    String? paymentId,
    String? userId,
    String? eventId,
    String? circleId,
    int? amount,
    PaymentStatus? status,
    PaymentMethod? method,
    String? transactionId,
    DateTime? paidAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PaymentModel(
      paymentId: paymentId ?? this.paymentId,
      userId: userId ?? this.userId,
      eventId: eventId ?? this.eventId,
      circleId: circleId ?? this.circleId,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      method: method ?? this.method,
      transactionId: transactionId ?? this.transactionId,
      paidAt: paidAt ?? this.paidAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isPaid => status == PaymentStatus.completed;
  bool get isPending => status == PaymentStatus.pending;
}
