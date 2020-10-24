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

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qunderlist/blocs/repeated.dart';
import 'package:qunderlist/repository/models.dart';

void main() {
  DateTime due = DateTime(2020, 5, 19);
  Repeated initial = Repeated(true, false, false, true, RepeatedStepDaily(1));
  bool initialAllowAutoComplete = false;

  group("bloc", () {
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
  });

  group("next item", () {
    var year = 2020;
    var month = 7;
    var baseItem = TodoItem("item", DateTime.now().subtract(Duration(days: 5)), id: 72, note: "this is a note", priority: TodoPriority.medium);

    test("step daily 1", () {
      var item = baseItem.copyWith(
          dueDate: Nullable(DateTime(year, month, 3)),
          reminders: [
            Reminder(DateTime(year,month,1, 10,30)),
            Reminder(DateTime(year,month,3, 9,15)),
            Reminder(DateTime(year,month,5, 22,8)),
          ],
          repeated: Nullable(Repeated(true, true, false, false, RepeatedStepDaily(1))),
      );
      var reminders = [
        Reminder(DateTime(year,month,2, 10,30)),
        Reminder(DateTime(year,month,4, 9,15)),
        Reminder(DateTime(year,month,6, 22,8)),
      ];
      var next = nextItem(item);
      expect(next, MatchesNext(item, DateTime(year, month, 4), reminders));
    });

    test("step daily 5", () {
      var item = baseItem.copyWith(
        dueDate: Nullable(DateTime(year, month, 3)),
        reminders: [
          Reminder(DateTime(year,month,1, 10,30)),
          Reminder(DateTime(year,month,3, 9,15)),
          Reminder(DateTime(year,month,5, 22,8)),
        ],
        repeated: Nullable(Repeated(true, true, false, false, RepeatedStepDaily(5))),
      );
      var reminders = [
        Reminder(DateTime(year,month,6, 10,30)),
        Reminder(DateTime(year,month,8, 9,15)),
        Reminder(DateTime(year,month,10, 22,8)),
      ];
      var next = nextItem(item);
      expect(next, MatchesNext(item, DateTime(year, month, 8), reminders));
    });

    test("step weekly 1", () {
      var item = baseItem.copyWith(
        dueDate: Nullable(DateTime(year, month, 3)),
        reminders: [
          Reminder(DateTime(year,month,1, 10,30)),
          Reminder(DateTime(year,month,3, 9,15)),
          Reminder(DateTime(year,month,5, 22,8)),
        ],
        repeated: Nullable(Repeated(true, true, false, false, RepeatedStepWeekly(1))),
      );
      var reminders = [
        Reminder(DateTime(year,month,8, 10,30)),
        Reminder(DateTime(year,month,10, 9,15)),
        Reminder(DateTime(year,month,12, 22,8)),
      ];
      var next = nextItem(item);
      expect(next, MatchesNext(item, DateTime(year, month, 10), reminders));
    });

    test("step weekly 3", () {
      var item = baseItem.copyWith(
        dueDate: Nullable(DateTime(year, month, 3)),
        reminders: [
          Reminder(DateTime(year,month,1, 10,30)),
          Reminder(DateTime(year,month,3, 9,15)),
          Reminder(DateTime(year,month,5, 22,8)),
        ],
        repeated: Nullable(Repeated(true, true, false, false, RepeatedStepWeekly(3))),
      );
      var reminders = [
        Reminder(DateTime(year,month,22, 10,30)),
        Reminder(DateTime(year,month,24, 9,15)),
        Reminder(DateTime(year,month,26, 22,8)),
      ];
      var next = nextItem(item);
      expect(next, MatchesNext(item, DateTime(year, month, 24), reminders));
    });

    test("step monthly 1", () {
      var item = baseItem.copyWith(
        dueDate: Nullable(DateTime(year, 9, 3)),
        reminders: [
          Reminder(DateTime(year,9,1, 10,30)),
          Reminder(DateTime(year,9,3, 9,15)),
          Reminder(DateTime(year,9,5, 22,8)),
        ],
        repeated: Nullable(Repeated(true, true, false, false, RepeatedStepMonthly(1,3))),
      );
      var reminders = [
        Reminder(DateTime(year,10,1, 10,30)),
        Reminder(DateTime(year,10,3, 9,15)),
        Reminder(DateTime(year,10,5, 22,8)),
      ];
      var next = nextItem(item);
      expect(next, MatchesNext(item, DateTime(year, 10, 3), reminders));
    });

    test("step monthly 3", () {
      var item = baseItem.copyWith(
        dueDate: Nullable(DateTime(year, 7, 3)),
        reminders: [
          Reminder(DateTime(year,7,1, 10,30)),
          Reminder(DateTime(year,7,3, 9,15)),
          Reminder(DateTime(year,7,5, 22,8)),
        ],
        repeated: Nullable(Repeated(true, true, false, false, RepeatedStepMonthly(3,3))),
      );
      var reminders = [
        Reminder(DateTime(year,10,1, 10,30)),
        Reminder(DateTime(year,10,3, 9,15)),
        Reminder(DateTime(year,10,5, 22,8)),
      ];
      var next = nextItem(item);
      expect(next, MatchesNext(item, DateTime(year, 10, 3), reminders));
    });

    test("step yearly 1", () {
      var item = baseItem.copyWith(
        dueDate: Nullable(DateTime(2020, month, 3)),
        reminders: [
          Reminder(DateTime(2020,month,1, 10,30)),
          Reminder(DateTime(2020,month,3, 9,15)),
          Reminder(DateTime(2020,month,5, 22,8)),
        ],
        repeated: Nullable(Repeated(true, true, false, false, RepeatedStepYearly(1,month,3))),
      );
      var reminders = [
        Reminder(DateTime(2021,month,1, 10,30)),
        Reminder(DateTime(2021,month,3, 9,15)),
        Reminder(DateTime(2021,month,5, 22,8)),
      ];
      var next = nextItem(item);
      expect(next, MatchesNext(item, DateTime(2021, month, 3), reminders));
    });

    test("step yearly 5", () {
      var item = baseItem.copyWith(
        dueDate: Nullable(DateTime(2020, month, 3)),
        reminders: [
          Reminder(DateTime(2020,month,1, 10,30)),
          Reminder(DateTime(2020,month,3, 9,15)),
          Reminder(DateTime(2020,month,5, 22,8)),
        ],
        repeated: Nullable(Repeated(true, true, false, false, RepeatedStepYearly(5,month,3))),
      );
      var reminders = [
        Reminder(DateTime(2025,month,1, 10,30)),
        Reminder(DateTime(2025,month,3, 9,15)),
        Reminder(DateTime(2025,month,5, 22,8)),
      ];
      var next = nextItem(item);
      expect(next, MatchesNext(item, DateTime(2025, month, 3), reminders));
    });

    test("step daily overflow next month", () {
      var item = baseItem.copyWith(
        dueDate: Nullable(DateTime(year, 8, 3)),
        reminders: [
          Reminder(DateTime(year,8,1, 10,30)),
          Reminder(DateTime(year,8,3, 9,15)),
          Reminder(DateTime(year,8,5, 22,8)),
        ],
        repeated: Nullable(Repeated(true, true, false, false, RepeatedStepDaily(30))),
      );
      var reminders = [
        Reminder(DateTime(year,8,31, 10,30)),
        Reminder(DateTime(year,9,2, 9,15)),
        Reminder(DateTime(year,9,4, 22,8)),
      ];
      var next = nextItem(item);
      expect(next, MatchesNext(item, DateTime(year, 9, 2), reminders));
    });

    test("step daily overflow next year", () {
      var item = baseItem.copyWith(
        dueDate: Nullable(DateTime(2019, 12, 3)),
        reminders: [
          Reminder(DateTime(2019,12,1, 10,30)),
          Reminder(DateTime(2019,12,3, 9,15)),
          Reminder(DateTime(2019,12,5, 22,8)),
        ],
        repeated: Nullable(Repeated(true, true, false, false, RepeatedStepDaily(30))),
      );
      var reminders = [
        Reminder(DateTime(2019,12,31, 10,30)),
        Reminder(DateTime(2020,1,2, 9,15)),
        Reminder(DateTime(2020,1,4, 22,8)),
      ];
      var next = nextItem(item);
      expect(next, MatchesNext(item, DateTime(2020, 1, 2), reminders));
    });

    test("step weekly overflow next month", () {
      var item = baseItem.copyWith(
        dueDate: Nullable(DateTime(year, 8, 3)),
        reminders: [
          Reminder(DateTime(year,8,1, 10,30)),
          Reminder(DateTime(year,8,3, 9,15)),
          Reminder(DateTime(year,8,5, 22,8)),
        ],
        repeated: Nullable(Repeated(true, true, false, false, RepeatedStepWeekly(5))),
      );
      var reminders = [
        Reminder(DateTime(year,9,5, 10,30)),
        Reminder(DateTime(year,9,7, 9,15)),
        Reminder(DateTime(year,9,9, 22,8)),
      ];
      var next = nextItem(item);
      expect(next, MatchesNext(item, DateTime(year, 9, 7), reminders));
    });

    test("step weekly overflow next year", () {
      var item = baseItem.copyWith(
        dueDate: Nullable(DateTime(2019, 12, 3)),
        reminders: [
          Reminder(DateTime(2019,12,1, 10,30)),
          Reminder(DateTime(2019,12,3, 9,15)),
          Reminder(DateTime(2019,12,5, 22,8)),
        ],
        repeated: Nullable(Repeated(true, true, false, false, RepeatedStepWeekly(5))),
      );
      var reminders = [
        Reminder(DateTime(2020,1,5, 10,30)),
        Reminder(DateTime(2020,1,7, 9,15)),
        Reminder(DateTime(2020,1,9, 22,8)),
      ];
      var next = nextItem(item);
      expect(next, MatchesNext(item, DateTime(2020, 1, 7), reminders));
    });

    test("step monthly overflow next year", () {
      var item = baseItem.copyWith(
        dueDate: Nullable(DateTime(2019, 10, 3)),
        reminders: [
          Reminder(DateTime(2019,10,1, 10,30)),
          Reminder(DateTime(2019,10,3, 9,15)),
          Reminder(DateTime(2019,10,5, 22,8)),
        ],
        repeated: Nullable(Repeated(true, true, false, false, RepeatedStepMonthly(5, 3))),
      );
      var reminders = [
        Reminder(DateTime(2020,3,1, 10,30)),
        Reminder(DateTime(2020,3,3, 9,15)),
        Reminder(DateTime(2020,3,5, 22,8)),
      ];
      var next = nextItem(item);
      expect(next, MatchesNext(item, DateTime(2020, 3, 3), reminders));
    });

    test("step monthly overflow", () {
      var item = baseItem.copyWith(
        dueDate: Nullable(DateTime(2020, 1, 31)),
        reminders: [
          Reminder(DateTime(2020,1,25, 10,30)),
          Reminder(DateTime(2020,1,31, 9,15)),
          Reminder(DateTime(2020,2,7, 22,8)),
        ],
        repeated: Nullable(Repeated(true, true, false, false, RepeatedStepMonthly(1, 31))),
      );
      var reminders = [
        Reminder(DateTime(2020,2,23, 10,30)),
        Reminder(DateTime(2020,2,29, 9,15)),
        Reminder(DateTime(2020,3,7, 22,8)),
      ];
      var next = nextItem(item);
      expect(next, MatchesNext(item, DateTime(2020, 2, 29), reminders));

      reminders = [
        Reminder(DateTime(2020,3,25, 10,30)),
        Reminder(DateTime(2020,3,31, 9,15)),
        Reminder(DateTime(2020,4,7, 22,8)),
      ];
      var next2 = nextItem(next);
      expect(next2, MatchesNext(next, DateTime(2020, 3, 31), reminders));

      reminders = [
        Reminder(DateTime(2020,4,24, 10,30)),
        Reminder(DateTime(2020,4,30, 9,15)),
        Reminder(DateTime(2020,5,7, 22,8)),
      ];
      var next3 = nextItem(next2);
      expect(next3, MatchesNext(next2, DateTime(2020, 4, 30), reminders));
    });

    test("step yearly overflow", () {
      var item = baseItem.copyWith(
        dueDate: Nullable(DateTime(2020, 2, 29)),
        reminders: [
          Reminder(DateTime(2020,2,25, 10,30)),
          Reminder(DateTime(2020,2,29, 9,15)),
          Reminder(DateTime(2020,3,5, 22,8)),
        ],
        repeated: Nullable(Repeated(true, true, false, false, RepeatedStepYearly(1,2,29))),
      );
      var reminders = [
        Reminder(DateTime(2021,2,24, 10,30)),
        Reminder(DateTime(2021,2,28, 9,15)),
        Reminder(DateTime(2021,3,5, 22,8)),
      ];
      var next = nextItem(item);
      expect(next, MatchesNext(item, DateTime(2021, 2, 28), reminders));

      reminders = [
        Reminder(DateTime(2022,2,24, 10,30)),
        Reminder(DateTime(2022,2,28, 9,15)),
        Reminder(DateTime(2022,3,5, 22,8)),
      ];
      var next2 = nextItem(next);
      expect(next2, MatchesNext(next, DateTime(2022, 2, 28), reminders));

      reminders = [
        Reminder(DateTime(2023,2,24, 10,30)),
        Reminder(DateTime(2023,2,28, 9,15)),
        Reminder(DateTime(2023,3,5, 22,8)),
      ];
      var next3 = nextItem(next2);
      expect(next3, MatchesNext(next2, DateTime(2023, 2, 28), reminders));

      reminders = [
        Reminder(DateTime(2024,2,25, 10,30)),
        Reminder(DateTime(2024,2,29, 9,15)),
        Reminder(DateTime(2024,3,5, 22,8)),
      ];
      var next4 = nextItem(next3);
      expect(next4, MatchesNext(next3, DateTime(2024, 2, 29), reminders));
    });

    test("step daily dst back", () {
      var item = baseItem.copyWith(
        dueDate: Nullable(DateTime(2020, 10, 20)),
        reminders: [
          Reminder(DateTime(2020,10,16, 10,30)),
          Reminder(DateTime(2020,10,20, 9,15)),
          Reminder(DateTime(2020,10,26, 22,8)),
        ],
        repeated: Nullable(Repeated(true, true, false, false, RepeatedStepDaily(10))),
      );
      var reminders = [
        Reminder(DateTime(2020,10,26, 10,30)),
        Reminder(DateTime(2020,10,30, 9,15)),
        Reminder(DateTime(2020,11,5, 22,8)),
      ];
      var next = nextItem(item);
      expect(next, MatchesNext(item, DateTime(2020, 10, 30), reminders));
    });

    test("dst back r_drd", () {
      var rp = DateTime(2020, 10, 20, 10,30);
      // DST: 2020 10 25
      var dp = DateTime(2020, 10, 28);
      var rn = DateTime(2020, 10, 30, 10,30);
      var dn = DateTime(2020, 11, 7);

      var item = baseItem.copyWith(dueDate: Nullable(dp), reminders: [Reminder(rp)], repeated: Nullable(Repeated(true, true, false, false, RepeatedStepDaily(10))));
      var next = nextItem(item);
      expect(next, MatchesNext(item, dn, [Reminder(rn)]));
    });

    test("dst back rd_rd", () {
      var rp = DateTime(2020, 10, 17, 10,30);
      var dp = DateTime(2020, 10, 18);
      // DST: 2020 10 25
      var rn = DateTime(2020, 10, 27, 10,30);
      var dn = DateTime(2020, 10, 28);

      var item = baseItem.copyWith(dueDate: Nullable(dp), reminders: [Reminder(rp)], repeated: Nullable(Repeated(true, true, false, false, RepeatedStepDaily(10))));
      var next = nextItem(item);
      expect(next, MatchesNext(item, dn, [Reminder(rn)]));
    });

    test("dst back rdr_d", () {
      var rp = DateTime(2020, 10, 10, 10,30);
      var dp = DateTime(2020, 10, 18);
      var rn = DateTime(2020, 10, 20, 10,30);
      // DST: 2020 10 25
      var dn = DateTime(2020, 10, 28);

      var item = baseItem.copyWith(dueDate: Nullable(dp), reminders: [Reminder(rp)], repeated: Nullable(Repeated(true, true, false, false, RepeatedStepDaily(10))));
      var next = nextItem(item);
      expect(next, MatchesNext(item, dn, [Reminder(rn)]));
    });

    test("dst back r_rdd", () {
      var rp = DateTime(2020, 10, 18, 10,30);
      // DST: 2020 10 25
      var rn = DateTime(2020, 10, 28, 10,30);
      var dp = DateTime(2020, 10, 31);
      var dn = DateTime(2020, 11, 10);

      var item = baseItem.copyWith(dueDate: Nullable(dp), reminders: [Reminder(rp)], repeated: Nullable(Repeated(true, true, false, false, RepeatedStepDaily(10))));
      var next = nextItem(item);
      expect(next, MatchesNext(item, dn, [Reminder(rn)]));
    });

    test("dst back rr_dd", () {
      var rp = DateTime(2020, 10, 10, 10,30);
      var rn = DateTime(2020, 10, 20, 10,30);
      // DST: 2020 10 25
      var dp = DateTime(2020, 10, 31);
      var dn = DateTime(2020, 11, 10);

      var item = baseItem.copyWith(dueDate: Nullable(dp), reminders: [Reminder(rp)], repeated: Nullable(Repeated(true, true, false, false, RepeatedStepDaily(10))));
      var next = nextItem(item);
      expect(next, MatchesNext(item, dn, [Reminder(rn)]));
    });

    test("dst back rrd_d", () {
      var rp = DateTime(2020, 10, 10, 10,30);
      var rn = DateTime(2020, 10, 20, 10,30);
      var dp = DateTime(2020, 10, 20);
      // DST: 2020 10 25
      var dn = DateTime(2020, 10, 30);

      var item = baseItem.copyWith(dueDate: Nullable(dp), reminders: [Reminder(rp)], repeated: Nullable(Repeated(true, true, false, false, RepeatedStepDaily(10))));
      var next = nextItem(item);
      expect(next, MatchesNext(item, dn, [Reminder(rn)]));
    });

    test("dst back d_drr", () {
      var dp = DateTime(2020, 10, 20);
      // DST: 2020 10 25
      var dn = DateTime(2020, 10, 30);
      var rp = DateTime(2020, 11, 10, 10,30);
      var rn = DateTime(2020, 11, 20, 10,30);

      var item = baseItem.copyWith(dueDate: Nullable(dp), reminders: [Reminder(rp)], repeated: Nullable(Repeated(true, true, false, false, RepeatedStepDaily(10))));
      var next = nextItem(item);
      expect(next, MatchesNext(item, dn, [Reminder(rn)]));
    });

    test("dst back dd_rr", () {
      var dp = DateTime(2020, 10, 10);
      var dn = DateTime(2020, 10, 20);
      // DST: 2020 10 25
      var rp = DateTime(2020, 11, 10, 10,30);
      var rn = DateTime(2020, 11, 20, 10,30);

      var item = baseItem.copyWith(dueDate: Nullable(dp), reminders: [Reminder(rp)], repeated: Nullable(Repeated(true, true, false, false, RepeatedStepDaily(10))));
      var next = nextItem(item);
      expect(next, MatchesNext(item, dn, [Reminder(rn)]));
    });

    test("dst back ddr_r", () {
      var dp = DateTime(2020, 10, 10);
      var dn = DateTime(2020, 10, 20);
      var rp = DateTime(2020, 10, 23, 10,30);
      // DST: 2020 10 25
      var rn = DateTime(2020, 11, 2, 10,30);

      var item = baseItem.copyWith(dueDate: Nullable(dp), reminders: [Reminder(rp)], repeated: Nullable(Repeated(true, true, false, false, RepeatedStepDaily(10))));
      var next = nextItem(item);
      expect(next, MatchesNext(item, dn, [Reminder(rn)]));
    });

    test("dst back d_rdr", () {
      var dp = DateTime(2020, 10, 20);
      // DST: 2020 10 25
      var rp = DateTime(2020, 10, 28, 10,30);
      var dn = DateTime(2020, 10, 30);
      var rn = DateTime(2020, 11, 7, 10,30);

      var item = baseItem.copyWith(dueDate: Nullable(dp), reminders: [Reminder(rp)], repeated: Nullable(Repeated(true, true, false, false, RepeatedStepDaily(10))));
      var next = nextItem(item);
      expect(next, MatchesNext(item, dn, [Reminder(rn)]));
    });

    test("dst back dr_dr", () {
      var dp = DateTime(2020, 10, 20);
      var rp = DateTime(2020, 10, 23, 10,30);
      // DST: 2020 10 25
      var dn = DateTime(2020, 10, 30);
      var rn = DateTime(2020, 11, 2, 10,30);

      var item = baseItem.copyWith(dueDate: Nullable(dp), reminders: [Reminder(rp)], repeated: Nullable(Repeated(true, true, false, false, RepeatedStepDaily(10))));
      var next = nextItem(item);
      expect(next, MatchesNext(item, dn, [Reminder(rn)]));
    });

    test("dst back drd_r", () {
      var dp = DateTime(2020, 10, 14);
      var rp = DateTime(2020, 10, 23, 10,30);
      var dn = DateTime(2020, 10, 24);
      // DST: 2020 10 25
      var rn = DateTime(2020, 11, 2, 10,30);

      var item = baseItem.copyWith(dueDate: Nullable(dp), reminders: [Reminder(rp)], repeated: Nullable(Repeated(true, true, false, false, RepeatedStepDaily(10))));
      var next = nextItem(item);
      expect(next, MatchesNext(item, dn, [Reminder(rn)]));
    });

    test("step daily dst back midnight", () {
      var item = baseItem.copyWith(
        dueDate: Nullable(DateTime(2020, 10, 25)),
        reminders: [
          Reminder(DateTime(2020,10,24, 0,0)),
          Reminder(DateTime(2020,10,25, 0,0)),
          Reminder(DateTime(2020,10,26, 0,0)),
        ],
        repeated: Nullable(Repeated(true, true, false, false, RepeatedStepDaily(1))),
      );
      var reminders = [
        Reminder(DateTime(2020,10,25, 0,0)),
        Reminder(DateTime(2020,10,26, 0,0)),
        Reminder(DateTime(2020,10,27, 0,0)),
      ];
      var next = nextItem(item);
      expect(next, MatchesNext(item, DateTime(2020, 10, 26), reminders));
    });

    test("step daily dst forward", () {
      var item = baseItem.copyWith(
        dueDate: Nullable(DateTime(2020, 3, 27)),
        reminders: [
          Reminder(DateTime(2020,3,25, 10,30)),
          Reminder(DateTime(2020,3,27, 9,15)),
          Reminder(DateTime(2020,3,29, 22,8)),
        ],
        repeated: Nullable(Repeated(true, true, false, false, RepeatedStepDaily(10))),
      );
      var reminders = [
        Reminder(DateTime(2020,4,4, 10,30)),
        Reminder(DateTime(2020,4,6, 9,15)),
        Reminder(DateTime(2020,4,8, 22,8)),
      ];
      var next = nextItem(item);
      expect(next, MatchesNext(item, DateTime(2020, 4, 6), reminders));
    });

    test("dst forward r_drd", () {
      var rp = DateTime(2020, 3, 24, 10,30);
      // DST: 2020 3 29
      var dp = DateTime(2020, 4, 1);
      var rn = DateTime(2020, 4, 3, 10,30);
      var dn = DateTime(2020, 4, 11);

      var item = baseItem.copyWith(dueDate: Nullable(dp), reminders: [Reminder(rp)], repeated: Nullable(Repeated(true, true, false, false, RepeatedStepDaily(10))));
      var next = nextItem(item);
      expect(next, MatchesNext(item, dn, [Reminder(rn)]));
    });

    test("dst forward rd_rd", () {
      var rp = DateTime(2020, 3, 24, 10,30);
      var dp = DateTime(2020, 3, 27);
      // DST: 2020 3 29
      var rn = DateTime(2020, 4, 3, 10,30);
      var dn = DateTime(2020, 4, 6);

      var item = baseItem.copyWith(dueDate: Nullable(dp), reminders: [Reminder(rp)], repeated: Nullable(Repeated(true, true, false, false, RepeatedStepDaily(10))));
      var next = nextItem(item);
      expect(next, MatchesNext(item, dn, [Reminder(rn)]));
    });

    test("dst forward rdr_d", () {
      var rp = DateTime(2020, 3, 18, 10,30);
      var dp = DateTime(2020, 3, 27);
      var rn = DateTime(2020, 3, 28, 10,30);
      // DST: 2020 3 29
      var dn = DateTime(2020, 4, 6);

      var item = baseItem.copyWith(dueDate: Nullable(dp), reminders: [Reminder(rp)], repeated: Nullable(Repeated(true, true, false, false, RepeatedStepDaily(10))));
      var next = nextItem(item);
      expect(next, MatchesNext(item, dn, [Reminder(rn)]));
    });

    test("dst forward r_rdd", () {
      var rp = DateTime(2020, 3, 22, 10,30);
      // DST: 2020 3 29
      var rn = DateTime(2020, 4, 1, 10,30);
      var dp = DateTime(2020, 4, 5);
      var dn = DateTime(2020, 4, 15);

      var item = baseItem.copyWith(dueDate: Nullable(dp), reminders: [Reminder(rp)], repeated: Nullable(Repeated(true, true, false, false, RepeatedStepDaily(10))));
      var next = nextItem(item);
      expect(next, MatchesNext(item, dn, [Reminder(rn)]));
    });

    test("dst forward rr_dd", () {
      var rp = DateTime(2020, 3, 12, 10,30);
      var rn = DateTime(2020, 3, 22, 10,30);
      // DST: 2020 3 29
      var dp = DateTime(2020, 4, 5);
      var dn = DateTime(2020, 4, 15);

      var item = baseItem.copyWith(dueDate: Nullable(dp), reminders: [Reminder(rp)], repeated: Nullable(Repeated(true, true, false, false, RepeatedStepDaily(10))));
      var next = nextItem(item);
      expect(next, MatchesNext(item, dn, [Reminder(rn)]));
    });

    test("dst forward rrd_d", () {
      var rp = DateTime(2020, 3, 12, 10,30);
      var rn = DateTime(2020, 3, 22, 10,30);
      var dp = DateTime(2020, 3, 26);
      // DST: 2020 3 29
      var dn = DateTime(2020, 4, 5);

      var item = baseItem.copyWith(dueDate: Nullable(dp), reminders: [Reminder(rp)], repeated: Nullable(Repeated(true, true, false, false, RepeatedStepDaily(10))));
      var next = nextItem(item);
      expect(next, MatchesNext(item, dn, [Reminder(rn)]));
    });

    test("dst forward d_rdr", () {
      var dp = DateTime(2020, 3, 24, 10,30);
      // DST: 2020 3 29
      var rp = DateTime(2020, 4, 1);
      var dn = DateTime(2020, 4, 3, 10,30);
      var rn = DateTime(2020, 4, 11);

      var item = baseItem.copyWith(dueDate: Nullable(dp), reminders: [Reminder(rp)], repeated: Nullable(Repeated(true, true, false, false, RepeatedStepDaily(10))));
      var next = nextItem(item);
      expect(next, MatchesNext(item, dn, [Reminder(rn)]));
    });

    test("dst forward dr_dr", () {
      var dp = DateTime(2020, 3, 24, 10,30);
      var rp = DateTime(2020, 3, 27);
      // DST: 2020 3 29
      var dn = DateTime(2020, 4, 3, 10,30);
      var rn = DateTime(2020, 4, 6);

      var item = baseItem.copyWith(dueDate: Nullable(dp), reminders: [Reminder(rp)], repeated: Nullable(Repeated(true, true, false, false, RepeatedStepDaily(10))));
      var next = nextItem(item);
      expect(next, MatchesNext(item, dn, [Reminder(rn)]));
    });

    test("dst forward drd_r", () {
      var dp = DateTime(2020, 3, 18, 10,30);
      var rp = DateTime(2020, 3, 27);
      var dn = DateTime(2020, 3, 28, 10,30);
      // DST: 2020 3 29
      var rn = DateTime(2020, 4, 6);

      var item = baseItem.copyWith(dueDate: Nullable(dp), reminders: [Reminder(rp)], repeated: Nullable(Repeated(true, true, false, false, RepeatedStepDaily(10))));
      var next = nextItem(item);
      expect(next, MatchesNext(item, dn, [Reminder(rn)]));
    });

    test("dst forward d_drr", () {
      var dp = DateTime(2020, 3, 22, 10,30);
      // DST: 2020 3 29
      var dn = DateTime(2020, 4, 1, 10,30);
      var rp = DateTime(2020, 4, 5);
      var rn = DateTime(2020, 4, 15);

      var item = baseItem.copyWith(dueDate: Nullable(dp), reminders: [Reminder(rp)], repeated: Nullable(Repeated(true, true, false, false, RepeatedStepDaily(10))));
      var next = nextItem(item);
      expect(next, MatchesNext(item, dn, [Reminder(rn)]));
    });

    test("dst forward dd_rr", () {
      var dp = DateTime(2020, 3, 12, 10,30);
      var dn = DateTime(2020, 3, 22, 10,30);
      // DST: 2020 3 29
      var rp = DateTime(2020, 4, 5);
      var rn = DateTime(2020, 4, 15);

      var item = baseItem.copyWith(dueDate: Nullable(dp), reminders: [Reminder(rp)], repeated: Nullable(Repeated(true, true, false, false, RepeatedStepDaily(10))));
      var next = nextItem(item);
      expect(next, MatchesNext(item, dn, [Reminder(rn)]));
    });

    test("dst forward ddr_r", () {
      var dp = DateTime(2020, 3, 12, 10,30);
      var dn = DateTime(2020, 3, 22, 10,30);
      var rp = DateTime(2020, 3, 26);
      // DST: 2020 3 29
      var rn = DateTime(2020, 4, 5);

      var item = baseItem.copyWith(dueDate: Nullable(dp), reminders: [Reminder(rp)], repeated: Nullable(Repeated(true, true, false, false, RepeatedStepDaily(10))));
      var next = nextItem(item);
      expect(next, MatchesNext(item, dn, [Reminder(rn)]));
    });

    test("step daily dst forward midnight", () {
      var item = baseItem.copyWith(
        dueDate: Nullable(DateTime(2020, 3, 29)),
        reminders: [
          Reminder(DateTime(2020,3,28, 0,0)),
          Reminder(DateTime(2020,3,29, 0,0)),
          Reminder(DateTime(2020,3,30, 0,0)),
        ],
        repeated: Nullable(Repeated(true, true, false, false, RepeatedStepDaily(1))),
      );
      var reminders = [
        Reminder(DateTime(2020,3,29, 0,0)),
        Reminder(DateTime(2020,3,30, 0,0)),
        Reminder(DateTime(2020,3,31, 0,0)),
      ];
      var next = nextItem(item);
      expect(next, MatchesNext(item, DateTime(2020, 3, 30), reminders));
    });
  });
}

