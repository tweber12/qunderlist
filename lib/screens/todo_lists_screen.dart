import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_reorderable_list/flutter_reorderable_list.dart';
import 'package:qunderlist/blocs/todo_lists.dart';
import 'package:qunderlist/repository/repository.dart';
import 'package:qunderlist/screens/todo_list_screen.dart';

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
  TodoListsBloc bloc;
  ScrollController scrollController;
  Chunk<TodoList> currentChunk;
  bool loading;
  bool swap;
  int swapFrom;
  int swapTo;

  @override
  void initState() {
    super.initState();
    scrollController = ScrollController();
    scrollController.addListener(scroller);
    bloc = BlocProvider.of<TodoListsBloc>(context);
    bloc.add(GetChunkEvent(0,50));
    swap = false;
    loading = false;
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
        currentChunk = state.chunkOfLists;
        return ReorderableList(
          onReorder: (Key movingItem, Key movedTo) {
            setState(() {
              swapFrom = currentChunk.data.indexWhere((element) => Key("Reorderable TodoList Item: ${element.id}") == movingItem) + currentChunk.start;
              var swapToNew = currentChunk.data.indexWhere((element) => Key("Reorderable TodoList Item: ${element.id}") == movedTo) + currentChunk.start;
              if (swapToNew == swapTo) {
                // The item is dragged back in the direction of it's original position
                swapTo = swapTo > swapFrom ? swapTo - 1 : swapTo + 1;
              } else {
                swapTo = swapToNew;
              }
              swap = true;
            });
            return true;
            },
          onReorderDone: (_) {
              bloc.add(ReorderTodoListsEvent(swapTo-25, swapTo+25, currentChunk.get(swapFrom), swapTo));
              swap = false;
            },
          child: ListView.builder(
            itemBuilder: (BuildContext context, int index) {
              if (swap) {
//                print("$swapFrom, $swapTo: $index");
                if (index == swapTo) {
                  index = swapFrom;
                } else if (swapFrom > swapTo && swapFrom >= index && swapTo < index) {
                  index = index -= 1;
                } else if (swapFrom < swapTo && swapFrom <= index && swapTo > index) {
                  index = index += 1;
                }
//                print(" => $index");
              }
//              print("Index: $index");
              if (index >= currentChunk.end || index < currentChunk.start) {
                if (!loading) {
                  print("Loading, $index, ${currentChunk.totalLength}, ${currentChunk.start}, ${currentChunk.end}");
                  BlocProvider.of<TodoListsBloc>(context).add(GetChunkEvent(index-15, index+15));
                  loading = true;
                }
                return Center(child: CircularProgressIndicator());
              } else {
                return TodoListsListItem(index, currentChunk.get(index));
              }
            },
            itemCount: state.chunkOfLists.totalLength,
            itemExtent: widget.itemExtent,
            controller: scrollController,
          ),
        );
      }
      throw "BUG: Failed to handle todolists state!";
    });
  }

  void scroller() {
    var position = scrollController.position;
    var firstVisibleItem = (position.pixels / widget.itemExtent).floor();
    var lastVisibleItem = currentChunk.totalLength - 1 - ((position.maxScrollExtent-position.pixels) / widget.itemExtent).floor();
    var bufferedAbove = firstVisibleItem-currentChunk.start;
    var bufferedBelow = currentChunk.end-1-lastVisibleItem;
    if (!loading && bufferedAbove < 10 && currentChunk.start != 0) {
      bloc.add(GetChunkEvent(firstVisibleItem-15, lastVisibleItem+15));
      loading = true;
    }
    if (!loading && bufferedBelow < 10 && currentChunk.end != currentChunk.totalLength) {
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
    return ReorderableItem(
      key: Key("Reorderable TodoList Item: ${list.id}"),
      childBuilder: (context, reorderState) {
        if (reorderState == ReorderableItemState.placeholder) {
          return Container();
        }
        return DelayedReorderableListener(
          child: Dismissible(
            key: Key(list.id.toString()),
            child: ListTile(title: Text(list.listName), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => showTodoListScreen(context, list))),),
            onDismissed: (_) {
              BlocProvider.of<TodoListsBloc>(context).add(TodoListDeletedEvent(index-25, index+25, list));
              Scaffold.of(context).showSnackBar(SnackBar(content: Text("Deleted list '${list.listName}'")));
            },
            background: Container( color: Colors.red, child: ListTile(leading: Icon(Icons.delete, color: Colors.white),title: Text("Delete list", style: TextStyle(color: Colors.white),)),),
            confirmDismiss: (_) => showDialog(context: context, builder: (context) => ConfirmDeleteDialog(title: "Delete list '${list.listName}'?", subtitle: "This action cannot be undone!")),
          )
        );
      },
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