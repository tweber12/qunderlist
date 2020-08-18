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
    int testLength = 50;
    var list = [for (int i=0; i<testLength; i++) i%134];
    var cache = ListCache(underlyingList(list), list.length, chunkSize: 10, numberOfChunks: 5);
    await cache.init(0);
    expect(await cache.getItem(4), list[4]);
    expect(await cache.getItem(14), list[14]);
    expect(await cache.getItem(24), list[24]);
    expect(await cache.getItem(34), list[34]);
    expect(await cache.getItem(44), list[44]);
    cache = cache.addElement(24, 100);
    expect(await cache.getItem(4), list[4]);
    expect(await cache.getItem(14), list[14]);
    expect(await cache.getItem(24), 100);
    expect(await cache.getItem(25), list[24]);
    expect(await cache.getItem(34), list[33]);
    expect(await cache.getItem(44), list[43]);
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
  test('addItemAtEndEmpty', () async {
    int testLength = 100;
    var list = [];
    var cache = ListCache(underlyingList(list), list.length, chunkSize: 10, numberOfChunks: 5);
    await cache.init(0);
    for (int i=0; i<testLength; i++) {
      cache = cache.addElement(cache.totalNumberOfItems, i);
      list.add(i);
    }
    for (int i=0; i<testLength; i++) {
      expect(await cache.getItem(i), i);
    }
  });
  test('addItemAtEndFilled', () async {
    int testLength = 100;
    var list = [for (int i=0; i<12; i++) i];
    var cache = ListCache(underlyingList(list), list.length, chunkSize: 10, numberOfChunks: 5);
    await cache.init(0);
    for (int i=12; i<testLength; i++) {
      cache = cache.addElement(cache.totalNumberOfItems, i);
      list.add(i);
    }
    for (int i=0; i<testLength; i++) {
      expect(await cache.getItem(i), i);
    }
  });
  test('findIndex0', () async {
    // This is a regression test for a bug where _findChunk fails if it needs to look for index 0 in any other but the current chunk
    // (Technically it's not about 0, but any index which starts a chunk)
    int testLength = 100;
    var list = [for (int i=0; i<testLength; i++) i%134];
    var cache = ListCache(underlyingList(list), list.length, chunkSize: 10, numberOfChunks: 5);
    await cache.init(0);
    // Access it normally, with it being in the current chunk
    expect(await cache.getItem(0), list[0]);
    // Access an element in the second chunk
    expect(await cache.getItem(15), list[15]);
    // Access 0 again, with the following chunk being the current one
    expect(await cache.getItem(0), list[0]);

    // Try again with a different chunk start
    // Access it with it being in the next chunk
    expect(await cache.getItem(10), list[10]);
    // Access an element in the third chunk
    expect(await cache.getItem(25), list[25]);
    // Access it again, this time it's in the previous one
    expect(await cache.getItem(10), list[10]);
  });

  test('findIndex19', () async {
    // As an extension to findIndex0, check if there are problems with the ends of chunks
    int testLength = 100;
    var list = [for (int i=0; i<testLength; i++) i%134];
    var cache = ListCache(underlyingList(list), list.length, chunkSize: 10, numberOfChunks: 5);
    await cache.init(0);
    expect(await cache.getItem(19), list[19]);
    expect(await cache.getItem(9), list[9]);
  });
}