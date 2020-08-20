import 'package:pigeon/pigeon.dart';

class ItemId {
  int id;
}

class SetReminder {
  int reminderId;
  int itemId;
  String itemName;
  String itemNote;
  String time;
}

@FlutterApi()
abstract class DartApi {
  void notificationCallback(ItemId itemId);
}

@HostApi()
abstract class Api {
  void ready();
  void setReminder(SetReminder reminder);
}