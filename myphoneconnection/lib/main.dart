import 'dart:async';
import 'dart:ui';
import 'package:flutter_notification_listener/flutter_notification_listener.dart';
import 'package:myphoneconnection/backgroundService.dart';
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
      darkTheme: ThemeData.dark(),
      themeMode: ThemeMode.system,
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

  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: scaffoldKey,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => scaffoldKey.currentState!.openDrawer(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SettingsPage()),
              );
            },
          ),
        ],
        automaticallyImplyLeading: false,
      ),
      drawer: Drawer(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center, // Add this line
          children: [
            ElevatedButton(onPressed: () {}, child: const Text("Main Page")),
            ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PowerpointController(),
                    ),
                  );
                },
                child: const Text("Powerpoint Controller")),
            ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MouseController(),
                    ),
                  );
                },
                child: const Text("Mouse Controller")),
          ],
        ),
      ),
      body: Wrap(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
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

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
      ),
      body: Column(
        children: [],
      ),
    );
  }
}

class DeviceListWidget extends StatelessWidget {
  final List<Device> devices;

  const DeviceListWidget({super.key, required this.devices});

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

class PowerpointController extends StatefulWidget {
  const PowerpointController({super.key});

  @override
  State<PowerpointController> createState() => _PowerpointControllerState();
}

class _PowerpointControllerState extends State<PowerpointController> {
  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.sizeOf(context).height;

    return Scaffold(
        key: scaffoldKey,
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: const Text("Powerpoint Controller"),
          leading: IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => scaffoldKey.currentState!.openDrawer(),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SettingsPage()),
                );
              },
            ),
          ],
          automaticallyImplyLeading: false,
        ),
        drawer: Drawer(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center, // Add this line
            children: [
              ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const MyHomePage(title: "My Phone Connection"),
                      ),
                    );
                  },
                  child: const Text("Main Page")),
              ElevatedButton(
                  onPressed: () {}, child: const Text("Powerpoint Controller")),
              ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MouseController(),
                      ),
                    );
                  },
                  child: const Text("Mouse Controller")),
            ],
          ),
        ),
        body: Wrap(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      IsolateNameServer.lookupPortByName('leftPowerpoint')
                          ?.send("");
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(
                          16.0), // Adjust the padding as needed
                      textStyle: const TextStyle(
                          fontSize: 20.0), // Adjust the font size as needed
                      minimumSize: Size(double.infinity,
                          height), // Set the minimum height of the button
                    ),
                    child: const Text('Left'),
                  ),
                ),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      IsolateNameServer.lookupPortByName('rightPowerpoint')
                          ?.send("");
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(
                          16.0), // Adjust the padding as needed
                      textStyle: const TextStyle(
                          fontSize: 20.0), // Adjust the font size as needed
                      minimumSize: Size(double.infinity,
                          height), // Set the minimum height of the button
                    ),
                    child: const Text('Right'),
                  ),
                ),
              ],
            ),
          ],
        ));
  }
}

class MouseController extends StatefulWidget {
  const MouseController({super.key});

  @override
  State<MouseController> createState() => _MouseController();
}

class _MouseController extends State<MouseController> {
  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: scaffoldKey,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text("Powerpoint Controller"),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => scaffoldKey.currentState!.openDrawer(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SettingsPage()),
              );
            },
          ),
        ],
        automaticallyImplyLeading: false,
      ),
      drawer: Drawer(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center, // Add this line
          children: [
            ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          const MyHomePage(title: "My Phone Connection"),
                    ),
                  );
                },
                child: const Text("Main Page")),
            ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PowerpointController(),
                    ),
                  );
                },
                child: const Text("Powerpoint Controller")),
            ElevatedButton(
                onPressed: () {}, child: const Text("Mouse Controller")),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (details) {
                  IsolateNameServer.lookupPortByName('mouseEvent')
                      ?.send("left_click");
                },
                onDoubleTap: () {
                  IsolateNameServer.lookupPortByName('mouseEvent')
                      ?.send("right_click");
                },
                onPanUpdate: (details) {
                  int dx = details.delta.dx.round();
                  int dy = details.delta.dy.round();
                  String sendString = "$dx|$dy";

                  IsolateNameServer.lookupPortByName('mouseMoveEvent')
                      ?.send(sendString);
                },
                child: Container(
                  color: const Color.fromARGB(255, 31, 31, 31),
                  child: const Stack(
                    children: [
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Opacity(
                          opacity: 0.50,
                          child: Icon(
                            color: Color.fromARGB(255, 65, 227, 168),
                            Icons.rounded_corner,
                            size: 24,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Opacity(
                          opacity: 0.50,
                          child: Icon(
                            color: Color.fromARGB(255, 65, 227, 168),
                            Icons.rounded_corner,
                            size: 24,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 10,
                        left: 10,
                        child: Opacity(
                          opacity: 0.50,
                          child: Icon(
                            color: Color.fromARGB(255, 65, 227, 168),
                            Icons.rounded_corner,
                            size: 24,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 10,
                        right: 10,
                        child: Opacity(
                          opacity: 0.50,
                          child: Icon(
                            color: Color.fromARGB(255, 65, 227, 168),
                            Icons.rounded_corner,
                            size: 24,
                          ),
                        ),
                      ),
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Opacity(
                              opacity: 0.50,
                              child: Icon(
                                color: Color.fromARGB(255, 65, 227, 168),
                                Icons.touch_app,
                                size: 50,
                              ),
                            ),
                            Opacity(
                              opacity: 0.50,
                              child: Text(
                                'TOUCHPAD!',
                                style: TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.bold,
                                  color: Color.fromARGB(255, 65, 227, 168),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Container(
            color: Colors.black,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () {
                    IsolateNameServer.lookupPortByName('mouseEvent')
                        ?.send("left_click");
                  },
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.all<Color>(
                      const Color.fromARGB(255, 59, 179, 135),
                    ),
                  ),
                  child: const Text('Left Click'),
                ),
                ElevatedButton(
                  onPressed: () {
                    IsolateNameServer.lookupPortByName('mouseEvent')
                        ?.send("right_click");
                  },
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.all<Color>(
                      const Color.fromARGB(255, 59, 179, 135),
                    ),
                  ),
                  child: const Text('Right Click'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
