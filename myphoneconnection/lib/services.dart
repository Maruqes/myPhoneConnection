import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_notification_listener/flutter_notification_listener.dart';
import 'package:http/http.dart' as http;

import 'package:myphoneconnection/main.dart';
import 'package:myphoneconnection/server.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:myphoneconnection/galleryFunctions.dart';
import 'package:device_apps/device_apps.dart';

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
  ReceivePort port0 = ReceivePort();
  IsolateNameServer.registerPortWithName(port0.sendPort, 'callService');
  port0.listen((deviceString) {
    List<String> division = deviceString.split("|div|");
    Device device = Device(
      division[0],
      division[1],
      division[2],
      division[3],
      division[4],
      division[5],
    );

    connectionPC.startConnectionWithPc(
        device, ConnectionSave(device, Uint8List(0)));
  });

  publicGallery.initGallery();
  Timer.periodic(const Duration(seconds: 10), (timer) async {
    publicGallery.checkNumberOfImagesOnGallery();

    debugPrint("Checking connection ${connectionPC.ws.checkWsConnection()}");

    if (connectionPC.ws.checkWsConnection() == false &&
        connectionPC.isTryingToConnect() == false) {
      try {
        await connectionPC.startProtocol(8080);
      } catch (e) {
        debugPrint("Error in startProtocol: $e");
      }
    } else {}
  });
}

class PcService {
  final service = FlutterBackgroundService();

  void startBackgroundService() {
    service.startService();
  }

  void stopBackgroundService() {
    service.invoke("stop");
  }

  Future<void> initializeService() async {
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
    // Start the background service when the app is closed
    startBackgroundService();
  }
}

class NotificationController {
  /// Use this method to detect when a new notification or a schedule is created
  @pragma("vm:entry-point")
  static Future<void> onNotificationCreatedMethod(
      ReceivedNotification receivedNotification) async {}

  /// Use this method to detect every time that a new notification is displayed
  @pragma("vm:entry-point")
  static Future<void> onNotificationDisplayedMethod(
      ReceivedNotification receivedNotification) async {}

  /// Use this method to detect if the user dismissed a notification
  @pragma("vm:entry-point")
  static Future<void> onDismissActionReceivedMethod(
      ReceivedAction receivedAction) async {
    debugPrint("Notification dismissed");
  }

  /// Use this method to detect when the user taps on a notification or action button
  @pragma("vm:entry-point")
  static Future<void> onActionReceivedMethod(
      ReceivedAction receivedAction) async {
    debugPrint("Action received");
    if (receivedAction.buttonKeyPressed == "pause") {
      connectionPC.ws.sendData("media", "pause");
    } else if (receivedAction.buttonKeyPressed == "next") {
      connectionPC.ws.sendData("media", "next");
    } else if (receivedAction.buttonKeyPressed == "previous") {
      connectionPC.ws.sendData("media", "previous");
    }
  }
}

class Notify {
  AwesomeNotifications myAwesomeNots = AwesomeNotifications();
  int mediaPlayerID = -1;

  void shutAllNots() {
    myAwesomeNots.cancelAll();
  }

  Future<void> init() async {
    await myAwesomeNots.initialize(
      null, //'resource://drawable/res_app_icon',//
      [
        NotificationChannel(
          channelKey: 'media_player',
          channelGroupKey: "media_player",
          channelName: 'No Sound Channel',
          channelDescription: 'Notification tests as alerts',
          playSound: false,
          enableVibration: false,
          vibrationPattern: null,
          importance: NotificationImportance.Min,
          defaultPrivacy: NotificationPrivacy.Public,
          onlyAlertOnce: true,
          groupAlertBehavior: GroupAlertBehavior.Summary,
          channelShowBadge: false,
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

  Future<String> saveLinkPngInDisk(String link) async {
    try {
      var response = await http.get(Uri.parse(link));
      var bytes = response.bodyBytes;
      String path = await GalleryFunctions().saveImageInDisk(bytes, "tempIMG");
      return path;
    } catch (e) {
      return "";
    }
  }

  //set a new media player notification with buttons
  Future<void> notifyMediaPlayer(String title, String body, String link,
      int length, int position, bool paused) async {
    double positionInt = 0;
    if (length <= 0 || position < 0) {
    } else {
      positionInt = (position / length) * 100;
    }

    if (position > length) {
      position = length;
    }

    String path = await saveLinkPngInDisk(link);

    if (path != "") {
      path = "file://$path";
    }

    if (mediaPlayerID == -1) {
      mediaPlayerID = Random().nextInt(100);
    }

    await myAwesomeNots.createNotification(
      content: NotificationContent(
        id: mediaPlayerID,
        channelKey: 'media_player',
        category: NotificationCategory.Transport,
        title: title,
        body: body,
        duration: Duration(microseconds: length),
        progress: positionInt,
        playbackSpeed: 1.0,
        playState: paused
            ? NotificationPlayState.paused
            : NotificationPlayState.playing,
        summary: "Now Playing",
        notificationLayout: NotificationLayout.MediaPlayer,
        largeIcon: path,
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
            actionType: ActionType.SilentAction),
        NotificationActionButton(
            key: 'next',
            label: 'Next',
            icon: 'resource://drawable/res_next',
            autoDismissible: false,
            showInCompactView: true,
            actionType: ActionType.SilentAction),
        NotificationActionButton(
            key: 'previous',
            label: 'Previous',
            icon: 'resource://drawable/res_previous',
            autoDismissible: false,
            showInCompactView: true,
            actionType: ActionType.SilentAction),
      ],
    );
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
    NotificationsListener.initialize(callbackHandle: onData);
    // register your event handler in the UI logic.
    NotificationsListener.receivePort?.listen((evt) => onData(evt));
  }
}
