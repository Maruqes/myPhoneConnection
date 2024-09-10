// ignore: file_names
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:myphoneconnection/config.dart';
import 'package:myphoneconnection/main.dart';
import 'package:audio_service/audio_service.dart';
import 'package:myphoneconnection/server.dart';

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
  bool paused = true;

  void clearNotification(String nullS) {
    customAudioHandler.audioHandler.stop();
  }

  void clearMediaPlayer(String nullS) {
    mediaPlayer = Players(currentPlayer: "", properties: []);
    url = "";
    title = "";
    album = "";
    length = 0;
    position = 0;
    paused = true;
  }

  void setPosition(String newPosition) {
    try {
      final data = newPosition.split("|/|");
      if (data[1] == "true") {
        paused = true;
      } else {
        paused = false;
      }
      if (url != "" && title != "" && album != "" && length != 0) {
        customAudioHandler.setPosition(int.parse(data[0]));
      }
    } catch (e) {
      debugPrint("Error: $e");
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
            url = metadata["mpris:artUrl"];
          }
        } catch (e) {
          debugPrint("Error: $e");
        }
      }
      if (mediaPlayer.properties[j].key == "PlaybackStatus") {
        if (mediaPlayer.properties[j].value == "\"Playing\"") {
          paused = false;
        } else {
          paused = true;
        }
        debugPrint("playbackStatus: ${mediaPlayer.properties[j].value}");
      }
    }

    debugPrint("URL: $url");
    debugPrint("Title: $title");
    debugPrint("Album: $album");
    debugPrint("Length: $length");
    debugPrint("Position: $position");
    debugPrint("Paused: $paused");
    if (title != "") {
      //restart the audio handler
      customAudioHandler.setMediaItem(title, album, url, length);
      if (paused) {
        customAudioHandler.PcPause();
        debugPrint("Paused");
      } else {
        customAudioHandler.pcPlay();
        debugPrint("Playing");
      }
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

class CustomAudioHandler extends BaseAudioHandler with SeekHandler {
  late AudioHandler audioHandler;

  // ignore: non_constant_identifier_names
  late String Title;
  // ignore: non_constant_identifier_names
  late String Album;
  // ignore: non_constant_identifier_names
  late String Url;
  // ignore: non_constant_identifier_names
  late int Length;
  // ignore: non_constant_identifier_names
  late int Position;

  @override
  Future<void> seek(Duration position) async {
    connectionPC.ws
        .sendData("mediaSetPosition", position.inMicroseconds.toString());
  }

  @override
  Future<void> skipToPrevious() async {
    connectionPC.ws.sendData("media", "previous");
  }

  @override
  Future<void> skipToNext() async {
    connectionPC.ws.sendData("media", "next");
  }

  @override
  Future<void> play() async {
    // Update the state to playing
    playbackState.add(playbackState.value.copyWith(
      playing: true,
      controls: [
        MediaControl.skipToPrevious,
        MediaControl.pause,
        MediaControl.skipToNext
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      processingState: AudioProcessingState.ready,
    ));

    connectionPC.ws.sendData("media", "play");

    // Update the notification
    _setNotification();
  }

  Future<void> pcPlay() async {
    // Update the state to playing
    playbackState.add(playbackState.value.copyWith(
      playing: true,
      controls: [
        MediaControl.skipToPrevious,
        MediaControl.pause,
        MediaControl.skipToNext
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      processingState: AudioProcessingState.ready,
    ));

    // Update the notification
    _setNotification();
  }

  @override
  Future<void> pause() async {
    // Update the state to paused
    playbackState.add(playbackState.value.copyWith(
      playing: false,
      controls: [
        MediaControl.skipToPrevious,
        MediaControl.play,
        MediaControl.skipToNext
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      processingState: AudioProcessingState.ready,
    ));
    connectionPC.ws.sendData("media", "pause");

    // Update the notification
    _setNotification();
  }

  // ignore: non_constant_identifier_names
  Future<void> PcPause() async {
    // Update the state to paused
    playbackState.add(playbackState.value.copyWith(
      playing: false,
      controls: [
        MediaControl.skipToPrevious,
        MediaControl.play,
        MediaControl.skipToNext
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      processingState: AudioProcessingState.ready,
    ));

    // Update the notification
    _setNotification();
  }

  Future<void> setPosition(int position) async {
    Position = position;
    // Update the position of the media

    playbackState.add(playbackState.value.copyWith(
      updatePosition: Duration(microseconds: Position),
    ));

    // Update the notification
  }

  Future<void> _setNotification() async {
    Uri? uri;
    if (await doesUrlExist(Url)) {
      uri = Uri.parse(Url);
    } else {
      uri = null;
    }
    mediaItem.add(MediaItem(
      id: '1',
      album: Album,
      title: Title,
      artUri: uri,
      duration: Duration(microseconds: Length),
    ));
  }

  void setMediaItem(String title, String album, String url, int length) async {
    Title = title;
    Album = album;
    Length = length;
    Url = url;
    _setNotification();
  }
}
