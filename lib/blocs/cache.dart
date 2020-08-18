import 'dart:collection';

import 'dart:math';

import 'package:mutex/mutex.dart';

typedef UnderlyingData<T> = Future<List<T>> Function(int, int);

class ListCache<T> {
  ListCache(this.underlyingData, this.totalNumberOfItems, {this.chunkSize=50, this.numberOfChunks=10}):
      chain = ListQueue(numberOfChunks),
      chainStart = 0,
      chainEnd = 0,
      loadingChunk = Mutex() {
    chain.add(Chunk(0,[]));
  }

  ListCache.reInit(this.underlyingData, this.totalNumberOfItems, this.chunkSize, this.numberOfChunks, this.chainStart, this.chainEnd, this.chain, this.currentChunkIndex):
      loadingChunk = Mutex();

  final int chunkSize;
  final int numberOfChunks;
  final UnderlyingData<T> underlyingData;

  int totalNumberOfItems;
  int chainStart;
  int chainEnd;
  ListQueue<Chunk<T>> chain;
  int currentChunkIndex;

  // Mutex used to indicate that a new chunk is being loaded
  Mutex loadingChunk;

  T operator[] (int index) {
    if (index < chainStart || index >= chainEnd) {
      return null;
    }
    var item = chain.elementAt(currentChunkIndex).getItem(index);
    if (item != null) {
      return item;
    }
    currentChunkIndex = _findChunk(index);
    print("CURRENT CHUNK INDEX: $currentChunkIndex");
    _preload();
    return chain.elementAt(currentChunkIndex).getItem(index);
  }

  Future<T> getItem(int index) async {
    print("INDEX: $index (chainStart: $chainStart, chainEnd: $chainEnd)");
    if (index < chainStart || index >= chainEnd) {
      await init(index);
      return getItem(index);
    }
    var item = chain.elementAt(currentChunkIndex).getItem(index);
    if (item != null) {
      return item;
    }
    currentChunkIndex = _findChunk(index);
    print("CURRENT CHUNK INDEX: $currentChunkIndex");
    _preload();
    return chain.elementAt(currentChunkIndex).getItem(index);
  }

  Future<T> peekItem(int index) async {
    if (index < chainStart || index >= chainEnd) {
      var data = await underlyingData(index, index+1);
      return data.first;
    }
    return chain.elementAt(_findChunk(index)).getItem(index);
  }

  int findItem(bool Function(T) predicate) {
    for (final chunk in chain) {
      for (int i=chunk.start; i<chunk.end; i++) {
        if (predicate(chunk.getItem(i))) {
          return i;
        }
      }
    }
    return null;
  }

  int _findChunk(int index) {
    var chunk = chain.elementAt(currentChunkIndex);
    if (chunk.start > index) {
      for (int i=currentChunkIndex-1; i>=0; i--) {
        if (chain.elementAt(i).start < index) {
          return i;
        }
      }
    } else if (chunk.end <= index) {
      for (int i=currentChunkIndex+1; i<chain.length; i++) {
        if (chain.elementAt(i).end > index) {
          return i;
        }
      }
    } else {
      return currentChunkIndex;
    }
  }

  void _preload() {
    if (currentChunkIndex == 0 && chainStart != 0) {
      _loadChunk(_getPreviousStart(), chainStart);
    } else if (currentChunkIndex == chain.length-1 && chainEnd != totalNumberOfItems) {
      print("ON LAST CHUNK");
      _loadChunk(chainEnd, _getNextEnd());
    }
  }

  Future<void> _loadChunk(int start, int end) async {
    if (chainStart < start && chainEnd > start) {
      // The chunk we were supposed to load is already there
      return;
    }
    // Obtain the mutex to make sure no one else is loading a chunk at the same time
    await loadingChunk.protect(() async {
      print("(PRE)LOADING CHUNK: $start, $end, $chainStart, $chainEnd");
      await _loadChunkInternal(start, end);
    });
  }

