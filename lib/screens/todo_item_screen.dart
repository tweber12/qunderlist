import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qunderlist/blocs/todo_details.dart';
import 'package:qunderlist/blocs/todo_list.dart';
import 'package:qunderlist/blocs/todo_lists.dart';
import 'package:qunderlist/repository/repository.dart';
import 'package:qunderlist/widgets/sliver_header.dart';

Widget showTodoItemScreen<R extends TodoRepository>(BuildContext context, R repository, {int itemId, TodoItem initialItem, TodoListBloc todoListBloc}) {
  assert(itemId != null || initialItem != null);
  return RepositoryProvider.value(
      value: repository,
      child: BlocProvider<TodoDetailsBloc>(
        create: (context) {
          var bloc = TodoDetailsBloc(
              repository,
              itemId ?? initialItem.id,
              item: initialItem,
              listBloc: todoListBloc
          );
          bloc.add(LoadItemEvent());
          return bloc;
        },
        child: TodoItemDetailScreen(),
      )
  );
}

class TodoItemDetailScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TodoDetailsBloc, TodoDetailsState>(
      builder: (context, state) {
        if (state is TodoDetailsLoading) {
          return Scaffold(
            body: LinearProgressIndicator(),
          );
        }
        TodoItem item;
        if (state is TodoDetailsLoadedItem) {
          item = state.item;
        } else if (state is TodoDetailsFullyLoaded) {
          item = state.item;
        }
        return Scaffold(
            body: CustomScrollView(
              slivers: <Widget>[
                SliverHeader(
                  item.todo,
                  dialogTitle: "Rename Task",
                  onTitleChange: (title) => BlocProvider.of<TodoDetailsBloc>(context).add(UpdateTitleEvent(title)),
                  actions: [InfoButton(item), ExtraActionsButton(item)],
                ),
                SliverList(
                    delegate: SliverChildListDelegate([
                      TodoItemDetailsLists(state),
                      Divider(
                        height: 8,
                      ),
                      TodoItemDetailsCompleted(item.completed),
                      TodoItemDetailsPriority(item.priority),
                      Divider(),
                      TodoItemDetailsDueDate(item.dueDate),
                      TodoItemDetailsReminders(item.reminders),
                      Divider(),
                      TodoItemDetailsNotes(item.note),
                    ])
                ),
              ],
            ));
      });
  }
}

class TodoItemDetailsLists extends StatelessWidget {
  final TodoDetailsState state;
  final double height = 70;
  TodoItemDetailsLists(this.state);

  @override
  Widget build(BuildContext context) {
    print("REPAINT");
    if (state is TodoDetailsLoadedItem || state is TodoDetailsLoading) {
      return SizedBox(
        height: height,
        child: Center(child: CircularProgressIndicator()),
      );
    } else {
      List<TodoList> lists;
      if (state is TodoDetailsFullyLoaded) {
        lists = (state as TodoDetailsFullyLoaded).lists;
      }
      return ListTile(
        leading: Icon(Icons.playlist_add),
        title: Wrap(
          children: lists
              .map((list) => TodoItemDetailsListChip(list,
              canRemove: lists.length > 1))
              .toList(),
          spacing: 6,
        ),
        onTap: () async => await addToList(context),
      );
    }
  }
}

class TodoItemDetailsListChip extends StatelessWidget {
  final TodoList list;
  final bool canRemove;
  TodoItemDetailsListChip(this.list, {this.canRemove = true});

  @override
  Widget build(BuildContext context) {
    return InputChip(
      label: Text(list.listName, style: TextStyle(color: Colors.white)),
      onDeleted: canRemove
          ? () {
              var bloc = BlocProvider.of<TodoDetailsBloc>(context);
              bloc.add(RemoveFromListEvent(list.id));
              Scaffold.of(context).showSnackBar(SnackBar(
                content: Text("Removed from list"),
                action: SnackBarAction(
                  label: "undo",
                  onPressed: () => bloc.add(AddToListEvent(list)),
                ),
              ));
            }
          : null,
      deleteIcon: Icon(Icons.cancel, color: Colors.white, size: 18),
      onPressed: () async => await addToList(context, moveFromList: list),
      backgroundColor: Colors.blue,
    );
  }
}

