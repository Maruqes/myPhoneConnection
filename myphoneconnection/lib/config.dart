import 'dart:convert';
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

Uint8List rsaEncrypt(RSAPublicKey myPublic, Uint8List dataToEncrypt) {
  final encryptor = PKCS1Encoding(RSAEngine())
    ..init(true, PublicKeyParameter<RSAPublicKey>(myPublic)); // true=encrypt

  return processInBlocks(encryptor, dataToEncrypt);
}

Uint8List rsaDecrypt(RSAPrivateKey myPrivate, Uint8List cipherText) {
  final decryptor = PKCS1Encoding(RSAEngine())
    ..init(
        false, PrivateKeyParameter<RSAPrivateKey>(myPrivate)); // false=decrypt

  return processInBlocks(decryptor, cipherText);
}

String generateRandomString(int len) {
  final random = Random.secure();
  const chars =
      '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';
  return List.generate(len, (index) => chars[random.nextInt(chars.length)])
      .join();
}

Uint8List generateRandomBytes(int length) {
  final random = Random.secure();
  final bytes = Uint8List(length);
  for (int i = 0; i < length; i++) {
    bytes[i] = random.nextInt(256);
  }
  return bytes;
}

String decryptAES(Uint8List key, String base64CipherText) {
  // Base64 decode the ciphertext
  Uint8List cipherTextWithIV = base64.decode(base64CipherText);

  Uint8List iv = Uint8List(16); // Use the same static zero IV as in Go code
  Uint8List cipherText =
      cipherTextWithIV.sublist(16); // Adjust based on actual IV handling

  var cipher =
      PaddedBlockCipherImpl(PKCS7Padding(), CBCBlockCipher(AESEngine()));
  var paddedParams = PaddedBlockCipherParameters(
    ParametersWithIV(KeyParameter(key), iv),
    null,
  );
  cipher.init(false, paddedParams);

  return utf8.decode(cipher.process(cipherText));
}

String encryptAES(Uint8List key, String plainText) {
  var cipher =
      PaddedBlockCipherImpl(PKCS7Padding(), CBCBlockCipher(AESEngine()));
  var iv = Uint8List(16);
  var paddedParams = PaddedBlockCipherParameters(
    ParametersWithIV(KeyParameter(key), iv),
    null,
  );
  cipher.init(true, paddedParams);

  var cipherText = cipher.process(utf8.encode(plainText));
  var cipherTextWithIV = Uint8List.fromList(iv + cipherText);

  return base64.encode(cipherTextWithIV);
}
