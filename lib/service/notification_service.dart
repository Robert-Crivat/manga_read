import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  bool _isAvailable = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      await _flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse details) {
          // Gestisce il tap sulla notifica
          if (kDebugMode) {
            print('Notification tapped: ${details.payload}');
          }
        },
      );

      _isAvailable = true;
      _isInitialized = true;
    } catch (e) {
      if (kDebugMode) {
        print('Notifiche non disponibili: $e');
      }
      _isAvailable = false;
      _isInitialized = true;
    }
  }

  Future<void> showDownloadProgress({
    required String mangaTitle,
    required int currentChapter,
    required int totalChapters,
    required double progress,
    String? currentImageInfo,
  }) async {
    if (!_isInitialized) await initialize();
    if (!_isAvailable) return; // Ignora se notifiche non disponibili

    try {
      final int notificationId = mangaTitle.hashCode;
      
      // Calcola il progresso complessivo
      final double chapterProgress = (currentChapter - 1) / totalChapters;
      final double imageProgress = progress / totalChapters;
      final double totalProgress = chapterProgress + imageProgress;
      final int progressPercent = (totalProgress * 100).round().clamp(0, 100);

      String title = 'Download $mangaTitle';
      String body = 'Capitolo $currentChapter/$totalChapters';
      if (currentImageInfo != null) {
        body += ' - $currentImageInfo';
      }
      body += ' ($progressPercent%)';

      const DarwinNotificationDetails iosNotificationDetails =
          DarwinNotificationDetails(
        presentAlert: false,
        presentBadge: true,
        presentSound: false,
      );

      final AndroidNotificationDetails androidDetailsWithProgress =
          AndroidNotificationDetails(
        'manga_download_channel',
        'Download Manga',
        channelDescription: 'Notifiche per il download dei manga',
        importance: Importance.low,
        priority: Priority.low,
        showProgress: true,
        maxProgress: 100,
        progress: progressPercent,
        playSound: false,
        enableVibration: false,
        ongoing: true,
        autoCancel: false,
        icon: '@mipmap/ic_launcher',
      );

      final NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetailsWithProgress,
        iOS: iosNotificationDetails,
      );

      await _flutterLocalNotificationsPlugin.show(
        notificationId,
        title,
        body,
        notificationDetails,
        payload: 'download_$mangaTitle',
      );
    } catch (e) {
      if (kDebugMode) {
        print('Errore mostrando notifica progresso: $e');
      }
    }
  }

  Future<void> showDownloadCompleted({
    required String mangaTitle,
    required int totalChapters,
  }) async {
    if (!_isInitialized) await initialize();
    if (!_isAvailable) return; // Ignora se notifiche non disponibili

    try {
      final int notificationId = mangaTitle.hashCode;

      const AndroidNotificationDetails androidNotificationDetails =
          AndroidNotificationDetails(
        'manga_download_channel',
        'Download Manga',
        channelDescription: 'Notifiche per il download dei manga',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        playSound: true,
        enableVibration: true,
        autoCancel: true,
        icon: '@mipmap/ic_launcher',
      );

      const DarwinNotificationDetails iosNotificationDetails =
          DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidNotificationDetails,
        iOS: iosNotificationDetails,
      );

      await _flutterLocalNotificationsPlugin.show(
        notificationId,
        'Download Completato',
        '$mangaTitle - $totalChapters capitoli scaricati',
        notificationDetails,
        payload: 'completed_$mangaTitle',
      );
    } catch (e) {
      if (kDebugMode) {
        print('Errore mostrando notifica completamento: $e');
      }
    }
  }

  Future<void> showDownloadError({
    required String mangaTitle,
    required String errorMessage,
  }) async {
    if (!_isInitialized) await initialize();
    if (!_isAvailable) return; // Ignora se notifiche non disponibili

    try {
      final int notificationId = mangaTitle.hashCode + 1000; // ID diverso per errori

      const AndroidNotificationDetails androidNotificationDetails =
          AndroidNotificationDetails(
        'manga_download_channel',
        'Download Manga',
        channelDescription: 'Notifiche per il download dei manga',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        autoCancel: true,
        icon: '@mipmap/ic_launcher',
      );

      const DarwinNotificationDetails iosNotificationDetails =
          DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidNotificationDetails,
        iOS: iosNotificationDetails,
      );

      await _flutterLocalNotificationsPlugin.show(
        notificationId,
        'Errore Download',
        '$mangaTitle: $errorMessage',
        notificationDetails,
        payload: 'error_$mangaTitle',
      );
    } catch (e) {
      if (kDebugMode) {
        print('Errore mostrando notifica errore: $e');
      }
    }
  }

  Future<void> cancelDownloadNotification(String mangaTitle) async {
    if (!_isInitialized) await initialize();
    if (!_isAvailable) return; // Ignora se notifiche non disponibili
    
    try {
      final int notificationId = mangaTitle.hashCode;
      await _flutterLocalNotificationsPlugin.cancel(notificationId);
    } catch (e) {
      if (kDebugMode) {
        print('Errore cancellando notifica: $e');
      }
    }
  }

  Future<void> cancelAllNotifications() async {
    if (!_isInitialized) await initialize();
    if (!_isAvailable) return; // Ignora se notifiche non disponibili
    
    try {
      await _flutterLocalNotificationsPlugin.cancelAll();
    } catch (e) {
      if (kDebugMode) {
        print('Errore cancellando tutte le notifiche: $e');
      }
    }
  }
}