class MatchesNext extends Matcher {
  TodoItem original;
  DateTime dueDate;
  List<Reminder> reminders;
  MatchesNext(this.original, this.dueDate, this.reminders);

  @override
  Description describe(Description description) {
    return description.add("${original}");
  }

  @override
  bool matches(item, Map matchState) {
    var ok = true;
    if (item.id != null) {
      ok = false;
      matchState["id"] = "id (${item.id} instead of null)";
    }
    if (item.todo != original.todo) {
      ok = false;
      matchState["todo"] = "title (${item.todo} instead of ${original.todo})";
    }
    if (item.note != original.note) {
      ok = false;
      matchState["note"] = "note (${item.note} instead of ${original.note})";
    }
    if (item.priority != original.priority) {
      ok = false;
      matchState["priority"] = "priority (${item.priority} instead of ${original.priority})";
    }
    if (item.onLists != original.onLists) {
      ok = false;
      matchState["onLists"] = "onLists (${item.onLists.map((l) => l.listName)} instead of ${original.onLists.map((l) => l.listName)})";
    }
    if (item.repeated != original.repeated) {
      ok = false;
      matchState["repeated"] = "repeated (${item.repeated} instead of ${original.repeated})";
    }
    if (item.dueDate != dueDate) {
      ok = false;
      matchState["dueDate"] = "dueDate (${item.dueDate} instead of $dueDate)";
    }
    for (int i = 0; i<item.reminders.length; i++) {
      if (item.reminders[i].at != reminders[i].at) {
        ok = false;
        matchState["reminder $i"] = "reminder $i (${item.reminders[i].at} instead of ${reminders[i].at})";
      }
    }
    return ok;
  }

  @override
  Description describeMismatch(item, Description mismatchDescription, Map matchState, bool verbose) {
    return mismatchDescription.addAll("Mismatched fields:\n\t", "\n\t", "", matchState.values);
  }
}