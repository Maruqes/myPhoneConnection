import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import "package:pointycastle/export.dart";

final storage = new FlutterSecureStorage();

Future<void> writeData(String key, String value) async {
  await storage.write(key: key, value: value);
  debugPrint('Data saved');
}

Future<String?> readData(String key) async {
  return await storage.read(key: key);
}

Future<Map<String, String>> readDataAll(String key) async {
  return await storage.readAll();
}

Future<void> deleteData(String key) async {
  await storage.delete(key: key);
}

Future<void> deleteAll() async {
  await storage.deleteAll();
}

AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey> generateRSAkeyPair(
    SecureRandom secureRandom,
    {int bitLength = 2048}) {
  // Create an RSA key generator and initialize it

  // final keyGen = KeyGenerator('RSA'); // Get using registry
  final keyGen = RSAKeyGenerator();

  keyGen.init(ParametersWithRandom(
      RSAKeyGeneratorParameters(BigInt.parse('65537'), bitLength, 64),
      secureRandom));

  // Use the generator

  final pair = keyGen.generateKeyPair();

  // Cast the generated key pair into the RSA key types

  final myPublic = pair.publicKey as RSAPublicKey;
  final myPrivate = pair.privateKey as RSAPrivateKey;

  return AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey>(myPublic, myPrivate);
}

SecureRandom exampleSecureRandom() {
  final secureRandom = FortunaRandom();
  final seedSource = Random.secure();
  final seeds = <int>[];

  for (var i = 0; i < 32; i++) {
    seeds.add(seedSource.nextInt(255));
  }
  secureRandom.seed(KeyParameter(Uint8List.fromList(seeds)));

  return secureRandom;
}

String getRandomString() {
  final length = Random().nextInt(10) + 10;
  const charset = 'abcdefghijklmnopqrstuvwxyz0123456789';
  return List.generate(length, (index) {
    final randomIndex = Random.secure().nextInt(charset.length);
    return charset[randomIndex];
  }).join();
}

Uint8List processInBlocks(AsymmetricBlockCipher engine, Uint8List input) {
  final numBlocks = input.length ~/ engine.inputBlockSize +
      ((input.length % engine.inputBlockSize != 0) ? 1 : 0);

  final output = Uint8List(numBlocks * engine.outputBlockSize);

  var inputOffset = 0;
  var outputOffset = 0;
  while (inputOffset < input.length) {
    final chunkSize = (inputOffset + engine.inputBlockSize <= input.length)
        ? engine.inputBlockSize
        : input.length - inputOffset;

    outputOffset += engine.processBlock(
        input, inputOffset, chunkSize, output, outputOffset);

    inputOffset += chunkSize;
  }

  return (output.length == outputOffset)
      ? output
      : output.sublist(0, outputOffset);
}
