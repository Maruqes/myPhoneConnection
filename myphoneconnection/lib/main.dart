import 'dart:async';
import 'dart:ui';
import 'package:myphoneconnection/backgroundService.dart';
import 'package:myphoneconnection/mediaPlayer.dart';
import 'package:myphoneconnection/server.dart';
import 'package:myphoneconnection/services.dart';
import 'package:flutter/material.dart';
import 'package:notification_listener_service/notification_listener_service.dart';
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

ValueNotifier<List<Process>> globalProcessListNotifier =
    ValueNotifier<List<Process>>([]);

Future<void> requestPermission() async {
  var status = await Permission.notification.status;
  if (status.isDenied) {
    status = await Permission.notification.request();
  }

  status = await Permission.contacts.status;
  if (status.isDenied) {
    status = await Permission.contacts.request();
  }

  status = await Permission.phone.status;
  if (status.isDenied) {
    status = await Permission.phone.request();
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final bool status = await NotificationListenerService.isPermissionGranted();

  if (!status) {
    final bool status2 = await NotificationListenerService.requestPermission();
    if (!status2) {
      return;
    }
  }

  await requestPermission();

  ListenToPort().initListenPort();

  nots.setListeners();
  await nots.init();

  await PcService().initializeService();

  runApp(const MyApp());
}

Drawer getMainDrawer(BuildContext context) {
  return Drawer(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
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
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MouseController(),
                ),
              );
            },
            child: const Text("Mouse Controller")),
        ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProcessController(),
                ),
              );
            },
            child: const Text("Process Controller")),
        ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SystemMonitorApp(),
                ),
              );
            },
            child: const Text("System Monitor")),
      ],
    ),
  );
}

