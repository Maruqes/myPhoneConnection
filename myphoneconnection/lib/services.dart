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

Future<void> _initAudioService() async {
  customAudioHandler.audioHandler = await AudioService.init(
    builder: () => customAudioHandler,
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.example.media',
      androidNotificationChannelName: 'Media Playback',
      androidNotificationOngoing: true,
    ),
  );
  debugPrint("Audio Service initialized");
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

  _initAudioService();
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
