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

class ChangeTextDialog extends StatefulWidget {
  final String title;
  final String initial;
  final bool multiline;
  ChangeTextDialog({this.title, this.initial = "", this.multiline = false});

  @override
  _ChangeTextDialogState createState() => _ChangeTextDialogState();
}

class _ChangeTextDialogState extends State<ChangeTextDialog> {
  TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.initial);
    controller.addListener(() {
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    var text = controller.text.trim();
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        keyboardType: widget.multiline ? TextInputType.multiline : TextInputType.text,
        maxLines: widget.multiline ? null : 1,
      ),
      actions: <Widget>[
        FlatButton(
          child: Text("Cancel"),
          onPressed: () => Navigator.pop(context, null),
        ),
        RaisedButton(
          child: Text("Update"),
          onPressed:
          text.isNotEmpty ? () => Navigator.pop(context, text) : null,
        )
      ],
    );
  }
}
