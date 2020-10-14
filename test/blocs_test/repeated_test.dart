import 'package:bloc_test/bloc_test.dart';
import 'package:qunderlist/blocs/repeated.dart';
import 'package:qunderlist/repository/models.dart';

void main() {
  DateTime due = DateTime(2020, 5, 19);
  Repeated initial = Repeated(true, false, false, true, RepeatedStepDaily(1));
  bool initialAllowAutoComplete = false;

  blocTest(
    "toggle active true",
    build: () => RepeatedBloc(initial: initial),
    act: (bloc) => bloc.add(RepeatedToggleActiveEvent(true)),
    expect: [RepeatedState(initial.copyWith(active: true), initialAllowAutoComplete, true)]
  );

  blocTest(
      "toggle active false",
      build: () => RepeatedBloc(initial: initial),
      act: (bloc) => bloc.add(RepeatedToggleActiveEvent(false)),
      expect: [RepeatedState(initial.copyWith(active: false), initialAllowAutoComplete, true)]
  );

  blocTest(
      "toggle auto advance true",
      build: () => RepeatedBloc(initial: initial),
      act: (bloc) => bloc.add(RepeatedToggleAutoAdvanceEvent(true)),
      expect: [RepeatedState(initial.copyWith(autoAdvance: true), true, true)]
  );

  blocTest(
      "toggle auto advance false",
      build: () => RepeatedBloc(initial: initial),
      act: (bloc) => bloc.add(RepeatedToggleAutoAdvanceEvent(false)),
      expect: [RepeatedState(initial.copyWith(autoAdvance: false), false, true)]
  );

  blocTest(
      "toggle auto complete true",
      build: () => RepeatedBloc(initial: initial),
      act: (bloc) {bloc.add(RepeatedToggleAutoAdvanceEvent(true)); bloc.add(RepeatedToggleAutoCompleteEvent(true));},
      expect: [RepeatedState(initial.copyWith(autoAdvance: true), true, true), RepeatedState(initial.copyWith(autoAdvance: true, autoComplete: true), true, true)]
  );

  blocTest(
      "toggle auto complete false",
      build: () => RepeatedBloc(initial: initial.copyWith(autoComplete: true)),
      act: (bloc) {bloc.add(RepeatedToggleAutoAdvanceEvent(true)); bloc.add(RepeatedToggleAutoCompleteEvent(false));},
      expect: [RepeatedState(initial.copyWith(autoAdvance: true, autoComplete: true), true, true), RepeatedState(initial.copyWith(autoAdvance: true, autoComplete: false), true, true)]
  );

  blocTest(
      "toggle keep history true",
      build: () => RepeatedBloc(initial: initial),
      act: (bloc) => bloc.add(RepeatedToggleKeepHistoryEvent(true)),
      expect: [RepeatedState(initial.copyWith(keepHistory: true), initialAllowAutoComplete, true)]
  );

  blocTest(
      "toggle keep history false",
      build: () => RepeatedBloc(initial: initial),
      act: (bloc) => bloc.add(RepeatedToggleKeepHistoryEvent(false)),
      expect: [RepeatedState(initial.copyWith(keepHistory: false), initialAllowAutoComplete, true)]
  );

  blocTest(
      "set amount",
      build: () => RepeatedBloc(initial: initial),
      act: (bloc) => bloc.add(RepeatedSetAmountEvent(8)),
      expect: [RepeatedState(initial.copyWith(step: initial.step.withAmount(8)), initialAllowAutoComplete, true)]
  );

  blocTest(
      "set amount null",
      build: () => RepeatedBloc(initial: initial),
      act: (bloc) => bloc.add(RepeatedSetAmountEvent(null)),
      expect: [RepeatedState(initial.copyWith(step: initial.step.withAmount(null)), initialAllowAutoComplete, false)]
  );

  blocTest(
      "set amount null 7",
      build: () => RepeatedBloc(initial: initial),
      act: (bloc) {bloc.add(RepeatedSetAmountEvent(null)); bloc.add(RepeatedSetAmountEvent(7));},
      expect: [
        RepeatedState(initial.copyWith(step: initial.step.withAmount(null)), initialAllowAutoComplete, false),
        RepeatedState(initial.copyWith(step: initial.step.withAmount(7)), initialAllowAutoComplete, true)
      ]
  );

  blocTest(
      "set step size daily",
      build: () => RepeatedBloc(dueDate: due, initial: initial.copyWith(step: RepeatedStepWeekly(1))),
      act: (bloc) => bloc.add(RepeatedSetStepSizeEvent(RepeatedStepSize.daily)),
      expect: [RepeatedState(initial.copyWith(step: RepeatedStepDaily(1)), initialAllowAutoComplete, true)]
  );

  blocTest(
      "set step size weekly",
      build: () => RepeatedBloc(dueDate: due, initial: initial),
      act: (bloc) => bloc.add(RepeatedSetStepSizeEvent(RepeatedStepSize.weekly)),
      expect: [RepeatedState(initial.copyWith(step: RepeatedStepWeekly(initial.step.amount)), initialAllowAutoComplete, true)]
  );

  blocTest(
      "set step size monthly",
      build: () => RepeatedBloc(dueDate: due, initial: initial),
      act: (bloc) => bloc.add(RepeatedSetStepSizeEvent(RepeatedStepSize.monthly)),
      expect: [RepeatedState(initial.copyWith(step: RepeatedStepMonthly(initial.step.amount, due.day)), initialAllowAutoComplete, true)]
  );

  blocTest(
      "set step size yearly",
      build: () => RepeatedBloc(dueDate: due, initial: initial),
      act: (bloc) => bloc.add(RepeatedSetStepSizeEvent(RepeatedStepSize.yearly)),
      expect: [RepeatedState(initial.copyWith(step: RepeatedStepYearly(initial.step.amount, due.month, due.day)), initialAllowAutoComplete, true)]
  );

  blocTest(
      "step size sequence",
      build: () => RepeatedBloc(dueDate: due, initial: initial),
      act: (bloc) {
        bloc.add(RepeatedSetStepSizeEvent(RepeatedStepSize.yearly));
        bloc.add(RepeatedSetAmountEvent(3));
        bloc.add(RepeatedSetStepSizeEvent(RepeatedStepSize.weekly));
        bloc.add(RepeatedSetStepSizeEvent(RepeatedStepSize.monthly));
        bloc.add(RepeatedSetAmountEvent(1));
      },
      expect: [
        RepeatedState(initial.copyWith(step: RepeatedStepYearly(initial.step.amount, due.month, due.day)), initialAllowAutoComplete, true),
        RepeatedState(initial.copyWith(step: RepeatedStepYearly(3, due.month, due.day)), initialAllowAutoComplete, true),
        RepeatedState(initial.copyWith(step: RepeatedStepWeekly(3)), initialAllowAutoComplete, true),
        RepeatedState(initial.copyWith(step: RepeatedStepMonthly(3, due.day)), initialAllowAutoComplete, true),
        RepeatedState(initial.copyWith(step: RepeatedStepMonthly(1, due.day)), initialAllowAutoComplete, true)
      ]
  );
}