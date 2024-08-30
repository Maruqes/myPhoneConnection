import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_notification_listener/flutter_notification_listener.dart';
import 'package:http/http.dart' as http;
import 'package:myphoneconnection/backgroundService.dart';
import 'package:myphoneconnection/calls.dart';

import 'package:myphoneconnection/main.dart';
import 'package:myphoneconnection/server.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:myphoneconnection/galleryFunctions.dart';
import 'package:device_apps/device_apps.dart';
import 'package:awesome_notifications/awesome_notifications.dart';

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

class OurNotificationListener {
  static Future<String> getIconWithPackageName(String package) async {
    List<Application> apps = await DeviceApps.getInstalledApplications(
        onlyAppsWithLaunchIntent: true,
        includeAppIcons: true,
        includeSystemApps: true);

    for (var app in apps) {
      if (app.packageName == package) {
        String iconBase64 =
            base64.encode(app is ApplicationWithIcon ? app.icon : Uint8List(0));
        return iconBase64;
      }
    }
    return "";
  }

  void startListening() async {
    try {
      debugPrint("start listening");
      var hasPermission = await NotificationsListener.hasPermission;
      if (hasPermission == null || !hasPermission) {
        debugPrint("no permission, so open settings");
        NotificationsListener.openPermissionSettings();
        return;
      }
      var isR = await NotificationsListener.isRunning;

      if (isR == null || !isR) {
        await NotificationsListener.startService();
      }
    } catch (e) {
      debugPrint("Error in startListening: $e");
    }
  }

  @pragma('vm:entry-point')
  static Future<void> onData(NotificationEvent evt) async {
    try {
      if (evt.packageName == "com.example.myphoneconnection") return;

      String iconb64 = base64.encode(evt.largeIcon!);

      String appIcon = await getIconWithPackageName(evt.packageName!);
      connectionPC.ws.sendData("newPhoneNotification",
          "${jsonEncode(evt.toString())}//||//$iconb64//||//$appIcon//||//${evt.uniqueId}");

      debugPrint("send evt to ui: $evt");
    } catch (e) {
      debugPrint("Error in onData: $e");
    }
  }

  Future<void> initPlatformState() async {
    try {
      NotificationsListener.initialize(callbackHandle: onData);
      // register your event handler in the UI logic.
      NotificationsListener.receivePort?.listen((evt) => onData(evt));
    } catch (e) {
      debugPrint("Error in initPlatformState: $e");
    }
  }

  void stopListening() async {
    await NotificationsListener.stopService();
  }
}

class NotificationController {
  @pragma("vm:entry-point")
  static Future<void> onNotificationCreatedMethod(
      ReceivedNotification receivedNotification) async {}

  @pragma("vm:entry-point")
  static Future<void> onNotificationDisplayedMethod(
      ReceivedNotification receivedNotification) async {}

  @pragma("vm:entry-point")
  static Future<void> onDismissActionReceivedMethod(
      ReceivedAction receivedAction) async {
    debugPrint("Notification dismissed");
  }

  @pragma("vm:entry-point")
  static Future<void> onActionReceivedMethod(
      ReceivedAction receivedAction) async {
    debugPrint("Action received");
  }
}

class Notify {
  AwesomeNotifications myAwesomeNots = AwesomeNotifications();
  int mediaPlayerID = -1;

  void shutAllNots() {
    myAwesomeNots.cancelAll();
  }

  Future<void> init() async {
    myAwesomeNots.setChannel(NotificationChannel(
      icon: 'resource://drawable/res_meuicon',
      channelKey: PcService.notificationChannelId,
      channelName: PcService.notificationChannelId,
      channelDescription: PcService.notificationChannelId,
      channelShowBadge: false,
      importance: NotificationImportance.Low,
    ));

    await myAwesomeNots.initialize(
      null, //'resource://drawable/res_app_icon',//
      [
        NotificationChannel(
          icon: 'resource://drawable/res_meuicon',
          channelKey: PcService.notificationChannelId,
          channelGroupKey: PcService.notificationChannelId,
          channelName: PcService.notificationChannelId,
          channelDescription: PcService.notificationChannelId,
          channelShowBadge: false,
          importance: NotificationImportance.Low,
        ),
      ],
    );

    myAwesomeNots.isNotificationAllowed().then((isAllowed) {
      if (!isAllowed) {
        myAwesomeNots.requestPermissionToSendNotifications();
      }
    });
    debugPrint("Notifications initialized");
  }

  void setListeners() {
    myAwesomeNots.setListeners(
        onActionReceivedMethod: NotificationController.onActionReceivedMethod,
        onNotificationCreatedMethod:
            NotificationController.onNotificationCreatedMethod,
        onNotificationDisplayedMethod:
            NotificationController.onNotificationDisplayedMethod,
        onDismissActionReceivedMethod:
            NotificationController.onDismissActionReceivedMethod);
    debugPrint("Listeners set");
  }

  //set a new media player notification with buttons
  Future<void> setBackgroundNotification(String title, String body) async {
    await myAwesomeNots.createNotification(
      content: NotificationContent(
        icon: 'resource://drawable/res_meuicon',
        id: PcService.notificationId,
        channelKey: PcService.notificationChannelId,
        category: NotificationCategory.Service,
        title: title,
        body: body,
      ),
    );
  }
}
