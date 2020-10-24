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

import 'package:equatable/equatable.dart';
import 'package:qunderlist/repository/models.dart';

abstract class RepeatedEvent with EquatableMixin {}

class RepeatedToggleActiveEvent extends RepeatedEvent {
  final bool active;
  RepeatedToggleActiveEvent(this.active);

  @override
  List<Object> get props => [active];
}

class RepeatedToggleAutoAdvanceEvent extends RepeatedEvent {
  final bool autoAdvance;
  RepeatedToggleAutoAdvanceEvent(this.autoAdvance);

  @override
  List<Object> get props => [autoAdvance];
}

class RepeatedToggleAutoCompleteEvent extends RepeatedEvent {
  final bool autoComplete;
  RepeatedToggleAutoCompleteEvent(this.autoComplete);

  @override
  List<Object> get props => [autoComplete];
}

class RepeatedToggleKeepHistoryEvent extends RepeatedEvent {
  final bool keepHistory;
  RepeatedToggleKeepHistoryEvent(this.keepHistory);

  @override
  List<Object> get props => [keepHistory];
}

class RepeatedSetStepSizeEvent extends RepeatedEvent {
  final RepeatedStepSize stepSize;
  RepeatedSetStepSizeEvent(this.stepSize);

  @override
  List<Object> get props => [stepSize];
}

class RepeatedSetAmountEvent extends RepeatedEvent {
  final int amount;
  RepeatedSetAmountEvent(this.amount);

  @override
  List<Object> get props => [amount];
}
