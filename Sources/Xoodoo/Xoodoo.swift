public struct Xoodoo {
    var a: (SIMD4<UInt32>, SIMD4<UInt32>, SIMD4<UInt32>)
    
    public init() {
        a = (.zero, .zero, .zero)
    }
    
    public subscript(index: Int) -> UInt8 {
        get {
            assert((0..<48).contains(index))
            return withUnsafePointer(to: a) {
                $0.withMemoryRebound(to: UInt8.self, capacity: 48) {
                    $0[index]
                }
            }
        }
        set {
            assert((0..<48).contains(index))
            return withUnsafeMutablePointer(to: &a) {
                $0.withMemoryRebound(to: UInt8.self, capacity: 48) {
                    $0[index] = newValue
                }
            }
        }
    }
    
    private mutating func unpack() {
        for i in 0..<4 {
            a.0[i] = UInt32(littleEndian: a.0[i])
            a.1[i] = UInt32(littleEndian: a.1[i])
            a.2[i] = UInt32(littleEndian: a.2[i])
        }
    }
    
    private mutating func pack() {
        for i in 0..<4 {
            a.0[i] = a.0[i].littleEndian
            a.1[i] = a.1[i].littleEndian
            a.2[i] = a.2[i].littleEndian
        }
    }
    
    public mutating func permute() {
        func round(_ constant: UInt32) {
            let p = (a.0 ^ a.1 ^ a.2).rotated()
            let e = p.rotatingLanes(by: 5) ^ p.rotatingLanes(by: 14)
            a.0 ^= e
            a.1 ^= e
            a.2 ^= e
            
            a.1.rotate()
            a.2.rotateLanes(by: 11)
            
            a.0.x ^= constant
            
            a.0 ^= ~a.1 & a.2
            a.1 ^= ~a.2 & a.0
            a.2 ^= ~a.0 & a.1
            
            a.1.rotateLanes(by: 1)
            a.2.rotateTwice()
            a.2.rotateLanes(by: 8)
        }
        
        self.unpack()
        
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
        
        self.pack()
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
