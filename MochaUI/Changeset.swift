//
//  Changeset.swift
//  Copyright (c) 2015-16 Joachim Bondo. All rights reserved.
//

import AppKit

/** Defines an atomic edit.
 - seealso: Note on `Edit.Operation`.
 */
public struct Edit<T: Equatable> {
    
    /** Defines the type of an `Edit`.
     */
    public enum Operation {
        case insertion
        case deletion
        case substitution
        case move(origin: Int)
    }
    
    public let operation: Operation
    public let value: T
    public let destination: Int
    
    // Define initializer so that we don't have to add the `operation` label.
    public init(_ operation: Operation, value: T, destination: Int) {
        self.operation = operation
        self.value = value
        self.destination = destination
    }
}

/** A `Changeset` is a way to describe the edits required to go from one set of data to another.
 It detects additions, deletions, substitutions, and moves. Data is a `Collection` of `Equatable` elements.
 - note: This implementation was inspired by [Dave DeLong](https://twitter.com/davedelong)'s article, [Edit distance and edit steps](http://davedelong.tumblr.com/post/134367865668/edit-distance-and-edit-steps).
 - seealso: `Changeset.editDistance`.
 */
public struct Changeset<T: Collection> where T.Iterator.Element: Equatable, T.IndexDistance == Int {
    
    /// The starting-point collection.
    public let origin: T
    
    /// The ending-point collection.
    public let destination: T
    
    /** The edit steps required to go from `self.origin` to `self.destination`.
     
     - note: I would have liked to make this `lazy`, but that would prohibit users from using constant `Changeset` values.
     
     - seealso: [Lazy Properties in Structs](http://oleb.net/blog/2015/12/lazy-properties-in-structs-swift/) by [Ole Begemann](https://twitter.com/olebegemann).
     */
    public let edits: [Edit<T.Iterator.Element>]
    
    public init(source origin: T, target destination: T) {
        self.origin = origin
        self.destination = destination
        self.edits = Changeset.edits(from: self.origin, to: self.destination)
    }
    
    /** Returns the edit steps required to go from one collection to another.
     
     The number of steps is the `count` of elements.
     
     - note: Indexes in the returned `Edit` elements are into the `from` source collection (just like how `UITableView` expects changes in the `beginUpdates`/`endUpdates` block.)
     
     - seealso:
     - [Edit distance and edit steps](http://davedelong.tumblr.com/post/134367865668/edit-distance-and-edit-steps) by [Dave DeLong](https://twitter.com/davedelong).
     - [Explanation of and Pseudo-code for the Wagner-Fischer algorithm](https://en.wikipedia.org/wiki/Wagner–Fischer_algorithm).
     
     - parameters:
     - from: The starting-point collection.
     - to: The ending-point collection.
     
     - returns: An array of `Edit` elements.
     */
    public static func edits(from source: T, to target: T) -> [Edit<T.Iterator.Element>] {
        
        let rows = source.count
        let columns = target.count
        
        // Only the previous and current row of the matrix are required.
        var previousRow: [[Edit<T.Iterator.Element>]] = Array(repeating: [], count: columns + 1)
        var currentRow = [[Edit<T.Iterator.Element>]]()
        
        // Indexes into the two collections.
        var sourceIndex = source.startIndex
        var targetIndex: T.Index
        
        // Fill first row of insertions.
        var edits = [Edit<T.Iterator.Element>]()
        for (column, element) in target.enumerated() {
            let edit = Edit(.insertion, value: element, destination: column)
            edits.append(edit)
            previousRow[column + 1] = edits
        }
        
        if rows > 0 {
            for row in 1...rows {
                targetIndex = target.startIndex
                
                currentRow = Array(repeating: [], count: columns + 1)
                
                // Fill first cell with deletion.
                var edits = previousRow[0]
                let edit = Edit(.deletion, value: source[sourceIndex], destination: row - 1)
                edits.append(edit)
                currentRow[0] = edits
                
                if columns > 0 {
                    for column in 1...columns {
                        if source[sourceIndex] == target[targetIndex] {
                            currentRow[column] = previousRow[column - 1] // no operation
                        } else {
                            var deletion = previousRow[column] // a deletion
                            var insertion = currentRow[column - 1] // an insertion
                            var substitution = previousRow[column - 1] // a substitution
                            
                            // Record operation.
                            let minimumCount = min(deletion.count, insertion.count, substitution.count)
                            if deletion.count == minimumCount {
                                let edit = Edit(.deletion, value: source[sourceIndex], destination: row - 1)
                                deletion.append(edit)
                                currentRow[column] = deletion
                            } else if insertion.count == minimumCount {
                                let edit = Edit(.insertion, value: target[targetIndex], destination: column - 1)
                                insertion.append(edit)
                                currentRow[column] = insertion
                            } else {
                                let edit = Edit(.substitution, value: target[targetIndex], destination: row - 1)
                                substitution.append(edit)
                                currentRow[column] = substitution
                            }
                        }
                        
                        targetIndex = target.index(targetIndex, offsetBy: 1)
                    }
                }
                
                previousRow = currentRow
                sourceIndex = source.index(sourceIndex, offsetBy: 1)
            }
        }
        
        // Convert deletion/insertion pairs of same element into moves.
        return reducedEdits(previousRow[columns])
    }
}

/** Returns an array where deletion/insertion pairs of the same element are replaced by `.move` edits.
 - parameter edits: An array of `Edit` elements to be reduced.
 - returns: An array of `Edit` elements.
 */
