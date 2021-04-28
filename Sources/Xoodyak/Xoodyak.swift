import Foundation
import Xoodoo

enum Phase {
    case up
    case down
}

enum Mode {
    case hash
    case keyed
}

struct Rate {
    let rawValue: Int
    fileprivate static let hash = Self(rawValue: 16)
}

enum Flag: UInt8 {
    case zero       = 0x00
    case absorbKey  = 0x02
    case absorb     = 0x03
    case ratchet    = 0x10
    case squeezeKey = 0x20
    case squeeze    = 0x40
    case crypt      = 0x80
}

public struct Xoodyak {
    var phase = Phase.up
    var state = Xoodoo()
    var mode  = Mode.hash
    var rates = (absorb: Rate.hash, squeeze: Rate.hash)
    
    public init() {}
    
    mutating func down(_ flag: Flag) {
        phase = .down
        state.first ^= 0x01
        state.last ^= (mode == .hash) ? (flag.rawValue & 0x01) : flag.rawValue
    }
    
    mutating func down<Block>(_ block: Block, _ flag: Flag) where Block: DataProtocol {
        phase = .down
        for (i, byte) in zip(state.indices, block) {
            state[i] ^= byte
        }
        state[block.count] ^= 0x01
        state.last ^= (mode == .hash) ? (flag.rawValue & 0x01) : flag.rawValue
    }
    
    mutating func up(_ flag: Flag) {
        phase = .up
        if mode != .hash {
            state.last ^= flag.rawValue
        }
        state.permute()
    }
    
    mutating func up<Block>(_ count: Int, to block: inout Block, _ flag: Flag)
    where Block: MutableDataProtocol {
        self.up(flag)
        block.append(contentsOf: state.prefix(count))
    }
    
    mutating func absorbAny<Input>(_ input: Input, rate: Rate, flag: Flag)
    where Input: DataProtocol {
        var input = input[...]
        var flag = flag
        
        repeat {
            let block = input.prefix(rate.rawValue)
            input = input.dropFirst(rate.rawValue)
            
            if phase != .up {
                self.up(.zero)
            }
            
            self.down(block, flag)
            flag = .zero
            
        } while !input.isEmpty
    }
    
    mutating func squeezeAny<Output>(_ count: Int, to output: inout Output, flag: Flag)
    where Output: MutableDataProtocol  {
        var blockSize = min(count, rates.squeeze.rawValue)
        var count = count - blockSize
        
        self.up(blockSize, to: &output, flag)
        
        while count > 0 {
            blockSize = min(count, rates.squeeze.rawValue)
            count -= blockSize
            
            self.down(.zero)
            self.up(blockSize, to: &output, .zero)
        }
    }
    
    @inline(__always)
    public mutating func absorb<Input>(_ input: Input) where Input: DataProtocol {
        self.absorbAny(input, rate: rates.absorb, flag: .absorb)
    }
    
    @inline(__always)
    public mutating func squeeze<Output>(_ count: Int, to output: inout Output)
    where Output: MutableDataProtocol {
        self.squeezeAny(count, to: &output, flag: .squeeze)
    }
}

public extension Xoodyak {
    mutating func squeeze(_ count: Int) -> [UInt8] {
        var output = [UInt8]()
        output.reserveCapacity(count)
        self.squeeze(count, to: &output)
        return output
    }
}
