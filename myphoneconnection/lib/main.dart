import 'dart:async';
import 'dart:ui';
import 'package:flutter_notification_listener/flutter_notification_listener.dart';
import 'package:myphoneconnection/mediaPlayer.dart';
import 'package:myphoneconnection/server.dart';
import 'package:myphoneconnection/services.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/*
todolistdavida
testar o caralho do protocolo duma maneira incrivel de forma a ters a puta da certeza que funciona
 caralho
*/

ValueNotifier<List<Device>> globalDeviceListNotifier =
    ValueNotifier<List<Device>>([]);

CustomAudioHandler customAudioHandler = CustomAudioHandler();
Notify nots = Notify();

Future<void> requestPermission() async {
  var status = await Permission.notification.status;
  if (status.isDenied) {
    status = await Permission.notification.request();
  }

  status = await Permission.contacts.status;
  if (status.isDenied) {
    status = await Permission.contacts.request();
  }

  status = await Permission.photos.status;
  if (status.isDenied) {
    status = await Permission.photos.request();
  }

  status = await Permission.videos.status;
  if (status.isDenied) {
    status = await Permission.videos.request();
  }

  status = await Permission.phone.status;
  if (status.isDenied) {
    status = await Permission.phone.request();
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await requestPermission();

  ListenToPort().initListenPort();

  await PcService().initializeService();

  OurNotificationListener().stopListening();

  nots.setListeners();
  await nots.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Phone Connection',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'My Phone Connection'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool started = false;

  void initState() {
    super.initState();
    globalDeviceListNotifier.addListener(_updateDeviceList);
  }

  @pragma('vm:entry-point')
  static void _onData(NotificationEvent event) {
    debugPrint(event.toString());
  }

  @override
  void dispose() {
    globalDeviceListNotifier.removeListener(_updateDeviceList);
    super.dispose();
  }

  void _updateDeviceList() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Wrap(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                ElevatedButton(
                    onPressed: () => {
                          //update UI
                          setState(() {}),
                        },
                    child: const Text("Update Device List")),
                ElevatedButton(
                    onPressed: () {
                      PairedDevices().clearAllConnectionSaves();
                    },
                    child: const Text("Clear All Connection Saves")),
                ValueListenableBuilder<List<Device>>(
                  valueListenable: globalDeviceListNotifier,
                  builder: (context, devices, _) {
                    return DeviceListWidget(
                      devices: devices,
                    );
                  },
                ),
              ],
            ),
          ),
          // Add InputWidget here
        ],
      ),
    );
  }
}

class DeviceListWidget extends StatelessWidget {
  final List<Device> devices;

  DeviceListWidget({Key? key, required this.devices}) : super(key: key);

  void tryConnection(Device device) {
    String stringToSend =
        "${device.hostname}|div|${device.os}|div|${device.CPU}|div|${device.RAM}|div|${device.ip}|div|${device.port}";
    IsolateNameServer.lookupPortByName('callService')?.send(stringToSend);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: devices
            .map(
              (device) => ElevatedButton(
                onPressed: () => tryConnection(device),
                child: Text("IP: ${device.ip} Name ${device.hostname}"),
              ),
            )
            .toList(),
      ),
    );
  }
}
