import EndianBytes

public struct Xoodoo {
    private var state: [UInt8] = .init(repeating: 0, count: 48)
    
    public init() {}
    
    @inline(__always)
    private func unpack() -> (SIMD4<UInt32>, SIMD4<UInt32>, SIMD4<UInt32>) {
        let a: SIMD4<UInt32> = .init(littleEndianBytes: state[00..<16])!
        let b: SIMD4<UInt32> = .init(littleEndianBytes: state[16..<32])!
        let c: SIMD4<UInt32> = .init(littleEndianBytes: state[32..<48])!
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
            let p = (a ^ b ^ c).rotated()
            let e = p.rotatingLanes(by: 5) ^ p.rotatingLanes(by: 14)
            a ^= e
            b ^= e
            c ^= e
            
            b.rotate()
            c.rotateLanes(by: 11)
            
            a.x ^= roundConstant
            
            a ^= ~b & c
            b ^= ~c & a
            c ^= ~a & b
            
            b.rotateLanes(by: 1)
            c.rotateTwice()
            c.rotateLanes(by: 8)
        }
        
        self.pack(a, b, c)
    }
}

fileprivate extension SIMD4 where Scalar == UInt32 {
    @inline(__always)
    func rotatingLanes(by n: UInt32) -> Self {
        (self &>> (32 &- n)) | (self &<< n)
    }
    
    @inline(__always)
    mutating func rotateLanes(by n: UInt32) {
        self = self.rotatingLanes(by: n)
    }
    
    @inline(__always)
    func rotated() -> Self {
        self[SIMD4(3, 0, 1, 2)]
    }
    
    @inline(__always)
    mutating func rotate() {
        self = self.rotated()
    }
    
    @inline(__always)
    mutating func rotateTwice() {
        self = self[SIMD4(2, 3, 0, 1)]
    }
}

extension Xoodoo: RandomAccessCollection {
    public typealias Element = UInt8
    
    public typealias Index = Array<UInt8>.Index
    
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
    public func index(after i: Self.Index) -> Self.Index {
        state.index(after: i)
    }
    
    @inline(__always)
    public func index(before i: Self.Index) -> Self.Index {
        state.index(before: i)
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
