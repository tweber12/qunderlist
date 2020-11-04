import 'package:equatable/equatable.dart';
import 'package:qunderlist/repository/models.dart';

abstract class BaseEvent with EquatableMixin {}

class BaseShowHomeEvent extends BaseEvent {
  @override
  List<Object> get props => [];
}

class BaseShowListEvent extends BaseEvent {
  final int listId;
  final TodoList list;
  BaseShowListEvent(this.listId, {this.list});

  @override
  List<Object> get props => [listId, list];
}

class BaseShowItemEvent extends BaseEvent {
  final int listId;
  final TodoList list;
  final int itemId;
  final TodoItemBase item;
  BaseShowItemEvent(this.itemId, {this.listId, this.list, this.item});

  @override
  List<Object> get props => [listId, itemId, this.list, this.item];
}

class BasePopEvent extends BaseEvent {
  @override
  List<Object> get props => [];
}