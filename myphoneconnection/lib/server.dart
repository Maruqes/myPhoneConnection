import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:myphoneconnection/clipboard.dart';
import 'package:myphoneconnection/config.dart';
import 'package:flutter/material.dart';
import 'package:myphoneconnection/main.dart';
import 'package:myphoneconnection/mediaPlayer.dart';
import 'package:myphoneconnection/services.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import "package:pointycastle/export.dart";
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:myphoneconnection/galleryFunctions.dart';

ConnectionPC connectionPC = ConnectionPC();

class Device {
  String hostname;
  String os;
  // ignore: non_constant_identifier_names
  String CPU;
  // ignore: non_constant_identifier_names
  String RAM;
  String ip;
  String port;

  Device(this.hostname, this.os, this.CPU, this.RAM, this.ip, this.port);

  toJson() {
    return {
      'hostname': hostname,
      'os': os,
      'CPU': CPU,
      'RAM': RAM,
      'ip': ip,
      'port': port,
    };
  }
}

class ConnectionSave {
  //falta desemparelhar function
  Device device;
  Uint8List nextPass;

  ConnectionSave(this.device, this.nextPass);

  toJson() {
    return {
      'device': device.toJson(),
      'nextPass': base64.encode(nextPass),
    };
  }
}

Future<String> checkIpConnection(ip, port, brand, model, id) async {
  try {
    final HttpClient client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 3);
    final HttpClientRequest request = await client.get(
      ip,
      port,
      '/do_i_exist?brand=$brand&model=$model&serialNumber=$id ',
    );
    final HttpClientResponse response = await request.close();
    final String reply = await response.transform(utf8.decoder).join();

    return reply;
  } catch (e) {
    return 'Error: $e';
  }
}

Future<List<Device>> scanNetwork(port) async {
  DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
  AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;

  List<Device> devices = [];
  await (NetworkInfo().getWifiIP()).then(
    (ip) async {
      final String subnet = ip!.substring(0, ip.lastIndexOf('.'));
      List<Future> futures = [];
      for (var i = 0; i < 256; i++) {
        String ip = '$subnet.$i';
        // debugPrint('Scanning IP: $ip:$port');
        try {
          Future future = checkIpConnection(ip, port, androidInfo.brand,
                  androidInfo.model, androidInfo.id)
              .then((value) {
            if (value.contains('My Phone Connection')) {
              value = value.replaceAll("My Phone Connection", "");

              List<String> info = value.split("//");
              devices.add(Device(
                  info[0], info[1], info[2], info[3], ip, port.toString()));
            }
          });
          futures.add(future);
        } catch (e) {
          debugPrint('Error: $e');
        }
      }
      await Future.wait(futures);
    },
  );
  debugPrint('Done');
  return devices;
}

class PairedDevices {
  WebSocketConnection ws = WebSocketConnection();

  Future<void> clearAllConnectionSaves() async {
    int index = 0;
    ConnectionSave? oldSave = await readConnectionSave("connectionSave", index);

    while (oldSave != null) {
      await deleteData("connectionSave$index");
      index++;
      oldSave = await readConnectionSave("connectionSave", index);
    }
    debugPrint('All connection saves cleared');
  }

  Future<ConnectionSave?> readConnectionSave(String key, int index) async {
    final temp = await readData(key + index.toString());
    if (temp != null) {
      final save = jsonDecode(temp);
      return ConnectionSave(
        Device(
          save['device']['hostname'],
          save['device']['os'],
          save['device']['CPU'],
          save['device']['RAM'],
          save['device']['ip'],
          save['device']['port'],
        ),
        base64.decode(save['nextPass']),
      );
    } else {
      return null;
    }
  }

  Future<void> writeConnectionSave(ConnectionSave save, Device device) async {
    ConnectionSave? oldSave = await readConnectionSave("connectionSave", 0);
    int index = 0;
    while (oldSave != null) {
      if (oldSave.device.hostname == device.hostname &&
          oldSave.device.os == device.os &&
          oldSave.device.CPU == device.CPU &&
          oldSave.device.RAM == device.RAM) {
        await writeData("connectionSave$index", jsonEncode(save.toJson()));
        debugPrint('Connection saved on index $index');
        return;
      }

      index++;
      oldSave = await readConnectionSave("connectionSave", index);
    }

    await writeData("connectionSave$index", jsonEncode(save.toJson()));
    debugPrint('Connection saved on index $index');
  }

