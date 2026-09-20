import 'package:flutter/services.dart';

/// A native bridge service that dispatches real-time download progress and
/// completion notifications to the Android Notification Shade.
class DownloadNotificationService {
  static const MethodChannel _channel = MethodChannel('com.localspotify.app/downloads');

  static Future<void> updateProgress({
    required String id,
    required String title,
    required String artist,
    required int progress,
    bool isIndeterminate = false,
  }) async {
    try {
      await _channel.invokeMethod('updateDownloadProgress', {
        'id': id,
        'title': title,
        'artist': artist,
        'progress': progress,
        'isIndeterminate': isIndeterminate,
      });
    } catch (_) {}
  }

  static Future<void> complete({
    required String id,
    required String title,
    required String artist,
  }) async {
    try {
      await _channel.invokeMethod('completeDownload', {
        'id': id,
        'title': title,
        'artist': artist,
      });
    } catch (_) {}
  }

  static Future<void> cancel(String id) async {
    try {
      await _channel.invokeMethod('cancelDownloadNotification', {
        'id': id,
      });
    } catch (_) {}
  }
}
