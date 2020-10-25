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
import 'package:intl/intl.dart';
import 'package:qunderlist/repository/models.dart';

class DueDateTile extends DateTile {
  DueDateTile(Function(DateTime dueDate) onDateChange, {DateTime initialDate}):
      super(onDateChange, selectedDate: initialDate, noDateMessage: "no due date", preDateMessage: "due ");
}

class ReminderTile extends StatelessWidget {
  final List<Reminder> reminders;
  final Function(DateTime) reminderAdded;
  final Function(Reminder) reminderUpdated;
  final Function(Reminder) reminderDeleted;
  final bool singleLine;
  final bool allowUndo;
  final DateTime startDate;

  ReminderTile(this.reminders, this.reminderAdded, this.reminderUpdated, this.reminderDeleted, {this.singleLine=false, this.allowUndo=false, this.startDate});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(Icons.alarm_add),
      title: reminders.isEmpty ? Text("no reminders") : _reminderChips(),
      onTap: () => _addReminder(context),
    );
  }

  Widget _reminderChips() {
    var children = reminders.map((r) => _ReminderChip(r, reminderAdded, reminderUpdated, reminderDeleted, allowUndo: allowUndo,)).toList();
    if (singleLine) {
      return Container(
        child: ListView(
          children: children,
          scrollDirection: Axis.horizontal,
        ),
        height: 40,
      );
    } else {
      return Wrap(
        children: children,
        spacing: 6,
      );
    }
  }

  Future<void> _addReminder(BuildContext context) {
    return showDialog(context: context, builder: (context) => ReminderDialog(reminderAdded, initialDateTime: startDate, onlyDate: true));
  }
}

class _ReminderChip extends StatelessWidget {
  final Reminder reminder;
  final Function(DateTime) reminderAdded;
  final Function(Reminder) reminderUpdated;
  final Function(Reminder) reminderDeleted;
  final bool allowUndo;

  _ReminderChip(this.reminder, this.reminderAdded, this.reminderUpdated, this.reminderDeleted, {this.allowUndo});

  @override
  Widget build(BuildContext context) {
    var isActive = reminder.at.isAfter(DateTime.now());
    return InputChip(
      label: Text(formatDateTime(reminder.at), style: TextStyle(color: isActive ? Theme.of(context).primaryTextTheme.headline6.color : null)),
      onDeleted: () => _deleteReminder(context),
      onPressed: () => showDialog(context: context, builder: (context) => ReminderDialog((at) => reminderUpdated(reminder.copyWith(at: at)), initialDateTime: reminder.at)),
      backgroundColor: isActive ? Theme.of(context).primaryColor : null,
    );
  }

  void _deleteReminder(BuildContext context) {
    reminderDeleted(reminder);
    if (!allowUndo) {
      return;
    }
    Scaffold.of(context).showSnackBar(SnackBar(
      content: Text("Reminder deleted"),
      action: SnackBarAction(
        label: "Undo",
        onPressed: () {
          reminderAdded(reminder.at);
        },
      ),
    ));
  }
}


enum _DateSelection {
  today,
  tomorrow,
  nextWeek,
  other,
}

class DateTile extends StatelessWidget {
  final Function(DateTime dueDate) onDateChange;
  final DateTime selectedDate;
  final bool allowRemove;
  final String noDateMessage;
  final String preDateMessage;

  DateTile(this.onDateChange, {this.selectedDate, this.allowRemove=true, this.noDateMessage, this.preDateMessage});

  static const _POPUP_MENU_ITEMS = [
    PopupMenuItem<_DateSelection>(
        value: _DateSelection.today, child: Text("Today")),
    PopupMenuItem<_DateSelection>(
        value: _DateSelection.tomorrow, child: Text("Tomorrow")),
    PopupMenuItem<_DateSelection>(
        value: _DateSelection.nextWeek, child: Text("Next week")),
    PopupMenuItem<_DateSelection>(
        value: _DateSelection.other, child: Text("Custom date")),
  ];

  @override
  Widget build(BuildContext context) {
    // TODO Build something so that the popup appears over the text, not at the start of the button
    // The offset parameter is completely useless, annoyingly
    return PopupMenuButton(
      child: ListTile(
        leading: Icon(Icons.today),
        title: Text(selectedDate==null ? noDateMessage ?? "" : "${preDateMessage ?? ""}${formatDate(selectedDate)}"),
        trailing: !allowRemove || selectedDate==null ? null : _removeButton(context),
      ),
      itemBuilder: (context) => _POPUP_MENU_ITEMS,
      onSelected: (selected) async => await _itemSelected(context, selected),
      offset: Offset(0, 80),
    );
  }

