import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qunderlist/blocs/cache.dart';
import 'package:qunderlist/blocs/todo_list.dart';
import 'package:qunderlist/repository/repository.dart';
import 'package:qunderlist/screens/cached_list.dart';
import 'package:qunderlist/screens/todo_item_screen.dart';
import 'package:qunderlist/theme.dart';
import 'package:qunderlist/widgets/date.dart';
import 'package:qunderlist/widgets/priority.dart';

Widget showTodoListScreen<R extends TodoRepository>(BuildContext context, R repository, TodoList initialList) {
  TodoStatusFilter initialFilter = TodoStatusFilter.active;
  return RepositoryProvider.value(
    value: repository,
    child: BlocProvider<TodoListBloc>(
      create: (context) {
        var bloc = TodoListBloc(repository, initialList);
        bloc.add(GetDataEvent(filter: initialFilter));
        return bloc;
      },
      child: Theme(
          child: TodoListScreen(initialFilter),
          data: themeFromPalette(initialList.color),
      ),
    )
  );
}

Widget showTodoListScreenExternal<R extends TodoRepository>(BuildContext context, R repository, TodoListBloc bloc) {
  return RepositoryProvider.value(
      value: repository,
      child: BlocProvider<TodoListBloc>.value(
        value: bloc,
        child: TodoListScreen(bloc.filter),
      )
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
    var bottomNavigationBar = () => BottomNavigationBar(
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
            floatingActionButton = FloatingActionButton(child: Icon(Icons.add), onPressed: () {showModalBottomSheet(context: context, builder: (context) => TodoItemAdder(bloc), isScrollControlled: true);});
            if (state.items.totalNumberOfItems != 0) {
              body = TodoListItemList(state.items, reorderable: filter==TodoStatusFilter.active);
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
          bottomNavigationBar: bottomNavigationBar(),
        );
      },
    );
  }

  void _setFilter(TodoStatusFilter newFilter) {
    filter = newFilter;
    bloc.add(UpdateFilterEvent(newFilter));
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

IconData _iconForFilter(TodoStatusFilter filter) {
  switch (filter) {
    case TodoStatusFilter.active: return Icons.radio_button_unchecked;
    case TodoStatusFilter.completed: return Icons.check_circle_outline;
    case TodoStatusFilter.important: return Icons.bookmark_border;
    case TodoStatusFilter.withDueDate: return Icons.date_range;
    default: throw "BUG: Unsupported filter in List BottomBar";
  }
}

class TodoListItemEmptyList extends StatelessWidget {
  final TodoStatusFilter filter;
  TodoListItemEmptyList(this.filter);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: <Widget>[
          Icon(_iconForFilter(filter), size: 96),
          Text(_messageForFilter(), style: TextStyle(fontSize: 24),),
        ],
        mainAxisAlignment: MainAxisAlignment.center,
      ),
    );
  }

  String _messageForFilter() {
    switch (filter) {
      case TodoStatusFilter.active: return "Nothing to do";
      case TodoStatusFilter.completed: return "Nothing done yet ;)";
      case TodoStatusFilter.important: return "No important tasks";
      case TodoStatusFilter.withDueDate: return "No scheduled tasks";
      default: throw "BUG: Unsupported filter used in list screen";
    }
  }
}

class TodoListItemList extends StatelessWidget {
  final ListCache<TodoItemShort> items;
  final bool reorderable;
  TodoListItemList(this.items, {this.reorderable=false});

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
          reorderCallback: reorderable ? (from, to) async => bloc.add(ReorderItemsEvent(await items.peekItem(from), from, await items.peekItem(to), to)) : null,
          itemHeight: 55
      ),
      color: Theme.of(context).backgroundColor,
      padding: EdgeInsets.symmetric(horizontal: 8),
    );
  }
}

class TodoListItemCard extends StatelessWidget {
  final int index;
  final TodoItemShort item;

