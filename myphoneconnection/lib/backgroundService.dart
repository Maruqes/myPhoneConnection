import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:myphoneconnection/calls.dart';
import 'package:myphoneconnection/galleryFunctions.dart';
import 'package:myphoneconnection/main.dart';
import 'package:myphoneconnection/server.dart';

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

  ReceivePort port1 = ReceivePort();
  IsolateNameServer.registerPortWithName(port1.sendPort, 'cameraView');
  port1.listen((img) {
    connectionPC.ws.sendData("cameraView", img);
  });

  _initAudioService();
  publicGallery.initGallery();
  Calls().setStream();

  nots.setBackgroundNotification("My Phone Connection",
      "Not connected"); //settar a notificação de background
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
  // this will be used as notification channel id
  static const notificationChannelId = 'my_foreground512';

// this will be used for notification id, So you can update your custom notification with this id.
  static const notificationId = 512;
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
        foregroundServiceNotificationId: notificationId,
        notificationChannelId:
            notificationChannelId, // this must match with notification channel you created above.
      ),
    );
    // Start the background service when the app is closed
    startBackgroundService();
  }
}
