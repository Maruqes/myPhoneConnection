import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:myphoneconnection/galleryFunctions.dart';
import 'package:myphoneconnection/main.dart';

class Properties {
  String key;
  String value;
  Properties({required this.key, required this.value});
}

class Players {
  String currentPlayer;
  List<Properties> properties = [];
  Players({required this.currentPlayer, required this.properties});
}

class MediaPlayer {
  Players mediaPlayer = Players(currentPlayer: "", properties: []);

  String url = "";
  String title = "";
  String album = "";
  int length = 0;
  int position = 0;

  void clearMediaPlayer() {
    mediaPlayer = Players(currentPlayer: "", properties: []);
    url = "";
    title = "";
    album = "";
    length = 0;
    position = 0;
  }

  void setPosition(String newPosition) {
    if (url != "" && title != "" && album != "" && length != 0) {
      nots.notifyMediaPlayer(title, album, url, length, int.parse(newPosition));
    }
  }

  void printAllMediaPlayers() {
    debugPrint("Player: ${mediaPlayer.currentPlayer}");
    for (var j = 0; j < mediaPlayer.properties.length; j++) {
      if (mediaPlayer.properties[j].key == "Metadata") {
        try {
          var newRep = mediaPlayer.properties[j].value
              .replaceAll('<', '')
              .replaceAll('>', '')
              .replaceAll('@t', '')
              .replaceAll('@d', '')
              .replaceAll('@o', '');

          debugPrint("newRep: $newRep");
          var metadata = jsonDecode(newRep) as Map<String, dynamic>;
          title = metadata["xesam:title"];
          if (metadata["mpris:length"] != null) {
            length = metadata["mpris:length"];
          } else {
            length = 0;
          }
          if (metadata["xesam:artist"][0] != null) {
            album = metadata["xesam:artist"][0];
          }
          if (metadata["mpris:artUrl"] != null) {
            album = metadata["mpris:artUrl"];
          }
        } catch (e) {
          debugPrint("Error: $e");
        }
      }
    }
    if (mediaPlayer.properties[0].key == "Position") {
      position = int.parse(mediaPlayer.properties[0].value);
    }

    debugPrint("URL: $url");
    debugPrint("Title: $title");
    debugPrint("Album: $album");
    debugPrint("Length: $length");
    debugPrint("Position: $position");

    if (title != "") {
      nots.notifyMediaPlayer(title, album, url, length, position);
    }
  }

  void updateData(String data) {
    try {
      var datadiv = data.split(":div:");
      var currentPlayer = datadiv[0];
      var propertie = datadiv[1];
      var propertieInfo = datadiv[2];
      var end = datadiv[3];

      mediaPlayer.currentPlayer = currentPlayer;
      mediaPlayer.properties
          .add(Properties(key: propertie, value: propertieInfo));

      if (end == "END") {
        printAllMediaPlayers();
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }
}
