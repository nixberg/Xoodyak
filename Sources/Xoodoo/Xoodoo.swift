import EndianBytes

public struct Xoodoo {
    private var state: [UInt8] = .init(repeating: 0, count: 48)
    
    public init() {}
    
    @inline(__always)
    private func unpack() -> (SIMD4<UInt32>, SIMD4<UInt32>, SIMD4<UInt32>) {
        let a: SIMD4<UInt32> = .init(littleEndianBytes: state[00..<16])
        let b: SIMD4<UInt32> = .init(littleEndianBytes: state[16..<32])
        let c: SIMD4<UInt32> = .init(littleEndianBytes: state[32..<48])
        return (a, b, c)
    }
    
    @inline(__always)
    private mutating func pack(_ a: SIMD4<UInt32>, _ b: SIMD4<UInt32>, _ c: SIMD4<UInt32>) {
        state.removeAll(keepingCapacity: true)
        state.append(contentsOf: a.littleEndianBytes())
        state.append(contentsOf: b.littleEndianBytes())
        state.append(contentsOf: c.littleEndianBytes())
    }
    
    public mutating func permute() {
        var (a, b, c) = self.unpack()
        
        let roundConstants: [UInt32] = [
            0x058, 0x038, 0x3c0, 0x0d0, 0x120, 0x014,
            0x060, 0x02c, 0x380, 0x0f0, 0x1a0, 0x012,
        ]
        
        for roundConstant in roundConstants {
            let p = (a ^ b ^ c).rotatingLanes(right: 1)
            let e = p.rotated(left: 5) ^ p.rotated(left: 14)
            a ^= e
            b ^= e
            c ^= e
            
            b.rotateLanes(right: 1)
            c.rotate(left: 11)
            
            a.x ^= roundConstant
            
            a ^= ~b & c
            b ^= ~c & a
            c ^= ~a & b
            
            b.rotate(left: 1)
            c.rotateLanes(right: 2) // TODO: rhoEastPartTwo
            c.rotate(left: 8)
        }
        
        self.pack(a, b, c)
    }
}

fileprivate extension SIMD4 where Scalar == UInt32 {
    @inline(__always)
    func rotated(left count: Scalar) -> Self {
        let countComplement = Scalar(Scalar.bitWidth) - count
        return (self &<< count) | (self &>> countComplement)
    }
    
    @inline(__always)
    mutating func rotate(left count: Scalar) {
        self = self.rotated(left: count)
    }
    
    @inline(__always)
    func rotatingLanes(right count: Int) -> Self {
        switch count {
        case 1:
            return self[SIMD4(3, 0, 1, 2)]
        case 2:
            return self[SIMD4(2, 3, 0, 1)]
        default:
            fatalError()
        }
    }
    
    @inline(__always)
    mutating func rotateLanes(right count: Int) {
        self = self.rotatingLanes(right: count)
    }
}

extension Xoodoo: RandomAccessCollection {
    public typealias Element = UInt8
    
    public typealias Index = Int
    
    @inline(__always)
    public var count: Int {
        48
    }
    
    @inline(__always)
    public var startIndex: Self.Index {
        0
    }
    
    @inline(__always)
    public var endIndex: Self.Index {
        48
    }
    
    @inline(__always)
    public subscript(index: Self.Index) -> Self.Element {
        get {
            state[index]
        }
        _modify {
            yield &state[index]
        }
    }
    
    @inline(__always)
    public var first: Self.Element {
        get {
            self[startIndex]
        }
        _modify {
            yield &state[startIndex]
        }
    }
    
    @inline(__always)
    public var last: Self.Element {
        get {
            self[endIndex - 1]
        }
        _modify {
            yield &state[endIndex - 1]
        }
    }
}