AppBar getMainAppBar(
    BuildContext context, String title, GlobalKey<ScaffoldState> scaffoldKey) {
  return AppBar(
    backgroundColor: Theme.of(context).colorScheme.inversePrimary,
    title: Text(title),
    leading: IconButton(
      icon: const Icon(Icons.menu),
      onPressed: () => scaffoldKey.currentState!.openDrawer(),
    ),
    automaticallyImplyLeading: false,
  );
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

  @override
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

  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: scaffoldKey,
      appBar: getMainAppBar(context, widget.title, scaffoldKey),
      drawer: getMainDrawer(context),
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
        appBar: getMainAppBar(context, "Powerpoint Controller", scaffoldKey),
        drawer: getMainDrawer(context),
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
                      padding: const EdgeInsets.all(16.0),
                      textStyle: const TextStyle(fontSize: 20.0),
                      minimumSize: Size(double.infinity, height),
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
                      padding: const EdgeInsets.all(16.0),
                      textStyle: const TextStyle(fontSize: 20.0),
                      minimumSize: Size(double.infinity, height),
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
  final TextEditingController _controller = TextEditingController();
  int _previousTextLength = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleTextInput);
  }

  void _handleTextInput() {
    String text = _controller.text;
    if (text.length < _previousTextLength) {
      // Backspace key pressed
      IsolateNameServer.lookupPortByName('keyboardEvent')?.send("backspace");
    } else {
      if (text.isNotEmpty) {
        String key = text[text.length - 1];
        IsolateNameServer.lookupPortByName('keyboardEvent')?.send(key);
        debugPrint(key);
      }
      _previousTextLength = text.length;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: scaffoldKey,
      appBar: getMainAppBar(context, "Mouse Controller", scaffoldKey),
      drawer: getMainDrawer(context),
      body: Column(
        children: [
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              labelText: 'Type here',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.multiline,
          ),
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
                child: const Stack(
                  children: [
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Opacity(
                        opacity: 0.50,
                        child: Icon(
                          color: Colors.deepPurple,
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
                          color: Colors.deepPurple,
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
                          color: Colors.deepPurple,
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
                          color: Colors.deepPurple,
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
                              color: Colors.deepPurple,
                              Icons.touch_app,
                              size: 50,
                            ),
                          ),
                          Opacity(
                            opacity: 0.50,
                            child: Text(
                              'MouseController',
                              style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.bold,
                                color: Colors.deepPurple,
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
                      Colors.deepPurple,
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
                      Colors.deepPurple,
                    ),
                  ),
                  child: const Text('Right Click'),
                ),
                ElevatedButton(
                  onPressed: () {
                    IsolateNameServer.lookupPortByName('keyboardEvent')
                        ?.send("enter");
                  },
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.all<Color>(
                      Colors.deepPurple,
                    ),
                  ),
                  child: const Text('Enter'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class Process {
  final String pid;
  final String name;

  Process({required this.pid, required this.name});
}

void setProcesses(String s) {
  IsolateNameServer.lookupPortByName('setNewProcesses')?.send(s);
}

class ProcessController extends StatefulWidget {
  const ProcessController({super.key});

  @override
  State<ProcessController> createState() => _ProcessControllerState();
}

class _ProcessControllerState extends State<ProcessController> {
  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

  List<Process> processes = [];

  @override
  void initState() {
    super.initState();
    IsolateNameServer.lookupPortByName('askForProcesses')?.send("");
    globalProcessListNotifier.addListener(_setProcesses);
  }

  void _setProcesses() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: scaffoldKey,
      appBar: getMainAppBar(context, "Process Controller", scaffoldKey),
      drawer: getMainDrawer(context),
      body: ValueListenableBuilder<List<Process>>(
        valueListenable: globalProcessListNotifier,
        builder: (context, processes, _) {
          return ListView.builder(
            itemCount: processes.length,
            itemBuilder: (context, index) {
              var process = processes[index];
              return ListTile(
                title: Text('Name: ${process.name}'),
                subtitle: Text('PID: ${process.pid}'),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: const Text('KILL PROCESS'),
                        content:
                            Text('Name: ${process.name}\nPID: ${process.pid}'),
                        actions: [
                          TextButton(
                            onPressed: () {
                              IsolateNameServer.lookupPortByName('killProcess')
                                  ?.send(process.pid);
                              Navigator.of(context).pop();
                            },
                            child: const Text('KILL'),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            child: const Text('Close'),
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          IsolateNameServer.lookupPortByName('askForProcesses')?.send("");
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class SystemMonitorApp extends StatelessWidget {
  const SystemMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'System Monitor',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple, // Change the primary color
        colorScheme: ColorScheme.fromSwatch(
          primarySwatch: Colors.deepPurple, // Change the color scheme
        ),
      ),
      darkTheme: ThemeData.dark(),
      home: const SystemMonitorScreen(),
    );
  }
}

class SystemMonitorScreen extends StatefulWidget {
  const SystemMonitorScreen({super.key});

  @override
  State<StatefulWidget> createState() => _SystemMonitorScreenState();
}

void setInfoPc(String data) {
  IsolateNameServer.lookupPortByName('setInfoPC')?.send(data);
}

// ignore: camel_case_types
class infoSystemMonitor {
  double cpuUsage;
  double ramUsage;
  double diskUsage;
  List<double> coresTemperature;

  infoSystemMonitor(
      this.cpuUsage, this.ramUsage, this.diskUsage, this.coresTemperature);
}

ValueNotifier<infoSystemMonitor> testNotList =
    ValueNotifier<infoSystemMonitor>(infoSystemMonitor(0, 0, 0, []));

class _SystemMonitorScreenState extends State<SystemMonitorScreen> {
  double cpuUsage = 0;
  double ramUsage = 0;
  double diskUsage = 0;
  List<double> coresTemperature = [];

  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    Timer.periodic(const Duration(seconds: 1), (timer) {
      IsolateNameServer.lookupPortByName('askForPcInfo')?.send("");
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: scaffoldKey,
      appBar: getMainAppBar(context, "Process Controller", scaffoldKey),
      drawer: getMainDrawer(context),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ValueListenableBuilder<infoSystemMonitor>(
          valueListenable: testNotList,
          builder: (context, infoSystemMonitor value, _) {
            return GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              children: <Widget>[
                _buildMonitoringCard(
                  'CPU Usage',
                  _buildProgressBar(value.cpuUsage, 'CPU'),
                  Icons.memory,
                ),
                _buildMonitoringCard(
                  'RAM Usage',
                  _buildProgressBar(value.ramUsage, 'RAM'),
                  Icons.storage,
                ),
                _buildMonitoringCard(
                  'Disk Usage',
                  _buildProgressBar(value.diskUsage, 'Disk'),
                  Icons.sd_storage,
                ),
                for (int i = 0; i < value.coresTemperature.length; i++)
                  _buildMonitoringCard(
                    'Core ${i + 1} Temperature',
                    _buildTemperatureBar(value.coresTemperature[i]),
                    Icons.thermostat,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildMonitoringCard(String title, Widget content, IconData icon) {
    return Card(
      elevation: 15,
      margin: const EdgeInsets.all(0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, size: 20),
            const SizedBox(height: 10),
            Text(title,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Expanded(child: content),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(double value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label Usage', style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 5),
        LinearProgressIndicator(
          value: value,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).colorScheme.primary),
        ),
        const SizedBox(height: 10),
        Text('${(value * 100).toInt()}%', style: const TextStyle(fontSize: 16)),
      ],
    );
  }

  Widget _buildTemperatureBar(double temperature) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Temperature: ${temperature.toStringAsFixed(1)}°C',
            style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 5),
        LinearProgressIndicator(
          value: temperature / 100, // assuming 100°C is the max
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(
            temperature > 75 ? Colors.red : Colors.green,
          ),
        ),
      ],
    );
  }

  void updateSystemData(infoSystemMonitor newInfo) {
    setState(() {
      cpuUsage = newInfo.cpuUsage;
      ramUsage = newInfo.ramUsage;
      diskUsage = newInfo.diskUsage;
      coresTemperature = newInfo.coresTemperature;
    });
  }
}
