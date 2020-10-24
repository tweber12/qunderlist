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
import 'package:qunderlist/repository/repository.dart';

abstract class TodoDetailsState with EquatableMixin {
  @override
  bool get stringify => true;
}

class TodoDetailsLoading extends TodoDetailsState {
  @override
  List<Object> get props => [];
}

class TodoDetailsLoadedShortItem extends TodoDetailsState {
  final TodoItemBase item;
  TodoDetailsLoadedShortItem(this.item);

  @override
  List<Object> get props => [item];
}

class TodoDetailsFullyLoaded extends TodoDetailsState {
  final TodoItem item;
  TodoDetailsFullyLoaded(this.item);

  @override
  List<Object> get props => [item];
}