Future<void> addToList(BuildContext context, {TodoList moveFromList}) async {
  var move = moveFromList != null;
  AddToList add = await showDialog(context: context, child: TodoItemDetailsAddListDialog(RepositoryProvider.of<TodoRepository>(context), move: move));
  if (add == null) {
    return;
  }
  if (move) {
    BlocProvider.of<TodoDetailsBloc>(context).add(MoveToListEvent(moveFromList.id, add.list));
  } else if (add.copy) {
    BlocProvider.of<TodoDetailsBloc>(context).add(CopyToListEvent(add.list.id));
  } else {
    BlocProvider.of<TodoDetailsBloc>(context).add(AddToListEvent(add.list));
  }
}

class TodoItemDetailsAddListDialog extends StatefulWidget {
  final bool move;
  final TodoRepository repository;
  TodoItemDetailsAddListDialog(this.repository, {this.move = false});
  @override
  _TodoItemDetailsAddListDialogState createState() =>
      _TodoItemDetailsAddListDialogState();
}

class _TodoItemDetailsAddListDialogState
    extends State<TodoItemDetailsAddListDialog> {
  TodoList selected;
  bool createCopy;

  @override
  void initState() {
    super.initState();
    createCopy = false;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("Add item to list"),
      content: BlocProvider<TodoListsBloc>(
        create: (context) {
          var bloc = TodoListsBloc(widget.repository);
          bloc.add(LoadTodoListsEvent());
          return bloc;
        },
        child: Column(
          children: <Widget>[
            ListSelector(selectList, initial: this.selected),
            if(!widget.move)
              CheckboxListTile(
                  controlAffinity: ListTileControlAffinity.leading,
                  value: createCopy,
                  title: Text("Create a copy of the item"),
                  onChanged: (value) => setCopy(value)
              ),
          ],
          mainAxisSize: MainAxisSize.min,
        ),
      ),
      actions: <Widget>[
        FlatButton(child: Text("Cancel"), onPressed: () => Navigator.pop(context,null),),
        RaisedButton(child: Text(widget.move ? "Move" : "Add"), onPressed: () => Navigator.pop(context,AddToList(selected,createCopy))),
      ],
    );
  }

  void selectList(TodoList list) {
    setState(() {
      selected = list;
    });
  }
  void setCopy(bool copy) {
    setState(() {
      createCopy = copy;
    });
  }
}
class AddToList {
  final TodoList list;
  final bool copy;

  AddToList(this.list, this.copy);
}

class ListSelector extends StatelessWidget {
  final Function(TodoList) callback;
  final TodoList initial;
  ListSelector(this.callback, {this.initial});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TodoListsBloc,TodoListsStates>(
      builder: (context, state) {
        if (state is TodoListsLoading) {
          return CircularProgressIndicator();
        }
        var cache = (state as TodoListsLoaded).lists;
        var lists = [for (int i=0; i<min(cache.totalNumberOfItems, 10); i++) cache[i]];
        return DropdownButton(
          value: initial,
          items: lists.map((list) => DropdownMenuItem(value: list, child: Text(list.listName),)).toList(),
          onChanged: (value) { callback(value); },
        );
      },
    );
  }
}

class TodoItemDetailsCompleted extends StatelessWidget {
  final bool completed;
  TodoItemDetailsCompleted(this.completed);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(completed
          ? Icons.check_circle_outline
          : Icons.radio_button_unchecked),
      title: Text(completed ? "completed" : "active"),
      onTap: () =>
          BlocProvider.of<TodoDetailsBloc>(context).add(ToggleCompletedEvent()),
    );
  }
}

class TodoItemDetailsPriority extends StatelessWidget {
  final TodoPriority priority;
  TodoItemDetailsPriority(this.priority);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(Icons.bookmark_border, color: bgColorForPriority(priority)),
      title: Text("${nameForPriority(priority)} priority"),
      onTap: () => BlocProvider.of<TodoDetailsBloc>(context).add(
          UpdatePriorityEvent(priority == TodoPriority.none
              ? TodoPriority.high
              : TodoPriority.none)),
    );
  }
}

class TodoItemDetailsDueDate extends StatelessWidget {
  final DateTime dueDate;
  TodoItemDetailsDueDate(this.dueDate);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(Icons.calendar_today),
      title:
          Text(dueDate == null ? "no due date" : "due ${formatDate(dueDate)}"),
      trailing: dueDate == null ? null : IconButton(icon: Icon(Icons.cancel), onPressed: () {BlocProvider.of<TodoDetailsBloc>(context).add(UpdateDueDateEvent(null));},),
      onTap: () async {
        var now = DateTime.now();
        var date = await showDatePicker(
            context: context,
            initialDate: now,
            firstDate: now,
            lastDate: DateTime(now.year + 10));
        if (date == null) {
          return;
        }
        BlocProvider.of<TodoDetailsBloc>(context).add(UpdateDueDateEvent(date));
      },
    );
  }
}

