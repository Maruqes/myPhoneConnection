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

var publicGallery = PublicGallery();
late List<Album> imageAlbums;
bool sendingNewImages = false;

class PublicGallery {
  int numberOfImagesOnGallery = -1;

  void initGallery() async {
    imageAlbums = await PhotoGallery.listAlbums();
  }

  Future<int> getNumberOfImagesOnGallery() async {
    final MediaPage imagePage = await imageAlbums[0].listMedia();

    return imagePage.items.length;
  }

  void checkNumberOfImagesOnGallery() {
    getNumberOfImagesOnGallery().then((value) async {
      if (numberOfImagesOnGallery == -1) {
        numberOfImagesOnGallery = value;
      } else if (numberOfImagesOnGallery != value) {
        var numberOfNewImages = value - numberOfImagesOnGallery;
        if (connectionPC.ws.checkWsConnection()) {
          if (sendingNewImages) return;
          if (await GalleryFunctions()
              .sendNewImages(numberOfNewImages, value)) {
            numberOfImagesOnGallery = value;
          }
        }
      }
    });
  }
}

class GalleryFunctions {
  int lastImageIndex = 0;
  bool gettingImages = false;
  int imagesIndex = 0;
  int numberOfImages = 750;
  int imageWidth = 150;
  int imageQuality = 30;

  Future<void> sendFullImage(index) async {
    final MediaPage imagePage = await imageAlbums[0].listMedia(
      skip: index,
      take: 1,
    );
    final image = await imagePage.items[0].getFile();
    final mediaType = imagePage.items[0].mediumType;

    Uint8List res = Uint8List(0);
    if (mediaType == MediumType.image) {
      res = await FlutterImageCompress.compressWithList(
        image.readAsBytesSync(),
        quality: 85,
        format: CompressFormat.jpeg,
      );
    } else {
      res = image.readAsBytesSync();
    }

    final compressedImage = compressData(res);
    final imagesb64Bytes = base64.encode(compressedImage);

    if (mediaType == MediumType.video) {
      connectionPC.ws.sendData("fullVIDEO//$imagesb64Bytes");
    } else if (mediaType == MediumType.image) {
      connectionPC.ws.sendData("fullImage//$imagesb64Bytes");
    }
    debugPrint("SENDING FULL IMAGE $index with size ${imagesb64Bytes.length}");
  }

  Future<List<List<int>>> getImageThumbnailFromGalleryWithIndex(
      int numberOfImages, int index) async {
    debugPrint("GETTING IMAGES");

    final MediaPage imagePage = await imageAlbums[0].listMedia(
      skip: index,
      take: numberOfImages,
    );

    final ret = await Future.wait(imagePage.items
        .map((Medium media) =>
            media.getThumbnail(highQuality: true, width: imageWidth))
        .toList());

    return ret;
  }

  Future<String> imageTreatment(List<int> image) async {
    final res = await FlutterImageCompress.compressWithList(
      Uint8List.fromList(image),
      quality: imageQuality,
      format: CompressFormat.jpeg,
    );
    final compressedImage = compressData(res);
    final imagesb64Bytes = base64.encode(compressedImage);

    return "$imagesb64Bytes//DIVIDER//";
  }

  Future<void> sendImages() async {
    if (gettingImages) return;

    gettingImages = true;
    List<Future<String>> futures = [];

    debugPrint("Step 1");
    final imageTest = await getImageThumbnailFromGalleryWithIndex(
        numberOfImages, imagesIndex);
    var resBytes = "";

    debugPrint("Step 2");
    if (imageTest.isNotEmpty) {
      for (var image in imageTest) {
        futures.add(imageTreatment(image));
      }
    }

    debugPrint("Step 3");
    List<String> results = await Future.wait(futures);
    for (var result in results) {
      resBytes += result;
    }

    debugPrint("Step 4");
    debugPrint("resBytes length: ${resBytes.length}");
    connectionPC.ws.sendData("imagetest//$resBytes");
    imagesIndex += numberOfImages;
    gettingImages = false;
    debugPrint("Step 5");
  }

  Future<void> sendFirstImages() async {
    debugPrint("SENDING FIRST IMAGES");

    int numberOfImagesFIRST = 100;

    debugPrint("We are getting: $numberOfImagesFIRST images");

    List<Future<String>> futures = [];

    final imageTest = await getImageThumbnailFromGalleryWithIndex(
        numberOfImagesFIRST, imagesIndex);
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
    connectionPC.ws.sendData("imageFirst//$resBytes");
    imagesIndex += numberOfImagesFIRST;
  }

//entao... o que eu acho q estava a conetcer era no momento em q pedia novas images o numero era x, e durante o tempo de ir buscar essas x images
//o nummero de images na galeria mudava, e entao quando ia buscar as x images,
//o numero de images na galeria ja nao era o mesmo, entao é preciso o numberOfNeededImages
  Future<bool> sendNewImages(
      int numberOfNewImages, numberOfNeededImages) async {
    sendingNewImages = true;
    List<Future<String>> futures = [];

    final imageTest =
        await getImageThumbnailFromGalleryWithIndex(numberOfNewImages, 0);
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

    int numberOfCurrentImages =
        await publicGallery.getNumberOfImagesOnGallery();

    if (numberOfCurrentImages != numberOfNeededImages) {
      debugPrint(
          "We are not sending the images because the number of images on the gallery is different from the number of images we have");
      sendingNewImages = false;
      return false;
    }

    debugPrint("Sending NEW images  $numberOfNewImages");
    debugPrint("resBytes length: ${resBytes.length}");
    connectionPC.ws.sendData("updateGallery//$resBytes");
    imagesIndex += numberOfNewImages;
    sendingNewImages = false;
    return true;
  }
}
