import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/storage_service.dart';

// StorageServiceのProvider
final storageServiceProvider = Provider<StorageService>((ref) => StorageService());

// プロフィール画像アップロードのProvider
final uploadProfileImageProvider = Provider<Future<String?> Function({
  required String circleId,
  required String userId,
  required File imageFile,
})>((ref) {
  return ({
    required String circleId,
    required String userId,
    required File imageFile,
  }) async {
    final storageService = ref.read(storageServiceProvider);
    return await storageService.uploadProfileImage(
      circleId: circleId,
      userId: userId,
      imageFile: imageFile,
    );
  };
});

// プロフィール画像削除のProvider
final deleteProfileImageProvider = Provider<Future<bool> Function({
  required String circleId,
  required String userId,
})>((ref) {
  return ({
    required String circleId,
    required String userId,
  }) async {
    final storageService = ref.read(storageServiceProvider);
    return await storageService.deleteProfileImage(
      circleId: circleId,
      userId: userId,
    );
  };
});
