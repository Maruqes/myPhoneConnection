import 'dart:async';
import 'dart:io';

import 'package:myphoneconnection/config.dart';
import 'package:myphoneconnection/server.dart';
import 'package:myphoneconnection/services.dart';
import 'package:flutter/material.dart';
import 'package:photo_gallery/photo_gallery.dart';

int lastImageIndex = 0;
ValueNotifier<List<Device>> globalDeviceListNotifier =
    ValueNotifier<List<Device>>([]);

Future<List<File>> getImageFromGallery(int numberOfImages) async {
  debugPrint("GETTING IMAGES");

  final List<Album> imageAlbums = await PhotoGallery.listAlbums();
  final MediaPage imagePage = await imageAlbums[0].listMedia(
    skip: lastImageIndex,
    take: numberOfImages,
  );

  lastImageIndex += numberOfImages;
  final List<File> imageFiles = await Future.wait(imagePage.items
      .where((Medium media) =>
          media.filename!.contains("png") ||
          media.filename!.contains("jpg") ||
          media.filename!.contains("jpeg"))
      .map((Medium media) => media.getFile())
      .toList());

  return imageFiles;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalNotificationService().init();

  ListenToPort().initListenPort();

  await PcService().initializeService();

  runApp(MyApp());
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
  void initState() {
    super.initState();
    globalDeviceListNotifier.addListener(_updateDeviceList);
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
    ConnectionPC().startConnectionWithPc(device);
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
