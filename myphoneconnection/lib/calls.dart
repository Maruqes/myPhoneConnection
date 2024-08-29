import 'dart:convert';

import 'package:myphoneconnection/server.dart';
import 'package:phone_state/phone_state.dart';
import 'package:contacts_service/contacts_service.dart';

class Calls {
  void setStream() {
    PhoneState.stream.listen((event) {
      String res = "${event.number}//||//${event.status}";

      if (event.number != null) {
        ContactsService.getContactsForPhone(event.number).then((value) {
          String? displayName = "empty";
          String iconb64 = "empty";
          if (value.isNotEmpty) {
            displayName = value.first.displayName;
            iconb64 = base64.encode(value.first.avatar ?? []);
          }
          res += "//||//$displayName";
          res += "//||//$iconb64";
          connectionPC.ws.sendData("phoneCall", res);
        });
      }
    });
  }
}