  Future<void> deleteConnectionSave(ConnectionSave save, Device device) async {
    ConnectionSave? oldSave = await readConnectionSave("connectionSave", 0);
    int index = 0;
    while (oldSave != null) {
      if (oldSave.device.hostname == device.hostname &&
          oldSave.device.os == device.os &&
          oldSave.device.CPU == device.CPU &&
          oldSave.device.RAM == device.RAM) {
        await deleteData("connectionSave$index");
        debugPrint('Connection deleted on index $index');

        //pass next connections 1 index back
        index++;
        oldSave = await readConnectionSave("connectionSave", index);
        while (oldSave != null) {
          await writeData(
              "connectionSave${index - 1}", jsonEncode(oldSave.toJson()));
          await deleteData("connectionSave$index");
          index++;
          oldSave = await readConnectionSave("connectionSave", index);
        }
        return;
      }

      index++;
      oldSave = await readConnectionSave("connectionSave", index);
    }
  }

  Future<void> printAllConnectionSave() async {
    debugPrint("Printing all connection saves");
    int index = 0;
    ConnectionSave? oldSave = await readConnectionSave("connectionSave", index);

    while (oldSave != null) {
      debugPrint(
          'Old save($index): ${oldSave.device.hostname} with CPU ${oldSave.device.CPU} and RAM ${oldSave.device.RAM}');
      index++;
      oldSave = await readConnectionSave("connectionSave", index);
    }
  }

  Future<void> createTestConnectionSave() async {
    const numberOfTestConnections = 5;

    for (int i = 0; i < numberOfTestConnections; i++) {
      final device = Device(
        'TestDevice$i',
        'TestOS$i',
        'TestCPU$i',
        'TestRAM$i',
        '192.168.1.$i',
        '8080',
      );

      final nextPass = generateRandomBytes(16);
      final save = ConnectionSave(device, nextPass);

      await writeConnectionSave(save, device);
      debugPrint('Test connection save $i created');
    }
  }

  //should check the fact that it is giving full pass
  Future<void> checkNextPasswordProtocolLast(
      Device device, ConnectionSave oldSave) async {
    await connectionPC.startConnectionWithPc(device, oldSave);
  }

  Future<void> checkNextPasswordProtocol(
      Device device, ConnectionSave oldSave) async {
    final HttpClient client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 3);
    try {
      HttpClientRequest request = await client.get(
        device.ip,
        int.parse(device.port),
        '/startNextPassProtocol',
      );
      final HttpClientResponse response = await request.close();
      final String reply = await response.transform(utf8.decoder).join();

      final last8Bytes = oldSave.nextPass.sublist(8, 16);
      final last8BytesBase64 = base64.encode(last8Bytes);
      if (reply == last8BytesBase64) {
        debugPrint('Connection is going with ${device.ip}');
        await checkNextPasswordProtocolLast(device, oldSave);
      } else {
        debugPrint('Connection failed with ${device.ip}');
        deleteConnectionSave(oldSave, device);
      }
    } catch (e) {
      debugPrint('Error: $e');
      deleteConnectionSave(oldSave, device);
      return;
    }
  }

  Future<void> connectToAlreadyPairedDevice(Device device) async {
    int index = 0;
    ConnectionSave? oldSave = await readConnectionSave("connectionSave", index);

    while (oldSave != null) {
      oldSave = await readConnectionSave("connectionSave", index);
      if (oldSave?.device.hostname == null ||
          oldSave?.device.CPU == null ||
          oldSave?.device.RAM == null) {
        await deleteData("connectionSave$index");
        index++;
        continue;
      }

      debugPrint(
          'Old save($index): ${oldSave?.device.hostname} with CPU ${oldSave?.device.CPU} and RAM ${oldSave?.device.RAM}');

      if (oldSave != null) {
        if (oldSave.device.hostname == device.hostname &&
            oldSave.device.os == device.os &&
            oldSave.device.CPU == device.CPU &&
            oldSave.device.RAM == device.RAM) {
          debugPrint(
              'Found matching save ${device.hostname} with CPU ${device.CPU} and RAM ${device.RAM}');
          await checkNextPasswordProtocol(device, oldSave);
          return;
        }
      }

      debugPrint('Checked Index: $index');
      index++;
    }
  }

  void setNextPasswordForConnection(Device device, WebSocketConnection ws_) {
    ws = ws_;
    final nextPass = generateRandomBytes(16);
    final nextPassBase64 = base64.encode(nextPass);
    final data = nextPassBase64;
    ws.sendData("nextPass", data);

    ConnectionSave save = ConnectionSave(
      device,
      nextPass,
    );

    writeConnectionSave(save, device);
  }
}

