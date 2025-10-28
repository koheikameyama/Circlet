import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'logger_service.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// プロフィール画像をアップロード
  Future<String?> uploadProfileImage({
    required String circleId,
    required String userId,
    required File imageFile,
  }) async {
    try {
      final ref = _storage.ref().child('profiles/$circleId/$userId.jpg');

      // メタデータを設定
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'uploadedBy': userId,
          'circleId': circleId,
        },
      );

      // アップロード
      await ref.putFile(imageFile, metadata);

      // ダウンロードURLを取得
      final downloadUrl = await ref.getDownloadURL();

      AppLogger.info('Profile image uploaded successfully: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      AppLogger.error('Error uploading profile image: $e');
      return null;
    }
  }

  /// プロフィール画像を削除
  Future<bool> deleteProfileImage({
    required String circleId,
    required String userId,
  }) async {
    try {
      final ref = _storage.ref().child('profiles/$circleId/$userId.jpg');
      await ref.delete();

      AppLogger.info('Profile image deleted successfully');
      return true;
    } catch (e) {
      AppLogger.error('Error deleting profile image: $e');
      return false;
    }
  }

  /// サークルアイコンをアップロード
  Future<String?> uploadCircleIcon({
    required String circleId,
    required File imageFile,
  }) async {
    try {
      final ref = _storage.ref().child('circles/$circleId/icon.jpg');

      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
      );

      await ref.putFile(imageFile, metadata);
      final downloadUrl = await ref.getDownloadURL();

      AppLogger.info('Circle icon uploaded successfully: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      AppLogger.error('Error uploading circle icon: $e');
      return null;
    }
  }
}
