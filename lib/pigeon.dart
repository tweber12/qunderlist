// Autogenerated from Pigeon (v0.1.4), do not edit directly.
// See also: https://pub.dev/packages/pigeon
// ignore_for_file: public_member_api_docs, non_constant_identifier_names, avoid_as, unused_import
import 'dart:async';
import 'package:flutter/services.dart';

class ItemId {
  int id;
  // ignore: unused_element
  Map<dynamic, dynamic> _toMap() {
    final Map<dynamic, dynamic> pigeonMap = <dynamic, dynamic>{};
    pigeonMap['id'] = id;
    return pigeonMap;
  }
  // ignore: unused_element
  static ItemId _fromMap(Map<dynamic, dynamic> pigeonMap) {
    if (pigeonMap == null){
      return null;
    }
    final ItemId result = ItemId();
    result.id = pigeonMap['id'];
    return result;
  }
}

class SetReminder {
  int reminderId;
  int time;
  // ignore: unused_element
  Map<dynamic, dynamic> _toMap() {
    final Map<dynamic, dynamic> pigeonMap = <dynamic, dynamic>{};
    pigeonMap['reminderId'] = reminderId;
    pigeonMap['time'] = time;
    return pigeonMap;
  }
  // ignore: unused_element
  static SetReminder _fromMap(Map<dynamic, dynamic> pigeonMap) {
    if (pigeonMap == null){
      return null;
    }
    final SetReminder result = SetReminder();
    result.reminderId = pigeonMap['reminderId'];
    result.time = pigeonMap['time'];
    return result;
  }
}

class DeleteReminder {
  int reminderId;
  // ignore: unused_element
  Map<dynamic, dynamic> _toMap() {
    final Map<dynamic, dynamic> pigeonMap = <dynamic, dynamic>{};
    pigeonMap['reminderId'] = reminderId;
    return pigeonMap;
  }
  // ignore: unused_element
  static DeleteReminder _fromMap(Map<dynamic, dynamic> pigeonMap) {
    if (pigeonMap == null){
      return null;
    }
    final DeleteReminder result = DeleteReminder();
    result.reminderId = pigeonMap['reminderId'];
    return result;
  }
}

abstract class DartApi {
  void notificationCallback(ItemId arg);
  void reloadDb();
  static void setup(DartApi api) {
    {
      const BasicMessageChannel<dynamic> channel =
          BasicMessageChannel<dynamic>('dev.flutter.pigeon.DartApi.notificationCallback', StandardMessageCodec());
      channel.setMessageHandler((dynamic message) async {
        final Map<dynamic, dynamic> mapMessage = message as Map<dynamic, dynamic>;
        final ItemId input = ItemId._fromMap(mapMessage);
        api.notificationCallback(input);
      });
    }
    {
      const BasicMessageChannel<dynamic> channel =
          BasicMessageChannel<dynamic>('dev.flutter.pigeon.DartApi.reloadDb', StandardMessageCodec());
      channel.setMessageHandler((dynamic message) async {
        final Map<dynamic, dynamic> mapMessage = message as Map<dynamic, dynamic>;
        api.reloadDb();
      });
    }
  }
}

class Api {
  Future<void> ready() async {
    const BasicMessageChannel<dynamic> channel =
        BasicMessageChannel<dynamic>('dev.flutter.pigeon.Api.ready', StandardMessageCodec());
    
    final Map<dynamic, dynamic> replyMap = await channel.send(null);
    if (replyMap == null) {
      throw PlatformException(
        code: 'channel-error',
        message: 'Unable to establish connection on channel.',
        details: null);
    } else if (replyMap['error'] != null) {
      final Map<dynamic, dynamic> error = replyMap['error'];
      throw PlatformException(
          code: error['code'],
          message: error['message'],
          details: error['details']);
    } else {
      // noop
    }
    
  }
  Future<void> setReminder(SetReminder arg) async {
    final Map<dynamic, dynamic> requestMap = arg._toMap();
    const BasicMessageChannel<dynamic> channel =
        BasicMessageChannel<dynamic>('dev.flutter.pigeon.Api.setReminder', StandardMessageCodec());
    
    final Map<dynamic, dynamic> replyMap = await channel.send(requestMap);
    if (replyMap == null) {
      throw PlatformException(
        code: 'channel-error',
        message: 'Unable to establish connection on channel.',
        details: null);
    } else if (replyMap['error'] != null) {
      final Map<dynamic, dynamic> error = replyMap['error'];
      throw PlatformException(
          code: error['code'],
          message: error['message'],
          details: error['details']);
    } else {
      // noop
    }
    
  }
  Future<void> updateReminder(SetReminder arg) async {
    final Map<dynamic, dynamic> requestMap = arg._toMap();
    const BasicMessageChannel<dynamic> channel =
        BasicMessageChannel<dynamic>('dev.flutter.pigeon.Api.updateReminder', StandardMessageCodec());
    
    final Map<dynamic, dynamic> replyMap = await channel.send(requestMap);
    if (replyMap == null) {
      throw PlatformException(
        code: 'channel-error',
        message: 'Unable to establish connection on channel.',
        details: null);
    } else if (replyMap['error'] != null) {
      final Map<dynamic, dynamic> error = replyMap['error'];
      throw PlatformException(
          code: error['code'],
          message: error['message'],
          details: error['details']);
    } else {
      // noop
    }
    
  }
  Future<void> deleteReminder(DeleteReminder arg) async {
    final Map<dynamic, dynamic> requestMap = arg._toMap();
    const BasicMessageChannel<dynamic> channel =
        BasicMessageChannel<dynamic>('dev.flutter.pigeon.Api.deleteReminder', StandardMessageCodec());
    
    final Map<dynamic, dynamic> replyMap = await channel.send(requestMap);
    if (replyMap == null) {
      throw PlatformException(
        code: 'channel-error',
        message: 'Unable to establish connection on channel.',
        details: null);
    } else if (replyMap['error'] != null) {
      final Map<dynamic, dynamic> error = replyMap['error'];
      throw PlatformException(
          code: error['code'],
          message: error['message'],
          details: error['details']);
    } else {
      // noop
    }
    
  }
}

