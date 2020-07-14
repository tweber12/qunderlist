import 'dart:math';

import 'package:qunderlist/repository/models.dart';
import 'package:qunderlist/repository/todos_repository_sqflite.dart';
import 'package:test/test.dart';
import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  // Init ffi loader if needed.
  sqfliteFfiInit();

  test('move List giant', () async {
    var db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await createDatabase(db, 1);
    var repository = TodoRepositorySqflite.getInstance(db: db);

    int from = 10;
    int to = 87;
    for (int i=0; i<100; i++) {
      await repository.addTodoList(TodoList("L$i"));
    }
    var listIds = (await repository.getTodoLists().first);

    await repository.moveList(await repository.getTodoList(listIds[from]).first, to);

    var newListIds = (await repository.getTodoLists().first);
    print(listIds);
    print(newListIds);
    for (int i=0; i<from; i++) {
      expect(newListIds[i], listIds[i]);
    }
    for (int i=from; i<to-2; i++) {
      expect(newListIds[i], listIds[i+1]);
    }
    for (int i=to; i<listIds.length; i++) {
      expect(newListIds[i], listIds[i]);
    }
    expect(newListIds[to-2], listIds[from]);
    await db.close();
  });
}