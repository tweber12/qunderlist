import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:mutex/mutex.dart';
import 'package:qunderlist/blocs/todo_details/todo_details_events.dart';
import 'package:qunderlist/blocs/todo_details/todo_details_states.dart';
import 'package:qunderlist/blocs/todo_list.dart';
import 'package:qunderlist/notification_handler.dart';
import 'package:qunderlist/pigeon.dart';
import 'package:qunderlist/repository/repository.dart';

class RateLimit {
  final Duration _gap;
  final Function() _callback;

  bool _timeout = false;
  bool _requestDuringTimeout = false;

  RateLimit(this._gap, this._callback);

  void call() async {
    if (_timeout) {
      _requestDuringTimeout = true;
      return;
    }
    _timeout = true;
    _requestDuringTimeout = false;
    _callback();
    await Future.delayed(_gap);
    _timeout = false;
    if (_requestDuringTimeout) {
      call();
    }
  }
}

class TodoDetailsBloc<R extends TodoRepository> extends Bloc<TodoDetailsEvent,TodoDetailsState> {
  int _itemId;
  TodoItem _item;
  List<TodoList> _lists;
  final TodoListBloc _listBloc;
  final R _repository;
  final Api api;
  RateLimit notifier;
  // Ensure that only one process modifies the cache and db at the same time
  // This is done to avoid problems with the db and the cache getting out of sync
  final Mutex _writeMutex = Mutex();
  StreamSubscription _updateStream;

  TodoDetailsBloc(R repository, int itemId, {TodoItem item, TodoListBloc listBloc}):
        _repository=repository,
        _listBloc=listBloc,
        _item=item,
        _itemId = itemId,
        api = Api(),
        super(item==null ? TodoDetailsLoading() : TodoDetailsLoadedItem(item))
  {
    notifier = _listBloc!=null ? RateLimit(Duration(seconds: 1), _notifyHelper) : null;
    _updateStream = _repository.updateStream.listen((_) => add(ExternalUpdateEvent()));
  }

  @override
  Stream<TodoDetailsState> mapEventToState(TodoDetailsEvent event) async* {
    if (event is LoadItemEvent) {
      yield* _mapLoadItemEventToState(event);
    } else if (event is UpdateTitleEvent) {
      yield* _mapUpdateTitleEventToState(event);
    } else if (event is ToggleCompletedEvent) {
      yield* _mapToggleCompletedEventToState(event);
    } else if (event is UpdatePriorityEvent) {
      yield* _mapUpdatePriorityEventToState(event);
    } else if (event is UpdateNoteEvent) {
      yield* _mapUpdateNoteEventToState(event);
    } else if (event is UpdateDueDateEvent) {
      yield* _mapUpdateDueDateEventToState(event);
    } else if (event is AddReminderEvent) {
      yield* _mapAddReminderEventToState(event);
    } else if (event is UpdateReminderEvent) {
      yield* _mapUpdateReminderEventToState(event);
    } else if (event is DeleteReminderEvent) {
      yield* _mapDeleteReminderEventToState(event);
    } else if (event is AddToListEvent) {
      yield* _mapAddToListEventToState(event);
    } else if (event is RemoveFromListEvent) {
      yield* _mapRemoveFromListEventToState(event);
    } else if (event is MoveToListEvent) {
      yield* _mapMoveToListEventToState(event);
    } else if (event is CopyToListEvent) {
      yield* _mapCopyToListEventToState(event);
    } else if (event is DeleteEvent) {
      yield* _mapDeleteEventToState(event);
    } else if (event is ExternalUpdateEvent) {
      yield* _externalUpdate(event);
    } else {
      throw "BUG: Unhandled TodoDetailsEvent!";
    }
  }

  Stream<TodoDetailsState> _mapLoadItemEventToState(LoadItemEvent event) async* {
    if (_item == null) {
      _item = await _repository.getTodoItem(_itemId);
      yield TodoDetailsLoadedItem(_item);
    }
    if (_lists == null) {
      _lists = await _repository.getListsOfItem(_item.id);
    }
    yield TodoDetailsFullyLoaded(_item, _lists);
  }

  Stream<TodoDetailsState> _mapUpdateTitleEventToState(UpdateTitleEvent event) async* {
    await _writeMutex.acquire();
    _item = _item.copyWith(todo: event.newTitle);
    yield TodoDetailsFullyLoaded(_item, _lists);
    _notifyList();
    await _repository.updateTodoItem(_item);
    _writeMutex.release();
  }

  Stream<TodoDetailsState> _mapUpdatePriorityEventToState(UpdatePriorityEvent event) async* {
    await _writeMutex.acquire();
    _item = _item.copyWith(priority: event.newPriority);
    yield TodoDetailsFullyLoaded(_item, _lists);
    _notifyList();
    await _repository.updateTodoItem(_item);
    _writeMutex.release();
  }

