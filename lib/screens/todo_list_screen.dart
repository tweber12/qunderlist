import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qunderlist/blocs/cache.dart';
import 'package:qunderlist/blocs/todo_list.dart';
import 'package:qunderlist/repository/models.dart';
import 'package:qunderlist/repository/repository.dart';
import 'package:qunderlist/repository/todos_repository_sqflite.dart';
import 'package:qunderlist/screens/cached_list.dart';
import 'package:qunderlist/screens/todo_item_screen.dart';

Widget showTodoListScreen(BuildContext context, TodoList initialList) {
  TodoStatusFilter initialFilter = TodoStatusFilter.active;
  return BlocProvider<TodoListBloc>(
    create: (context) {
      var bloc = TodoListBloc(TodoRepositorySqflite.getInstance(), initialList);
      bloc.add(GetDataEvent(filter: initialFilter));
      return bloc;
    },
    child: TodoListScreen(initialFilter),
  );
}

class TodoListScreen extends StatefulWidget {
  final TodoStatusFilter filter;
  TodoListScreen(this.filter);

  @override
  _TodoListScreenState createState() => _TodoListScreenState();
}

class _TodoListScreenState extends State<TodoListScreen> {
  TodoListBloc bloc;
  TodoStatusFilter filter;

  @override
  void initState() {
    bloc = BlocProvider.of<TodoListBloc>(context);
    filter = widget.filter;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    var bottomNavigationBar = BottomNavigationBar(
      items: [
        BottomNavigationBarItem(icon: Icon(_iconForFilter(TodoStatusFilter.active)), title: Text("Active")),
        BottomNavigationBarItem(icon: Icon(_iconForFilter(TodoStatusFilter.completed)), title: Text("Completed")),
        BottomNavigationBarItem(icon: Icon(_iconForFilter(TodoStatusFilter.important)), title: Text("Important")),
        BottomNavigationBarItem(icon: Icon(_iconForFilter(TodoStatusFilter.withDueDate)), title: Text("Due")),
      ],
      currentIndex: _filterToBottomBarIndex(filter),
      type: BottomNavigationBarType.fixed,
      onTap: (index) {
        _setFilter(_bottomBarIndexToFilter(index));
      },
    );
    return BlocBuilder<TodoListBloc,TodoListStates>(
      builder: (context, state) {
        AppBar appBar;
        Widget body;
        FloatingActionButton floatingActionButton;
        if (state is TodoListLoading) {
            appBar = AppBar(title: Text(state.list.listName),);
            body = LinearProgressIndicator();
        } else if (state is TodoListLoadingFailed) {
            appBar = AppBar(title: Text("Qunderlist"));
            body = Center(child: Text("Failed to load list!"));
        } else if (state is TodoListDeleted) {
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          } else {
              appBar = AppBar(title: Text("Qunderlist"));
              body = Center(child: Text("Error: The list was deleted!"));
          }
        } else if (state is TodoListLoaded) {
            appBar = AppBar(title: Text(state.list.listName));
            floatingActionButton = FloatingActionButton(child: Icon(Icons.add), onPressed: () {showModalBottomSheet(context: context, builder: (context) => TodoItemAdder(bloc));});
            if (state.items.totalNumberOfItems != 0) {
              body = TodoListItemList(state.items);
            } else {
              body = Center(child: Column(children: <Widget>[
                Icon(_iconForFilter(filter), size: 96),
                Text("There's nothing here", style: TextStyle(fontSize: 24),),
              ],
                mainAxisAlignment: MainAxisAlignment.center,
              ),
              );
            }
        } else {
          throw "BUG: Unhandled state in todo lists screen";
        }
        return Scaffold(
          appBar: appBar,
          body: body,
          floatingActionButton: floatingActionButton,
          bottomNavigationBar: bottomNavigationBar,
        );
      },
    );
  }

  void _setFilter(TodoStatusFilter newFilter) {
    setState(() {
      filter = newFilter;
      bloc.add(UpdateFilterEvent(newFilter));
    });
  }

  static IconData _iconForFilter(TodoStatusFilter filter) {
    switch (filter) {
      case TodoStatusFilter.active: return Icons.radio_button_unchecked;
      case TodoStatusFilter.completed: return Icons.check_circle_outline;
      case TodoStatusFilter.important: return Icons.bookmark_border;
      case TodoStatusFilter.withDueDate: return Icons.date_range;
      default: throw "BUG: Unsupported filter in List BottomBar";
    }
  }

  static int _filterToBottomBarIndex(TodoStatusFilter filter) {
    switch (filter) {
      case TodoStatusFilter.active: return 0;
      case TodoStatusFilter.completed: return 1;
      case TodoStatusFilter.important: return 2;
      case TodoStatusFilter.withDueDate: return 3;
      default: throw "BUG: Unsupported filter in List BottomBar";
    }
  }
  static TodoStatusFilter _bottomBarIndexToFilter(int index) {
    switch (index) {
      case 0: return TodoStatusFilter.active;
      case 1: return TodoStatusFilter.completed;
      case 2: return TodoStatusFilter.important;
      case 3: return TodoStatusFilter.withDueDate;
      default: throw "BUG: Unsupported index for List BottomBar";
    }
  }

  @override
  void dispose() {
    bloc.close();
    super.dispose();
  }
}

