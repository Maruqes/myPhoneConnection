import 'dart:async';
import 'dart:io';

import 'package:myphoneconnection/server.dart';
import 'package:myphoneconnection/services.dart';
import 'package:flutter/material.dart';
import 'package:photo_gallery/photo_gallery.dart';

int lastImageIndex = 0;
List<Device> globalDeviceList = [];

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
  List<File> images = [];

  Future<void> addImage() async {
    List<File> img = await getImageFromGallery(20);
    images.addAll(img);
    debugPrint("added image number ${images.length}");
  }

  WidgetsFlutterBinding.ensureInitialized();
  await LocalNotificationService().init();

  LocalNotificationService().showNotificationAndroid("Title", "Value");

  final con = ConnectionPC();
  con.startProtocol(8080);

  await addImage();

  await initializeService();

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
                const InputWidget(),
                DeviceListWidget(
                  devices: globalDeviceList,
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

//ask user for a port to use

class InputWidget extends StatelessWidget {
  const InputWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final myController = TextEditingController();

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          TextField(
            controller: myController,
          ),
          ElevatedButton(
            onPressed: () {
              debugPrint(
                  'Try to Connect wth port number: ${myController.text}');
              if (myController.text.isEmpty) {
                return;
              }
              if (int.parse(myController.text) < 0 ||
                  int.parse(myController.text) > 65535) {
                return;
              }

              final con = ConnectionPC();
              con.startProtocol(int.parse(myController.text));
            },
            child: const Text('Try to Connect'),
          ),
        ],
      ),
    );
  }
}

class DeviceListWidget extends StatefulWidget {
  final List<Device> devices;

  const DeviceListWidget({Key? key, required this.devices}) : super(key: key);

  @override
  _DeviceListWidgetState createState() => _DeviceListWidgetState();
}

class _DeviceListWidgetState extends State<DeviceListWidget> {
  void tryConnection(Device device) {
    ConnectionPC().startConnectionWithPc(device);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: widget.devices
            .map((device) => ElevatedButton(
                onPressed: () => tryConnection(device),
                child: ElevatedButton(
                  child: Text("IP: ${device.ip} Name ${device.hostname}"),
                  onPressed: () => tryConnection(device),
                )))
            .toList(),
      ),
    );
  }
}