  Stream<TodoDetailsState> _mapToggleCompletedEventToState(ToggleCompletedEvent event) async* {
    await _writeMutex.acquire();
    _item = _item.toggleCompleted();
    yield TodoDetailsFullyLoaded(_item, _lists);
    if (_item.completed) {
      cancelRemindersForItem(_item);
    } else {
      setRemindersForItem(_item);
    }
    _notifyList();
    await _repository.updateTodoItem(_item);
    _writeMutex.release();
  }

  Stream<TodoDetailsState> _mapUpdateNoteEventToState(UpdateNoteEvent event) async* {
    await _writeMutex.acquire();
    _item = _item.copyWith(note: Nullable(event.newNote));
    yield TodoDetailsFullyLoaded(_item, _lists);
    _notifyList();
    await _repository.updateTodoItem(_item);
    _writeMutex.release();
  }

  Stream<TodoDetailsState> _mapUpdateDueDateEventToState(UpdateDueDateEvent event) async* {
    await _writeMutex.acquire();
    _item = _item.copyWith(dueDate: Nullable(event.newDueDate));
    yield TodoDetailsFullyLoaded(_item, _lists);
    _notifyList();
    await _repository.updateTodoItem(_item);
    _writeMutex.release();
  }

  Stream<TodoDetailsState> _mapAddReminderEventToState(AddReminderEvent event) async* {
    await _writeMutex.acquire();
    var id = await _repository.addReminder(_item.id, event.reminder.at);
    var newReminders = List.of(_item.reminders);
    newReminders.add(event.reminder.withId(id));
    _item = _item.copyWith(reminders: newReminders);
    yield TodoDetailsFullyLoaded(_item, _lists);
    _notifyList();
    setReminder(event.reminder.withId(id));
    _writeMutex.release();
  }

  Stream<TodoDetailsState> _mapUpdateReminderEventToState(UpdateReminderEvent event) async* {
    await _writeMutex.acquire();
    var newReminders = _item.reminders.map((r) {return r.id == event.reminder.id ? event.reminder : r;}).toList();
    _item = _item.copyWith(reminders: newReminders);
    yield TodoDetailsFullyLoaded(_item, _lists);
    _notifyList();
    await _repository.updateReminder(event.reminder.id, event.reminder.at);
    setReminder(event.reminder);
    _writeMutex.release();
  }

  Stream<TodoDetailsState> _mapDeleteReminderEventToState(DeleteReminderEvent event) async* {
    await _writeMutex.acquire();
    var newReminders = _item.reminders.where((element) => element.id != event.reminder.id).toList();
    _item = _item.copyWith(reminders: newReminders);
    yield TodoDetailsFullyLoaded(_item, _lists);
    _notifyList();
    await _repository.deleteReminder(event.reminder.id);
    cancelReminder(event.reminder);
    _writeMutex.release();
  }

  Stream<TodoDetailsState> _mapAddToListEventToState(AddToListEvent event) async* {
    await _writeMutex.acquire();
    _lists = [..._lists, event.list];
    yield TodoDetailsFullyLoaded(_item, _lists);
    _notifyList();
    await _repository.addTodoItemToList(_item.id, event.list.id);
    _writeMutex.release();
  }

  Stream<TodoDetailsState> _mapRemoveFromListEventToState(RemoveFromListEvent event) async* {
    await _writeMutex.acquire();
    _lists = _lists.where((element) => element.id != event.listId).toList();
    yield TodoDetailsFullyLoaded(_item, _lists);
    _notifyList();
    await _repository.removeTodoItemFromList(_item.id, event.listId);
    _writeMutex.release();
  }

  Stream<TodoDetailsState> _mapMoveToListEventToState(MoveToListEvent event) async* {
    await _writeMutex.acquire();
    _lists = [event.newList, ..._lists.where((element) => element.id != event.oldListId)];
    yield TodoDetailsFullyLoaded(_item, _lists);
    _notifyList();
    await _repository.moveTodoItemToList(_item.id, event.oldListId, event.newList.id);
    _writeMutex.release();
  }

  Stream<TodoDetailsState> _mapCopyToListEventToState(CopyToListEvent event) async* {
    yield TodoDetailsFullyLoaded(_item, _lists);
    _notifyList();
    _repository.addTodoItem(_item, event.listId);
  }

  Stream<TodoDetailsState> _mapDeleteEventToState(DeleteEvent event) async* {
    _notifyList();
    await _repository.deleteTodoItem(_item.id);
    cancelRemindersForItem(_item);
  }

  Stream<TodoDetailsState> _externalUpdate(ExternalUpdateEvent event) async* {
    _item = await _repository.getTodoItem(_itemId);
    yield TodoDetailsLoadedItem(_item);
    _lists = await _repository.getListsOfItem(_item.id);
    yield TodoDetailsFullyLoaded(_item, _lists);
  }

  Future<void> _notifyList() async {
    notifier?.call();
  }

  void _notifyHelper() {
    _listBloc.add(NotifyItemUpdateEvent(_item));
  }

  @override
  Future<void> close() {
    _updateStream.cancel();
    _notifyHelper();
    return super.close();
  }
}