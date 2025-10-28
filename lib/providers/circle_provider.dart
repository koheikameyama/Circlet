import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/circle_model.dart';
import '../services/circle_service.dart';

// CircleServiceのProvider
final circleServiceProvider = Provider<CircleService>((ref) => CircleService());

// 選択中のサークルIDのProvider
final selectedCircleIdProvider = StateProvider<String?>((ref) => null);

// サークル情報のProvider
final circleProvider = StreamProvider.autoDispose.family<CircleModel?, String>((ref, circleId) {
  final circleService = ref.watch(circleServiceProvider);
  return circleService.getCircleStream(circleId);
});

// 選択中のサークル情報のProvider
final selectedCircleProvider = StreamProvider.autoDispose<CircleModel?>((ref) {
  final circleId = ref.watch(selectedCircleIdProvider);
  if (circleId == null) {
    return Stream.value(null);
  }

  final circleService = ref.watch(circleServiceProvider);
  return circleService.getCircleStream(circleId);
});

// ユーザーが所属するサークル一覧のProvider
final userCirclesProvider = StreamProvider.autoDispose.family<List<CircleModel>, String>((ref, userId) {
  final circleService = ref.watch(circleServiceProvider);
  return circleService.getUserCircles(userId);
});

// サークル作成のProvider
final createCircleProvider = Provider<Future<String> Function({
  required String name,
  required String description,
  required String creatorUserId,
  String? iconUrl,
})>((ref) {
  return ({
    required String name,
    required String description,
    required String creatorUserId,
    String? iconUrl,
  }) async {
    final circleService = ref.read(circleServiceProvider);
    return await circleService.createCircle(
      name: name,
      description: description,
      creatorUserId: creatorUserId,
      iconUrl: iconUrl,
    );
  };
});

// メンバー追加のProvider
final addMemberProvider = Provider<Future<void> Function({
  required String circleId,
  required String userId,
  String role,
  List<String> tags,
})>((ref) {
  return ({
    required String circleId,
    required String userId,
    String role = 'member',
    List<String> tags = const [],
  }) async {
    final circleService = ref.read(circleServiceProvider);
    await circleService.addMember(
      circleId: circleId,
      userId: userId,
      role: role,
      tags: tags,
    );
  };
});

// メンバー削除のProvider
final removeMemberProvider = Provider<Future<void> Function({
  required String circleId,
  required String userId,
})>((ref) {
  return ({
    required String circleId,
    required String userId,
  }) async {
    final circleService = ref.read(circleServiceProvider);
    await circleService.removeMember(
      circleId: circleId,
      userId: userId,
    );
  };
});

// メンバーの役割更新のProvider
final updateMemberRoleProvider = Provider<Future<void> Function({
  required String circleId,
  required String userId,
  required String role,
})>((ref) {
  return ({
    required String circleId,
    required String userId,
    required String role,
  }) async {
    final circleService = ref.read(circleServiceProvider);
    await circleService.updateMemberRole(
      circleId: circleId,
      userId: userId,
      role: role,
    );
  };
});

// サークル情報更新のProvider
final updateCircleProvider = Provider<Future<void> Function({
  required String circleId,
  String? name,
  String? description,
  String? iconUrl,
})>((ref) {
  return ({
    required String circleId,
    String? name,
    String? description,
    String? iconUrl,
  }) async {
    final circleService = ref.read(circleServiceProvider);
    await circleService.updateCircle(
      circleId: circleId,
      name: name,
      description: description,
      iconUrl: iconUrl,
    );
  };
});

// メンバーのプロフィール画像更新のProvider
final updateMemberProfileImageProvider = Provider<Future<void> Function({
  required String circleId,
  required String userId,
  required String? profileImageUrl,
})>((ref) {
  return ({
    required String circleId,
    required String userId,
    required String? profileImageUrl,
  }) async {
    final circleService = ref.read(circleServiceProvider);
    await circleService.updateMemberProfileImage(
      circleId: circleId,
      userId: userId,
      profileImageUrl: profileImageUrl,
    );
  };
});
