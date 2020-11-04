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
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qunderlist/blocs/base.dart';
import 'package:qunderlist/blocs/todo_details.dart';
import 'package:qunderlist/blocs/todo_list.dart';
import 'package:qunderlist/blocs/todo_lists.dart';
import 'package:qunderlist/notification_ffi.dart';
import 'package:qunderlist/repository/repository.dart';
import 'package:qunderlist/repository/todos_repository_sqflite.dart';
import 'package:qunderlist/screens/todo_item_screen.dart';
import 'package:qunderlist/screens/todo_list_screen.dart';
import 'package:qunderlist/screens/todo_lists_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var repository = await TodoRepositorySqflite.getInstance();
  var base = BaseBloc(repository);
  var notificationHandler = NotificationFFI(repository, base);
  runApp(
      MultiRepositoryProvider(
          providers: [
            RepositoryProvider<TodoRepository>.value(value: repository),
            RepositoryProvider<NotificationFFI>.value(value: notificationHandler),
          ],
          child: BlocProvider.value(
            value: base,
            child: MyApp(),
          )
      )
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Qunderlist',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      routerDelegate: TodoRouterDelegate(
        RepositoryProvider.of<TodoRepository>(context),
        BlocProvider.of<BaseBloc>(context)
      ),
      routeInformationParser: TodoRouteInformationParser(),
    );
  }
}

class TodoRoutePath with EquatableMixin {
  final int listId;
  final int itemId;

  TodoRoutePath.home():
      listId = null,
      itemId = null;

  TodoRoutePath.list(int listId):
      this.listId = listId,
      itemId = null;

  TodoRoutePath.item(int listId, int itemId):
      this.listId = listId,
      this.itemId = itemId;

  bool get isHome => listId == null && itemId == null;
  bool get isList => listId != null && itemId == null;
  bool get isItem => listId != null && itemId != null;

  @override
  List<Object> get props => [listId, itemId];
}

class TodoRouterDelegate extends RouterDelegate<TodoRoutePath> with ChangeNotifier, PopNavigatorRouterDelegateMixin<TodoRoutePath>{
  final GlobalKey<NavigatorState> navigatorKey;
  final TodoRepository repository;

  final BaseBloc _bloc;
  BaseState _state;

  TodoRouterDelegate(this.repository, BaseBloc bloc):
        _bloc = bloc,
        navigatorKey = GlobalKey<NavigatorState>()
  {
    _state = bloc.state;
    bloc.listen((state) async {
      _state = state;
      notifyListeners();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      pages: [
        MaterialPage(
          child: BlocProvider<TodoListsBloc>.value(
              value: _state.listsBloc,
              child: TodoListsScreen()
          )
        ),
        if (_state.listId != null)
          MaterialPage(
            child: BlocProvider<TodoListBloc>.value(
              value: _state.listBloc,
              child: TodoListScreen(TodoStatusFilter.active)
            )
          ),
        if (_state.itemId != null)
          MaterialPage(
              child: BlocProvider<TodoDetailsBloc>.value(
                value: _state.itemBloc,
                child: TodoItemDetailScreen()
              )
          )
      ],
      onPopPage: (route, result) {
        if (!route.didPop(result)) {
          return false;
        }
        _bloc.add(BasePopEvent());
        return true;
      },
    );
  }

  @override
  Future<void> setNewRoutePath(TodoRoutePath configuration) async {
    if (configuration.isHome) {
      _bloc.add(BaseShowHomeEvent());
    } else if (configuration.isList) {
      _bloc.add(BaseShowListEvent(configuration.listId));
    } else {
      _bloc.add(BaseShowItemEvent(configuration.itemId, listId: configuration.listId));
    }
  }
}

class TodoRouteInformationParser extends RouteInformationParser<TodoRoutePath> {
  @override
  Future<TodoRoutePath> parseRouteInformation(RouteInformation routeInformation) async {
    final uri = Uri.parse(routeInformation.location);
    if (uri.pathSegments.length == 0) {
      return TodoRoutePath.home();
    }
    if (uri.pathSegments[0] == "list") {
      return TodoRoutePath.list(int.parse(uri.pathSegments[1]));
    } else if (uri.pathSegments[1] == "item") {
      return TodoRoutePath.item(int.parse(uri.pathSegments[1]), int.parse(uri.pathSegments[2]));
    }
    throw "BUG: Malformed path";
  }

  @override
  RouteInformation restoreRouteInformation(TodoRoutePath configuration) {
    if (configuration.isHome) {
      return RouteInformation(location: "/");
    } else if (configuration.isList) {
      return RouteInformation(location: "/list/${configuration.listId}");
    } else if (configuration.isItem) {
      return RouteInformation(location: "/item/${configuration.listId}/${configuration.itemId}");
    }
    throw "BUG: Unhandled route";
  }
}