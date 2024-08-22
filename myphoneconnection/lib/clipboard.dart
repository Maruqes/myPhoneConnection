import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:super_clipboard/super_clipboard.dart';
import 'package:flutter/services.dart';

class ClipboardUniversal {
  void copy(String data) async {
    try {
      final clipboard = SystemClipboard.instance;
      if (clipboard != null) {
        final item = DataWriterItem();
        item.add(Formats.plainText(data));
        await clipboard.write([item]);
      } else {
        debugPrint('Clipboard is not available on this platform.');
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  void copyIMG(String data) async {
    try {
      final clipboard = SystemClipboard.instance;
      if (clipboard != null) {
        final item = DataWriterItem();

        Uint8List bytes = base64.decode(data);
        item.add(Formats.png(bytes));
        await clipboard.write([item]);
      } else {
        debugPrint('Clipboard is not available on this platform.');
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }
}


//teste
