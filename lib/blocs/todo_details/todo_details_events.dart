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

abstract class TodoDetailsEvent with EquatableMixin {
  @override
  bool get stringify => true;
}

class UpdateTitleEvent extends TodoDetailsEvent {
  final String newTitle;
  UpdateTitleEvent(this.newTitle);

  @override
  List<Object> get props => [newTitle];
}

class ToggleCompletedEvent extends TodoDetailsEvent {
  @override
  List<Object> get props => [];
}

class UpdatePriorityEvent extends TodoDetailsEvent {
  final TodoPriority newPriority;
  UpdatePriorityEvent(this.newPriority);

  @override
  List<Object> get props => [newPriority];
}

class UpdateNoteEvent extends TodoDetailsEvent {
  final String newNote;
  UpdateNoteEvent(this.newNote);

  @override
  List<Object> get props => [newNote];
}

class UpdateDueDateEvent extends TodoDetailsEvent {
  final DateTime newDueDate;
  UpdateDueDateEvent(this.newDueDate);

  @override
  List<Object> get props => [newDueDate];
}

class UpdateRepeatedEvent extends TodoDetailsEvent {
  final Repeated repeated;
  UpdateRepeatedEvent(this.repeated);

  @override
  List<Object> get props => [repeated];
}

class AddReminderEvent extends TodoDetailsEvent {
  final Reminder reminder;
  AddReminderEvent(this.reminder);

  @override
  List<Object> get props => [reminder];
}
class UpdateReminderEvent extends TodoDetailsEvent {
  final Reminder reminder;
  UpdateReminderEvent(this.reminder);

  @override
  List<Object> get props => [reminder];
}
class DeleteReminderEvent extends TodoDetailsEvent {
  final Reminder reminder;
  DeleteReminderEvent(this.reminder);

  @override
  List<Object> get props => [reminder];
}

class LoadItemEvent extends TodoDetailsEvent {
  @override
  List<Object> get props => [];
}

class AddToListEvent extends TodoDetailsEvent {
  final TodoList list;
  AddToListEvent(this.list);

  @override
  List<Object> get props => [list];
}

class RemoveFromListEvent extends TodoDetailsEvent {
  final int listId;
  RemoveFromListEvent(this.listId);

  @override
  List<Object> get props => [listId];
}

class MoveToListEvent extends TodoDetailsEvent {
  final int oldListId;
  final TodoList newList;
  MoveToListEvent(this.oldListId, this.newList);

  @override
  List<Object> get props => [oldListId,newList];
}

class CopyToListEvent extends TodoDetailsEvent {
  final TodoList list;
  CopyToListEvent(this.list);

  @override
  List<Object> get props => [list];
}

class DeleteEvent extends TodoDetailsEvent {
  @override
  List<Object> get props => [];
}

class ExternalUpdateEvent extends TodoDetailsEvent {
  @override
  List<Object> get props => [];
}