import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/widgets.dart';
// import 'package:flutter_notification_listener/flutter_notification_listener.dart';
import 'package:myphoneconnection/backgroundService.dart';

import 'package:myphoneconnection/main.dart';
import 'package:myphoneconnection/server.dart';
import 'package:flutter/material.dart';
import 'package:device_apps/device_apps.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:notification_listener_service/notification_event.dart';
import 'package:notification_listener_service/notification_listener_service.dart';

class ListenToPort {
  List<Device> devicesTempToAdd = [];

  void initListenPort() {
    ReceivePort infoPC = ReceivePort();
    IsolateNameServer.registerPortWithName(infoPC.sendPort, 'setInfoPC');
    infoPC.listen((data) {
      String cpuUsage = data.split("&%&")[0];
      String memTotal = data.split("&%&")[1];
      String memUsed = data.split("&%&")[2];
      String diskTotal = data.split("&%&")[3];
      String diskUsed = data.split("&%&")[4];
      String temp = data.split("&%&")[5];

      double cpuUsageFloat = double.parse(cpuUsage);
      cpuUsageFloat = cpuUsageFloat / 100;

      double memUsageFloat = double.parse(memUsed) / double.parse(memTotal);

      double diskUsageFloat = double.parse(diskUsed) / double.parse(diskTotal);

      List<String> tempSplit = temp.split(",");

      List<double> temps = [];

      for (int i = 0; i < tempSplit.length; i++) {
        try {
          temps.add(double.parse(tempSplit[i]));
        } catch (e) {
          debugPrint("Error in setInfoPC: $e");
        }
      }

      infoSystemMonitor tmd = infoSystemMonitor(
          cpuUsageFloat, memUsageFloat, diskUsageFloat, temps);
      testNotList.value = tmd;
    });

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

    ReceivePort setNewProcesses = ReceivePort();
    IsolateNameServer.registerPortWithName(
        setNewProcesses.sendPort, 'setNewProcesses');
    setNewProcesses.listen((data) {
      List<String> processesString = data.split("//||//");

      List<Process> newProcesses = [];

      for (int i = 0; i < processesString.length; i++) {
        try {
          String name = processesString[i].split("&%&")[0];
          String pid = processesString[i].split("&%&")[1];

          newProcesses.add(Process(pid: pid, name: name));
        } catch (e) {
          debugPrint("Error in setNewProcesses: $e");
        }
      }
      globalProcessListNotifier.value = newProcesses;

      debugPrint("Processes set");
    });
  }
}

class ServiceNotificationEventWithDate {
  ServiceNotificationEvent event;
  DateTime date;
  ServiceNotificationEventWithDate(this.event, this.date);
}

List<ServiceNotificationEventWithDate> serviceNotificationsSave = [];

class NotsListener {
  Future<void> checkServiceNotificationsSave() async {
    for (int i = 0; i < serviceNotificationsSave.length; i++) {
      if (DateTime.now()
              .toUtc()
              .difference(serviceNotificationsSave[i].date)
              .inMinutes >
          2) {
        serviceNotificationsSave.removeAt(i);
        debugPrint("Notification removed from save");
      }
    }
  }

  void replyToServiceNotification(String id, String message) {
    int idInt = int.parse(id);
    for (int i = 0; i < serviceNotificationsSave.length; i++) {
      if (serviceNotificationsSave[i].event.id! == idInt) {
        serviceNotificationsSave[i].event.sendReply(message);
        debugPrint("Notification replied");
        serviceNotificationsSave.removeAt(i);
        return;
      }
    }
  }

  void replyParser(String message) {
    List<String> messageSplit = message.split("//||//");
    String id = messageSplit[0];
    String reply = messageSplit[1];

    replyToServiceNotification(id, reply);
  }

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

  Future<void> startListening() async {
    NotificationListenerService.notificationsStream.listen((event) async {
      checkServiceNotificationsSave();

      if (event.packageName == "com.android.systemui" ||
          event.packageName == "com.maruqes.myphoneconnection") {
        return;
      }
      String iconb64 = "";
      String appIcon = "";
      if (event.largeIcon != null) {
        iconb64 = base64.encode(event.largeIcon!);
      } else {
        iconb64 = "null";
      }

      appIcon = await getIconWithPackageName(event.packageName!);

      String canReply = "false";
      if (event.canReply! == true) {
        canReply = "true";
        serviceNotificationsSave.add(
            ServiceNotificationEventWithDate(event, DateTime.now().toUtc()));
        debugPrint("Notification added to save");
      }

      connectionPC.ws.sendData("newPhoneNotification",
          "${event.title}//||//${event.content}//||//$iconb64//||//$appIcon//||//${event.packageName}//||//$canReply//||//${event.id}");
    });
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