class DataStream {
  String indetifier;
  Function function;

  DataStream(this.indetifier, this.function);
}

//when sending new img after killin app it crashes:D
//and is trying to connect 2 times , think is about the 3 seconds
class WebSocketConnection {
  late WebSocketChannel channel;
  late Uint8List key;
  bool isConnected = false;
  GalleryFunctions galleryFunctions = GalleryFunctions();
  MediaPlayer mediaPlayer = MediaPlayer();

  List<DataStream> dataStreams = [];

  void registerDataStream(String identifier, Function(String) function) {
    dataStreams.add(DataStream(identifier, function));
  }

  Function getFunction(String identifier) {
    for (var dataStream in dataStreams) {
      if (dataStream.indetifier == identifier) {
        return dataStream.function;
      }
    }
    return () {};
  }

  void sendData(String identifier, String data) {
    String res = "$identifier//||DIVIDER||\\\\$data";

    if (isConnected == false) {
      debugPrint('Not connected');
      return;
    }
    final encData = encryptAES(key, res);
    channel.sink.add(encData);
  }

  Future<void> recieveData(String data) async {
    final dec = decryptAES(key, data);

    final fullData = dec.split("//||DIVIDER||\\\\");
    final identifier = fullData[0];
    final data_ = fullData[1];
    final funcToCall = getFunction(identifier);
    funcToCall(data_);

    // debugPrint('Recieved dec: $dec');
    // if (dec == "askImages") {
    //   galleryFunctions.sendImages();
    // } else if (dec == "firstImages") {
    //   galleryFunctions.sendFirstImages();
    // } else if (dec.contains("askFullImage//")) {
    //   final index = int.parse(dec.split("//")[1]);
    //   galleryFunctions.sendFullImage(index);
    // } else if (dec.contains("dataMediaPlayer//||//")) {
    //   final data = dec.split("dataMediaPlayer//||//")[1];
    //   mediaPlayer.updateData(data);
    // } else if (dec.contains("clearMediaPlayer")) {
    //   mediaPlayer.clearMediaPlayer();
    // } else if (dec.contains("setMediaPosition//")) {
    //   final data = dec.split("setMediaPosition//")[1];
    //   mediaPlayer.setPosition(data);
    // } else if (dec.contains("shutAllNots")) {
    //   mediaPlayer.shutAllNots();
    // } else if (dec.contains("notAction//")) {
    //   final data = dec.split("notAction//")[1];
    //   OurNotificationListener().actionOnNotification(data);
    // } else if (dec.contains("clipboard//||//&&//||//")) {
    //   final data = dec.split("clipboard//||//&&//||//")[1];
    //   ClipboardUniversal().copy(data);
    // } else if (dec.contains("clipboardIMG//||//&&//||//")) {
    //   final data = dec.split("clipboardIMG//||//&&//||//")[1];
    //   ClipboardUniversal().copyIMG(data);
    // }
  }

  void createWebSocket(Uint8List key_, Device device) {
    key = key_;

    registerDataStream("askImages", galleryFunctions.sendImages);
    registerDataStream("firstImages", galleryFunctions.sendFirstImages);
    registerDataStream("askFullImage", galleryFunctions.sendFullImage);
    registerDataStream("dataMediaPlayer", mediaPlayer.updateData);
    registerDataStream("clearMediaPlayer", mediaPlayer.clearMediaPlayer);
    registerDataStream("setMediaPosition", mediaPlayer.setPosition);
    registerDataStream("shutAllNots", mediaPlayer.shutAllNots);
    registerDataStream(
        "notAction", OurNotificationListener().actionOnNotification);
    registerDataStream("clipboard", ClipboardUniversal().copy);
    registerDataStream("clipboardIMG", ClipboardUniversal().copyIMG);

    channel = WebSocketChannel.connect(
      Uri.parse('ws://${device.ip}:${device.port}/ws'),
    );
    channel.stream.listen((message) {
      recieveData(message);
    }, onDone: () {
      debugPrint('WebSocket done');
      isConnected = false;
      connectionPC = ConnectionPC();
      notificationListener.stopListening();
    }, onError: (error) {
      debugPrint('WebSocket error: $error');
      isConnected = false;
      connectionPC = ConnectionPC();
      notificationListener.stopListening();
    }, cancelOnError: true);

    isConnected = true;
    sendData("createdSocket", "null");
    debugPrint("WebSocket created");

    nots.setListeners();
    nots.init();

    notificationListener.initPlatformState();
    notificationListener.startListening();
  }

