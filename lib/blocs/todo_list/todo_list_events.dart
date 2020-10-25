// Copyright 2020 Torsten Weber
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

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

class ChangeListColorEvent extends TodoListEvent {
  final Palette color;
  ChangeListColorEvent(this.color);

  @override
  List<Object> get props => [color];
}

class DeleteListEvent extends TodoListEvent {
  @override
  List<Object> get props => [];
}

class GetDataEvent extends TodoListEvent {
  final TodoStatusFilter filter;
  final TodoListOrdering ordering;

  GetDataEvent({this.filter=TodoStatusFilter.active, this.ordering=TodoListOrdering.custom});

  @override
  List<Object> get props => [filter, ordering];
}

class NotifyItemUpdateEvent extends TodoListEvent {
  final TodoItemShort item;
  NotifyItemUpdateEvent(this.item);

  @override
  List<Object> get props => [item];
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
  final TodoItemShort item;
  final int index;

  DeleteItemEvent(this.item, {this.index});

  @override
  List<Object> get props => [item];
}

class CompleteItemEvent extends TodoListEvent {
  final TodoItemShort item;
  final int index;

  CompleteItemEvent(this.item, {this.index});

  @override
  List<Object> get props => [item];
}

class UpdateItemPriorityEvent extends TodoListEvent {
  final TodoItemShort item;
  final int index;
  final TodoPriority priority;

  UpdateItemPriorityEvent(this.item, this.priority, {this.index});

  @override
  List<Object> get props => [item, priority];
}

class ReorderItemsEvent extends TodoListEvent {
  final TodoItemShort moveFrom;
  final int moveFromIndex;
  final TodoItemShort moveTo;
  final int moveToIndex;

  ReorderItemsEvent(this.moveFrom, this.moveFromIndex, this.moveTo, this.moveToIndex);

  @override
  List<Object> get props => [moveFrom, moveTo, moveFromIndex, moveToIndex];
}