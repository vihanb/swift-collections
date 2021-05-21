//
extension Node {
  typealias Splinter = (median: Element, rightChild: Node<Key, Value>)

  /// Inserts a node, if a split occurs this returns a tuple of the new right-child and the
  /// node that should be propogated upward
  internal func insertValue(_ value: Value, forKey key: Key) -> Splinter? {
    let targetIndex = self.lastIndex(of: key)

    // TODO: specialize and optimize cases to minimize element shuffling
    self.keys.insert(key, at: targetIndex)
    self.values.insert(value, at: targetIndex)

    // If we need to split
    if count == capacity {
      let medianIndex = (count + 1) / 2
      let medianElement = (key: self.keys[medianIndex], value: self.values[medianIndex])

      // Create the new right node
      let rightValues = (medianIndex + 1)...
      let rightNode = Node<Key, Value>(
        capacity: capacity,
        keys: Array(self.keys[rightValues]),
        values: Array(self.values[rightValues]),
        children: Array(self.children[rightValues])
      )

      self.keys.removeLast(count - medianIndex)
      self.count = medianIndex + 1

      _checkInvariants()
      return (median: medianElement, rightChild: rightNode)
    } else {
      self.count += 1

      _checkInvariants()
      return nil
    }
  }
}
