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
  return BlocProvider<TodoListBloc>(
    create: (context) {
      var bloc = TodoListBloc(TodoRepositorySqflite.getInstance(), initialList);
      bloc.add(GetDataEvent(filter: TodoStatusFilter.active));
      return bloc;
    },
    child: TodoListScreen(),
  );
}

class TodoListScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TodoListBloc,TodoListStates>(
      builder: (context, state) {
        if (state is TodoListLoading) {
          return Scaffold(
            appBar: AppBar(title: Text(state.list.listName),),
            body: LinearProgressIndicator(),
          );
        }
        if (state is TodoListLoadingFailed) {
          return Scaffold(
            appBar: AppBar(title: Text("Qunderlist")),
            body: Center(child: Text("Failed to load list!")),
          );
        }
        if (state is TodoListDeleted) {
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          } else {
            return Scaffold(
              appBar: AppBar(title: Text("Qunderlist")),
              body: Center(child: Text("Error: The list was deleted!")),
            );
          }
        }
        if (state is TodoListLoaded) {
          print("Redraw: n_items = ${state.items.totalNumberOfItems}");
          return Scaffold(
            appBar: AppBar(title: Text(state.list.listName), actions: <Widget>[FilterButton(), IconButton(icon: Icon(Icons.more_vert))],),
            body: TodoListItemList(state.items),
            floatingActionButton: FloatingActionButton(child: Icon(Icons.add), onPressed: () {var bloc = BlocProvider.of<TodoListBloc>(context); showModalBottomSheet(context: context, builder: (context) => TodoItemAdder(bloc));}),
          );
        }
        throw "BUG: Unhandled state in todo lists screen";
      },
    );
  }
}

class FilterButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<TodoStatusFilter>(
      child: Icon(Icons.filter_list),
      itemBuilder: (_) => [
        const PopupMenuItem(value: TodoStatusFilter.active ,child: ListTile(leading: Icon(Icons.check_box_outline_blank), title: Text("active"))),
        const PopupMenuItem(value: TodoStatusFilter.completed ,child: ListTile(leading: Icon(Icons.check_box), title: Text("completed"))),
        const PopupMenuItem(value: TodoStatusFilter.important ,child: ListTile(leading: Icon(Icons.bookmark_border), title: Text("important"))),
        const PopupMenuItem(value: TodoStatusFilter.withDueDate ,child: ListTile(leading: Icon(Icons.calendar_today), title: Text("with date"))),
      ],
      onSelected: (filter) => BlocProvider.of<TodoListBloc>(context).add(GetDataEvent(filter: filter)),
    );
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