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
import 'package:qunderlist/blocs/repeated.dart';
import 'package:qunderlist/repository/models.dart';

class RepeatedTile extends StatelessWidget {
  final Repeated repeated;
  final DateTime dueDate;
  final Function(Repeated) onRepeatedChanged;
  final bool active;

  RepeatedTile({@required this.onRepeatedChanged, this.repeated, this.dueDate}):
      active = repeated?.active ?? false;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(Icons.repeat),
      title: Text(_repeatedTitle()),
      trailing: active ? _removeButton() : null,
      onTap: () async {
        var result = await showRepeatedDialog(context, initial: repeated, dueDate: dueDate);
        if (result != null) {
          onRepeatedChanged(result);
        }
      },
    );
  }

  Widget _removeButton() {
    return IconButton(icon: Icon(Icons.cancel), onPressed: () => onRepeatedChanged(null));
  }

  String _repeatedTitle() {
    if (repeated == null) {
      return "not repeated";
    }
    var amount = repeated.step.amount;
    if (amount == 1) {
      return "every ${_repeatedStepOne()}";
    } else {
      return "every ${repeated.step.amount} ${_repeatedStep()}";
    }
  }

  String _repeatedStepOne() {
    switch (repeated.step.stepSize) {
      case RepeatedStepSize.daily: return "day";
      case RepeatedStepSize.weekly: return "week";
      case RepeatedStepSize.monthly: return "month";
      case RepeatedStepSize.yearly: return "year";
    }
    throw "BUG: Unexpected step size: ${repeated.step.stepSize}";
  }

  String _repeatedStep() {
    switch (repeated.step.stepSize) {
      case RepeatedStepSize.daily: return "days";
      case RepeatedStepSize.weekly: return "weeks";
      case RepeatedStepSize.monthly: return "months";
      case RepeatedStepSize.yearly: return "years";
    }
    throw "BUG: Unexpected step size: ${repeated.step.stepSize}";
  }
}


Future<Repeated> showRepeatedDialog(BuildContext context, {DateTime dueDate, Repeated initial}) {
  return showDialog(
      context: context,
      builder: (context) => BlocProvider(
          create: (context) => RepeatedBloc(dueDate: dueDate, initial: initial),
          child: RepeatedDialog(),
      )
  );
}

class RepeatedDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RepeatedBloc, RepeatedState>(
      builder: (context, state) {
        return AlertDialog(
          title: Text("Repeat every"),
          content: ListView(
            children: [
              Padding(
                child: QuantityTile(
                  state.repeated.step.amount,
                  state.repeated.step.stepSize,
                  (amount) => BlocProvider.of<RepeatedBloc>(context).add(RepeatedSetAmountEvent(amount)),
                  [
                    DropdownMenuItem(child: Text("days"), value: RepeatedStepSize.daily,),
                    DropdownMenuItem(child: Text("weeks"), value: RepeatedStepSize.weekly,),
                    DropdownMenuItem(child: Text("months"), value: RepeatedStepSize.monthly,),
                    DropdownMenuItem(child: Text("years"), value: RepeatedStepSize.yearly,),
                  ],
                  (size) => BlocProvider.of<RepeatedBloc>(context).add(RepeatedSetStepSizeEvent(size))
                ),
                padding: EdgeInsets.only(left: 16),
              ),
              CheckboxListTile(
                  title: Text("Auto advance"),
                  value: state.repeated.autoAdvance,
                  onChanged: (value) => BlocProvider.of<RepeatedBloc>(context).add(RepeatedToggleAutoAdvanceEvent(value))
              ),
              CheckboxListTile(
                  title: Text("Auto complete"),
                  value: state.allowAutoComplete && state.repeated.autoComplete,
                  onChanged: state.allowAutoComplete ? (value) => BlocProvider.of<RepeatedBloc>(context).add(RepeatedToggleAutoCompleteEvent(value)) : null,
              ),
              CheckboxListTile(
                  title: Text("Keep history"),
                  value: state.repeated.keepHistory,
                  onChanged: (value) => BlocProvider.of<RepeatedBloc>(context).add(RepeatedToggleKeepHistoryEvent(value))
              ),
            ],
            shrinkWrap: true,
          ),
          actions: [
            FlatButton(onPressed: () => Navigator.pop(context), child: Text("Cancel")),
            RaisedButton(onPressed: state.valid ? () => Navigator.pop(context, state.repeated) : null, child: Text("Set"))
          ],
        );
      },
    );
  }
}

class QuantityTile<T> extends StatefulWidget {
  final int amount;
  final T unit;
  final Function(int) onAmountChanged;
  final List<DropdownMenuItem<T>> units;
  final Function(T) onUnitChanged;
  QuantityTile(this.amount, this.unit, this.onAmountChanged, this.units, this.onUnitChanged);

  @override
  _QuantityTileState createState() => _QuantityTileState();
}

class _QuantityTileState extends State<QuantityTile> {
  TextEditingController amountController;

  @override
  void initState() {
    super.initState();
    amountController = TextEditingController(text: widget.amount.toString());
    amountController.addListener(() { widget.onAmountChanged(int.tryParse(amountController.text)); });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 45, child: TextField(controller: amountController, keyboardType: TextInputType.number, textAlign: TextAlign.center,)),
        SizedBox(width: 20,),
        DropdownButton(items: widget.units, value: widget.unit, onChanged: widget.onUnitChanged),
      ]
    );
  }
}

