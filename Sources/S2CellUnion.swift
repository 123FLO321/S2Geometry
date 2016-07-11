//
//  S2CellUnion.swift
//  S2Geometry
//
//  Created by Alex Studnicka on 7/1/16.
//  Copyright © 2016 Alex Studnicka. MIT License.
//

/**
	An S2CellUnion is a region consisting of cells of various sizes. Typically a
	cell union is used to approximate some other shape. There is a tradeoff
	between the accuracy of the approximation and how many cells are used. Unlike
	polygons, cells have a fixed hierarchical structure. This makes them more
	suitable for optimizations based on preprocessing.
*/
public struct S2CellUnion: S2Region {
	
	/// The CellIds that form the Union
	public var cellIds: [S2CellId]
	
	/**
		Populates a cell union with the given S2CellIds or 64-bit cells ids, and
		then calls Normalize(). The InitSwap() version takes ownership of the
		vector data without copying and clears the given vector. These methods may
		be called multiple times.
	*/
	public init(cellIds: [S2CellId] = []) {
		self.cellIds = cellIds
		normalize()
	}
	
	/**
		Replaces "output" with an expanded version of the cell union where any
		cells whose level is less than "min_level" or where (level - min_level) is
		not a multiple of "level_mod" are replaced by their children, until either
		both of these conditions are satisfied or the maximum level is reached.
	
		This method allows a covering generated by S2RegionCoverer using
		min_level() or level_mod() constraints to be stored as a normalized cell
		union (which allows various geometric computations to be done) and then
		converted back to the original list of cell ids that satisfies the desired
		constraints.
	*/
	public func denormalize(minLevel: Int, levelMod: Int) -> [S2CellId] {
		// assert (minLevel >= 0 && minLevel <= S2CellId.MAX_LEVEL);
		// assert (levelMod >= 1 && levelMod <= 3);
		
		var output: [S2CellId] = []
		output.reserveCapacity(cellIds.count)
		
		for id in cellIds {
			let level = id.level
			var newLevel = max(minLevel, level)
			if levelMod > 1 {
				// Round up so that (new_level - min_level) is a multiple of level_mod.
				// (Note that S2CellId::kMaxLevel is a multiple of 1, 2, and 3.)
				newLevel += (S2CellId.maxLevel - (newLevel - minLevel)) % levelMod
				newLevel = min(S2CellId.maxLevel, newLevel)
			}
			if (newLevel == level) {
				output.append(id)
			} else {
				let end = id.childEnd(level: newLevel)
				
				var childId = id.childBegin()
				while childId != end {
					output.append(id)
					childId = childId.next()
				}
			}
		}
		
		return output
	}
	
	/**
		Normalizes the cell union by discarding cells that are contained by other
		cells, replacing groups of 4 child cells by their parent cell whenever
		possible, and sorting all the cell ids in increasing order. Returns true if
		the number of cells was reduced.
	
		This method *must* be called before doing any calculations on the cell
		union, such as Intersects() or Contains().
	
		- Returns: true if the normalize operation had any effect on the cell union,
				   false if the union was already normalized
	*/
	@discardableResult
	public mutating func normalize() -> Bool {
		// Optimize the representation by looking for cases where all subcells
		// of a parent cell are present.
		
		var output: [S2CellId] = []
		output.reserveCapacity(cellIds.count)
		cellIds.sort()
		
		for var id in cellIds {
			var size = output.count
			// Check whether this cell is contained by the previous cell.
			if (!output.isEmpty && output[size - 1].contains(other: id)) {
				continue
			}
		
			// Discard any previous cells contained by this cell.
			while (!output.isEmpty && id.contains(other: output[output.count - 1])) {
				output.remove(at: output.count - 1)
			}
		
			// Check whether the last 3 elements of "output" plus "id" can be
			// collapsed into a single parent cell.
			while output.count >= 3 {
				size = output.count
				// A necessary (but not sufficient) condition is that the XOR of the
				// four cells must be zero. This is also very fast to test.
				if ((output[size - 3].id ^ output[size - 2].id ^ output[size - 1].id) != id.id) {
					break
				}
				
				// Now we do a slightly more expensive but exact test. First, compute a
				// mask that blocks out the two bits that encode the child position of
				// "id" with respect to its parent, then check that the other three
				// children all agree with "mask.
				var mask = id.lowestOnBit << 1
				mask = ~(mask + (mask << 1))
				let idMasked = (id.id & mask)
				if ((output[size - 3].id & mask) != idMasked
					|| (output[size - 2].id & mask) != idMasked
					|| (output[size - 1].id & mask) != idMasked || id.isFace) {
					break
				}
				
				// Replace four children by their parent cell.
				output.remove(at: size - 1)
				output.remove(at: size - 2)
				output.remove(at: size - 3)
				id = id.parent
			}
			output.append(id)
		}
		
		if output.count < cellIds.count {
			cellIds = output
			return true
		}
		
		return false
	}
	
	////////////////////////////////////////////////////////////////////////
	// MARK: S2Region
	////////////////////////////////////////////////////////////////////////
	
	public var capBound: S2Cap {
		return S2Cap()
	}
	
	public var rectBound: S2LatLngRect {
		var bound: S2LatLngRect = .empty
		for id in cellIds {
			bound = bound.union(with: S2Cell(id: id).rectBound)
		}
		return bound
	}
	
	public func contains(cell: S2Cell) -> Bool {
		return false
	}
	
	public func mayIntersect(cell: S2Cell) -> Bool {
		return false
	}
	
}
