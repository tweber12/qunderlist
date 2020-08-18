import 'package:flutter/material.dart';
import 'package:qunderlist/blocs/cache.dart';
import 'package:reorderables/reorderables.dart';

class CachedList<T> extends StatelessWidget {
  final ListCache<T> cache;
  final Widget Function(BuildContext context, int index, T item) itemBuilder;
  final double itemHeight;
  final Function(int from, int to) reorderCallback;

  CachedList({@required this.cache, @required this.itemBuilder, @required this.reorderCallback, this.itemHeight=50});

  @override
  Widget build(BuildContext context) {
      return CustomScrollView(
        controller: ScrollController(),
        slivers: <Widget>[
          SliverPadding(
      padding: EdgeInsets.symmetric(vertical: 6),
      sliver:
          ReorderableSliverList(
          delegate: ReorderableSliverChildBuilderDelegate(
              (context, index) {
                print("Building element: $index");
                var elem = cache[index];
                if (elem != null) {
                  return itemBuilder(context, index, elem);
                } else {
                  return FutureBuilder(
                      future: cache.getItem(index),
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          return itemBuilder(context, index, snapshot.data);
                        } else {
                          print("NO DATA: $index, ${cache.getItem(index)}");
                          return SizedBox(child: Center(child: CircularProgressIndicator()), height: itemHeight);
                        }
                      });
                }
              },
            childCount: cache.totalNumberOfItems
          ),
          onReorder: reorderCallback,
        ))],
      );
  }
}

class DismissibleItem extends StatelessWidget {
  final Key key;
  final Widget child;
  final String deleteMessage;

  final String confirmMessage;
  final String deletedMessage;

  final Function() onDismissed;
  final Function() undoAction;

  DismissibleItem({@required this.key, @required this.child, @required this.deleteMessage, this.onDismissed, this.undoAction, this.confirmMessage, this.deletedMessage});

  @override
  Widget build(BuildContext context) {
    return Dismissible(
        key: key,
        child: child,
        background: Container( color: Colors.red, child: ListTile(leading: Icon(Icons.delete_outline, color: Colors.white),title: Text(deleteMessage, style: TextStyle(color: Colors.white),)),),
        confirmDismiss: confirmMessage==null ? null : (_) => showDialog(context: context, child: ConfirmDismissDialog(title: confirmMessage)),
        onDismissed: (_) {
          if (onDismissed != null) {
            onDismissed();
            Scaffold.of(context).showSnackBar(
                SnackBar(
                  content: Text(deletedMessage ?? "Item deleted"),
                  action: undoAction==null ? null : SnackBarAction(label: "undo", onPressed: undoAction),
                )
            );
          }
        },
    );
  }
}

class ConfirmDismissDialog extends StatelessWidget {
  final String title;
  final String subtitle;

  ConfirmDismissDialog({@required this.title, this.subtitle});

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