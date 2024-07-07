import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:myphoneconnection/config.dart';
import 'package:flutter/material.dart';
import 'package:myphoneconnection/main.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import "package:pointycastle/export.dart";

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

/* 
doulhe uma public key onde ele deve guardar
ps:devo guardar a private e public key no storage

para aceitar um websocket ele deve descriptar uma mensagem minha com a public key dele e me enviar a resposta 
*/

class ConnectionPC {
  late Uint8List key;

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

    //reply is a encrypted message in base 64 decrypt it with private key
    final List<int> encrypted = base64.decode(reply);
    Uint8List bytes = Uint8List.fromList(encrypted);

    //decrypt the message with PKCS1v15
    final decryptedBase64 = rsaDecrypt(privateKey, bytes);
    key = base64.decode(utf8.decode(decryptedBase64));

    debugPrint('Key received: $key');

    return client;
  }

  Future<void> startConnectionWithPc(Device device) async {
    HttpClient client = await askForConnection(device);
  }

  Future<void> startProtocol(port) async {
    List<Device> devices = await scanNetwork(port);

    debugPrint('Devices found:');
    for (int i = 0; i < devices.length; i++) {
      debugPrint(
          'Device found: ${devices[i].ip} with hostname: ${devices[i].hostname} and OS: ${devices[i].os} and CPU: ${devices[i].CPU} and RAM: ${devices[i].RAM} at port: ${devices[i].port}');
      globalDeviceList.add(devices[i]);
    }
  }
}
