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

class PublicGallery {
  int numberOfImagesOnGallery = -1;

  Future<int> getNumberOfImagesOnGallery() async {
    final List<Album> imageAlbums = await PhotoGallery.listAlbums();
    final MediaPage imagePage = await imageAlbums[0].listMedia();

    return imagePage.items.length;
  }

  void checkNumberOfImagesOnGallery() {
    getNumberOfImagesOnGallery().then((value) {
      if (numberOfImagesOnGallery == -1) {
        numberOfImagesOnGallery = value;
      } else if (numberOfImagesOnGallery != value) {
        var numberOfNewImages = value - numberOfImagesOnGallery;
        if (connectionPC.ws.checkWsConnection()) {
          GalleryFunctions().sendNewImages(numberOfNewImages);
        }
        numberOfImagesOnGallery = value;
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
  int imageQuality = 15;

  Future<void> sendFullImage(index) async {
    debugPrint("Waiting here 1");
    final List<Album> imageAlbums = await PhotoGallery.listAlbums();
    debugPrint("Waiting here 2");
    final MediaPage imagePage = await imageAlbums[0].listMedia(
      skip: index,
      take: 1,
    );
    debugPrint("Waiting here 3");
    final image = await imagePage.items[0].getFile();

    debugPrint("Waiting here 4");

    final compressedImage = compressData(image.readAsBytesSync());
    debugPrint("Waiting here 5");
    final imagesb64Bytes = base64.encode(compressedImage);
    debugPrint("Waiting here 6");
    connectionPC.ws.sendData("fullImage//$imagesb64Bytes");
    debugPrint("SENDING FULL IMAGE $index with size ${imagesb64Bytes.length}");
  }

  Future<List<List<int>>> getImageThumbnailFromGalleryWithIndex(
      int numberOfImages, int index) async {
    debugPrint("GETTING IMAGES");

    final List<Album> imageAlbums = await PhotoGallery.listAlbums();
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

  //there is a bug if i call cache images async they get same index

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

    final imageTest = await getImageThumbnailFromGalleryWithIndex(
        numberOfImages, imagesIndex);
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
    gettingImages = false;
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

  Future<void> sendNewImages(int numberOfNewImages) async {
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
    debugPrint("Sending NEW images  $numberOfNewImages");
    debugPrint("resBytes length: ${resBytes.length}");
    connectionPC.ws.sendData("updateGallery//$resBytes");
    imagesIndex += numberOfNewImages;
  }
}
