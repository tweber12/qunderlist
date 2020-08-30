import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qunderlist/blocs/todo_lists.dart';
import 'package:qunderlist/repository/repository.dart';
import 'package:qunderlist/screens/cached_list.dart';
import 'package:qunderlist/screens/todo_list_screen.dart';
import 'package:qunderlist/theme.dart';

class TodoListsScreen extends StatelessWidget {
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
    _bloc = BlocProvider.of(context);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: CachedList<TodoList>(
          cache: widget.state.lists,
          itemBuilder: (context, index, item) => DismissibleItem(
            key: Key(item.id.toString()),
            child: TodoListCard(item),
            deleteMessage: "Delete todo list",
            deletedMessage: "Todo list deleted",
            onDismissed: () => _bloc.add(TodoListDeletedEvent(item, index)),
            confirmMessage: "Delete list '${item.listName}'?",
          ),
          reorderCallback: (from, to) => _bloc.add(TodoListsReorderedEvent(from, to)),
          itemHeight: 50
      ),
      color: Colors.blue.shade200,
      padding: EdgeInsets.symmetric(horizontal: 8),
    );
  }
}

class TodoListCard extends StatelessWidget {
  final TodoList list;
  TodoListCard(this.list);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        child: Container(
          height: 50,
          child: Row(children: [Text(list.listName, style: TextStyle(fontSize: 15))], crossAxisAlignment: CrossAxisAlignment.center,),
          padding: EdgeInsets.symmetric(horizontal: 16),
        ),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (ctx) => showTodoListScreen(ctx, RepositoryProvider.of<TodoRepository>(context), list))),
      ),
      margin: EdgeInsets.symmetric(vertical: 0.5),
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
              title: TextField(controller: titleController, autofocus: true, decoration: InputDecoration(labelText: "List title"),)
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