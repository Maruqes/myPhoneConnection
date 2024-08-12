import 'dart:convert';

import 'package:flutter/material.dart';

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
  List<Players> mediaPlayers = [];

  void printAllMediaPlayers() {
    for (var i = 0; i < mediaPlayers.length; i++) {
      debugPrint("Player: ${mediaPlayers[i].currentPlayer}");
      for (var j = 0; j < mediaPlayers[i].properties.length; j++) {
        debugPrint(
            "Key: ${mediaPlayers[i].properties[j].key} = ${mediaPlayers[i].properties[j].value}");
      }
    }
  }

  void updateData(String data) {
    var dataSplit = data.split("/|/MediaPlayer/|/");
    for (var i = 0; i < dataSplit.length; i++) {
      var datadiv = dataSplit[i].split(":div:");
      var currentPlayer = datadiv[0];
      var propertie = datadiv[1];
      var propertieInfo = datadiv[2];
      var end = datadiv[3];

      bool found = false;
      for (int j = 0; j < mediaPlayers.length; j++) {
        if (mediaPlayers[j].currentPlayer == currentPlayer) {
          mediaPlayers[j]
              .properties
              .add(Properties(key: propertie, value: propertieInfo));
          found = true;
          break;
        }
      }
      if (!found) {
        mediaPlayers.add(Players(
            currentPlayer: currentPlayer,
            properties: [Properties(key: propertie, value: propertieInfo)]));
      }

      if (end == "END") {
        printAllMediaPlayers();
      }
    }
  }
}