class TodoListItemList extends StatelessWidget {
  final ListCache<TodoItem> items;
  TodoListItemList(this.items);

  @override
  Widget build(BuildContext context) {
    var bloc = BlocProvider.of<TodoListBloc>(context);
    print("${items.totalNumberOfItems}");
    return Container(
      child: CachedList(
          cache: items,
          itemBuilder: (context, index, item) => DismissibleItem(
              key: Key(item.id.toString()),
              child: TodoListItemCard(index, item),
              deleteMessage: "Delete todo item",
              deletedMessage: "Todo item deleted",
              onDismissed: () => bloc.add(DeleteItemEvent(item, index: index)),
              undoAction: () => bloc.add(AddItemEvent(item)),
          ),
          reorderCallback: (from, to) => bloc.add(ReorderItemsEvent(from, to)),
          itemHeight: 50
      ),
      color: Colors.blue.shade100,
      padding: EdgeInsets.symmetric(horizontal: 8),
    );
  }
}

class TodoListItemCard extends StatelessWidget {
  final int index;
  final TodoItem item;
  TodoListItemCard(this.index, this.item);

  @override
  Widget build(BuildContext context) {
    Widget center;
    if (item.dueDate != null || item.note != null || item.reminders.isNotEmpty) {
      center =  Column(
          children: <Widget>[
            Text(item.todo, style: TextStyle(fontSize: 15)),
            Row(
              children: <Widget>[
                if (item.dueDate != null) Text(formatDate(item.dueDate), style: TextStyle(fontSize: 13, color: Colors.black54)),
                if (item.reminders.isNotEmpty) Icon(Icons.alarm, size: 13, color: Colors.black54,),
                if (item.note != null && item.note != "") Icon(Icons.attach_file, size: 13, color: Colors.black54),
            ],
            )
          ],
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.start,
      );
    } else {
      center = Text(item.todo, style: TextStyle(fontSize: 15));
    }
    return Card(
      child: Container(
        height: 50,
        child: Row(
          children: <Widget>[
            IconButton(
              icon: Icon(item.completed ? Icons.check_box : Icons.check_box_outline_blank, color: Colors.black54), //item.completed ? Icon(Icons.check_box) : Icon(Icons.check_box_outline_blank),
              onPressed: () => BlocProvider.of<TodoListBloc>(context).add(CompleteItemEvent(item, index: index)),
            ),
            Expanded(
                child: InkWell(
                  child: center,
                  onTap: () async {
                    var bloc = BlocProvider.of<TodoListBloc>(context);
                    TodoItem updatedItem = await Navigator.push(context, MaterialPageRoute(builder: (context) => showTodoItemScreen(context, item, index: index, todoListBloc: bloc)));
                  },
                )
            ),
            Ink(
              decoration: ShapeDecoration(
                color: bgColorForPriority(item.priority),
                shape: CircleBorder(),
              ),
              child: IconButton(
                icon: Icon(Icons.bookmark_border, color: Colors.black54,),
                color: item.priority==TodoPriority.none ? null : Colors.white,
                onPressed: () => BlocProvider.of<TodoListBloc>(context).add(UpdateItemPriorityEvent(item, item.priority==TodoPriority.none ? TodoPriority.high : TodoPriority.none, index: index)),
              ),
            ),
          ],
        ),
      ),
      margin: EdgeInsets.symmetric(vertical: 0.5),
    );
  }
}

class TodoListItemView extends StatelessWidget {
  final int index;
  final TodoItem item;
  TodoListItemView(this.index, this.item);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: IconButton(
          icon: item.completed ? Icon(Icons.check_box) : Icon(Icons.check_box_outline_blank),
          onPressed: () => BlocProvider.of<TodoListBloc>(context).add(CompleteItemEvent(item, index: index)),
      ),
      title: Text("${item.todo} => ${item.id}"),
      subtitle: item.dueDate!=null ? Text(formatDate(item.dueDate)) : null,
      trailing: Ink(
        decoration: ShapeDecoration(
            color: bgColorForPriority(item.priority),
            shape: CircleBorder(),
        ),
        child: IconButton(
          icon: Icon(Icons.bookmark_border),
          color: item.priority==TodoPriority.none ? null : Colors.white,
          onPressed: () => BlocProvider.of<TodoListBloc>(context).add(UpdateItemPriorityEvent(item, item.priority==TodoPriority.none ? TodoPriority.high : TodoPriority.none, index: index)),
        ),
      ),
    );
  }
}