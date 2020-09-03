// Generate code by running
// C:\Users\torst\devel\flutter\bin\flutter pub run pigeon --input pigeon.dart --dart_out lib\pigeon.dart --java_out android\app\src\main\java\dev\flutter\pigeon\Pigeon.java --java_package "dev.flutter.pigeon"

import 'package:pigeon/pigeon.dart';

class ItemId {
  int id;
}

class SetReminder {
  int reminderId;
  int time;
}
class DeleteReminder {
  int reminderId;
}

@FlutterApi()
abstract class DartApi {
  void notificationCallback(ItemId itemId);
}

@HostApi()
abstract class Api {
  void ready();
  void setReminder(SetReminder reminder);
  void updateReminder(SetReminder reminder);
  void deleteReminder(DeleteReminder reminder);
}