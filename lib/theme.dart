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
import 'package:qunderlist/repository/models.dart';

MaterialColor colorFromPalette(Palette palette) {
  switch(palette) {
    case Palette.pink: return Colors.pink;
    case Palette.red: return Colors.red;
    case Palette.deepOrange: return Colors.deepOrange;
    case Palette.orange: return Colors.orange;
    case Palette.amber: return Colors.amber;
    case Palette.yellow: return Colors.yellow;
    case Palette.lime: return Colors.lime;
    case Palette.lightGreen: return Colors.lightGreen;
    case Palette.green: return Colors.green;
    case Palette.teal: return Colors.teal;
    case Palette.cyan: return Colors.cyan;
    case Palette.lightBlue: return Colors.lightBlue;
    case Palette.blue: return Colors.blue;
    case Palette.indigo: return Colors.indigo;
    case Palette.purple: return Colors.purple;
    case Palette.deepPurple: return Colors.deepPurple;
    case Palette.blueGrey: return Colors.blueGrey;
    case Palette.brown: return Colors.brown;
    case Palette.grey: return Colors.grey;
    default: throw "BUG: Unhandled Palette in colorFromPalette: $palette";
  }
}

ThemeData themeFromPalette(Palette palette) {
  return ThemeData(primarySwatch: colorFromPalette(palette));
}

class ThemePicker extends StatefulWidget {
  final Function(Palette) themeSelected;
  final Palette defaultPalette;
  ThemePicker(this.themeSelected, {this.defaultPalette = Palette.blue});

  @override
  _ThemePickerState createState() => _ThemePickerState();
}

class _ThemePickerState extends State<ThemePicker> {
  Palette selected;

  @override
  void initState() {
    super.initState();
    selected = widget.defaultPalette;
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
        children: Palette.values.map((p) => _themePickerItem(p)).toList(),
      spacing: 4,
      runSpacing: 4,
    );
  }

  Widget _themePickerItem(Palette p) {
    return Ink(
      child: InkResponse(
        child: Container(
          child: p==selected ? Icon(Icons.check) : null,
          width: 40,
          height: 40,
        ),
        onTap: () => _selectTheme(p),
        containedInkWell: true,
      ),
      decoration: ShapeDecoration(
        color: colorFromPalette(p),
        shape: CircleBorder(),
      ),
    );
  }

  void _selectTheme(Palette palette) {
    setState(() {
      selected = palette;
      widget.themeSelected(palette);
    });
  }
}