  Widget _removeButton(BuildContext context) {
    return IconButton(
        icon: Icon(Icons.cancel),
        onPressed: () => _setDate(null),
    );
  }

  Future<void> _itemSelected(BuildContext context, _DateSelection selected) async {
    var now = DateTime.now();
    switch (selected) {
      case _DateSelection.today: return _setDate(DateTime(now.year, now.month, now.day));
      case _DateSelection.tomorrow: return _setDate(DateTime(now.year, now.month, now.day+1));
      case _DateSelection.nextWeek: return _setDate(DateTime(now.year, now.month, now.day+DateTime.daysPerWeek));
      case _DateSelection.other: return _askForDate(context, now);
      default: throw "BUG: Unexpected _DateSelection in DueDateTile._itemSelected: $selected";
    }
  }

  void _setDate(DateTime date) {
    onDateChange(date);
  }

  Future<void> _askForDate(BuildContext context, DateTime now) async {
    var date = await showDatePicker(
        context: context,
        initialDate: now,
        firstDate: now,
        lastDate: DateTime(now.year+10, now.month, now.day));
    if (date != null) {
      _setDate(date);
    }
  }
}

enum _TimeSelection {
  morning,
  noon,
  evening,
  night,
  other,
}
TimeOfDay _timeForSelection(_TimeSelection selection) {
  switch(selection) {
    case _TimeSelection.morning: return TimeOfDay(hour: 8, minute: 0);
    case _TimeSelection.noon: return TimeOfDay(hour: 12, minute: 0);
    case _TimeSelection.evening: return TimeOfDay(hour: 19, minute: 0);
    case _TimeSelection.night: return TimeOfDay(hour: 22, minute: 0);
    case _TimeSelection.other: return null;
    default: throw "BUG: Unhandled _TimeSelection: $selection";
  }
}
String _textForSelection(_TimeSelection selection) {
  switch(selection) {
    case _TimeSelection.morning: return "Morning (${formatTimeOfDay(_timeForSelection(selection))})";
    case _TimeSelection.noon: return "Noon (${formatTimeOfDay(_timeForSelection(selection))})";
    case _TimeSelection.evening: return "Evening (${formatTimeOfDay(_timeForSelection(selection))})";
    case _TimeSelection.night: return "Night (${formatTimeOfDay(_timeForSelection(selection))})";
    case _TimeSelection.other: return null;
    default: throw "BUG: Unhandled _TimeSelection: $selection";
  }
}

class TimeTile extends StatelessWidget {
  final Function(TimeOfDay) onTimeChanged;
  final DateTime time;
  final bool today;

  TimeTile(this.onTimeChanged, {DateTime initialTime, this.today = false}):
    time = initialTime ?? DateTime.now();

  @override
  Widget build(BuildContext context) {
    // TODO Build something so that the popup appears over the text, not at the start of the button
    // The offset parameter is completely useless, annoyingly
    return PopupMenuButton(
      child: ListTile(
        leading: Icon(Icons.access_time),
        title: Text(formatTime(time)),
      ),
      itemBuilder: (context) => _popupMenuItems(),
      onSelected: (selected) async => await _itemSelected(context, selected),
    );
  }

  List<PopupMenuItem<_TimeSelection>> _popupMenuItems() {
    var now = TimeOfDay.now();
    var list = _TimeSelection
        .values
        .where((s) => s!=_TimeSelection.other)
        .map((s) => PopupMenuItem(value: s, child: Text(_textForSelection(s)), enabled: !today || _timeOfDayBefore(_timeForSelection(s), now),))
        .toList();
    list.add(PopupMenuItem(value: _TimeSelection.other, child: Text("Custom time")));
    return list;
  }

  Future<void> _itemSelected(BuildContext context, _TimeSelection selection) async {
    switch (selection) {
      case _TimeSelection.morning: return _setTime(_timeForSelection(selection));
      case _TimeSelection.noon: return _setTime(_timeForSelection(selection));
      case _TimeSelection.evening: return _setTime(_timeForSelection(selection));
      case _TimeSelection.night: return _setTime(_timeForSelection(selection));
      case _TimeSelection.other: return _askForTime(context, TimeOfDay.now());
      default: throw "BUG: Unexpected _TimeSelection in DueDateTile._itemSelected: $selection";
    }
  }

  Future<void> _askForTime(BuildContext context, TimeOfDay initialTime) async {
    var time = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (time != null) {
      _setTime(time);
    }
  }

  void _setTime(TimeOfDay time) {
    onTimeChanged(time);
  }

  bool _timeOfDayBefore(TimeOfDay time, TimeOfDay now) {
    return time.hour > now.hour || (time.hour == now.hour && time.minute > now.minute);
  }
}


