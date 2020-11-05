import 'package:bloc/bloc.dart';
import 'package:qunderlist/blocs/base/base_events.dart';
import 'package:qunderlist/blocs/base/base_state.dart';
import 'package:qunderlist/blocs/todo_details.dart';
import 'package:qunderlist/blocs/todo_list.dart';
import 'package:qunderlist/blocs/todo_lists.dart';
import 'package:qunderlist/notification_handler.dart';
import 'package:qunderlist/repository/repository.dart';

class BaseBloc extends Bloc<BaseEvent, BaseState> {
  BaseBloc(TodoRepository repository, NotificationHandler notificationHandler): this._internal(repository, notificationHandler, null, null, TodoListsBloc(repository, notificationHandler), null, null);

  BaseBloc._internal(this.repository, this.notificationHandler, this._listId, this._itemId, this._listsBloc, this._listBloc, this._itemBloc):
        super(BaseState(_listId, _itemId, _listsBloc, _listBloc, _itemBloc))
  {
    _listsBloc.add(LoadTodoListsEvent());
  }

  final TodoRepository repository;
  final NotificationHandler notificationHandler;
  int _listId;
  int _itemId;
  TodoListsBloc _listsBloc;
  TodoListBloc _listBloc;
  TodoDetailsBloc _itemBloc;

  @override
  Stream<BaseState> mapEventToState(BaseEvent event) async* {
    if (event is BaseShowHomeEvent) {
      yield* _navigateToHome();
    } else if (event is BaseShowListEvent) {
      yield* _navigateToList(event.listId, event.list);
    } else if (event is BaseShowItemEvent) {
      yield* _navigateToItem(event.listId ?? _listId, event.itemId, event.list, event.item);
    } else if (event is BasePopEvent) {
      yield* _mapPopEventToState();
    }
  }

  Stream<BaseState> _navigateToHome() async* {
    if (_listId == null && _itemId == null) {
      yield state;
      return;
    } else if (_itemId == null) {
      _listBloc.close();
      _listBloc = null;
    } else {
      _itemBloc.close();
      _listBloc.close();
      _itemBloc = null;
      _listBloc = null;
    }
    _listId = null;
    _itemId = null;
    yield BaseState(_listId, _itemId, _listsBloc, _listBloc, _itemBloc);
  }

  Stream<BaseState> _mapPopEventToState() async* {
    if (_listId == null && _itemId == null) {
      yield state;
      return;
    } else if (_itemId == null) {
      _listBloc.close();
      _listBloc = null;
      _listId = null;
    } else {
      _itemBloc.close();
      _itemBloc = null;
      _itemId = null;
    }
    yield BaseState(_listId, _itemId, _listsBloc, _listBloc, _itemBloc);
  }

  Stream<BaseState> _navigateToList(int listId, TodoList list) async* {
    _navigateToListInternal(listId, list);
    yield BaseState(_listId, _itemId, _listsBloc, _listBloc, _itemBloc);
  }

  void _navigateToListInternal(int listId, TodoList list) {
    if (_listId == null && _itemId == null) {
      _listBloc = TodoListBloc(repository, notificationHandler, listId, list: list, listsBloc: _listsBloc);
      _listBloc.add(GetDataEvent());
      _listId = listId;
    } else if (_itemId == null) {
      _replaceList(listId, list);
    } else {
      _itemBloc.close();
      _itemBloc = null;
      _itemId = null;
      _replaceList(listId, list);
    }
  }

  void _replaceList(int listId, TodoList list) {
    if (_listId == listId) {
      return;
    } else {
      _listBloc.close();
      _listBloc = TodoListBloc(repository, notificationHandler, listId, list: list, listsBloc: _listsBloc);
      _listBloc.add(GetDataEvent());
      _listId = listId;
    }
  }

  Stream<BaseState> _navigateToItem(int listId, int itemId, TodoList list, TodoItemBase item) async* {
    if (listId == _listId && itemId == _itemId) {
      return;
    }
    _navigateToListInternal(listId, list);
    _itemBloc = TodoDetailsBloc(repository, notificationHandler, itemId, listBloc: _listBloc, item: item);
    _itemBloc.add(LoadItemEvent());
    _itemId = itemId;
    yield BaseState(_listId, _itemId, _listsBloc, _listBloc, _itemBloc);
  }

  @override
  Future<void> close() {
    _listsBloc.close();
    return super.close();
  }
}