  Future<void> _loadChunkInternal(int start, int end) async {
    if (chainStart < start && chainEnd > start) {
      // The chunk we were supposed to load was loaded in the meantime
      return;
    }
    if (start != chainEnd && end != chainStart) {
      // The chunk we were supposed to load doesn't fit in with the rest of the
      // chain anymore. This probably means that a preload call ended up being
      // run too late for it to still be useful.
      // Do nothing and let the caller figure it out
      return;
    }
    var data = await underlyingData(start, end);
    if (start < chainStart) {
      assert(end == chainStart);
      if (chain.length == numberOfChunks) {
        chain.removeLast();
        chainEnd = chain.last.end;
      }
      chain.addFirst(Chunk(start, data, end: end));
      chainStart = start;
    } else {
      assert(start == chainEnd, "start=$start, chainEnd=$chainEnd, end=$end, chainStart=$chainStart");
      if (chain.length == numberOfChunks) {
        chain.removeFirst();
        chainStart = chain.first.start;
      }
      chain.addLast(Chunk(start, data, end: end));
      chainEnd = end;
    }
  }

  Future<void> init(int index) async {
    print("INIT CALLED");
    await loadingChunk.protect(() async {
      if (index >= chainStart && index < chainEnd) {
        // The chunk was already loaded while waiting for the mutex
        return;
      }
      if (chainEnd!=0 && index>=chainEnd && index-chunkSize < chainEnd) {
        // The data we need is just in the next chunk
        print("INIT LOADING NEXT");
        await _loadChunkInternal(chainEnd, _getNextEnd());
        return;
      } else if (index<chainStart && index+chunkSize>=chainStart) {
        // The data we need is in the previous chunk
        await _loadChunkInternal(_getPreviousStart(), chainStart);
        return;
      }
      print("RE INIT");
      var newChain = ListQueue<Chunk<T>>(numberOfChunks);

      // TODO Check if we're close to the edge and expand the chunk size
      var central = await underlyingData(index, min(index+chunkSize, totalNumberOfItems));
      newChain.add(Chunk(index, central));
      if (index != 0) {
        var start = max(0,index-chunkSize);
        var previous = await underlyingData(start, index);
        newChain.addFirst(Chunk(start, previous));
      }
      if (index+chunkSize < totalNumberOfItems) {
        var next = await underlyingData(index+chunkSize, min(index+2*chunkSize, totalNumberOfItems));
        newChain.addLast(Chunk(index+chunkSize, next));
      }
      chain = newChain;
      chainStart = chain.first.start;
      chainEnd = chain.last.end;
      currentChunkIndex = index==0 ? 0 : 1;
    });
  }

  ListCache<T> updateElement(int index, T element) {
    return _modifyChain(index, (chunk) => chunk.update(index,element), 0);
  }

  ListCache<T> addElement(int index, T element) {
    print("ADD ELEMENT: $index, $chainEnd");
    if (index == chainEnd) {
      // Inserting at the end of the chain. This is a bit of a special case, because usually this means that the cache can remain unchanged
      var newChunk = chain.last.addElement(index, element);
      return _withNewChunk(chain.length, newChunk, shift: 1);
    }
    return _modifyChain(index, (chunk) => chunk.addElement(index, element), 1);
  }

  ListCache<T> removeElement(int index) {
    return _modifyChain(index, (chunk) => chunk.removeElement(index), -1);
  }

//  Future<ListCache<T>> removeElement(int index) async {
//    if (index < chainStart || index >= chainEnd) {
//      // The element to remove is not contained in the cache, so there's nothing to do
//      return this;
//    }
//    var chunkIndex = _findChunk(index);
//    var chunk = chain.elementAt(chunkIndex).removeElement(index);
//    var newChain = ListQueue.of([...chain.take(chunkIndex-1), chunk, ...chain.skip(chunkIndex+1).map((elem) => elem.shift(-1))]);
//    return ListCache.reInit(underlyingData, totalNumberOfItems-1, chunkSize, numberOfChunks, chainStart, chainEnd-1, newChain, currentChunkIndex);
//  }

  ListCache<T> _modifyChain(int index, Chunk<T> Function(Chunk<T>) modder, int shift) {
    print("MODIFY CHAIN: $index, $shift, $chainStart, $chainEnd");
    if (index >= chainEnd) {
      // The element to modify is not contained in the cache, so there's nothing to do
      return this;
    } else if (index < chainStart) {
      // The element is not contained in the cache, but appears before the loaded segment, so that indices can be shifted
      if (shift == 0) {
        return this;
      }
      var newChain = ListQueue.of(chain.map((elem) => elem.shift(shift)));
      return ListCache.reInit(underlyingData, totalNumberOfItems+shift, chunkSize, numberOfChunks, chainStart+shift, chainEnd+shift, newChain, currentChunkIndex);
    }
    var chunkIndex = _findChunk(index);
    print("CHUNKINDEX: $chunkIndex");
    var chunk = chain.elementAt(chunkIndex);
    var newChunk = modder(chunk);
    return _withNewChunk(chunkIndex, newChunk, shift: shift);
  }

