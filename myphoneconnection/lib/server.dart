import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:myphoneconnection/config.dart';
import 'package:flutter/material.dart';
import 'package:myphoneconnection/main.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import "package:pointycastle/export.dart";
import 'package:web_socket_channel/web_socket_channel.dart';

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
        debugPrint('Scanning IP: $ip:$port');
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
        writeData("connectionSave$index", jsonEncode(save.toJson()));
        debugPrint('Connection saved on index $index');
        return;
      }

      oldSave = await readConnectionSave("connectionSave", index);
      index++;
    }

    writeData("connectionSave$index", jsonEncode(save.toJson()));
    debugPrint('Connection saved on index $index');
  }

  Future<void> checkNextPasswordProtocolLast(
      Device device, Uint8List nextPass) async {
    //clear connection save FALTA DAR CLEAR CARALHO

    final HttpClient client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 30);
    final HttpClientRequest request = await client.postUrl(
      Uri.parse('http://${device.ip}:${device.port}/nextPassProtocolLastPass'),
    );

    request.headers.set('Content-Type', 'application/json');
    request.write(jsonEncode({
      'fullPass': base64.encode(nextPass),
    }));

    final HttpClientResponse response = await request.close();
    final String reply = await response.transform(utf8.decoder).join();
    if (reply == 'OK') {
      debugPrint('Connection established with ${device.ip}');
      ConnectionPC().startConnectionWithPc(device);
    } else {
      debugPrint('Connection failed with ${device.ip}');
    }
  }

  Future<void> checkNextPasswordProtocol(
      Device device, Uint8List nextPass) async {
    final HttpClient client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 3);
    final HttpClientRequest request = await client.get(
      device.ip,
      int.parse(device.port),
      '/startNextPassProtocol',
    );
    final HttpClientResponse response = await request.close();
    final String reply = await response.transform(utf8.decoder).join();

    final last8Bytes = nextPass.sublist(8, 16);
    final last8BytesBase64 = base64.encode(last8Bytes);
    if (reply == last8BytesBase64) {
      debugPrint('Connection is going with ${device.ip}');
      checkNextPasswordProtocolLast(device, nextPass);
    } else {
      debugPrint('Connection failed with ${device.ip}');
    }
  }

  Future<void> connectToAlreadyPairedDevice(Device device) async {
    int index = 0;
    ConnectionSave? oldSave = await readConnectionSave("connectionSave", index);

    while (oldSave != null) {
      oldSave = await readConnectionSave("connectionSave", index);
      debugPrint(
          'Old save($index): ${oldSave?.device.hostname} with CPU ${oldSave?.device.CPU} and RAM ${oldSave?.device.RAM}');

      if (oldSave != null) {
        if (oldSave.device.hostname == device.hostname &&
            oldSave.device.os == device.os &&
            oldSave.device.CPU == device.CPU &&
            oldSave.device.RAM == device.RAM) {
          checkNextPasswordProtocol(device, oldSave.nextPass);
          debugPrint(
              'Found matching save ${device.hostname} with CPU ${device.CPU} and RAM ${device.RAM}');
          return;
        }
      }

      debugPrint('Checked Index: $index');
      index++;
    }
  }

  void setNextPasswordForConnection(Device device, WebSocketConnection ws) {
    final nextPass = generateRandomBytes(16);
    final nextPassBase64 = base64.encode(nextPass);
    final data = "nextPass//$nextPassBase64";
    ws.sendData(data);

    ConnectionSave save = ConnectionSave(
      device,
      nextPass,
    );

    writeConnectionSave(save, device);
  }
}

class WebSocketConnection {
  late WebSocketChannel channel;
  late Uint8List key;

  WebSocketConnection(this.key);

  void sendData(dynamic data) {
    final encData = encryptAES(key, data);
    channel.sink.add(encData);
  }

  void recieveData(String data) {
    final dec = decryptAES(key, data);
    debugPrint('Recieved dec: $dec');
  }

  void createWebSocket(Device device) {
    channel = WebSocketChannel.connect(
      Uri.parse('ws://${device.ip}:${device.port}/ws'),
    );
    channel.stream.listen((message) {
      recieveData(message);
    });
    sendData('Hello from phone');
  }
}

class ConnectionPC {
  late Uint8List key;
  HttpClient clientPublic = HttpClient();
  late WebSocketConnection ws;

  Uint8List decryptKey(privateKey, encryptedKey) {
    //reply is a encrypted message in base 64 decrypt it with private key
    final List<int> encrypted = base64.decode(encryptedKey);
    Uint8List bytes = Uint8List.fromList(encrypted);

    //decrypt the message with PKCS1v15
    final decryptedBase64 = rsaDecrypt(privateKey, bytes);
    key = base64.decode(utf8.decode(decryptedBase64));
    return key;
  }

  Future<HttpClient> askForConnection(Device device) async {
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
    }));

    final HttpClientResponse response = await request.close();
    final String reply = await response.transform(utf8.decoder).join();

    final key = decryptKey(privateKey, reply);

    debugPrint('Key received: $key');

    return client;
  }

  Future<void> startConnectionWithPc(Device device) async {
    clientPublic = await askForConnection(device);
    ws = WebSocketConnection(key);
    ws.createWebSocket(device);
    PairedDevices().setNextPasswordForConnection(device, ws);
  }

  Future<void> startProtocol(port) async {
    IsolateNameServer.lookupPortByName('clearDevices')?.send("");

    List<Device> devices = await scanNetwork(port);

    debugPrint('Devices found->');
    for (int i = 0; i < devices.length; i++) {
      final deviceJson = devices[i].toJson();
      IsolateNameServer.lookupPortByName('addDevice')?.send(deviceJson);

      PairedDevices().connectToAlreadyPairedDevice(devices[i]);

      debugPrint(
          'Device found: ${devices[i].ip} with hostname: ${devices[i].hostname} and OS: ${devices[i].os} and CPU: ${devices[i].CPU} and RAM: ${devices[i].RAM} at port: ${devices[i].port}');
    }
  }
}
