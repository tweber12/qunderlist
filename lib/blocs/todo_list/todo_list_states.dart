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
import 'package:qunderlist/blocs/cache.dart';
import 'package:qunderlist/repository/repository.dart';

abstract class TodoListStates with EquatableMixin {
  @override
  bool get stringify => true;
}

class TodoListLoading extends TodoListStates {
  final TodoList list;
  TodoListLoading(this.list);

  @override
  List<Object> get props => [list];
}

class TodoListLoadingFailed extends TodoListStates {
  @override
  List<Object> get props => [];
}

class TodoListLoaded extends TodoListStates {
  final TodoList list;
  final ListCache<TodoItemShort> items;

  TodoListLoaded(this.list, this.items);

  @override
  List<Object> get props => [list, items];
}

class TodoListDeleted extends TodoListStates {
  @override
  List<Object> get props => [];
}