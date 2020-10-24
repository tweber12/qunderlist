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
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:qunderlist/blocs/todo_details.dart';
import 'package:qunderlist/blocs/todo_list.dart';
import 'package:qunderlist/repository/repository.dart';
import 'package:qunderlist/theme.dart';
import 'package:qunderlist/widgets/date.dart';
import 'package:qunderlist/widgets/priority.dart';
import 'package:qunderlist/widgets/repeated.dart';
import 'package:qunderlist/widgets/sliver_header.dart';

Widget showTodoItemScreen<R extends TodoRepository>(BuildContext context, R repository, {int itemId, TodoItemBase initialItem, TodoListBloc todoListBloc}) {
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
        child: Theme(
            child: TodoItemDetailScreen(),
            data: themeFromPalette(todoListBloc?.color ?? Palette.blue),
        ),
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
        TodoItemBase item;
        if (state is TodoDetailsLoadedShortItem) {
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
                      PriorityTile(item.priority, (priority) => BlocProvider.of<TodoDetailsBloc>(context).add(UpdatePriorityEvent(priority))),
                      Divider(),
                      DueDateTile((date) => BlocProvider.of<TodoDetailsBloc>(context).add(UpdateDueDateEvent(date)), initialDate: item.dueDate),
                      item is TodoItem ? RepeatedTile(
                        onRepeatedChanged: (repeated) => BlocProvider.of<TodoDetailsBloc>(context).add(UpdateRepeatedEvent(repeated)),
                        repeated: item.repeated,
                        dueDate: item.dueDate,
                      ) : CircularProgressIndicator(),
                      item is TodoItem ? ReminderTile(
                        item.reminders,
                        (date) => BlocProvider.of<TodoDetailsBloc>(context).add(AddReminderEvent(Reminder(date))),
                        (reminder) => BlocProvider.of<TodoDetailsBloc>(context).add(UpdateReminderEvent(reminder)),
                        (reminder) => BlocProvider.of<TodoDetailsBloc>(context).add(DeleteReminderEvent(reminder)),
                        allowUndo: true,
                        startDate: item.dueDate,
                      ) : CircularProgressIndicator(),
//                      TodoItemDetailsReminders(item.reminders),
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
    if (state is TodoDetailsLoadedShortItem || state is TodoDetailsLoading) {
      return SizedBox(
        height: height,
        child: Center(child: CircularProgressIndicator()),
      );
    } else {
      List<TodoList> lists;
      if (state is TodoDetailsFullyLoaded) {
        lists = (state as TodoDetailsFullyLoaded).item.onLists;
      }
      return ListTile(
        leading: Icon(Icons.playlist_add),
        title: Wrap(
          children: lists
              .map((list) => TodoItemDetailsListChip(list, lists,
              canRemove: lists.length > 1))
              .toList(),
          spacing: 6,
        ),
        onTap: () async => await _addToList(context, lists),
      );
    }
  }
}

class TodoItemDetailsListChip extends StatelessWidget {
  final TodoList list;
  final bool canRemove;
  final List<TodoList> lists;
  TodoItemDetailsListChip(this.list, this.lists, {this.canRemove = true});

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    return InputChip(
      label: Text(list.listName, style: TextStyle(color: theme.primaryTextTheme.headline6.color)),
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
      deleteIcon: Icon(Icons.cancel, color: theme.primaryTextTheme.headline6.color, size: 18),
      onPressed: () async => await _addToList(context, lists, moveFromList: list),
      backgroundColor: theme.primaryColor,
    );
  }
}

Future<void> _addToList(BuildContext context, List<TodoList> onLists, {TodoList moveFromList}) async {
  var move = moveFromList != null;

  void _addToListInternal(TodoList list, bool copy) {
    if (move) {
      BlocProvider.of<TodoDetailsBloc>(context).add(MoveToListEvent(moveFromList.id, list));
    } else if (copy) {
      BlocProvider.of<TodoDetailsBloc>(context).add(CopyToListEvent(list));
    } else {
      BlocProvider.of<TodoDetailsBloc>(context).add(AddToListEvent(list));
    }
  }

  return showDialog(
      context: context,
      child: _AddToListDialog(RepositoryProvider.of<TodoRepository>(context), _addToListInternal, onLists, move: move)
  );
}

class _AddToListDialog extends StatefulWidget {
  final TodoRepository repository;
  final Function(TodoList list, bool copy) addToList;
  final bool move;
  final List<TodoList> onLists;

  _AddToListDialog(this.repository, this.addToList, this.onLists, {this.move=false});

  @override
  __AddToListDialogState createState() => __AddToListDialogState();
}

class __AddToListDialogState extends State<_AddToListDialog> {
  TodoList _list;
  bool _copy = false;
  bool _alreadyOn = false;
  List<int> _excludeLists;
  final TextEditingController _typeAheadController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _excludeLists = widget.onLists.map((l) => l.id).toList();
  }

  @override
  Widget build(BuildContext context) {
    var verb = (_copy || _alreadyOn) ? "Copy" : widget.move ? "Move" : "Add";
    return AlertDialog(
      title: Text("$verb item to list"),
      content: Column(
        children: [
          _listSelector(context, widget.repository),
          if (!widget.move) _copyCheckbox(context),
        ],
        mainAxisSize: MainAxisSize.min,
      ),
      actions: [
        FlatButton(child: Text("Cancel"), onPressed: () => Navigator.pop(context)),
        RaisedButton(
            child: Text(verb),
            onPressed: _list!=null ? () {
              widget.addToList(_list, _copy);
              Navigator.pop(context);
            } : null
        )
      ],
    );
  }

  Widget _listSelector(BuildContext context, TodoRepository repository) {
    return TypeAheadField<TodoList>(
        itemBuilder: (context, list) => ListTile(title: Text(list.listName)),
        suggestionsCallback: _getSuggestion,
        onSuggestionSelected: (list) => _selectList(list),
        transitionBuilder: (context, suggestionsBox, controller) {
          return suggestionsBox;
        },
        textFieldConfiguration: TextFieldConfiguration(
            autofocus: true,
            controller: _typeAheadController,
            decoration: InputDecoration(labelText: "List Name"),
            onChanged: (name) => _lookupList(name)
            ),
    );
  }

  Widget _copyCheckbox(BuildContext context) {
    return CheckboxListTile(
        controlAffinity: ListTileControlAffinity.leading,
        value: _alreadyOn || _copy,
        title: Text("Create a copy of the item"),
        onChanged: _alreadyOn ? null : (value) => _setCopy(value),
    );
  }

  Future<Iterable<TodoList>> _getSuggestion(String pattern) async {
    return widget.repository.getMatchingLists(pattern, limit: 4);
  }

  void _setCopy(bool value) {
    setState(() {
      _copy = value;
    });
  }
  void _lookupList(String name) async {
    var list = await widget.repository.getTodoListByName(name);
    if (list != null) {
      _selectList(list);
    } else {
      setState(() {
        _list = null;
        _alreadyOn = false;
      });
    }
  }
  void _selectList(TodoList list) {
    setState(() {
      if (_typeAheadController.text != list.listName) {
        _typeAheadController.text = list.listName;
      }
      _list = list;
      _alreadyOn = _excludeLists.contains(_list.id);
    });
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
  final TodoItemBase item;
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
  final TodoItemBase item;
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