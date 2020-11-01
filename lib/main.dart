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

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qunderlist/blocs/todo_lists.dart';
import 'package:qunderlist/notification_ffi.dart';
import 'package:qunderlist/repository/repository.dart';
import 'package:qunderlist/repository/todos_repository_sqflite.dart';
import 'package:qunderlist/screens/todo_lists_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var repository = await TodoRepositorySqflite.getInstance();
  var notificationHandler = NotificationFFI();
  runApp(
      MultiRepositoryProvider(
          providers: [
            RepositoryProvider<TodoRepository>.value(value: repository),
            RepositoryProvider<NotificationFFI>.value(value: notificationHandler),
          ],
          child: BlocProvider(
            create: (ctx) => TodoListsBloc(repository),
            child: MyApp(),
          )
      )
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Qunderlist',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: AppInit(),
    );
  }
}

class AppInit extends StatefulWidget {
  @override
  _AppInitState createState() => _AppInitState();
}

class _AppInitState extends State<AppInit> {
  @override
  void initState() {
    super.initState();
    RepositoryProvider.of<NotificationFFI>(context).init(context);
    BlocProvider.of<TodoListsBloc>(context).add(LoadTodoListsEvent());
  }

  @override
  Widget build(BuildContext context) {
    return TodoListsScreen();
  }
}