class TodoItemDetailsReminders extends StatelessWidget {
  final List<Reminder> reminders;
  TodoItemDetailsReminders(this.reminders);

  @override
  Widget build(BuildContext context) {
    if (reminders.isEmpty) {
      return ListTile(
        leading: Icon(Icons.alarm_add),
        title: Text("no reminders"),
        onTap: () => addReminder(context),
      );
    } else {
      reminders.sort((a, b) => a.at.compareTo(b.at));
      return ListTile(
          leading: Icon(Icons.alarm_add),
          title: Wrap(
            children: <Widget>[
              for (var index = 0; index < reminders.length; index++)
                TodoItemDetailsReminderChip(reminders, index)
            ],
            spacing: 6,
          ),
          onTap: () => addReminder(context));
    }
  }

  Future<void> addReminder(BuildContext context) async {
    var newReminder = await showDateTimeDialog(context);
    BlocProvider.of<TodoDetailsBloc>(context)
        .add(AddReminderEvent(Reminder(newReminder)));
  }
}

class TodoItemDetailsReminderChip extends StatelessWidget {
  final List<Reminder> reminders;
  final int index;
  TodoItemDetailsReminderChip(this.reminders, this.index);

  @override
  Widget build(BuildContext context) {
    var reminder = reminders[index];
    return InputChip(
      label: Text(
          "${formatDate(reminder.at)}, ${reminder.at.hour}:${reminder.at.minute.toString().padLeft(2, "0")}"),
      onDeleted: () {
        var bloc = BlocProvider.of<TodoDetailsBloc>(context);
        bloc.add(DeleteReminderEvent(reminder));
        Scaffold.of(context).showSnackBar(SnackBar(
          content: Text("Reminder deleted"),
          action: SnackBarAction(
            label: "Undo",
            onPressed: () {
              reminders.add(reminder);
              bloc.add(AddReminderEvent(reminder));
            },
          ),
        ));
      },
      onPressed: () async {
        var newReminder = await showDateTimeDialog(context, initial: reminder.at);
        if (newReminder != reminder.at) {
          BlocProvider.of<TodoDetailsBloc>(context)
              .add(UpdateReminderEvent(reminder.copyWith(at: newReminder)));
        }
      },
    );
  }
}

Future<DateTime> showDateTimeDialog(BuildContext context, {DateTime initial}) async {
  var now = DateTime.now();
  var initialDate = initial ?? now;
  var initialTime = TimeOfDay(hour: initialDate.hour, minute: initialDate.minute);
  var date = await showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: now,
    lastDate: DateTime(now.year + 10),
  );
  if (date == null) {
    return null;
  }
  var time = await showTimePicker(
    context: context,
    initialTime: initialTime,
  );
  if (time == null) {
    return null;
  }
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

class TodoItemDetailsNotes extends StatelessWidget {
  final String note;
  final bool hasNote;
  TodoItemDetailsNotes(this.note): hasNote = note!=null && note.trim()!="";

  @override
  Widget build(BuildContext context) {
    return ListTile(
        leading: Icon(Icons.description),
        title: Text(hasNote ? note : "no notes"),
        trailing: hasNote ? removeButton(context, note) : null,
        onTap: () async {
          var newNote = await showDialog(context: context, child: TodoItemDetailsNotesDialog(note));
          print("new note");
          if (newNote != null && newNote != note) {
            BlocProvider.of<TodoDetailsBloc>(context).add(UpdateNoteEvent(newNote));
          }
        },
    );
  }

  Widget removeButton(BuildContext context, String oldNote) {
    return IconButton(
      icon: Icon(Icons.cancel),
      onPressed: () {
        var bloc = BlocProvider.of<TodoDetailsBloc>(context);
        bloc.add(UpdateNoteEvent(""));
        Scaffold.of(context).showSnackBar(SnackBar(
          content: Text("Note removed"),
          action: SnackBarAction(
              label: "undo",
              onPressed: () => bloc.add(UpdateNoteEvent(oldNote))
          )
        ));
      },
    );
  }
}

class TodoItemDetailsNotesDialog extends StatefulWidget {
  final String note;
  final bool hasNote;
  TodoItemDetailsNotesDialog(this.note): hasNote = note!=null && note.trim()!="";

  @override
  _TodoItemDetailsNotesDialogState createState() => _TodoItemDetailsNotesDialogState();
}

