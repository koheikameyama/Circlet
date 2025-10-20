import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/circle_model.dart';

class CircleService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  // サークルを作成
  Future<String> createCircle({
    required String name,
    required String description,
    required String creatorUserId,
    String? iconUrl,
  }) async {
    try {
      final circleId = _uuid.v4();
      final circle = CircleModel(
        circleId: circleId,
        name: name,
        description: description,
        iconUrl: iconUrl,
        members: [
          CircleMember(
            userId: creatorUserId,
            role: 'admin',
            tags: [],
            joinedAt: DateTime.now(),
          ),
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _firestore
          .collection('circles')
          .doc(circleId)
          .set(circle.toFirestore());

      // ユーザーのcircleIdsを更新
      await _firestore.collection('users').doc(creatorUserId).update({
        'circleIds': FieldValue.arrayUnion([circleId]),
        'updatedAt': Timestamp.now(),
      });

      return circleId;
    } catch (e) {
      print('Error creating circle: $e');
      rethrow;
    }
  }

  // サークル情報を取得
  Future<CircleModel?> getCircle(String circleId) async {
    try {
      final doc = await _firestore.collection('circles').doc(circleId).get();
      if (doc.exists) {
        return CircleModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting circle: $e');
      return null;
    }
  }

  // サークル情報のストリームを取得
  Stream<CircleModel?> getCircleStream(String circleId) {
    return _firestore
        .collection('circles')
        .doc(circleId)
        .snapshots()
        .map((doc) => doc.exists ? CircleModel.fromFirestore(doc) : null);
  }

  // ユーザーが所属するサークル一覧を取得
  Stream<List<CircleModel>> getUserCircles(String userId) async* {
    // ユーザー情報を取得してcircleIdsを取得
    await for (final userDoc in _firestore.collection('users').doc(userId).snapshots()) {
      if (!userDoc.exists) {
        yield [];
        continue;
      }

      final userData = userDoc.data();
      final circleIds = (userData?['circleIds'] as List<dynamic>?)?.cast<String>() ?? [];

      if (circleIds.isEmpty) {
        yield [];
        continue;
      }

      // circleIdsに基づいてサークルを取得
      // Firestoreの制限により、in演算子は最大10件まで
      final circles = <CircleModel>[];

      // 10件ずつに分割してクエリ
      for (var i = 0; i < circleIds.length; i += 10) {
        final batch = circleIds.skip(i).take(10).toList();
        final snapshot = await _firestore
            .collection('circles')
            .where(FieldPath.documentId, whereIn: batch)
            .get();

        circles.addAll(
          snapshot.docs.map((doc) => CircleModel.fromFirestore(doc)),
        );
      }

      yield circles;
    }
  }

  // サークル情報を更新
  Future<void> updateCircle({
    required String circleId,
    String? name,
    String? description,
    String? iconUrl,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updatedAt': Timestamp.now(),
      };

      if (name != null) updates['name'] = name;
      if (description != null) updates['description'] = description;
      if (iconUrl != null) updates['iconUrl'] = iconUrl;

      await _firestore.collection('circles').doc(circleId).update(updates);
    } catch (e) {
      print('Error updating circle: $e');
      rethrow;
    }
  }

  // メンバーを追加
  Future<void> addMember({
    required String circleId,
    required String userId,
    String role = 'member',
    List<String> tags = const [],
  }) async {
    try {
      final member = CircleMember(
        userId: userId,
        role: role,
        tags: tags,
        joinedAt: DateTime.now(),
      );

      await _firestore.collection('circles').doc(circleId).update({
        'members': FieldValue.arrayUnion([member.toMap()]),
        'updatedAt': Timestamp.now(),
      });

      // ユーザーのcircleIdsを更新
      await _firestore.collection('users').doc(userId).update({
        'circleIds': FieldValue.arrayUnion([circleId]),
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      print('Error adding member: $e');
      rethrow;
    }
  }

  // メンバーを削除
  Future<void> removeMember({
    required String circleId,
    required String userId,
  }) async {
    try {
      final circle = await getCircle(circleId);
      if (circle == null) return;

      final updatedMembers = circle.members
          .where((m) => m.userId != userId)
          .map((m) => m.toMap())
          .toList();

      await _firestore.collection('circles').doc(circleId).update({
        'members': updatedMembers,
        'updatedAt': Timestamp.now(),
      });

      // ユーザーのcircleIdsを更新
      await _firestore.collection('users').doc(userId).update({
        'circleIds': FieldValue.arrayRemove([circleId]),
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      print('Error removing member: $e');
      rethrow;
    }
  }

  // メンバーのタグを更新
  Future<void> updateMemberTags({
    required String circleId,
    required String userId,
    required List<String> tags,
  }) async {
    try {
      final circle = await getCircle(circleId);
      if (circle == null) return;

      final updatedMembers = circle.members.map((m) {
        if (m.userId == userId) {
          return CircleMember(
            userId: m.userId,
            role: m.role,
            tags: tags,
            joinedAt: m.joinedAt,
          );
        }
        return m;
      }).map((m) => m.toMap()).toList();

      await _firestore.collection('circles').doc(circleId).update({
        'members': updatedMembers,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      print('Error updating member tags: $e');
      rethrow;
    }
  }

  // メンバーの役割を更新（管理者権限の付与/剥奪）
  Future<void> updateMemberRole({
    required String circleId,
    required String userId,
    required String role, // 'admin' or 'member'
  }) async {
    try {
      final circle = await getCircle(circleId);
      if (circle == null) {
        throw Exception('Circle not found');
      }

      // 少なくとも1人の管理者が必要
      if (role != 'admin') {
        final adminCount = circle.members.where((m) => m.role == 'admin').length;
        final isCurrentUserAdmin = circle.members
            .firstWhere((m) => m.userId == userId)
            .role == 'admin';

        if (isCurrentUserAdmin && adminCount <= 1) {
          throw Exception('少なくとも1人の管理者が必要です');
        }
      }

      final updatedMembers = circle.members.map((m) {
        if (m.userId == userId) {
          return CircleMember(
            userId: m.userId,
            role: role,
            tags: m.tags,
            joinedAt: m.joinedAt,
          );
        }
        return m;
      }).map((m) => m.toMap()).toList();

      await _firestore.collection('circles').doc(circleId).update({
        'members': updatedMembers,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      print('Error updating member role: $e');
      rethrow;
    }
  }

  // サークルを削除
  Future<void> deleteCircle(String circleId) async {
    try {
      final circle = await getCircle(circleId);
      if (circle == null) return;

      // 全メンバーのcircleIdsから削除
      for (final member in circle.members) {
        await _firestore.collection('users').doc(member.userId).update({
          'circleIds': FieldValue.arrayRemove([circleId]),
          'updatedAt': Timestamp.now(),
        });
      }

      // サークルに関連するイベントを削除
      final events = await _firestore
          .collection('events')
          .where('circleId', isEqualTo: circleId)
          .get();
      for (final event in events.docs) {
        await event.reference.delete();
      }

      // サークルを削除
      await _firestore.collection('circles').doc(circleId).delete();
    } catch (e) {
      print('Error deleting circle: $e');
      rethrow;
    }
  }

  // 招待リンク用のトークンを生成
  String generateInviteToken(String circleId) {
    return '$circleId:${_uuid.v4()}';
  }

  // 招待トークンからサークルIDを抽出
  String? getCircleIdFromToken(String token) {
    final parts = token.split(':');
    if (parts.length == 2) {
      return parts[0];
    }
    return null;
  }

  // デバッグ用：ダミーメンバーを追加
  Future<void> addDummyMember({
    required String circleId,
    required String name,
    String role = 'member',
  }) async {
    try {
      // ダミーのユーザーIDを生成
      final dummyUserId = 'dummy_${_uuid.v4().substring(0, 8)}';

      final member = CircleMember(
        userId: dummyUserId,
        role: role,
        tags: [],
        joinedAt: DateTime.now(),
      );

      // サークルにメンバーを追加
      await _firestore.collection('circles').doc(circleId).update({
        'members': FieldValue.arrayUnion([member.toMap()]),
        'updatedAt': Timestamp.now(),
      });

      // ダミーユーザーのドキュメントも作成（オプション）
      await _firestore.collection('users').doc(dummyUserId).set({
        'userId': dummyUserId,
        'name': name,
        'lineUserId': 'dummy_line_$dummyUserId',
        'circleIds': [circleId],
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      print('Error adding dummy member: $e');
      rethrow;
    }
  }
}
