import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:myphoneconnection/config.dart';
import 'package:myphoneconnection/main.dart';
import 'package:myphoneconnection/server.dart';
import 'package:photo_gallery/photo_gallery.dart';

class GalleryFunctions {
  int lastImageIndex = 0;

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

  Future<List<File>> getImageFromGalleryWithIndex(
      int numberOfImages, int index) async {
    debugPrint("GETTING IMAGES");

    final List<Album> imageAlbums = await PhotoGallery.listAlbums();
    final MediaPage imagePage = await imageAlbums[0].listMedia(
      skip: index,
      take: numberOfImages,
    );

    final List<File> imageFiles = await Future.wait(imagePage.items
        .where((Medium media) =>
            media.filename!.contains("png") ||
            media.filename!.contains("jpg") ||
            media.filename!.contains("jpeg"))
        .map((Medium media) => media.getFile())
        .toList());

    return imageFiles;
  }

  int imagesIndex = 0;
  int numberOfImages = 500;
  //there is a bug if i call cache images async they get same index

  Future<String> imageTreatment(File image) async {
    final imageBytes = await image.readAsBytes();

    final res = await FlutterImageCompress.compressWithList(
      imageBytes,
      quality: 70,
      format: CompressFormat.jpeg,
      minWidth: 150,
      minHeight: 150,
    );
    final compressedImage = compressData(res);
    final imagesb64Bytes = base64.encode(compressedImage);
    return "$imagesb64Bytes//DIVIDER//";
  }

  Future<void> sendImages() async {
    List<Future<String>> futures = [];

    final imageTest =
        await getImageFromGalleryWithIndex(numberOfImages, imagesIndex);
    var resBytes = "";

    if (imageTest.isNotEmpty) {
      for (var image in imageTest) {
        futures.add(imageTreatment(image));
      }
    }
    List<String> results = await Future.wait(futures);
    for (var result in results) {
      resBytes += result;
    }
    debugPrint("resBytes length: ${resBytes.length}");
    connectionPC.ws.sendData("imagetest//$resBytes");
    imagesIndex += numberOfImages;
  }

  Future<void> sendFirstImages() async {
    debugPrint("SENDING FIRST IMAGES");
    const numberOfImagesFIRST = 30;

    List<Future<String>> futures = [];

    final imageTest =
        await getImageFromGalleryWithIndex(numberOfImagesFIRST, imagesIndex);
    var resBytes = "";

    if (imageTest.isNotEmpty) {
      for (var image in imageTest) {
        futures.add(imageTreatment(image));
      }
    }
    List<String> results = await Future.wait(futures);
    for (var result in results) {
      resBytes += result;
    }
    debugPrint("resBytes length: ${resBytes.length}");
    connectionPC.ws.sendData("imagetest//$resBytes");
    imagesIndex += numberOfImagesFIRST;
  }
}
