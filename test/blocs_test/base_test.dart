import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:qunderlist/blocs/base.dart';
import 'package:qunderlist/notification_handler.dart';
import 'package:qunderlist/repository/repository.dart';

void main() {
  MockRepository repository;
  MockNotificationHandler notificationHandler;

  setUp(() {
    repository = MockRepository();
    notificationHandler = MockNotificationHandler();
  });
  tearDown(() {
    repository.stream.close();
  });

  group("Direct navigation", () {
    blocTest(
      "Home from initial",
      build: () => BaseBloc(repository, notificationHandler),
      act: (bloc) => bloc.add(BaseShowHomeEvent()),
      expect: [MatchesHome()]
    );

    blocTest(
        "List from initial",
        build: () => BaseBloc(repository, notificationHandler),
        act: (bloc) => bloc.add(BaseShowListEvent(3)),
        expect: [MatchesList(3)]
    );

    blocTest(
        "Item from initial",
        build: () => BaseBloc(repository, notificationHandler),
        act: (bloc) => bloc.add(BaseShowItemEvent(2, listId: 4)),
        expect: [MatchesItem(4,2)]
    );

    blocTest(
        "Home from Home",
        build: () => BaseBloc(repository, notificationHandler),
        act: (bloc) {
          bloc.add(BaseShowHomeEvent());
          bloc.add(BaseShowHomeEvent());
        },
        expect: [MatchesHome()]
    );

    blocTest(
        "List from Home",
        build: () => BaseBloc(repository, notificationHandler),
        act: (bloc) {
          bloc.add(BaseShowHomeEvent());
          bloc.add(BaseShowListEvent(3));
        },
        expect: [MatchesHome(), MatchesList(3)]
    );

    blocTest(
        "Item from Home",
        build: () => BaseBloc(repository, notificationHandler),
        act: (bloc) {
          bloc.add(BaseShowHomeEvent());
          bloc.add(BaseShowItemEvent(2, listId: 4));
        },
        expect: [MatchesHome(), MatchesItem(4,2)]
    );

    blocTest(
        "Home from List",
        build: () => BaseBloc(repository, notificationHandler),
        act: (bloc) {
          bloc.add(BaseShowListEvent(3));
          bloc.add(BaseShowHomeEvent());
        },
        expect: [MatchesList(3), MatchesHome()]
    );

    blocTest(
        "List from same List",
        build: () => BaseBloc(repository, notificationHandler),
        act: (bloc) {
          bloc.add(BaseShowListEvent(3));
          bloc.add(BaseShowListEvent(3));
        },
        expect: [MatchesList(3), MatchesList(3)]
    );

    blocTest(
        "List from different List",
        build: () => BaseBloc(repository, notificationHandler),
        act: (bloc) {
          bloc.add(BaseShowListEvent(1));
          bloc.add(BaseShowListEvent(3));
        },
        expect: [MatchesList(1), MatchesList(3)]
    );

    blocTest(
        "Item from same List",
        build: () => BaseBloc(repository, notificationHandler),
        act: (bloc) {
          bloc.add(BaseShowListEvent(4));
          bloc.add(BaseShowItemEvent(2, listId: 4));
        },
        expect: [MatchesList(4), MatchesItem(4,2)]
    );

    blocTest(
        "Item from different List",
        build: () => BaseBloc(repository, notificationHandler),
        act: (bloc) {
          bloc.add(BaseShowListEvent(7));
          bloc.add(BaseShowItemEvent(2, listId: 4));
        },
        expect: [MatchesList(7), MatchesItem(4,2)]
    );

    blocTest(
        "Item from implicit List",
        build: () => BaseBloc(repository, notificationHandler),
        act: (bloc) {
          bloc.add(BaseShowListEvent(7));
          bloc.add(BaseShowItemEvent(2));
        },
        expect: [MatchesList(7), MatchesItem(7,2)]
    );

    blocTest(
        "Home from Item",
        build: () => BaseBloc(repository, notificationHandler),
        act: (bloc) {
          bloc.add(BaseShowItemEvent(3, listId: 1));
          bloc.add(BaseShowHomeEvent());
        },
        expect: [MatchesItem(1,3), MatchesHome()]
    );

    blocTest(
        "List from Item, same list",
        build: () => BaseBloc(repository, notificationHandler),
        act: (bloc) {
          bloc.add(BaseShowItemEvent(3, listId: 1));
          bloc.add(BaseShowListEvent(1));
        },
        expect: [MatchesItem(1,3), MatchesList(1)]
    );

    blocTest(
        "List from Item, different list",
        build: () => BaseBloc(repository, notificationHandler),
        act: (bloc) {
          bloc.add(BaseShowItemEvent(3, listId: 1));
          bloc.add(BaseShowListEvent(4));
        },
        expect: [MatchesItem(1,3), MatchesList(4)]
    );

    blocTest(
        "Item from Item, same list same item",
        build: () => BaseBloc(repository, notificationHandler),
        act: (bloc) {
          bloc.add(BaseShowItemEvent(3, listId: 1));
          bloc.add(BaseShowItemEvent(3, listId: 1));
        },
        expect: [MatchesItem(1,3)]
    );

    blocTest(
        "Item from Item, same list different item",
        build: () => BaseBloc(repository, notificationHandler),
        act: (bloc) {
          bloc.add(BaseShowItemEvent(3, listId: 1));
          bloc.add(BaseShowItemEvent(5, listId: 1));
        },
        expect: [MatchesItem(1,3), MatchesItem(1, 5)]
    );

    blocTest(
        "Item from Item, different list same item",
        build: () => BaseBloc(repository, notificationHandler),
        act: (bloc) {
          bloc.add(BaseShowItemEvent(3, listId: 1));
          bloc.add(BaseShowItemEvent(3, listId: 2));
        },
        expect: [MatchesItem(1,3), MatchesItem(2,3)]
    );

    blocTest(
        "Item from Item, different list different item",
        build: () => BaseBloc(repository, notificationHandler),
        act: (bloc) {
          bloc.add(BaseShowItemEvent(3, listId: 1));
          bloc.add(BaseShowItemEvent(5, listId: 2));
        },
        expect: [MatchesItem(1,3), MatchesItem(2,5)]
    );

    blocTest(
        "Item from Item, implicit list same item",
        build: () => BaseBloc(repository, notificationHandler),
        act: (bloc) {
          bloc.add(BaseShowItemEvent(3, listId: 1));
          bloc.add(BaseShowItemEvent(3));
        },
        expect: [MatchesItem(1,3)]
    );

    blocTest(
        "Item from Item, implicit list different item",
        build: () => BaseBloc(repository, notificationHandler),
        act: (bloc) {
          bloc.add(BaseShowItemEvent(3, listId: 1));
          bloc.add(BaseShowItemEvent(18));
        },
        expect: [MatchesItem(1,3), MatchesItem(1,18)]
    );
  });

  group("Pop", () {
    blocTest(
        "Pop from home",
        build: () => BaseBloc(repository, notificationHandler),
        act: (bloc) {
          bloc.add(BaseShowHomeEvent());
          bloc.add(BasePopEvent());
        },
        expect: [MatchesHome()]
    );

    blocTest(
        "Pop from list",
        build: () => BaseBloc(repository, notificationHandler),
        act: (bloc) {
          bloc.add(BaseShowListEvent(3));
          bloc.add(BasePopEvent());
        },
        expect: [MatchesList(3), MatchesHome()]
    );

    blocTest(
        "Pop from item",
        build: () => BaseBloc(repository, notificationHandler),
        act: (bloc) {
          bloc.add(BaseShowItemEvent(5, listId: 3));
          bloc.add(BasePopEvent());
        },
        expect: [MatchesItem(3,5), MatchesList(3)]
    );
  });
}