class ReminderDialog extends StatefulWidget {
  final Function(DateTime remindAt) onReminderSet;
  final DateTime initialDateTime;
  final bool onlyDate;

  ReminderDialog(this.onReminderSet, {this.initialDateTime, this.onlyDate = false});

  @override
  _ReminderDialogState createState() => _ReminderDialogState();
}

class _ReminderDialogState extends State<ReminderDialog> {
  DateTime reminderAt;
  bool today;

  @override
  void initState() {
    super.initState();
    var now = DateTime.now();
    today = widget.initialDateTime != null ? _isTodayDay(widget.initialDateTime, now) : true;
    if (widget.initialDateTime != null && !widget.onlyDate) {
      // Both date and time are given, use them independently of if they are in the past
      reminderAt = widget.initialDateTime;
    } else if (widget.initialDateTime != null && !today) {
      // The date is given and it's not today => use the morning as initial time
      var reminderTime = _timeForSelection(_TimeSelection.morning);
      reminderAt = DateTime(widget.initialDateTime.year, widget.initialDateTime.month, widget.initialDateTime.day, reminderTime.hour, reminderTime.minute);
    } else {
      // The date is not given or it's today
      // If it's late in the evening, shift the date to tomorrow and set the the initial time to the morning
      // If it's not late, shift the time to a few hours from now
      if (now.hour <= 21) {
        reminderAt = DateTime(now.year, now.month, now.day, now.hour + (now.minute >= 30 ? 4 : 3), 0);
      } else {
        var reminderTime = _timeForSelection(_TimeSelection.morning);
        reminderAt = DateTime(now.year, now.month, now.day+1, reminderTime.hour, reminderTime.minute);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("Set reminder"),
      content: Column(
        children: [
          DateTile(_updateDate, selectedDate: reminderAt, allowRemove: false),
          TimeTile(_updateTime, initialTime: reminderAt, today: today),
        ],
        mainAxisSize: MainAxisSize.min,
      ),
      actions: [
        FlatButton(child: Text("Cancel"), onPressed: () => Navigator.pop(context),),
        RaisedButton(child: Text("Set"), onPressed: reminderAt.isBefore(DateTime.now()) ? null : () {
          if (reminderAt != widget.initialDateTime && reminderAt.isAfter(DateTime.now())) {
            widget.onReminderSet(reminderAt);
          }
          Navigator.pop(context);
        })
      ],
    );
  }

  void _updateDate(DateTime date) {
    setState(() {
      reminderAt = DateTime(date.year, date.month, date.day, reminderAt.hour, reminderAt.minute);
      today = _isTodayDay(reminderAt, DateTime.now());
    });
  }

  void _updateTime(TimeOfDay time) {
    setState(() {
      reminderAt = DateTime(reminderAt.year, reminderAt.month, reminderAt.day, time.hour, time.minute);
    });
  }
}

String formatDateTime(DateTime date) {
  return "${formatDate(date)}, ${formatTime(date)}";
}

String formatTime(DateTime date) {
  return _timeFormatter.format(date);
}
String formatTimeOfDay(TimeOfDay time) {
  return formatTime(DateTime(2020,1,1,time.hour,time.minute));
}


String formatDate(DateTime date) {
  var now = DateTime.now();
  if (_isTodayDay(date, now)) {
    return "Today";
  } else if (_isTomorrow(date, now)) {
    return "Tomorrow";
  } else if (_isYesterday(date, now)) {
    return "Yesterday";
  } else {
    return formatFullDate(date);
  }
}

String formatFullDate(DateTime date, {DateTime now}) {
  var year = now?.year ?? DateTime.now().year;
  if (date.year == year) {
    return _dateFormatter.format(date);
  } else {
    return _dateFormatterYear.format(date);
  }
}

final _timeFormatter = DateFormat.jm();
// ABBR_WEEKDAY, DAY ABBR_MONTH
final _dateFormatter = DateFormat.E().addPattern(",","").add_d().add_MMM();
// ABBR_WEEKDAY, DAY ABBR_MONTH YEAR
final _dateFormatterYear = DateFormat.E().addPattern(",","").add_d().add_MMM().add_y();

bool _isTodayDay(DateTime date, DateTime now) {
  return _isSameDay(date, now);
}

bool _isYesterday(DateTime date, DateTime now) {
  var yesterday = DateTime(now.year, now.month, now.day-1);
  return _isSameDay(date, yesterday);
}

bool _isTomorrow(DateTime date, DateTime now) {
  var tomorrow = DateTime(now.year, now.month, now.day+1);
  return _isSameDay(date, tomorrow);
}

bool _isSameDay(DateTime date1, DateTime date2) {
  return date1.year==date2.year && date1.month == date2.month && date1.day == date2.day;
}