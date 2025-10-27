import 'package:cloud_firestore/cloud_firestore.dart';

enum CancellationRequestStatus {
  pending,   // 承認待ち
  approved,  // 承認済み
  rejected,  // 却下
}

/// キャンセル申請
class CancellationRequestModel {
  final String requestId;
  final String eventId;
  final String userId; // 申請者のユーザーID
  final String reason; // キャンセル理由
  final CancellationRequestStatus status;
  final DateTime createdAt;
  final DateTime? processedAt; // 処理日時
  final String? processedBy; // 処理した管理者のID

  CancellationRequestModel({
    required this.requestId,
    required this.eventId,
    required this.userId,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.processedAt,
    this.processedBy,
  });

  /// FirestoreからCancellationRequestModelを作成
  factory CancellationRequestModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return CancellationRequestModel(
      requestId: doc.id,
      eventId: data['eventId'] as String,
      userId: data['userId'] as String,
      reason: data['reason'] as String,
      status: CancellationRequestStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => CancellationRequestStatus.pending,
      ),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      processedAt: data['processedAt'] != null
          ? (data['processedAt'] as Timestamp).toDate()
          : null,
      processedBy: data['processedBy'] as String?,
    );
  }

  /// FirestoreへのMap変換
  Map<String, dynamic> toFirestore() {
    return {
      'eventId': eventId,
      'userId': userId,
      'reason': reason,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'processedAt':
          processedAt != null ? Timestamp.fromDate(processedAt!) : null,
      'processedBy': processedBy,
    };
  }

  /// コピーメソッド
  CancellationRequestModel copyWith({
    String? requestId,
    String? eventId,
    String? userId,
    String? reason,
    CancellationRequestStatus? status,
    DateTime? createdAt,
    DateTime? processedAt,
    String? processedBy,
  }) {
    return CancellationRequestModel(
      requestId: requestId ?? this.requestId,
      eventId: eventId ?? this.eventId,
      userId: userId ?? this.userId,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      processedAt: processedAt ?? this.processedAt,
      processedBy: processedBy ?? this.processedBy,
    );
  }

  /// 承認待ちかどうか
  bool get isPending => status == CancellationRequestStatus.pending;

  /// 承認済みかどうか
  bool get isApproved => status == CancellationRequestStatus.approved;

  /// 却下されたかどうか
  bool get isRejected => status == CancellationRequestStatus.rejected;
}