class MockRepository extends Mock implements TodoRepository {
  final StreamController<ExternalUpdate> stream;
  MockRepository(): stream = StreamController<ExternalUpdate>.broadcast();
  @override
  Stream<ExternalUpdate> get updateStream => stream.stream;
}

class MockNotificationHandler extends Mock implements NotificationHandler {}

class MatchesHome extends Matcher {
  @override
  Description describe(Description description) {
    return description.add("BaseState(home)");
  }

  @override
  bool matches(item, Map matchState) {
    if (item.listId != null) {
      return false;
    }
    if (item.itemId != null) {
      return false;
    }
    return true;
  }

  @override
  Description describeMismatch(item, Description mismatchDescription, Map matchState, bool verbose) {
    var description = mismatchDescription;
    if (item.itemId != null) {
      return description.add("BaseState(listId = ${item.listId}, itemId = ${item.itemId})");
    } else {
      return description.add("BaseState(listId = ${item.listId})");
    }
  }
}

class MatchesList extends Matcher {
  final int listId;
  MatchesList(this.listId);

  @override
  Description describe(Description description) {
    return description.add("BaseState(listId = $listId})");
  }

  @override
  bool matches(item, Map matchState) {
    if (item.listId != listId) {
      return false;
    }
    if (item.listBloc.listId != listId) {
      return false;
    }
    if (item.itemId != null) {
      return false;
    }
    return true;
  }

  @override
  Description describeMismatch(item, Description mismatchDescription, Map matchState, bool verbose) {
    var description = mismatchDescription;
    if (item.itemId != null) {
      return description.add("BaseState(listId = ${item.listId}, itemId = ${item.itemId})");
    } else if (item.listId != listId){
      return description.add("BaseState(listId = ${item.listId})");
    } else {
      return description.add("BaseState(listId = $listId), listBloc.listId = ${item.listBloc.listId}");
    }
  }
}


class MatchesItem extends Matcher {
  final int listId;
  final int itemId;
  MatchesItem(this.listId, this.itemId);

  @override
  Description describe(Description description) {
    return description.add("BaseState(listId = $listId, itemId = $itemId)");
  }

  @override
  bool matches(item, Map matchState) {
    if (item.listId != listId) {
      return false;
    }
    if (item.listBloc.listId != listId) {
      return false;
    }
    if (item.itemId != itemId) {
      return false;
    }
    if (item.itemBloc.itemId != itemId) {
      return false;
    }
    return true;
  }

  @override
  Description describeMismatch(item, Description mismatchDescription, Map matchState, bool verbose) {
    var description = mismatchDescription;
    if (item.itemId != itemId || item.listId != listId) {
      return description.add("BaseState(listId = ${item.listId}, itemId = ${item.itemId})");
    } else {
      return description.add("BaseState(listId = $listId, itemId = $itemId), listBloc.listId = ${item.listBloc.listId}, itemBloc.itemId = ${item.itemBloc.itemId}");
    }
  }
}