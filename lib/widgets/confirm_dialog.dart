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