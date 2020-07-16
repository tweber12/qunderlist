import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_reorderable_list/flutter_reorderable_list.dart';
import 'package:qunderlist/blocs/todo_lists.dart';
import 'package:qunderlist/repository/repository.dart';

class TodoListsScreen extends StatelessWidget {
  final list = TodoListsListView();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Qunderlist"),),
      body: list,
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add),
        onPressed: () async {
          var added = await showModalBottomSheet<bool>(context: context, builder: (_) => TodoListAdder(BlocProvider.of<TodoListsBloc>(context)));
          if (added) {
            list.scrollToBottom();
          }
          },
      ),
    );
  }
}

class TodoListsListView extends StatefulWidget {
  final scrollController = ScrollController();
  final double itemExtent = 60;

  @override
  State<StatefulWidget> createState() {
    return _TodoListsListViewState();
  }

  void scrollToBottom() {
    print("Scrolling");
    scrollController.jumpTo(scrollController.position.maxScrollExtent);
  }
}
class _TodoListsListViewState extends State<TodoListsListView> {
  int currentLength;
  TodoListsBloc bloc;
  ScrollController scrollController;
  int chunkFrom;
  int chunkTo;
  bool loading;

  @override
  void initState() {
    super.initState();
    scrollController = ScrollController();
    scrollController.addListener(scroller);
    bloc = BlocProvider.of<TodoListsBloc>(context);
    bloc.add(GetChunkEvent(0,50));
    currentLength = 0;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TodoListsBloc,TodoListsStates>(builder: (context, state) {
      if (state is TodoListsLoading) {
        loading = true;
        return LinearProgressIndicator();
      }
      if (state is ChunkLoadFailed) {
        return Center(child: Text("Failed to load lists"));
      }
      if (state is ChunkLoaded) {
        loading = false;
        Chunk<TodoList> chunk = state.chunkOfLists;
        currentLength = chunk.totalLength;
        chunkTo = chunk.end;
        chunkFrom = chunk.start;
        return ListView.builder(
          itemBuilder: (BuildContext context, int index) {
            print("Index: $index");
            if (index >= chunk.end || index < chunk.start) {
              if (!loading) {
                print("Loading, $index, $currentLength, ${chunk.start}, ${chunk.end}");
                BlocProvider.of<TodoListsBloc>(context).add(GetChunkEvent(index-15, index+15));
                loading = true;
              }
              return Center(child: CircularProgressIndicator());
            } else {
              return TodoListsListItem(index, chunk.get(index));
            }
          },
          itemCount: state.chunkOfLists.totalLength,
          itemExtent: widget.itemExtent,
          controller: scrollController,
        );
      }
      throw "BUG: Failed to handle todolists state!";
    });
  }

  void scroller() {
    var position = scrollController.position;
    var firstVisibleItem = (position.pixels / widget.itemExtent).floor();
    var lastVisibleItem = currentLength - 1 - ((position.maxScrollExtent-position.pixels) / widget.itemExtent).floor();
    var bufferedAbove = firstVisibleItem-chunkFrom;
    var bufferedBelow = chunkTo-1-lastVisibleItem;
    if (!loading && bufferedAbove < 10 && chunkFrom != 0) {
      bloc.add(GetChunkEvent(firstVisibleItem-15, lastVisibleItem+15));
      loading = true;
    }
    if (!loading && bufferedBelow < 10 && chunkTo != currentLength) {
      bloc.add(GetChunkEvent(firstVisibleItem-15, lastVisibleItem+15));
      loading = true;
    }
//    print("Scroll callback: $loading, ${firstVisibleItem+1}, ${lastVisibleItem+1}, ${bufferedAbove}, ${bufferedBelow}");
  }
}

class TodoListsListItem extends StatelessWidget {
  final int index;
  final TodoList list;
  TodoListsListItem(this.index, this.list);
  
  @override
  Widget build(BuildContext context) {
    return Dismissible(
        key: Key(list.id.toString()),
        child: ListTile(title: Text(list.listName)),
        onDismissed: (_) {
          BlocProvider.of<TodoListsBloc>(context).add(TodoListDeletedEvent(index-25, index+25, list));
          Scaffold.of(context).showSnackBar(SnackBar(content: Text("Deleted list '${list.listName}'")));
          },
        background: Container( color: Colors.red, child: ListTile(leading: Icon(Icons.delete, color: Colors.white),title: Text("Delete list", style: TextStyle(color: Colors.white),)),),
        confirmDismiss: (_) => showDialog(context: context, builder: (context) => ConfirmDeleteDialog(title: "Delete list '${list.listName}'?", subtitle: "This action cannot be undone!")),
    );
  }
}

class ConfirmDeleteDialog extends StatelessWidget {
  final String title;
  final String subtitle;

  ConfirmDeleteDialog({@required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    var subtitleWidget;
    if (subtitle != null) {
      subtitleWidget = Text(subtitle);
    }
    return AlertDialog(
      title: Text(title),
      content: subtitleWidget,
      actions: <Widget>[
        FlatButton(child: Text("Cancel"), onPressed: () => Navigator.pop(context, false),),
        RaisedButton( child: Text("Delete"), onPressed: () => Navigator.pop(context, true),),
      ],
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
  @override
  void initState() {
    super.initState();
    titleController.addListener(() { setState(() {});});
  }

  @override
  Widget build(BuildContext context) {
    var title = titleController.text.trim();
    print(title);
    // TODO Figure out what to do with the chunk size
    var action = () {widget.bloc.add(TodoListAddedEvent(0, 10, TodoList(title), fromBottom: true)); Navigator.pop(context, true);};
    return Column(
      children: <Widget>[
        ListTile(title: TextField(controller: titleController, autofocus: true, decoration: InputDecoration(labelText: "List title"),)),
        Row(
          children: <Widget>[
            RaisedButton(child: Text("Create List"), onPressed: title.isEmpty ? null : action),
          ],
          mainAxisAlignment: MainAxisAlignment.end,
        ),
      ],
    );
  }
}