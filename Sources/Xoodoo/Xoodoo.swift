import Foundation

public struct Xoodoo {
    private var state: [UInt8] = .init(repeating: 0, count: 48)
    
    public init() {}
    
    @inline(__always)
    private func unpack() -> (SIMD4<UInt32>, SIMD4<UInt32>, SIMD4<UInt32>) {
        let a = SIMD4(littleEndianBytes: state[00..<16])
        let b = SIMD4(littleEndianBytes: state[16..<32])
        let c = SIMD4(littleEndianBytes: state[32..<48])
        return (a, b, c)
    }
    
    @inline(__always)
    private mutating func pack(_ a: SIMD4<UInt32>, _ b: SIMD4<UInt32>, _ c: SIMD4<UInt32>) {
        state.removeAll(keepingCapacity: true)
        state.append(littleEndianBytesOf: a)
        state.append(littleEndianBytesOf: b)
        state.append(littleEndianBytesOf: c)
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
    init(littleEndianBytes bytes: ArraySlice<UInt8>) {
        assert(bytes.count * 8 == Self.scalarCount * Scalar.bitWidth)
        var result = Self()
        var bytes = bytes
        for i in result.indices {
            result[i] = UInt32(littleEndianBytes: bytes.prefix(4))
            bytes = bytes.dropFirst(4)
        }
        self = result
    }
    
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

fileprivate extension UInt32 {
    init(littleEndianBytes bytes: ArraySlice<UInt8>) {
        assert(bytes.count * 8 == Self.bitWidth)
        self = bytes.reversed().reduce(0, { $0 << 8 | Self($1) })
    }
}

fileprivate extension Array where Element == UInt8 {
    mutating func append(littleEndianBytesOf x: SIMD4<UInt32>) {
        for i in x.indices {
            for count in stride(from: 0, to: 32, by: 8) {
                self.append(UInt8(truncatingIfNeeded: x[i] >> count))
            }
        }
    }
}

extension Xoodoo: RandomAccessCollection {
    public typealias Element = UInt8
    
    public typealias Index = Array<UInt8>.Index
    
    public typealias Indices = Array<UInt8>.Indices
    
    public typealias SubSequence = Array<UInt8>.SubSequence
    
    @inline(__always)
    public var startIndex: Int {
        0
    }
    
    @inline(__always)
    public var endIndex: Int {
        48
    }
    
    @inline(__always)
    public var indices: Self.Indices {
        (0..<48)
    }
    
    @inline(__always)
    public func formIndex(after i: inout Self.Index) {
        state.formIndex(after: &i)
    }
    
    @inline(__always)
    public func formIndex(before i: inout Self.Index) {
        state.formIndex(before: &i)
    }
    
    @inline(__always)
    public subscript(index: Self.Index) -> Self.Element {
        get {
            state[index]
        }
        set {
            state[index] = newValue
        }
    }
    
    @inline(__always)
    public subscript(bounds: Self.Indices) -> Self.SubSequence {
        get {
            state[bounds]
        }
        set {
            state[bounds] = newValue
        }
    }
}

extension Xoodoo {
    @inline(__always)
    public var first: Self.Element {
        get {
            self[0]
        }
        set {
            self[0] = newValue
        }
    }
    
    @inline(__always)
    public var last: Self.Element {
        get {
            self[47]
        }
        set {
            self[47] = newValue
        }
    }
}

extension Xoodoo: DataProtocol {
    public typealias Regions = Array<UInt8>.Regions
    
    @inline(__always)
    public var regions: Self.Regions {
        state.regions
    }
}
