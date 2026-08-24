import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'api_client.dart';

class FcmService {
  static final FcmService _instance = FcmService._internal();
  factory FcmService() => _instance;
  FcmService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  Future<void> init() async {
    try {
      // Request permissions
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('User granted permission');
      } else {
        debugPrint('User declined or has not accepted permission');
        return;
      }

      // Get FCM token
      String? token = await _messaging.getToken();
      if (token != null) {
        debugPrint('FCM Token: $token');
        await sendTokenToServer(token);
      }

      // Listen to token refresh
      _messaging.onTokenRefresh.listen((newToken) {
        sendTokenToServer(newToken);
      });

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Got a message whilst in the foreground!');
        debugPrint('Message data: ${message.data}');

        if (message.notification != null) {
          debugPrint('Message also contained a notification: ${message.notification}');
        }
      });
      
    } catch (e) {
      debugPrint('Failed to initialize FCM: $e');
    }
  }

  Future<void> sendTokenToServer(String token) async {
    try {
      // Send token to backend. ApiClient automatically attaches the JWT token.
      final res = await ApiClient().dio.post('/auth/fcm-token', data: {'token': token});
      if (res.data['success']) {
        debugPrint('FCM token registered with server successfully');
      }
    } catch (e) {
      debugPrint('Failed to send FCM token to server: $e');
    }
  }
}
