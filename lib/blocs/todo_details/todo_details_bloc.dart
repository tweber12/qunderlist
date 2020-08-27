import 'package:bloc/bloc.dart';
import 'package:qunderlist/blocs/todo_details/todo_details_events.dart';
import 'package:qunderlist/blocs/todo_details/todo_details_states.dart';
import 'package:qunderlist/blocs/todo_list.dart';
import 'package:qunderlist/notification_handler.dart';
import 'package:qunderlist/pigeon.dart';
import 'package:qunderlist/repository/repository.dart';

class TodoDetailsBloc<R extends TodoRepository> extends Bloc<TodoDetailsEvent,TodoDetailsState> {
  int _itemId;
  TodoItem _item;
  List<TodoList> _lists;
  int _index;
  final TodoListBloc _listBloc;
  final R _repository;
  final Api api;

  TodoDetailsBloc(R repository, int itemId, {TodoItem item, int index, TodoListBloc listBloc}):
        _repository=repository,
        _index = index,
        _listBloc=listBloc,
        _item=item,
        _itemId = itemId,
        api = Api(),
        super(item==null ? TodoDetailsLoading() : TodoDetailsLoadedItem(item));

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
    print("\nUPDATE TITLE: ${event.newTitle}\n");
    _item = _item.copyWith(todo: event.newTitle);
    yield TodoDetailsFullyLoaded(_item, _lists);
    _notifyList();
    _repository.updateTodoItem(_item);
    updateAllRemindersForNotification(_item);
  }

  Stream<TodoDetailsState> _mapUpdatePriorityEventToState(UpdatePriorityEvent event) async* {
    _item = _item.copyWith(priority: event.newPriority);
    yield TodoDetailsFullyLoaded(_item, _lists);
    _notifyList();
    _repository.updateTodoItem(_item);
  }

  Stream<TodoDetailsState> _mapToggleCompletedEventToState(ToggleCompletedEvent event) async* {
    _item = _item.toggleCompleted();
    yield TodoDetailsFullyLoaded(_item, _lists);
    if (_item.completed) {
      cancelAllNotificationsForItem(_item);
    } else {
      setAllNotificationsForItem(_item);
    }
    _notifyList();
    _repository.updateTodoItem(_item);
  }

  Stream<TodoDetailsState> _mapUpdateNoteEventToState(UpdateNoteEvent event) async* {
    _item = _item.copyWith(note: event.newNote);
    yield TodoDetailsFullyLoaded(_item, _lists);
    _notifyList();
    _repository.updateTodoItem(_item);
    updateAllRemindersForNotification(_item);
  }

  Stream<TodoDetailsState> _mapUpdateDueDateEventToState(UpdateDueDateEvent event) async* {
    _item = _item.copyWith(dueDate: event.newDueDate, deleteDueDate: true);
    yield TodoDetailsFullyLoaded(_item, _lists);
    _notifyList();
    _repository.updateTodoItem(_item);
  }

  Stream<TodoDetailsState> _mapAddReminderEventToState(AddReminderEvent event) async* {
    var id = await _repository.addReminder(_item.id, event.reminder.at);
    var newReminders = List.of(_item.reminders);
    newReminders.add(event.reminder.withId(id));
    _item = _item.copyWith(reminders: newReminders);
    yield TodoDetailsFullyLoaded(_item, _lists);
    _notifyList();
    setNotificationForItem(_item, event.reminder.withId(id));
  }

  Stream<TodoDetailsState> _mapUpdateReminderEventToState(UpdateReminderEvent event) async* {
    var newReminders = _item.reminders.map((r) {return r.id == event.reminder.id ? event.reminder : r;}).toList();
    _item = _item.copyWith(reminders: newReminders);
    yield TodoDetailsFullyLoaded(_item, _lists);
    _notifyList();
    _repository.updateReminder(event.reminder.id, event.reminder.at);
    updateNotificationForItem(_item, event.reminder);
  }

  Stream<TodoDetailsState> _mapDeleteReminderEventToState(DeleteReminderEvent event) async* {
    var newReminders = _item.reminders.where((element) => element.id != event.reminder.id).toList();
    _item = _item.copyWith(reminders: newReminders);
    yield TodoDetailsFullyLoaded(_item, _lists);
    _notifyList();
    _repository.deleteReminder(event.reminder.id);
    cancelNotificationForItem(event.reminder.id);
  }

  Stream<TodoDetailsState> _mapAddToListEventToState(AddToListEvent event) async* {
    _lists = [..._lists, event.list];
    yield TodoDetailsFullyLoaded(_item, _lists);
    _notifyList();
    _repository.addTodoItemToList(_item.id, event.list.id);
  }

  Stream<TodoDetailsState> _mapRemoveFromListEventToState(RemoveFromListEvent event) async* {
    _lists = _lists.where((element) => element.id != event.listId).toList();
    yield TodoDetailsFullyLoaded(_item, _lists);
    _notifyList();
    _repository.removeTodoItemFromList(_item.id, event.listId);
  }

  Stream<TodoDetailsState> _mapMoveToListEventToState(MoveToListEvent event) async* {
    _lists = [event.newList, ..._lists.where((element) => element.id != event.oldListId)];
    yield TodoDetailsFullyLoaded(_item, _lists);
    _notifyList();
    _repository.moveTodoItemToList(_item.id, event.oldListId, event.newList.id);
  }

  Stream<TodoDetailsState> _mapCopyToListEventToState(CopyToListEvent event) async* {
    yield TodoDetailsFullyLoaded(_item, _lists);
    _notifyList();
    _repository.addTodoItem(_item, event.listId);
  }

  Stream<TodoDetailsState> _mapDeleteEventToState(DeleteEvent event) async* {
    _notifyList();
    await _repository.deleteTodoItem(_item.id);
    cancelAllNotificationsForItem(_item);
  }

  Future<void> _notifyList() async {
    if (_listBloc == null) {
      return;
    }
    _listBloc.add(NotifyItemUpdateEvent(_index, _item, _lists));
  }

  @override
  Future<void> close() {
    print("Close called");
    _notifyList();
    return super.close();
  }
}