  ListCache<T> _withNewChunk(int chunkIndex, Chunk<T> newChunk, {int shift=0}) {
    var newChain;
    if (newChunk.length > chunkSize*2) {
      // The chunk is too large, split it in two
      newChain = _splitChunk(chunkIndex, newChunk, shift: shift);
    } else if (chain.length>=2 && newChunk.length < chunkSize ~/ 2) {
      // The chunk is too small, merge two
      newChain = _mergeChunk(chunkIndex, newChunk, shift: shift);
    } else {
      // The size of the chunk is fine, no need to do anything with it
      newChain = ListQueue.of([
        ...chain.take(max(chunkIndex - 1,0)),
        newChunk,
        ...chain.skip(chunkIndex + 1).map((elem) => elem.shift(shift))
      ]);
    }
    return ListCache.reInit(underlyingData, totalNumberOfItems+shift, chunkSize, numberOfChunks, chainStart, chainEnd+shift, newChain, currentChunkIndex);
  }

  ListQueue<Chunk<T>> _splitChunk(int chunkIndex, Chunk<T> newChunk, {int shift=0}) {
    print("SPLITTING CHUNK");
    int skipFront = chain.length == numberOfChunks && chunkIndex*2 > numberOfChunks ? 1 : 0;
    return ListQueue.of([
      ...chain.take(max(chunkIndex-1,0)).skip(skipFront),
      ...newChunk.split(),
      ...chain.take(numberOfChunks-skipFront).skip(chunkIndex+1).map((elem) => elem.shift(shift))
    ]);
  }

  ListQueue<Chunk<T>> _mergeChunk(int chunkIndex, Chunk<T> newChunk, {int shift=0}) {
    if (chunkIndex==0 || (chunkIndex!=chain.length-1 && chain.elementAt(chunkIndex-1).length > chain.elementAt(chunkIndex+1).length)) {
      return ListQueue.of([
        ...chain.take(max(chunkIndex - 1,0)),
        Chunk.joined(newChunk, chain.elementAt(chunkIndex+1)),
        ...chain.skip(chunkIndex + 2).map((elem) => elem.shift(shift))
      ]);
    } else {
      return ListQueue.of([
        ...chain.take(max(chunkIndex - 2,0)),
        Chunk.joined(chain.elementAt(chunkIndex - 1), newChunk),
        ...chain.skip(chunkIndex + 1).map((elem) => elem.shift(shift))
      ]);
    }
  }

  int _getPreviousStart({int start}) {
    var oldStart = start ?? chainStart;
    return max(oldStart-chunkSize, 0);
  }
  int _getNextEnd({int end}) {
    var oldEnd = end ?? chainEnd;
    return min(oldEnd+chunkSize, totalNumberOfItems);
  }
}

class Chunk<T> {
  final int start;
  final int end;
  final List<T> data;
  Chunk(this.start, this.data, {int end}):
      this.end = end ?? start+data.length;

  Chunk.joined(Chunk<T> chunk1, Chunk<T> chunk2):
      assert(chunk1.end == chunk2.start),
      start = chunk1.start,
      end = chunk2.end,
      data = [...chunk1.data, ...chunk2.data];

  int get length => data.length;

  T getItem(int index) {
    return (index>=start && index<end) ? data[index-start] : null;
  }

  Chunk<T> update(int index, T element) {
    var newData = List.of(data);
    newData[index-start] = element;
    return Chunk(start, newData, end: end);
  }

  Chunk<T> addElement(int index, T element) {
    var newData = List.of(data);
    newData.insert(index-start, element);
    return Chunk(start, newData, end: end+1);
  }

  Chunk<T> removeElement(int index) {
    var newData = List.of(data);
    newData.removeAt(index-start);
    return Chunk(start, newData);
  }

  Chunk<T> shift(int by) {
    return Chunk(start+by, data, end: end+by);
  }

  List<Chunk<T>> split() {
      var length = data.length ~/ 2;
      var data1 = List.of(data.take(length)).toList();
      var data2 = List.of(data.skip(length)).toList();
      return [Chunk(start, data1), Chunk(start+data1.length, data2)];
  }
}