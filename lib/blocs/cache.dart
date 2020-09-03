import 'dart:collection';

import 'dart:math';

import 'package:mutex/mutex.dart';

typedef UnderlyingData<T> = Future<List<T>> Function(int, int);

abstract class Cacheable {
  int get cacheId;
}

class ListCache<T extends Cacheable> {
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

  // Get an item based on its index in the list. If it's not currently loaded,
  // return null.
  T operator[] (int index) {
    print("[] => $index, $currentChunkIndex, ${chain.length}");
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

  // Get an item based on its index in the list. If it's not currently loaded,
  // drop the cache and reload so that the item is included.
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

  // Get an item based on its index in the list. If it's not currently loaded,
  // get it from the database.
  // The cache itself is never modified, so nothing is loaded into it and the
  // currently active chunk isn't updated.
  Future<T> peekItem(int index) async {
    if (index < chainStart || index >= chainEnd) {
      var data = await underlyingData(index, index+1);
      return data.first;
    }
    return chain.elementAt(_findChunk(index)).getItem(index);
  }

  // Find the index of an item by its id. Returns null if it's not currently loaded.
  int findItem(int id) {
    for (final chunk in chain) {
      var index = chunk.findItem(id);
      if (index != null) {
        return index;
      }
    }
    return null;
  }

  // Find the index of an item in the cache. Returns null if it's not currently loaded.
  int findItemBy(bool Function(T) predicate) {
    for (final chunk in chain) {
      for (int i=chunk.start; i<chunk.end; i++) {
        if (predicate(chunk.getItem(i))) {
          return i;
        }
      }
    }
    return null;
  }

  // Find the chunk that a given item is in.
  // It is an error if the item is not currently loaded.
  int _findChunk(int index) {
    var chunk = chain.elementAt(currentChunkIndex);
    if (chunk.start > index) {
      for (int i=currentChunkIndex-1; i>=0; i--) {
        if (chain.elementAt(i).start <= index) {
          return i;
        }
      }
      throw("BUG: Somehow the chain got corrupted");
    } else if (chunk.end <= index) {
      for (int i=currentChunkIndex+1; i<chain.length; i++) {
        if (chain.elementAt(i).end > index) {
          return i;
        }
      }
      throw("BUG: Somehow the chain got corrupted");
    } else {
      return currentChunkIndex;
    }
  }

  int _verifyIndex(T item, int index) {
    if (item == null) {
      return index;
    }
    var id = item.cacheId;
    if (index < chainStart || index >= chainEnd) {
      // The index isn't contained in the list. To prove that it's really not there search for it. If it's found,
      // then return it's index, else the old index to indicate if the item is before or after the loaded piece.
      // This is necessary, if some elements got deleted in succession and therefore the end of the chain moved
      // Doing this search is not great from a performance perspective, but it should be highly unlikely to end
      // up in this situation anyway
      return findItem(id) ?? index;
    }
    var atIndex = chain.elementAt(_findChunk(index)).getItem(index);
    if (atIndex.cacheId != id) {
      return findItem(id);
    }
    return index;
  }

  // Load more data in the background. If the load takes place at the beginning or end
  // of the cache depends on the currently active chunk.
  // If the currently active chunk is neither the first or last, nothing is done.
  void _preload() {
    if (currentChunkIndex == 0 && chainStart != 0) {
      _loadChunk(_getPreviousStart(), chainStart);
    } else if (currentChunkIndex == chain.length-1 && chainEnd != totalNumberOfItems) {
      print("ON LAST CHUNK");
      _loadChunk(chainEnd, _getNextEnd());
    }
  }

  // Load a chunk if it's not already there. Acquires the loadingChunk mutex first.
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

  // Internal function to actually load a new chunk. This function should not be used
  // directly, unless the calling code acquired the loadingChunk mutex before calling
  // this.
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
      // TODO Check if currentChunkIndex needs to be incremented to still point to the same thing
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

  // Initialize the cache by loading the chunk starting with `index` and the chunks before
  // and after, assuming they exist.
  // If the cache is already there and `index` would be in a chunk adjacent to what's already
  // loaded, only load the adjacent chunk.
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

  // Update the given element
  // To speed up finding the element, the index of the element can be given
  // This function does not modify the existing cache but returns a new one.
  ListCache<T> updateElement(int index, {T element}) {
    var verifiedIndex = _verifyIndex(element, index);
    return _modifyChain(verifiedIndex, (chunk) => chunk.update(verifiedIndex,element), 0);
  }

  // Add an element at a given index, before the item that's already there
  // This function does not modify the existing cache but returns a new one.
  ListCache<T> addElementBefore(int index, T newElement, {T beforeElement}) {
    var verifiedIndex = _verifyIndex(beforeElement, index);
    return _modifyChain(verifiedIndex, (chunk) => chunk.addElement(verifiedIndex, newElement), 1);
  }

  // Add an element at a given index, after the item that's already there
  // This function does not modify the existing cache but returns a new one.
  ListCache<T> addElementAfter(int index, T newElement, {T afterElement}) {
    var verifiedIndex = _verifyIndex(afterElement, index) + 1;
    if (verifiedIndex == chainEnd) {
      return addElementAtEnd(newElement);
    }
    return _modifyChain(verifiedIndex, (chunk) => chunk.addElement(verifiedIndex, newElement), 1);
  }

  // Add an element at the end of the list
  // This function does not modify the existing cache but returns a new one.
  ListCache<T> addElementAtEnd(T element) {
    if (totalNumberOfItems > chainEnd) {
      // The end of the list is not loaded, so only update the total number of items
      return ListCache.reInit(underlyingData, totalNumberOfItems+1, chunkSize, numberOfChunks, chainStart, chainEnd, chain, currentChunkIndex);
    }
    var newChunk = chain.last.addElementAtEnd(element);
    return _withNewChunk(chain.length-1, newChunk, shift: 1);
  }

  // Delete the given element
  // To speed up finding the element, the index of the element can be given
  // This function does not modify the existing cache but returns a new one.
  ListCache<T> removeElement(int index, {T element}) {
    var verifiedIndex = _verifyIndex(element, index);
    return _modifyChain(verifiedIndex, (chunk) => chunk.removeElement(verifiedIndex), -1);
  }

  ListCache<T> reorderElements(int moveFromIndex, int moveToIndex, T elementFrom, {T elementTo}) {
    // First, delete the element that's moving from it's old position
    var temp = removeElement(moveFromIndex, element: elementFrom);
    // Next, move the element to it's new position
    if (moveFromIndex < moveToIndex) {
      // The item has moved backwards and as such is inserted after elementTo
      // moveToIndex needs to be decremented, because elementFrom was deleted ahead of it
      return temp.addElementAfter(moveToIndex-1, elementFrom, afterElement: elementTo);
    } else {
      // The item has moved forwards and as such is inserted before elementTo
      var t2 = temp.addElementBefore(moveToIndex, elementFrom, beforeElement: elementTo);
      print(t2.totalNumberOfItems);
      return t2;
    }
  }

  // Internal function to modify an item, so either update, delete or remove it
  // If necessary, chunks are merged if they get to small or split if they get too large
  // The actual cache is never modified, but a copy is returned
  ListCache<T> _modifyChain(int index, Chunk<T> Function(Chunk<T>) modder, int shift) {
    print("MODIFY CHAIN: $index, $shift, $chainStart, $chainEnd");
    if (index >= chainEnd) {
      // The element to modify is not contained in the cache, so there's nothing to do except modifying the total number of items
      if (shift == 0) {
        return this;
      }
      return ListCache.reInit(underlyingData, totalNumberOfItems+shift, chunkSize, numberOfChunks, chainStart, chainEnd, chain, currentChunkIndex);
    } else if (index < chainStart) {
      // The element is not contained in the cache, but appears before the loaded segment, so that indices need to be shifted by `shift`
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

  // Build a new cache that contains a modified chunk
  ListCache<T> _withNewChunk(int chunkIndex, Chunk<T> newChunk, {int shift=0}) {
    ListQueue<Chunk<T>> newChain;
    print("WITH NEW CHUNK: ${newChunk.length}, $chunkSize, ${chunkSize*2}, ${chunkSize~/2}");
    if (newChunk.length > chunkSize*2) {
      // The chunk is too large, split it in two
      newChain = _splitChunk(chunkIndex, newChunk, shift: shift);
    } else if (chain.length>=2 && newChunk.length < chunkSize ~/ 2) {
      // The chunk is too small, merge two
      newChain = _mergeChunk(chunkIndex, newChunk, shift: shift);
    } else {
      // The size of the chunk is fine, no need to do anything with it
      newChain = ListQueue.of([
        ...chain.take(chunkIndex),
        newChunk,
        ...chain.skip(chunkIndex + 1).map((elem) => elem.shift(shift))
      ]);
    }
    return ListCache.reInit(
        underlyingData,
        totalNumberOfItems + shift,
        chunkSize,
        numberOfChunks,
        newChain.first.start,
        newChain.last.end,
        newChain,
        currentChunkIndex>=newChain.length ? currentChunkIndex-1 : currentChunkIndex
    );
  }

  ListQueue<Chunk<T>> _splitChunk(int chunkIndex, Chunk<T> newChunk, {int shift=0}) {
    print("SPLITTING CHUNK");
    var newChain = ListQueue.of([
      // Everything in front of the chunk to be split
      ...chain.take(chunkIndex),
      // The chunk that has been split
      ...newChunk.split(),
      // Everything after the split chunk, shifted over
      ...chain.skip(chunkIndex+1).map((elem) => elem.shift(shift))
    ]);
    if (newChain.length > numberOfChunks) {
      // The newly created chain is too long
      if (currentChunkIndex*2 > numberOfChunks) {
        // The current chunk is in the top half of the chain => drop an element at the front
        newChain.removeFirst();
      } else {
        newChain.removeLast();
      }
    }
    return newChain;
  }

  ListQueue<Chunk<T>> _mergeChunk(int chunkIndex, Chunk<T> newChunk, {int shift=0}) {
    print("MERGING CHUNKS");
    // The chunk to merge with is found by checking (if both sides are available) which of the two candidates contains less elements
    if (chunkIndex==0 || (chunkIndex!=chain.length-1 && chain.elementAt(chunkIndex-1).length > chain.elementAt(chunkIndex+1).length)) {
      // The chunk to merge with is to the right of the modified chunk
      return ListQueue.of([
        // Everything ahead of the modified chunk
        ...chain.take(chunkIndex),
        // The combined chunk
        Chunk.joined(newChunk, chain.elementAt(chunkIndex+1), shift),
        // Everything after the modified chunk and the chunk it was joined with
        ...chain.skip(chunkIndex + 2).map((elem) => elem.shift(shift))
      ]);
    } else {
      // The chunk to merge with is to the left of the modified chunk
      return ListQueue.of([
        // Everything to the left of the modified chunk, leaving out the one directly to the left
        ...chain.take(chunkIndex - 1),
        // The combined chunk
        Chunk.joined(chain.elementAt(chunkIndex - 1), newChunk, 0),
        // Everything after the modified chunk
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

class Chunk<T extends Cacheable> {
  final int start;
  final int end;
  final List<T> data;
  Chunk(this.start, this.data, {int end}):
      this.end = end ?? start+data.length;

  Chunk.joined(Chunk<T> chunk1, Chunk<T> chunk2, int shift):
      assert(chunk1.end == chunk2.start+shift),
      start = chunk1.start,
      end = chunk2.end+shift,
      data = [...chunk1.data, ...chunk2.data];

  int get length => data.length;

  T getItem(int index) {
    return (index>=start && index<end) ? data[index-start] : null;
  }

  int findItem(int itemId) {
    for (int i=0; i<data.length; i++) {
      if (data[i].cacheId == itemId) {
        return i+start;
      }
    }
    return null;
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

  Chunk<T> addElementAtEnd(T element) {
    var newData = List.of(data);
    newData.add(element);
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