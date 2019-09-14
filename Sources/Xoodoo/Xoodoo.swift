public struct Xoodoo {
    var a: (SIMD4<UInt32>, SIMD4<UInt32>, SIMD4<UInt32>)
    
    public init() {
        a = (.zero, .zero, .zero)
    }
    
    public subscript(index: Int) -> UInt8 {
        get {
            withUnsafePointer(to: a) {
                $0.withMemoryRebound(to: UInt8.self, capacity: 48) {
                    $0[index]
                }
            }
        }
        set {
            withUnsafeMutablePointer(to: &a) {
                $0.withMemoryRebound(to: UInt8.self, capacity: 48) {
                    $0[index] = newValue
                }
            }
        }
    }
    
    public var last: UInt8 {
        get {
            self[47]
        }
        set {
            self[47] = newValue
        }
    }
    
    public mutating func permute() {
        [0x058 as UInt32, 0x038, 0x3c0, 0x0d0, 0x120, 0x014, 0x060, 0x02c, 0x380, 0x0f0, 0x1a0, 0x012].forEach {
            // θ:
            let p = (a.0 ^ a.1 ^ a.2).rotated()
            let e = p.rotatingLanes(by: 5) ^ p.rotatingLanes(by: 14)
            a.0 ^= e
            a.1 ^= e
            a.2 ^= e
            
            // ρ-west:
            a.1.rotate()
            a.2.rotateLanes(by: 11)
            
            // ι:
            a.0.x ^= $0
            
            // χ:
            a.0 ^= ~a.1 & a.2
            a.1 ^= ~a.2 & a.0
            a.2 ^= ~a.0 & a.1
            
            // ρ-east:
            a.1.rotateLanes(by: 1)
            a.2.rhoEastPartTwo()
        }
    }
}

extension SIMD4 where Scalar == UInt32 {
    @inline(__always)
    func rotatingLanes(by n: UInt32) -> SIMD4<UInt32> {
        (self &>> (32 &- n)) | (self &<< n)
    }
    
    @inline(__always)
    mutating func rotateLanes(by n: UInt32) {
        self = self.rotatingLanes(by: n)
    }
    
    @inline(__always)
    func rotated() -> SIMD4<UInt32> {
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
