import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

/// Firebase Emulatorに接続するための設定
class FirebaseEmulatorConfig {
  static const bool useEmulator = kDebugMode; // デバッグモードでのみエミュレータを使用

  static void connectToEmulator() {
    if (!useEmulator) return;

    const emulatorHost = 'localhost';

    // Firestore Emulator
    FirebaseFirestore.instance.useFirestoreEmulator(emulatorHost, 8080);

    // Authentication Emulator
    FirebaseAuth.instance.useAuthEmulator(emulatorHost, 9099);

    // Storage Emulator
    FirebaseStorage.instance.useStorageEmulator(emulatorHost, 9199);

    print('🔧 Firebase Emulator に接続しました');
  }
}
