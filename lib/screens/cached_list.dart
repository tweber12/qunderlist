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
import 'package:qunderlist/blocs/cache.dart';
import 'package:qunderlist/widgets/confirm_dialog.dart';
import 'package:reorderables/reorderables.dart';

class CachedList<T extends Cacheable> extends StatelessWidget {
  final ListCache<T> cache;
  final Widget Function(BuildContext context, int index, T item) itemBuilder;
  final double itemHeight;
  final Function(int from, int to) reorderCallback;

  CachedList({@required this.cache, @required this.itemBuilder, this.reorderCallback, this.itemHeight=50});

  @override
  Widget build(BuildContext context) {
    if (reorderCallback == null) {
      return _buildNonReorderable(context);
    } else {
      return _buildReorderable(context);
    }
  }

  Widget _buildNonReorderable(BuildContext context) {
    return ListView.builder(
        itemBuilder: _wrapItem,
        itemExtent: itemHeight,
        itemCount: cache.totalNumberOfItems,
        padding: EdgeInsets.symmetric(vertical: 6),
    );
  }

  Widget _buildReorderable(BuildContext context) {
    return CustomScrollView(
      controller: ScrollController(),
      slivers: <Widget>[
        SliverPadding(
            padding: EdgeInsets.symmetric(vertical: 6),
            sliver: ReorderableSliverList(
              delegate: ReorderableSliverChildBuilderDelegate(
                  _wrapItem,
                  childCount: cache.totalNumberOfItems
              ),
              onReorder: reorderCallback,
            )
        )
      ],
    );
  }

  Widget _wrapItem(BuildContext context, int index) {
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
  }
}

class DismissibleItem<T> extends StatelessWidget {
  final Key key;
  final Widget child;
  final String deleteMessage;

  final String confirmMessage;
  final String deletedMessage;

  final T Function() onDismissed;
  final Function(T) undoAction;

  DismissibleItem({@required this.key, @required this.child, @required this.deleteMessage, this.onDismissed, this.undoAction, this.confirmMessage, this.deletedMessage});

  @override
  Widget build(BuildContext context) {
    return Dismissible(
        key: key,
        child: child,
        background: Container( color: Colors.red, child: ListTile(leading: Icon(Icons.delete_outline, color: Colors.white),title: Text(deleteMessage, style: TextStyle(color: Colors.white),)),),
        confirmDismiss: confirmMessage==null ? null : (_) => showDialog(context: context, child: ConfirmDeleteDialog(title: confirmMessage)),
        onDismissed: (_) {
          if (onDismissed != null) {
            var item = onDismissed();
            Scaffold.of(context).showSnackBar(
                SnackBar(
                  content: Text(deletedMessage ?? "Item deleted"),
                  action: undoAction==null ? null : SnackBarAction(label: "undo", onPressed: () => undoAction(item)),
                )
            );
          }
        },
    );
  }
}