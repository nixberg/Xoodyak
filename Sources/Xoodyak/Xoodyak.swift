import Foundation
import Xoodoo

enum Flag: UInt8 {
    case zero       = 0x00
    case absorbKey  = 0x02
    case absorb     = 0x03
    case ratchet    = 0x10
    case squeezeKey = 0x20
    case squeeze    = 0x40
    case crypt      = 0x80
}

enum Mode {
    case hash
    case keyed
}

struct Rates {
    static let hash    = 16
    static let input   = 44
    static let output  = 24
    static let ratchet = 16
    
    let absorb: Int
    let squeeze: Int
}

enum Phase {
    case up
    case down
}

public struct Xoodyak {
    var mode: Mode
    var rates: Rates
    var phase = Phase.up
    var xoodoo = Xoodoo()
    
    public init() {
        mode = .hash
        rates = Rates(absorb: Rates.hash, squeeze: Rates.hash)
    }
    
    public init<Key, ID, Counter>(key: Key, id: ID?, counter: Counter?) where Key: DataProtocol, ID: DataProtocol, Counter: DataProtocol {
        precondition(!key.isEmpty)
        self.init()
        self.absorbKey(key: key, id: id, counter: counter)
    }
    
    private mutating func down(_ flag: Flag) {
        phase = .down
        xoodoo[0] ^= 0x01
        xoodoo[47] ^= (mode == .hash) ? (flag.rawValue & 0x01) : flag.rawValue
    }
    
    private mutating func down<Block>(_ block: Block, _ flag: Flag) where Block: DataProtocol {
        phase = .down
        for (i, byte) in block.enumerated() {
            xoodoo[i] ^= byte
        }
        xoodoo[block.count] ^= 0x01
        xoodoo[47] ^= (mode == .hash) ? (flag.rawValue & 0x01) : flag.rawValue
    }
    
    private mutating func up(_ flag: Flag) {
        phase = .up
        if mode != .hash {
            xoodoo[47] ^= flag.rawValue
        }
        xoodoo.permute()
    }
    
    private mutating func up<Block>(_ count: Int, to block: inout Block, _ flag: Flag) where Block: MutableDataProtocol {
        self.up(flag)
        for i in 0..<count {
            block.append(xoodoo[i])
        }
    }
    
    private mutating func absorbAny<Input>(_ input: Input, rate: Int, flag: Flag) where Input: DataProtocol {
        var input = input[...]
        var flag = flag
        
        repeat {
            let block = input.prefix(rate)
            input = input.dropFirst(rate)
            
            if phase != .up {
                self.up(.zero)
            }
            
            self.down(block, flag)
            flag = .zero
            
        } while !input.isEmpty
    }
    
    private mutating func absorbKey<Key, ID, Counter>(key: Key, id: ID?, counter: Counter?) where Key: DataProtocol, ID: DataProtocol, Counter: DataProtocol {
        let id = id?.map { $0 } ?? []
        
        precondition(key.count + id.count <= Rates.input - 1)
        
        mode = .keyed
        rates = Rates(absorb: Rates.input, squeeze: Rates.output)
        
        var data = [UInt8](key)
        data.append(contentsOf: id)
        data.append(UInt8(id.count))
        self.absorbAny(data, rate: rates.absorb, flag: .absorbKey)
        
        if let counter = counter, !counter.isEmpty {
            self.absorbAny(counter, rate: 1, flag: .zero)
        }
    }
    
    private mutating func crypt<Input, Output>(_ input: Input, to output: inout Output, decrypt: Bool) where Input: DataProtocol, Output: MutableDataProtocol {
        var input = input[...]
        var flag = Flag.crypt
        
        repeat {
            let block = input.prefix(Rates.output)
            input = input.dropFirst(Rates.output)
            
            up(flag)
            flag = .zero
            
            for (i, byte) in block.enumerated() {
                output.append(byte ^ xoodoo[i])
            }
            
            if decrypt {
                self.down(output.suffix(block.count), .zero)
            } else {
                self.down(block, .zero)
            }
            
        } while !input.isEmpty
    }
    
    private mutating func squeezeAny<Output>(_ count: Int, to output: inout Output, flag: Flag) where Output: MutableDataProtocol  {
        var blockSize = min(count, rates.squeeze)
        var count = count - blockSize
        
        self.up(blockSize, to: &output, flag)
        
        while count > 0 {
            blockSize = min(count, rates.squeeze)
            count -= blockSize
            
            self.down(.zero)
            self.up(blockSize, to: &output, .zero)
        }
    }
    
    public mutating func absorb<Input>(_ input: Input) where Input: DataProtocol {
        self.absorbAny(input, rate: rates.absorb, flag: .absorb)
    }
    
    public mutating func encrypt<Input, Output>(_ plaintext: Input, to ciphertext: inout Output) where Input: DataProtocol, Output: MutableDataProtocol {
        precondition(mode == .keyed)
        self.crypt(plaintext, to: &ciphertext, decrypt: false)
    }
    
    public mutating func decrypt<Input, Output>(_ ciphertext: Input, to plaintext: inout Output) where Input: DataProtocol, Output: MutableDataProtocol {
        precondition(mode == .keyed)
        self.crypt(ciphertext, to: &plaintext, decrypt: true)
    }
    
    public mutating func squeeze<Output>(_ count: Int, to output: inout Output) where Output: MutableDataProtocol {
        self.squeezeAny(count, to: &output, flag: .squeeze)
    }
    
    public mutating func squeezeKey<Output>(_ count: Int, to output: inout Output) where Output: MutableDataProtocol {
        precondition(mode == .keyed)
        self.squeezeAny(count, to: &output, flag: .squeezeKey)
    }
    
    public mutating func ratchet() {
        precondition(mode == .keyed)
        var buffer = [UInt8]()
        buffer.reserveCapacity(Rates.ratchet)
        self.squeezeAny(Rates.ratchet, to: &buffer, flag: .ratchet)
        self.absorbAny(buffer, rate: rates.absorb, flag: .zero)
    }
}

public extension Xoodyak {
    mutating func encrypt<Input>(_ plaintext: Input) -> [UInt8] where Input: DataProtocol {
        var output = [UInt8]()
        output.reserveCapacity(plaintext.count + 16)
        self.encrypt(plaintext, to: &output)
        return output
    }
    
    mutating func decrypt<Input>(_ ciphertext: Input) -> [UInt8] where Input: DataProtocol {
        var output = [UInt8]()
        output.reserveCapacity(ciphertext.count + 16)
        self.decrypt(ciphertext, to: &output)
        return output
    }
    
    mutating func squeeze(_ count: Int) -> [UInt8] {
        var output = [UInt8]()
        output.reserveCapacity(count)
        self.squeeze(count, to: &output)
        return output
    }
    
    mutating func squeezeKey(_ count: Int) -> [UInt8] {
        var output = [UInt8]()
        output.reserveCapacity(count)
        self.squeezeKey(count, to: &output)
        return output
    }
}
