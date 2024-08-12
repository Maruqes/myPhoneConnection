import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:ui';

import 'package:awesome_notifications/awesome_notifications.dart';

import 'package:myphoneconnection/main.dart';
import 'package:myphoneconnection/server.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
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

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  publicGallery.initGallery();
  Timer.periodic(const Duration(seconds: 10), (timer) async {
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

class Notify {
  static Future<void> notify(String title, String body) async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: Random().nextInt(100),
        channelKey: 'basic_channel',
        title: title,
        body: body,
      ),
    );
  }

  //set a new media player notification with buttons
  static Future<void> notifyMediaPlayer(String title, String body) async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: Random().nextInt(100),
        channelKey: 'basic_channel',
        title: title,
        body: body,
        category: NotificationCategory.Transport,
        notificationLayout: NotificationLayout.MediaPlayer,
        color: Colors.purple.shade700,
        autoDismissible: false,
        showWhen: false,
      ),
      actionButtons: [
        NotificationActionButton(
          key: 'pause',
          label: 'Pause',
          icon: 'resource://drawable/res_pause',
          autoDismissible: false,
          showInCompactView: true,
        ),
        NotificationActionButton(
          key: 'next',
          label: 'Next',
          icon: 'resource://drawable/res_next',
          autoDismissible: false,
          showInCompactView: true,
        ),
        NotificationActionButton(
          key: 'previous',
          label: 'Previous',
          icon: 'resource://drawable/res_previous',
          autoDismissible: false,
          showInCompactView: true,
        ),
      ],
    );
  }
}
