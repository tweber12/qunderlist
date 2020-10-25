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

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:qunderlist/widgets/change_text_dialog.dart';

class SliverHeader extends StatefulWidget {
  final String title;
  final String dialogTitle;
  final Function(String newTitle) onTitleChange;
  final List<Widget> actions;
  final double minHeight;
  final double collapsedPaddingLeft;
  final double collapsedPaddingRight;
  final double expandedPaddingLeft;
  final double expandedPaddingRight;


  SliverHeader(this.title, {
    this.onTitleChange,
    this.dialogTitle = "Enter new title",
    this.actions,
    this.minHeight=140,
    this.collapsedPaddingLeft=72,
    this.collapsedPaddingRight=90,
    this.expandedPaddingLeft=15,
    this.expandedPaddingRight=15
  });

  @override
  _SliverHeaderState createState() => _SliverHeaderState();
}

class _SliverHeaderState extends State<SliverHeader> {
  String title;
  int numberOfLines;
  double expandedHeight;

  @override
  void initState() {
    super.initState();
    title = widget.title;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _computeSize();
  }

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      actions: widget.actions,
      expandedHeight: expandedHeight,
      flexibleSpace: FlexibleSpaceBar(
        title: _HeaderText(
          title,
          numberOfLines,
          widget.onTitleChange != null ? _updateTitle : null,
          collapsedPaddingLeft: widget.collapsedPaddingLeft,
          collapsedPaddingRight: widget.collapsedPaddingRight,
          expandedPaddingLeft: widget.expandedPaddingLeft,
          expandedPaddingRight: widget.expandedPaddingRight,
        ),
        titlePadding: EdgeInsetsDirectional.only(start: widget.expandedPaddingLeft, bottom: widget.expandedPaddingRight, end: 15),
      ),
      pinned: true,
    );
  }

  void _updateTitle(BuildContext context) async {
    var newTitle = await showDialog(
      context: context,
      child: ChangeTextDialog(title: widget.dialogTitle, initial: title),
    );
    if (newTitle == null) {
      return;
    }
    widget.onTitleChange(newTitle);
    setState(() {
      title = newTitle;
      _computeSize();
    });
  }

  void _computeSize() {
    final width = MediaQuery.of(context).size.width;
    var textPainter = (TextPainter(
        text: TextSpan(text: title, style: Theme.of(context).primaryTextTheme.headline6),
        textScaleFactor: MediaQuery.of(context).textScaleFactor*1.5,
        textDirection: TextDirection.ltr)
      ..layout(maxWidth: width-widget.expandedPaddingLeft-widget.expandedPaddingRight));
    var fullTextHeight = textPainter.size.height;
    textPainter.maxLines = 1;
    textPainter.layout();
    var singleLineHeight = textPainter.size.height;
    expandedHeight = max(widget.minHeight, fullTextHeight+60);
    numberOfLines = (fullTextHeight / singleLineHeight).ceil();
  }
}

class _HeaderText extends StatelessWidget {
  final String title;
  final double collapsedPaddingLeft;
  final double collapsedPaddingRight;
  final double expandedPaddingLeft;
  final double expandedPaddingRight;
  final int numberOfLines;
  final Function(BuildContext context) updateTitle;

  _HeaderText(
      this.title,
      this.numberOfLines,
      this.updateTitle,
      {
        this.collapsedPaddingLeft=72,
        this.collapsedPaddingRight=90,
        this.expandedPaddingLeft=15,
        this.expandedPaddingRight=15,
      });

  @override
  Widget build(BuildContext context) {
    // Move between the collapsed and expanded states of the header widget
    // This means to add enough padding on the sides to not overlap any title bar items
    // and to reduce the number of lines available down to one in the collapsed state
    final settings = context.dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>();
    final deltaExtent = settings.maxExtent - settings.minExtent;
    final t = (1.0 - (settings.currentExtent - settings.minExtent) / deltaExtent).clamp(0.0, 1.0) as double;
    final scaleValue = Tween<double>(begin: 1.5, end: 1.0).transform(t);
    // FlexibleSpace scales its child by scaleValue, so to counteract that the following padding values are divided by the respective amount
    final paddingLeft = Tween<double>(begin: expandedPaddingLeft, end: collapsedPaddingLeft-expandedPaddingLeft).transform(t) / scaleValue;
    final paddingRight = Tween<double>(begin: expandedPaddingRight, end: collapsedPaddingRight-expandedPaddingRight).transform(t) / scaleValue;
    final maxLines = Tween<double>(begin: numberOfLines.truncateToDouble(), end: 1).transform(t).round();
    return Container(
      width: double.infinity,
      child: InkWell(
        child: Text(title, maxLines: maxLines, overflow: TextOverflow.ellipsis,),
        onTap: () => updateTitle(context),
      ),
      padding: EdgeInsetsDirectional.only(start: paddingLeft, end: paddingRight),
    );
  }
}