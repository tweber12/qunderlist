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

import 'package:qunderlist/repository/repository.dart';
import 'package:equatable/equatable.dart';

abstract class TodoListsEvents with EquatableMixin {
  @override
  bool get stringify => true;
}

class LoadTodoListsEvent extends TodoListsEvents {
  @override
  List<Object> get props => [];
}

class TodoListAddedEvent extends TodoListsEvents {
  final TodoList list;
  TodoListAddedEvent(this.list);

  @override
  List<Object> get props => [list];
}

class TodoListDeletedEvent extends TodoListsEvents {
  final int index;
  final TodoList list;
  TodoListDeletedEvent(this.list, this.index);

  @override
  List<Object> get props => [list];
}

class TodoListsReorderedEvent extends TodoListsEvents {
  final TodoList moveFrom;
  final int moveFromIndex;
  final TodoList moveTo;
  final int moveToIndex;
  TodoListsReorderedEvent(this.moveFrom, this.moveFromIndex, this.moveTo, this.moveToIndex);

  @override
  List<Object> get props => [moveFrom,moveTo,moveFromIndex,moveToIndex];
}

class ExternalUpdateEvent extends TodoListsEvents {
  @override
  List<Object> get props => [];
}