private func reducedEdits<T>(_ edits: [Edit<T>]) -> [Edit<T>] {
    return edits.reduce([Edit<T>]()) { (edits, edit) in
        var reducedEdits = edits
        if let (move, index) = move(from: edit, in: reducedEdits), case .move = move.operation {
            reducedEdits.remove(at: index)
            reducedEdits.append(move)
        } else {
            reducedEdits.append(edit)
        }
        
        return reducedEdits
    }
}

/** Returns a potential `.move` edit based on an array of `Edit` elements and an edit to match up against.
 If `edit` is a deletion or an insertion, and there is a matching opposite insertion/deletion with the same value in the array, a corresponding `.move` edit is returned.
 - parameters:
 - deletionOrInsertion: A `.deletion` or `.insertion` edit there will be searched an opposite match for.
 - edits: The array of `Edit` elements to search for a match in.
 - returns: An optional tuple consisting of the `.move` `Edit` that corresponds to the given deletion or insertion and an opposite match in `edits`, and the index of the match – if one was found.
 */
private func move<T>(from deletionOrInsertion: Edit<T>, `in` edits: [Edit<T>]) -> (move: Edit<T>, index: Int)? {
    
    switch deletionOrInsertion.operation {
        
    case .deletion:
        if let insertionIndex = edits.index(where: { (earlierEdit) -> Bool in
            if case .insertion = earlierEdit.operation, earlierEdit.value == deletionOrInsertion.value { return true } else { return false }
        }) {
            return (Edit(.move(origin: deletionOrInsertion.destination), value: deletionOrInsertion.value, destination: edits[insertionIndex].destination), insertionIndex)
        }
        
    case .insertion:
        if let deletionIndex = edits.index(where: { (earlierEdit) -> Bool in
            if case .deletion = earlierEdit.operation, earlierEdit.value == deletionOrInsertion.value { return true } else { return false }
        }) {
            return (Edit(.move(origin: edits[deletionIndex].destination), value: deletionOrInsertion.value, destination: deletionOrInsertion.destination), deletionIndex)
        }
        
    default:
        break
    }
    
    return nil
}

extension Edit: Equatable {}
public func ==<T>(lhs: Edit<T>, rhs: Edit<T>) -> Bool {
    guard lhs.destination == rhs.destination && lhs.value == rhs.value else { return false }
    switch (lhs.operation, rhs.operation) {
    case (.insertion, .insertion), (.deletion, .deletion), (.substitution, .substitution):
        return true
    case (.move(let lhsOrigin), .move(let rhsOrigin)):
        return lhsOrigin == rhsOrigin
    default:
        return false
    }
}

extension NSTableView {
    
    /// Performs batch updates on the table view, given the edits of a Changeset, and animates the transition.
    open func update<T>(with edits: [Edit<T>],
                        insertAnimation: AnimationOptions = [.effectFade, .slideUp],
                        deleteAnimation: AnimationOptions = [.effectFade, .slideDown]) {
        guard !edits.isEmpty else { return }
        let indexPaths = batchIndices(from: edits)
        
        self.beginUpdates()
        if !indexPaths.deletions.isEmpty { self.removeRows(at: IndexSet(indexPaths.deletions), withAnimation: insertAnimation) }
        if !indexPaths.insertions.isEmpty { self.insertRows(at: IndexSet(indexPaths.insertions), withAnimation: deleteAnimation) }
        if !indexPaths.updates.isEmpty { self.reloadData(forRowIndexes: IndexSet(indexPaths.updates), columnIndexes: IndexSet()) }
        self.endUpdates()
    }
}

extension NSCollectionView {
    
    /// Performs batch updates on the table view, given the edits of a Changeset, and animates the transition.
    open func update<T>(with edits: [Edit<T>], in section: Int = 0, completion: ((Bool) -> Void)? = nil) {
        guard !edits.isEmpty else { return }
        let indexPaths = batchIndexPaths(from: edits, in: section)
        
        self.animator().performBatchUpdates({
            if !indexPaths.deletions.isEmpty { self.deleteItems(at: Set(indexPaths.deletions)) }
            if !indexPaths.insertions.isEmpty { self.insertItems(at: Set(indexPaths.insertions)) }
            if !indexPaths.updates.isEmpty { self.reloadItems(at: Set(indexPaths.updates)) }
        }, completionHandler: completion)
    }
}

private func batchIndices<T> (from edits: [Edit<T>]) -> (insertions: [Int], deletions: [Int], updates: [Int]) {
    var insertions = [Int](), deletions = [Int](), updates = [Int]()
    for edit in edits {
        switch edit.operation {
        case .deletion:
            deletions.append(edit.destination)
        case .insertion:
            insertions.append(edit.destination)
        case .move(let origin):
            deletions.append(origin)
            insertions.append(edit.destination)
        case .substitution:
            updates.append(edit.destination)
        }
    }
    return (insertions: insertions, deletions: deletions, updates: updates)
}

private func batchIndexPaths<T> (from edits: [Edit<T>], in section: Int) -> (insertions: [IndexPath], deletions: [IndexPath], updates: [IndexPath]) {
    var insertions = [IndexPath](), deletions = [IndexPath](), updates = [IndexPath]()
    for edit in edits {
        let destinationIndexPath = IndexPath(item: edit.destination, section: section)
        switch edit.operation {
        case .deletion:
            deletions.append(destinationIndexPath)
        case .insertion:
            insertions.append(destinationIndexPath)
        case .move(let origin):
            let originIndexPath = IndexPath(item: origin, section: section)
            deletions.append(originIndexPath)
            insertions.append(destinationIndexPath)
        case .substitution:
            updates.append(destinationIndexPath)
        }
    }
    return (insertions: insertions, deletions: deletions, updates: updates)
}
