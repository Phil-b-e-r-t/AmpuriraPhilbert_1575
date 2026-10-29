import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class FirebaseConfig {
  static const _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const _senderId =
      String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const _authDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
  static const _storageBucket =
      String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
  static const _webAppId = String.fromEnvironment('FIREBASE_WEB_APP_ID');
  static const _androidAppId =
      String.fromEnvironment('FIREBASE_ANDROID_APP_ID');
  static const _iosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');
  static const _iosBundleId = String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID');

  static bool get isConfigured {
    final appId = switch (defaultTargetPlatform) {
      TargetPlatform.android => _androidAppId,
      TargetPlatform.iOS => _iosAppId,
      _ => kIsWeb ? _webAppId : '',
    };
    return _apiKey.isNotEmpty &&
        _senderId.isNotEmpty &&
        _projectId.isNotEmpty &&
        appId.isNotEmpty &&
        (!kIsWeb || _authDomain.isNotEmpty) &&
        (defaultTargetPlatform != TargetPlatform.iOS ||
            _iosBundleId.isNotEmpty);
  }

  static FirebaseOptions get currentPlatform {
    if (!isConfigured) {
      throw StateError('Firebase configuration is incomplete.');
    }

    return FirebaseOptions(
      apiKey: _apiKey,
      appId: kIsWeb
          ? _webAppId
          : switch (defaultTargetPlatform) {
              TargetPlatform.android => _androidAppId,
              TargetPlatform.iOS => _iosAppId,
              _ => throw UnsupportedError(
                  'Firebase sign-in is configured for Android, iOS, and web.'),
            },
      messagingSenderId: _senderId,
      projectId: _projectId,
      authDomain: kIsWeb ? _authDomain : null,
      storageBucket: _storageBucket.isEmpty ? null : _storageBucket,
      iosBundleId:
          defaultTargetPlatform == TargetPlatform.iOS ? _iosBundleId : null,
    );
  }
}