  TodoListItemCard(this.index, this.item);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        child: Container(
          height: 55,
          child: Row(
            children: <Widget>[
              _checkbox(context),
              _itemInfo(context),
              PriorityButton(item.priority, (priority) => BlocProvider.of<TodoListBloc>(context).add(UpdateItemPriorityEvent(item, priority, index: index))),
            ],
          ),
          padding: EdgeInsets.fromLTRB(0, 0, 8, 0),
        ),
        onTap: () => _showDetails(context),
      ),
      margin: EdgeInsets.symmetric(vertical: 0.5),
    );
  }

  Widget _checkbox(BuildContext context) {
    return IconButton(
      icon: Icon(item.completed ? Icons.check_circle_outline : Icons
          .radio_button_unchecked, color: Colors.black54),
      onPressed: () =>
          BlocProvider.of<TodoListBloc>(context).add(
              CompleteItemEvent(item, index: index)),
    );
  }

  static const TITLE_FONT_SIZE = 15.0;
  static const SUB_INFO_SIZE = 13.0;
  Widget _itemInfo(BuildContext context) {
    if (item.note == null && item.dueDate == null && item.nActiveReminders==0) {
      return Expanded(child: Text(item.todo, style: TextStyle(fontSize: TITLE_FONT_SIZE), maxLines: 2, overflow: TextOverflow.ellipsis));
    }
    var numReminders = item.nActiveReminders;
    return Expanded(
        child: Column(
          children: [
            Text(item.todo, style: TextStyle(fontSize: TITLE_FONT_SIZE), maxLines: 1, overflow: TextOverflow.ellipsis),
            if (item.note != null && item.note != "") Text(item.note, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: SUB_INFO_SIZE, color: Colors.black54),),
            Row(
              children: [
                if (item.dueDate != null) Text(formatDate(item.dueDate), style: TextStyle(fontSize: SUB_INFO_SIZE, color: _dueDateColor(item.dueDate, item.completedOn))),
                if (item.dueDate != null) Container(width: 5),
                if (numReminders > 0) Icon(Icons.alarm, size: SUB_INFO_SIZE, color: Colors.black54,),
                if (numReminders > 0) Text("($numReminders)", style: TextStyle(fontSize: SUB_INFO_SIZE, color: Colors.black54)),
                if (numReminders > 0) Container(width: 5),
              ],
            ),
          ],
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
        )
    );
  }

  Color _dueDateColor(DateTime dueDate, DateTime completed) {
    var compare = completed ?? DateTime.now();
    var day = DateTime(compare.year, compare.month, compare.day);
    if (dueDate.isBefore(day)) {
      return Colors.red;
    } else if (dueDate.day == compare.day && dueDate.month == compare.month && dueDate.year == dueDate.year) {
      return Colors.blue;
    } else {
      return Colors.black54;
    }
  }

  void _showDetails(BuildContext context) async {
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (ctx) => showTodoItemScreen(
                ctx,
                RepositoryProvider.of<TodoRepository>(context),
                initialItem: item,
                todoListBloc: BlocProvider.of<TodoListBloc>(context)
            )
        )
    );
  }
}


class TodoItemAdder extends StatefulWidget {
  final TodoListBloc bloc;
  TodoItemAdder(this.bloc);

  @override
  State<StatefulWidget> createState() {
    return _TodoItemAdderState();
  }
}

class _TodoItemAdderState extends State<TodoItemAdder> {
  var nameController = TextEditingController();
  DateTime dueDate;
  int reminderId = 0;
  List<Reminder> reminders = [];
  TodoPriority priority = TodoPriority.none;

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Column(
        children: <Widget>[
          ListTile(
            leading: Icon(Icons.title),
            title: TextField(
              controller: nameController,
              decoration: InputDecoration(labelText: "Todo"),
              autofocus: true,
            ),
            trailing: PriorityButton(priority, _setPriority),
          ),
          DueDateTile(_setDueDate),
          ReminderTile(reminders, _addReminder, _updateReminder, _deleteReminder, startDate: dueDate, singleLine: true),
          ButtonBar(children: [
            RaisedButton(
                child: Text("Add"),
                onPressed: () {
                  widget.bloc.add(AddItemEvent(TodoItem(
                      nameController.text, DateTime.now(), priority: priority,
                      dueDate: dueDate, reminders: reminders.map((r) => Reminder(r.at)).toList())));
                  Navigator.pop(context);
                })
          ]),
        ],
        mainAxisSize: MainAxisSize.min
      ),
      padding: EdgeInsets.fromLTRB(10, 3, 10, MediaQuery.of(context).viewInsets.bottom+9),
    );
  }

  void _setPriority(TodoPriority priority) {
    setState(() {
      this.priority = priority;
    });
  }
  void _setDueDate(DateTime date) {
    setState(() {
      dueDate = date;
    });
  }
  void _addReminder(DateTime at) {
    setState(() {
      reminders.add(Reminder(at, id: reminderId));
      reminderId += 1;
      reminders.sort((a,b) => a.at.compareTo(b.at));
    });
  }
  void _updateReminder(Reminder updated) {
    setState(() {
      reminders = reminders.map((r) {return r.id == updated.id ? updated : r;}).toList();
      reminders.sort((a,b) => a.at.compareTo(b.at));
    });
  }
  void _deleteReminder(Reminder deleted) {
    setState(() {
      reminders = reminders.where((r) => r.id != deleted.id).toList();
    });
  }
}