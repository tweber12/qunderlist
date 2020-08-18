import 'package:flutter_test/flutter_test.dart';
import 'package:qunderlist/blocs/cache.dart';

UnderlyingData<T> underlyingList<T>(List<T> list) {
  return (start, end) {
    return Future.value(list.sublist(start,end));
  };
}
UnderlyingData<T> underlyingListTimed<T>(List<T> list) {
  return (start, end) {
    return Future.delayed(Duration(milliseconds: 100), () => list.sublist(start,end));
  };
}

void main() {
  test('getItemSequential', () async {
    int testLength = 2300;
    var list = [for (int i=0; i<testLength; i++) i%134];
    var cache = ListCache(underlyingList(list), list.length);
    for (int i = 0; i<list.length; i++) {
      expect(await cache.getItem(i), list[i]);
    }
  });
  test('getItemSequentialDelay', () async {
    int testLength = 230;
    var list = [for (int i=0; i<testLength; i++) i%134];
    var cache = ListCache(underlyingListTimed(list), list.length);
    for (int i = 0; i<list.length; i++) {
      expect(await cache.getItem(i), list[i]);
    }
  });
  test('getItemSequentialDelayBunched', () async {
    int testLength = 1000;
    var list = [for (int i=0; i<testLength; i++) i%134];
    var cache = ListCache(underlyingListTimed(list), list.length);
    await cache.init(0);
    var futures = [for (int i=0; i<testLength; i++) cache.getItem(i)];
    var result = await Future.wait(futures);
    for (int i=0; i<testLength; i++) {
      expect(result[i], list[i]);
    }
  });
  test('addItemAfter', () async {
    int testLength = 100;
    var list = [for (int i=0; i<testLength; i++) i%134];
    var cache = ListCache(underlyingList(list), list.length, chunkSize: 10, numberOfChunks: 5);
    await cache.init(0);
    expect(await cache.getItem(4), list[4]);
    cache = cache.addElement(100, 5);
    expect(await cache.getItem(4), list[4]);
  });
  test('addItemBefore', () async {
    int testLength = 100;
    var list = [for (int i=0; i<testLength; i++) i%134];
    var cache = ListCache(underlyingList(list), list.length, chunkSize: 10, numberOfChunks: 5);
    await cache.init(0);
    expect(await cache.getItem(95), list[95]);
    cache = cache.addElement(5, 5);
    expect(await cache.getItem(95), list[94]);
  });
  test('addItemAt', () async {
    int testLength = 100;
    var list = [for (int i=0; i<testLength; i++) i%134];
    var cache = ListCache(underlyingList(list), list.length, chunkSize: 10, numberOfChunks: 5);
    await cache.init(0);
    expect(await cache.getItem(4), list[4]);
    expect(await cache.getItem(5), list[5]);
    expect(await cache.getItem(6), list[6]);
    cache = cache.addElement(5, 100);
    expect(await cache.getItem(4), list[4]);
    expect(await cache.getItem(5), 100);
    expect(await cache.getItem(6), list[5]);
    expect(await cache.getItem(14), list[13]);
  });
  test('addItemAtMultiple', () async {
    int testLength = 100;
    int testInsert = 12;
    var list = [for (int i=0; i<testLength; i++) i%134];
    var cache = ListCache(underlyingList(list), list.length, chunkSize: 10, numberOfChunks: 5);
    await cache.init(0);
    expect(await cache.getItem(4), list[4]);
    expect(await cache.getItem(5), list[5]);
    expect(await cache.getItem(6), list[6]);
    for (int i=0; i<testInsert; i++) {
      cache = cache.addElement(5, 100+i);
    }
    expect(await cache.getItem(4), list[4]);
    for (int i=0; i<testInsert; i++) {
      expect(await cache.getItem(5+i), 100+testInsert-1-i);
    }
    expect(await cache.getItem(5+testInsert), list[5]);
    expect(await cache.getItem(13+testInsert), list[13]);
  });
}