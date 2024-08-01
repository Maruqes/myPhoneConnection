import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:ui';

import 'package:myphoneconnection/main.dart';
import 'package:myphoneconnection/server.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:myphoneconnection/galleryFunctions.dart';

class ListenToPort {
  List<Device> devicesTempToAdd = [];

  void initListenPort() {
    ReceivePort port = ReceivePort();
    IsolateNameServer.registerPortWithName(port.sendPort, 'addDevice');
    // Listen for messages from the background isolate
    port.listen((device) {
      Device newDevice = Device(
        device['hostname'],
        device['os'],
        device['CPU'],
        device['RAM'],
        device['ip'],
        device['port'],
      );

      devicesTempToAdd = List.from(devicesTempToAdd)..add(newDevice);
    });

    ReceivePort port2 = ReceivePort();
    IsolateNameServer.registerPortWithName(port2.sendPort, 'clearDevices');
    // Listen for messages from the background isolate
    port2.listen((_) {
      devicesTempToAdd = List.empty(growable: true);
    });

    ReceivePort port3 = ReceivePort();
    IsolateNameServer.registerPortWithName(port3.sendPort, 'setDevices');
    port3.listen((_) {
      globalDeviceListNotifier.value = List.from(devicesTempToAdd);
    });
  }
}

class LocalNotificationService {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    // Initialize native android notification
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // Initialize native Ios Notifications
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings();

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
    );
  }

  void showNotificationAndroid(String title, String value) async {
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails('channel_id', 'Channel Name',
            channelDescription: 'Channel Description',
            importance: Importance.max,
            priority: Priority.high,
            ticker: 'ticker');

    int notificationId = 1;
    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidNotificationDetails);

    await flutterLocalNotificationsPlugin.show(
        notificationId, title, value, notificationDetails,
        payload: 'Not present');
  }
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  Timer.periodic(const Duration(seconds: 5), (timer) async {
    publicGallery.checkNumberOfImagesOnGallery();

    debugPrint("Checking connection ${connectionPC.ws.checkWsConnection()}");
    if (connectionPC.ws.checkWsConnection() == false) {
      connectionPC.startProtocol(8080);
    } else {}
  });
}

class PcService {
  void startBackgroundService() {
    final service = FlutterBackgroundService();
    service.startService();
  }

  void stopBackgroundService() {
    final service = FlutterBackgroundService();
    service.invoke("stop");
  }

  Future<void> initializeService() async {
    final service = FlutterBackgroundService();

    await service.configure(
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
      androidConfiguration: AndroidConfiguration(
        autoStart: true,
        onStart: onStart,
        isForegroundMode: true,
        initialNotificationContent: "Running in the background",
        initialNotificationTitle: "Background Service",
        autoStartOnBoot: true,
      ),
    );
  }
}
