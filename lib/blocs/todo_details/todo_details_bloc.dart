import 'package:bloc/bloc.dart';
import 'package:qunderlist/blocs/todo_details/todo_details_events.dart';
import 'package:qunderlist/blocs/todo_details/todo_details_states.dart';
import 'package:qunderlist/repository/repository.dart';

class TodoDetailsBloc<R extends TodoRepository> extends Bloc<TodoDetailsEvent,TodoDetailsState> {
  TodoItem _item;
  List<TodoList> _lists;
  R _repository;

  TodoDetailsBloc(R repository, TodoItem item): _repository=repository, _item=item, super(TodoDetailsLoadedItem(item));

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
    } else if (event is UpdateRemindersEvent) {
      yield* _mapUpdateRemindersEventToState(event);
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
    if (_lists == null) {
      _lists = await _repository.getListsOfItem(_item.id);
    }
    yield TodoDetailsFullyLoaded(_item, _lists);
  }

  Stream<TodoDetailsState> _mapUpdateTitleEventToState(UpdateTitleEvent event) async* {
    print("\nUPDATE TITLE: ${event.newTitle}\n");
    _item = _item.copyWith(todo: event.newTitle);
    yield TodoDetailsFullyLoaded(_item, _lists);
    _repository.updateTodoItem(_item);
  }

  Stream<TodoDetailsState> _mapUpdatePriorityEventToState(UpdatePriorityEvent event) async* {
    _item = _item.copyWith(priority: event.newPriority);
    yield TodoDetailsFullyLoaded(_item, _lists);
    _repository.updateTodoItem(_item);
  }

  Stream<TodoDetailsState> _mapToggleCompletedEventToState(ToggleCompletedEvent event) async* {
    if (_item.completed) {
      _item = _item.copyWith(completed: false, completedOn: null);
    } else {
      _item = _item.copyWith(completed: true, completedOn: DateTime.now());
    }
    yield TodoDetailsFullyLoaded(_item, _lists);
    _repository.completeTodoItem(_item);
  }

  Stream<TodoDetailsState> _mapUpdateNoteEventToState(UpdateNoteEvent event) async* {
    _item = _item.copyWith(note: event.newNote);
    yield TodoDetailsFullyLoaded(_item, _lists);
    _repository.updateTodoItem(_item);
  }

  Stream<TodoDetailsState> _mapUpdateDueDateEventToState(UpdateDueDateEvent event) async* {
    _item = _item.copyWith(dueDate: event.newDueDate, deleteDueDate: true);
    yield TodoDetailsFullyLoaded(_item, _lists);
    _repository.updateTodoItem(_item);
  }

  Stream<TodoDetailsState> _mapUpdateRemindersEventToState(UpdateRemindersEvent event) async* {
    _item = _item.copyWith(reminders: event.newReminders);
    yield TodoDetailsFullyLoaded(_item, _lists);
    _repository.updateTodoItem(_item);
  }

  Stream<TodoDetailsState> _mapAddToListEventToState(AddToListEvent event) async* {
    _lists = [..._lists, event.list];
    yield TodoDetailsFullyLoaded(_item, _lists);
    print("EVENT RECIEVED");
    _repository.addTodoItemToList(_item, event.list.id);
  }

  Stream<TodoDetailsState> _mapRemoveFromListEventToState(RemoveFromListEvent event) async* {
    _lists = _lists.where((element) => element.id != event.listId).toList();
    yield TodoDetailsFullyLoaded(_item, _lists);
    _repository.removeTodoItemFromList(_item, event.listId);
  }

  Stream<TodoDetailsState> _mapMoveToListEventToState(MoveToListEvent event) async* {
    _lists = [event.newList, ..._lists.where((element) => element.id != event.oldListId)];
    yield TodoDetailsFullyLoaded(_item, _lists);
    _repository.moveTodoItemToList(_item, event.oldListId, event.newList.id);
  }

  Stream<TodoDetailsState> _mapCopyToListEventToState(CopyToListEvent event) async* {
    yield TodoDetailsFullyLoaded(_item, _lists);
    _repository.addTodoItem(_item, event.listId);
  }

  Stream<TodoDetailsState> _mapDeleteEventToState(DeleteEvent event) async* {
    await _repository.deleteTodoItem(_item);
  }
}