class _TodoItemDetailsNotesDialogState extends State<TodoItemDetailsNotesDialog> {
  TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.note);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.hasNote ? "Edit notes" : "Add notes"),
      content: TextField(controller: controller, autofocus: true, keyboardType: TextInputType.multiline, maxLength: null, maxLines: null,),
      actions: <Widget>[
        FlatButton(child: Text("Cancel"), onPressed: () => Navigator.pop(context, null),),
        RaisedButton(child: Text("Set note"), onPressed: () => Navigator.pop(context, controller.text),),
      ],
    );
  }
}

class InfoButton extends StatelessWidget {
  final TodoItem item;
  InfoButton(this.item);

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.info_outline),
      onPressed: () => showDialog(
        context: context,
        child: AlertDialog(
          title: Text("More Info"),
          content: ListView(
            shrinkWrap: true,
            children: <Widget>[
              ListTile(
                  leading: Icon(Icons.calendar_today),
                  title: Text("Created: ${formatDate(item.createdOn)}")),
              if (item.completed)
                ListTile(
                    leading: Icon(Icons.check_box),
                    title: Text("Completed: ${formatDate(item.completedOn)}"))
            ],
          ),
          actions: <Widget>[
            RaisedButton(
              child: Text("Ok"),
              onPressed: () => Navigator.pop(context),
            )
          ],
        ),
      ),
    );
  }
}

enum ExtraActions {
  delete,
}

class ExtraActionsButton extends StatelessWidget {
  final TodoItem item;
  ExtraActionsButton(this.item);

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return PopupMenuButton<ExtraActions>(
      itemBuilder: (context) => <PopupMenuEntry<ExtraActions>>[
        const PopupMenuItem(
          child: Text("Delete"),
          value: ExtraActions.delete,
        ),
      ],
      onSelected: (action) {
        switch (action) {
          case ExtraActions.delete:
            BlocProvider.of<TodoDetailsBloc>(context).add(DeleteEvent());
            print("Popping");
            Navigator.maybePop(context);
            break;
          default:
            throw "BUG: Unhandled option in extra actions menu!";
        }
      },
    );
  }
}

Widget priorityIcon(TodoPriority priority) {
  return Ink(
    decoration: ShapeDecoration(
      color: bgColorForPriority(priority),
      shape: CircleBorder(),
    ),
    width: 50,
    child: Padding(
      child: Icon(Icons.bookmark_border,
          size: 24, color: priority == TodoPriority.none ? null : Colors.white),
      padding: EdgeInsets.all(14),
    ),
  );
}

class PriorityButton extends StatelessWidget {
  final TodoPriority priority;
  final Function(TodoPriority newPriority) callback;

  PriorityButton(this.priority, this.callback);

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Ink(
        decoration: ShapeDecoration(
          color: bgColorForPriority(priority),
          shape: CircleBorder(),
        ),
        child: InkWell(
            child: Padding(
              child: Icon(Icons.bookmark_border,
                  size: 24,
                  color: priority == TodoPriority.none ? null : Colors.white),
              padding: EdgeInsets.all(14),
            ),
            onTap: () {
              var newPriority = priority == TodoPriority.none
                  ? TodoPriority.high
                  : TodoPriority.none;
              callback(newPriority);
            },
            onLongPress: () async {
              var newPriority = await showMenu<TodoPriority>(
                  context: context,
                  position: RelativeRect.fromLTRB(10, 85, 0, 0),
                  items: [
                    for (var prio in [
                      TodoPriority.high,
                      TodoPriority.medium,
                      TodoPriority.low,
                      TodoPriority.none
                    ])
                      PopupMenuItem(
                          child: Center(child: priorityIcon(prio)),
                          value: prio,
                          height: 50)
                  ]);
              callback(newPriority);
            }));
  }
}

String nameForPriority(TodoPriority priority) {
  switch (priority) {
    case TodoPriority.high:
      return "high";
    case TodoPriority.medium:
      return "medium";
    case TodoPriority.low:
      return "low";
    case TodoPriority.none:
      return "no";
    default:
      throw "BUG: Unhandled priority when assigning names!";
  }
}

Color bgColorForPriority(TodoPriority priority) {
  switch (priority) {
    case TodoPriority.high:
      return Colors.red;
    case TodoPriority.medium:
      return Colors.lightBlueAccent;
    case TodoPriority.low:
      return Colors.lightGreenAccent;
    case TodoPriority.none:
      return null;
    default:
      throw "BUG: Unhandled priority when assigning colors!";
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        ListTile(
            title: TextField(
          controller: nameController,
          decoration: InputDecoration(labelText: "Todo"),
          autofocus: true,
        )),
        DueDateButton(dueDate, (date) {
          setState(() {
            dueDate = date;
          });
        }),
        ButtonBar(children: [
          RaisedButton(
              child: Text("Add"),
              onPressed: () {
                widget.bloc.add(AddItemEvent(TodoItem(
                    nameController.text, DateTime.now(),
                    dueDate: dueDate)));
                Navigator.pop(context);
              })
        ]),
      ],
    );
  }
}

