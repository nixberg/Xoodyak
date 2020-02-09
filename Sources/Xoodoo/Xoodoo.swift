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
            a.2.rhoEastPartTwo()
        }
        
        [0x058, 0x038, 0x3c0, 0x0d0, 0x120, 0x014, 0x060, 0x02c, 0x380, 0x0f0, 0x1a0, 0x012].forEach(round)
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
    mutating func rhoEastPartTwo() {
        withUnsafeMutablePointer(to: &self) {
            $0.withMemoryRebound(to: SIMD16<UInt8>.self, capacity: 1) {
                $0.pointee = $0.pointee[SIMD16(
                    11,  8,  9, 10,
                    15, 12, 13, 14,
                     3,  0,  1,  2,
                     7,  4,  5,  6
                )]
            }
        }
    }
}