  bool checkWsConnection() {
    return isConnected;
  }
}

class ConnectionPC {
  late Uint8List key;
  HttpClient clientPublic = HttpClient();
  WebSocketConnection ws = WebSocketConnection();
  PairedDevices pairedDevices = PairedDevices();

  Uint8List decryptKey(privateKey, encryptedKey) {
    //reply is a encrypted message in base 64 decrypt it with private key
    final List<int> encrypted = base64.decode(encryptedKey);
    Uint8List bytes = Uint8List.fromList(encrypted);

    //decrypt the message with PKCS1v15
    final decryptedBase64 = rsaDecrypt(privateKey, bytes);
    key = base64.decode(utf8.decode(decryptedBase64));
    return key;
  }

  Future<HttpClient> askForConnection(
      Device device, ConnectionSave oldSave) async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;

    final keyPair = generateRSAkeyPair(exampleSecureRandom());

    final RSAPublicKey publicKey = keyPair.publicKey;
    final RSAPrivateKey privateKey = keyPair.privateKey;

    debugPrint('Asking for connection to ${device.ip}');
    final HttpClient client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 30);
    final HttpClientRequest request = await client.postUrl(
      Uri.parse('http://${device.ip}:${device.port}/connect'),
    );

    request.headers.set('Content-Type', 'application/json');
    request.write(jsonEncode({
      'brand': androidInfo.brand,
      'model': androidInfo.model,
      'id': androidInfo.id,
      'publicKey_modulus': publicKey.modulus.toString(),
      'publicKey_exponent': publicKey.exponent.toString(),
      'fullPass': base64.encode(oldSave.nextPass),
    }));

    final HttpClientResponse response = await request.close();
    final String reply = await response.transform(utf8.decoder).join();
    if (reply == "fullPass not correct") {
      debugPrint('fullPass not correct ${device.ip}');
      client.connectionTimeout = const Duration(seconds: 1);
      return client;
    } else if (reply == "Connection not accepted") {
      debugPrint('Connection not accepted ${device.ip}');
      client.connectionTimeout = const Duration(seconds: 1);
      return client;
    } else if (reply == "Error showing notification") {
      debugPrint('Connection already accepted ${device.ip}');
      client.connectionTimeout = const Duration(seconds: 1);
      return client;
    }

    final key = decryptKey(privateKey, reply);

    debugPrint('Key received: $key');
    return client;
  }

  Future<void> startConnectionWithPc(
      Device device, ConnectionSave oldSave) async {
    if (ws.checkWsConnection()) {
      debugPrint('Already connected');
      return;
    }
    clientPublic = await askForConnection(device, oldSave);
    if (clientPublic.connectionTimeout == const Duration(seconds: 1)) {
      debugPrint('Connection failed');
      return;
    }
    debugPrint('Connected to ${device.ip}');

    ws.createWebSocket(key, device);

    pairedDevices.setNextPasswordForConnection(device, ws);
  }

  Future<void> startProtocol(port) async {
    await pairedDevices.printAllConnectionSave();
    debugPrint("con is ${ws.checkWsConnection()}");

    IsolateNameServer.lookupPortByName('clearDevices')?.send("");

    List<Device> devices = await scanNetwork(port);

    debugPrint('Devices found->');
    for (int i = 0; i < devices.length; i++) {
      debugPrint(
          'Device found: ${devices[i].ip} with hostname: ${devices[i].hostname} and OS: ${devices[i].os} and CPU: ${devices[i].CPU} and RAM: ${devices[i].RAM} at port: ${devices[i].port}');

      final deviceJson = devices[i].toJson();
      IsolateNameServer.lookupPortByName('addDevice')
          ?.send(deviceJson); //add a UI devices

      await PairedDevices().connectToAlreadyPairedDevice(devices[i]);
    }
    IsolateNameServer.lookupPortByName('setDevices')?.send("");
  }
}


//check de desconnect e nao search if connected