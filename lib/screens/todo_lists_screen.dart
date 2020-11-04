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

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qunderlist/blocs/base.dart';
import 'package:qunderlist/blocs/todo_lists.dart';
import 'package:qunderlist/repository/repository.dart';
import 'package:qunderlist/screens/cached_list.dart';
import 'package:qunderlist/theme.dart';

class TodoListsScreen extends StatelessWidget {
  TodoListsScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Qunderlist"),),
      body: BlocBuilder<TodoListsBloc,TodoListsStates>(
          builder: (context, state) {
            if (state is TodoListsLoading) {
              return LinearProgressIndicator();
            } else if (state is TodoListsLoadingFailed) {
              return Center(child: Text("Failed to load lists"));
            } else if (state is TodoListsLoaded) {
              return TodoListsListView(state);
            } else {
              throw "BUG: Unexpected state in TodoListsScreen: $state";
            }
          }
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add),
        onPressed: () async {
          await showModalBottomSheet<bool>(
              context: context,
              builder: (_) => TodoListAdder(BlocProvider.of<TodoListsBloc>(context)),
            isScrollControlled:  true
          );
        },
      ),
    );
  }
}

class TodoListsListView extends StatefulWidget {
  final TodoListsLoaded state;
  TodoListsListView(this.state);

  @override
  _TodoListsListViewState createState() => _TodoListsListViewState();
}

class _TodoListsListViewState extends State<TodoListsListView> {
  TodoListsBloc _bloc;

  @override
  void initState() {
    super.initState();
    _bloc = BlocProvider.of(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: CachedList<TodoList>(
          cache: widget.state.lists,
          itemBuilder: (context, index, item) => DismissibleItem(
            key: Key(item.id.toString()),
            child: TodoListCard(item, widget.state.numberOfItems.getElement(item.id), widget.state.numberOfOverdueItems.getElement(item.id)),
            deleteMessage: "Delete todo list",
            deletedMessage: "Todo list deleted",
            onDismissed: () => _bloc.add(TodoListDeletedEvent(item, index)),
            confirmMessage: "Delete list '${item.listName}'?",
          ),
          reorderCallback: (from, to) async => _bloc.add(TodoListsReorderedEvent(await widget.state.lists.peekItem(from), from, await widget.state.lists.peekItem(to), to)),
          itemHeight: 50
      ),
      padding: EdgeInsets.symmetric(horizontal: 8),
    );
  }
}

class TodoListCard extends StatelessWidget {
  final TodoList list;
  final Future<int> numberOfActiveItems;
  final Future<int> numberOfOverdueItems;
  final Color color;
  TodoListCard(this.list, this.numberOfActiveItems, this.numberOfOverdueItems):
        color = themeFromPalette(list.color).primaryColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      child: Container(
        height: 55,
        child: Stack(children: [
          ListTile(
              leading: Icon(Icons.list, size: 28),
              title: Text(list.listName, style: TextStyle(fontSize: 17)),
              trailing: Row(children: [
                NumberOfOverdueItems(numberOfOverdueItems),
                NumberOfItems(numberOfActiveItems, themeFromPalette(list.color))
              ], mainAxisSize: MainAxisSize.min),
          ),
          Container(color: color, height: 1, margin: EdgeInsets.only(top: 41, left: 16, right: 16)),
        ]),
      ),
      onTap: () {
        BlocProvider.of<BaseBloc>(context).add(BaseShowListEvent(list.id, list: list));
      },
    );
  }
}

class NumberOfOverdueItems extends StatelessWidget {
  final Future<int> _number;
  NumberOfOverdueItems(Future<int> number): _number = number;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: _number,
        initialData: 0,
        builder: (context, AsyncSnapshot<int> snapshot) {
          var number = snapshot.data ?? 0;
          if (number == 0) {
            return Container(width: 0, height: 0,);
          } else {
            return Container(
              child: Container(child: Text(number.toString(), style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.bold)), margin: EdgeInsets.symmetric(vertical: 2, horizontal: 6)),
              decoration: ShapeDecoration(color: Colors.red.shade200, shape: StadiumBorder()),
              margin: EdgeInsets.only(right: 5),
            );
          }
        }
    );
  }
}


class NumberOfItems extends StatelessWidget {
  final Future<String> _number;
  final ThemeData theme;

  NumberOfItems(Future<int> number, this.theme): _number = number.then((value) => value.toString());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: _number,
        initialData: "",
        builder: (context, AsyncSnapshot<String> snapshot) {
          var number = snapshot.data ?? "";
          return Container(
            child: Container(child: Text(number, style: TextStyle(color: Colors.white)), margin: EdgeInsets.symmetric(vertical: 2, horizontal: 6)),
            decoration: ShapeDecoration(color: theme.primaryColor, shape: StadiumBorder()),
          );
        }
    );
  }
}


class TodoListAdder extends StatefulWidget {
  final TodoListsBloc bloc;

  TodoListAdder(this.bloc);

  @override
  State<StatefulWidget> createState() {
    return _TodoListAdderState();
  }
}
class _TodoListAdderState extends State<TodoListAdder> {
  var titleController = TextEditingController();
  Palette palette;
  @override
  void initState() {
    super.initState();
    titleController.addListener(() { setState(() {});});
    palette = Palette.blue;
  }

  @override
  Widget build(BuildContext context) {
    var title = titleController.text.trim();
    print(title);
    var action = () {widget.bloc.add(TodoListAddedEvent(TodoList(title, palette))); Navigator.pop(context, true);};
    return Container(
      child: Column(
        children: <Widget>[
          ListTile(
              title: TextField(controller: titleController, autofocus: true, textCapitalization: TextCapitalization.sentences, decoration: InputDecoration(labelText: "List title"),)
          ),
          ThemePicker(_setPalette, defaultPalette: Palette.blue,),
          Row(
            children: <Widget>[
              RaisedButton(child: Text("Create List"), onPressed: title.isEmpty ? null : action),
            ],
            mainAxisAlignment: MainAxisAlignment.end,
          ),
        ],
        mainAxisSize: MainAxisSize.min,
      ),
      padding: EdgeInsets.fromLTRB(10, 3, 10, MediaQuery.of(context).viewInsets.bottom+9),
    );
  }

  void _setPalette(Palette palette) {
    setState(() {
      this.palette = palette;
    });
  }
}