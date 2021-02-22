public struct Xoodoo {
    private var state: [UInt8]
    
    public init() {
        state = .init(repeating: 0, count: 48)
    }
    
    @inline(__always)
    public subscript(index: Int) -> UInt8 {
        get {
            state[index]
        }
        set {
            state[index] = newValue
        }
    }
    
    @inline(__always)
    private func unpack() -> (SIMD4<UInt32>, SIMD4<UInt32>, SIMD4<UInt32>) {
        var state = self.state[...]
        let a = SIMD4(littleEndianBytes: state.prefix(16))
        state = state.dropFirst(16)
        let b = SIMD4(littleEndianBytes: state.prefix(16))
        state = state.dropFirst(16)
        let c = SIMD4(littleEndianBytes: state.prefix(16))
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
        
        func round(_ constant: UInt32) {
            let p = (a ^ b ^ c).rotated()
            let e = p.rotatingLanes(by: 5) ^ p.rotatingLanes(by: 14)
            a ^= e
            b ^= e
            c ^= e
            
            b.rotate()
            c.rotateLanes(by: 11)
            
            a.x ^= constant
            
            a ^= ~b & c
            b ^= ~c & a
            c ^= ~a & b
            
            b.rotateLanes(by: 1)
            c.rotateTwice()
            c.rotateLanes(by: 8)
        }
        
        round(0x058)
        round(0x038)
        round(0x3c0)
        round(0x0d0)
        round(0x120)
        round(0x014)
        round(0x060)
        round(0x02c)
        round(0x380)
        round(0x0f0)
        round(0x1a0)
        round(0x012)
        
        self.pack(a, b, c)
    }
}

fileprivate extension SIMD4 where Scalar == UInt32 {
    @inline(__always)
    init(littleEndianBytes bytes: ArraySlice<UInt8>) {
        assert(bytes.count == Self.scalarCount * Scalar.bitWidth / 8)
        
        var bytes = bytes
        let x = UInt32(littleEndianBytes: bytes.prefix(4))
        bytes = bytes.dropFirst(4)
        let y = UInt32(littleEndianBytes: bytes.prefix(4))
        bytes = bytes.dropFirst(4)
        let z = UInt32(littleEndianBytes: bytes.prefix(4))
        bytes = bytes.dropFirst(4)
        let w = UInt32(littleEndianBytes: bytes.prefix(4))
        
        self = .init(x, y, z, w)
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
    @inline(__always)
    init(littleEndianBytes bytes: ArraySlice<UInt8>) {
        assert(bytes.count == Self.bitWidth / 8)
        self = bytes
            .reversed()
            .reduce(0) { $0 << 8 | Self($1) }
    }
}

fileprivate extension Array where Element == UInt8 {
    @inline(__always)
    mutating func append(littleEndianBytesOf x: SIMD4<UInt32>) {
        for i in x.indices {
            for count in stride(from: 0, to: 32, by: 8) {
                self.append(UInt8(truncatingIfNeeded: x[i] >> count))
            }
        }
    }
}
