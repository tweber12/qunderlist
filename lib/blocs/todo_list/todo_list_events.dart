import 'package:equatable/equatable.dart';
import 'package:qunderlist/repository/models.dart';

abstract class TodoListEvent with EquatableMixin {
  @override
  bool get stringify => true;
}

class RenameListEvent extends TodoListEvent {
  final String name;
  RenameListEvent(this.name);

  @override
  List<Object> get props => [name];
}

class DeleteListEvent extends TodoListEvent {
  @override
  List<Object> get props => [];
}

class GetDataEvent extends TodoListEvent {
  final int start;
  final int end;
  final bool fromBottom;
  final TodoStatusFilter filter;
  final TodoListOrdering ordering;

  GetDataEvent(this.start, this.end, {this.fromBottom=false, this.filter=TodoStatusFilter.active, this.ordering=TodoListOrdering.custom});

  @override
  List<Object> get props => [start, end, fromBottom, filter, ordering];
}

class ReloadDataEvent extends TodoListEvent {
  @override
  List<Object> get props => [];
}

class UpdateFilterEvent extends TodoListEvent {
  final TodoStatusFilter filter;
  UpdateFilterEvent(this.filter);

  @override
  List<Object> get props => [filter];
}

class AddItemEvent extends TodoListEvent {
  final TodoItem item;

  AddItemEvent(this.item);

  @override
  List<Object> get props => [item];
}

class DeleteItemEvent extends TodoListEvent {
  final TodoItem item;
  final int index;

  DeleteItemEvent(this.item, {this.index});

  @override
  List<Object> get props => [item];
}

class CompleteItemEvent extends TodoListEvent {
  final TodoItem item;
  final int index;

  CompleteItemEvent(this.item, {this.index});

  @override
  List<Object> get props => [item];
}

class UpdateItemPriorityEvent extends TodoListEvent {
  final TodoItem item;
  final int index;
  final TodoPriority priority;

  UpdateItemPriorityEvent(this.item, this.priority, {this.index});

  @override
  List<Object> get props => [item, priority];
}

class ReorderItemsEvent extends TodoListEvent {
  final TodoItem item;
  final int moveTo;

  ReorderItemsEvent(this.item, this.moveTo);

  @override
  List<Object> get props => [item, moveTo];
}