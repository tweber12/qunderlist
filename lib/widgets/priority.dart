import 'package:flutter/material.dart';
import 'package:qunderlist/repository/repository.dart';

class PriorityButton extends StatelessWidget {
  final TodoPriority priority;
  final Function(TodoPriority newPriority) callback;
  PriorityButton(this.priority, this.callback);

  static const ICON_SIZE = 24.0;
  static const ICON_PADDING = 9.0;

  @override
  Widget build(BuildContext context) {
    return Ink(
      child: InkResponse(
        child: Padding(
          child: priority == TodoPriority.none ?
          Icon(Icons.bookmark_border, color: Colors.black54, size: ICON_SIZE) :
          Icon(Icons.bookmark, color: Colors.white, size: ICON_SIZE),
          padding: EdgeInsets.all(ICON_PADDING),
        ),
        onTap: () => callback(priority==TodoPriority.none ? TodoPriority.high : TodoPriority.none),
        onLongPress: () => _priorityDropdown(context, _dropdownMenuItem, callback),
        containedInkWell: true,
        customBorder: CircleBorder(),
      ),
      decoration: ShapeDecoration(
        color: _bgColorForPriority(priority),
        shape: CircleBorder(),
      ),
    );
  }
}

class PriorityTile extends StatelessWidget {
  final TodoPriority priority;
  final Function(TodoPriority priority) onPriorityChanged;

  PriorityTile(this.priority, this.onPriorityChanged);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(priority == TodoPriority.none ? Icons.bookmark_border : Icons.bookmark, color: _bgColorForPriority(priority)),
      title: Text("${_nameForPriority(priority)} priority"),
      onTap: () => onPriorityChanged(priority == TodoPriority.none ? TodoPriority.high : TodoPriority.none),
      onLongPress: () => _priorityDropdown(context, _tileDropdownItem, onPriorityChanged),
    );
  }
}

Color _bgColorForPriority(TodoPriority priority) {
  switch (priority) {
    case TodoPriority.high:
      return Colors.red;
    case TodoPriority.medium:
      return Colors.blue;
    case TodoPriority.low:
      return Colors.green;
    case TodoPriority.none:
      return null;
    default:
      throw "BUG: Unhandled priority when assigning colors!";
  }
}

Future<void> _priorityDropdown(BuildContext context, PopupMenuItem<TodoPriority> Function(TodoPriority) itemBuilder, Function(TodoPriority) callback) async {
  // Inspired by the PopupMenuButton code
  final RenderBox button = context.findRenderObject() as RenderBox;
  final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
  final RelativeRect position = RelativeRect.fromRect(
    Rect.fromPoints(
      button.localToGlobal(Offset.zero, ancestor: overlay),
      button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay),
    ),
    Offset.zero & overlay.size,
  );
  var priority = await showMenu<TodoPriority>(
      context: context,
      position: position,
      items: TodoPriority.values.map(itemBuilder).toList()
  );
  callback(priority);
}

PopupMenuItem<TodoPriority> _dropdownMenuItem(TodoPriority priority) {
  return PopupMenuItem(
    value: priority,
    child: Container(
      child: Center(
        child: Text(_priorityDropdownText(priority)),
      ),
      decoration: ShapeDecoration(
        color: _bgColorForPriority(priority),
        shape: StadiumBorder(),
      ),
      height: 35,
      width: 80,
    ),
    height: 40,
  );
}
String _priorityDropdownText(TodoPriority priority) {
  switch (priority) {
    case TodoPriority.none: return "None";
    case TodoPriority.low: return "Low";
    case TodoPriority.medium: return "Medium";
    case TodoPriority.high: return "High";
    default: throw "BUG: Unsupported priority in priority button";
  }
}

PopupMenuItem<TodoPriority> _tileDropdownItem(TodoPriority priority) {
  return PopupMenuItem(
    value: priority,
    child: ListTile(
      leading: Icon(priority == TodoPriority.none ? Icons.bookmark_border : Icons.bookmark, color: _bgColorForPriority(priority)),
      title: Text("${_nameForPriority(priority)} priority"),
    )
  );
}
String _nameForPriority(TodoPriority priority) {
  switch (priority) {
    case TodoPriority.high: return "high";
    case TodoPriority.medium: return "medium";
    case TodoPriority.low: return "low";
    case TodoPriority.none: return "no";
    default: throw "BUG: Unhandled priority when assigning names!";
  }
}