enum DateSelection {
  today,
  tomorrow,
  nextWeek,
  other,
}

class DueDateButton extends StatelessWidget {
  final DateTime dueDate;
  final Function(DateTime) callback;
  DueDateButton(this.dueDate, this.callback);

  @override
  Widget build(BuildContext context) {
    Widget child = ListTile(
      leading: Icon(Icons.date_range),
      title:
          Text(dueDate == null ? "Add due date" : "Due ${formatDate(dueDate)}"),
      trailing: dueDate != null ? IconButton(icon: Icon(Icons.delete)) : null,
    );
    var button = PopupMenuButton<DateSelection>(
      itemBuilder: (context) => [
        PopupMenuItem<DateSelection>(
            value: DateSelection.today, child: Text("Today")),
        PopupMenuItem<DateSelection>(
            value: DateSelection.tomorrow, child: Text("Tomorrow")),
        PopupMenuItem<DateSelection>(
            value: DateSelection.nextWeek, child: Text("Next week")),
        PopupMenuItem<DateSelection>(
            value: DateSelection.other, child: Text("Custom date")),
      ],
      onSelected: (DateSelection result) async {
        var now = DateTime.now();
        var today = DateTime(now.year, now.month, now.day);
        switch (result) {
          case DateSelection.today:
            callback(today);
            break;
          case DateSelection.tomorrow:
            callback(today.add(Duration(days: 1)));
            break;
          case DateSelection.nextWeek:
            callback(today.add(Duration(days: DateTime.daysPerWeek)));
            break;
          case DateSelection.other:
            var last = DateTime(today.year + 5);
            var date = await showDatePicker(
                context: context,
                initialDate: today,
                firstDate: today,
                lastDate: last);
            if (date != null) {
              callback(date);
            }
            break;
        }
      },
      child:
          Text(dueDate == null ? "Set due date" : "Due ${formatDate(dueDate)}"),
    );
    return ListTile(
      leading: Icon(Icons.calendar_today),
      title: button,
      trailing: dueDate != null
          ? IconButton(
              icon: Icon(Icons.delete),
              onPressed: () => callback(null),
            )
          : null,
    );
  }
}

String formatDate(DateTime date) {
  var now = DateTime.now();
  var today = DateTime(now.year, now.month, now.day);
  var distance = DateTime(date.year, date.month, date.day).difference(today);
  if (distance.isNegative) {
    if (distance.inHours > -12) {
      return "Today";
    } else if (distance.inHours > -36) {
      return "Yesterday";
    } else {
      return formatFullDate(date, date.year == today.year);
    }
  } else {
    if (distance.inHours < 12) {
      return "Today";
    } else if (distance.inHours < 36) {
      return "Tomorrow";
    } else {
      return formatFullDate(date, date.year != today.year);
    }
  }
}

String formatFullDate(DateTime date, bool showYear) {
  var weekday;
  switch (date.weekday) {
    case DateTime.monday:
      weekday = "Mo";
      break;
    case DateTime.tuesday:
      weekday = "Tu";
      break;
    case DateTime.wednesday:
      weekday = "We";
      break;
    case DateTime.thursday:
      weekday = "Th";
      break;
    case DateTime.friday:
      weekday = "Fr";
      break;
    case DateTime.saturday:
      weekday = "Sa";
      break;
    case DateTime.sunday:
      weekday = "Su";
      break;
  }
  var month;
  switch (date.month) {
    case DateTime.january:
      month = "Jan";
      break;
    case DateTime.february:
      month = "Feb";
      break;
    case DateTime.march:
      month = "Mar";
      break;
    case DateTime.april:
      month = "Apr";
      break;
    case DateTime.may:
      month = "May";
      break;
    case DateTime.june:
      month = "Jun";
      break;
    case DateTime.july:
      month = "Jul";
      break;
    case DateTime.august:
      month = "Aug";
      break;
    case DateTime.september:
      month = "Sep";
      break;
    case DateTime.october:
      month = "Oct";
      break;
    case DateTime.november:
      month = "Nov";
      break;
    case DateTime.december:
      month = "Dec";
      break;
  }
  return "$weekday, ${date.day} $month${showYear ? " ${date.year}" : ""}";
}
