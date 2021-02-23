import Foundation
import Xoodoo

public struct KeyedXoodyak {
    private var xoodyak = Xoodyak()
    
    public init<Key, ID, Counter>(key: Key, id: ID, counter: Counter)
    where Key: DataProtocol, ID: DataProtocol, Counter: DataProtocol {
        precondition(!key.isEmpty)
        
        xoodyak.mode = .keyed
        xoodyak.rates = (absorb: .keyedInput, squeeze: .keyedOutput)
        
        var buffer = [UInt8](key)
        buffer.append(contentsOf: id)
        buffer.append(UInt8(truncatingIfNeeded: id.count))
        precondition(buffer.count <= Rate.keyedInput.rawValue)
        
        xoodyak.absorbAny(buffer, rate: xoodyak.rates.absorb, flag: .absorbKey)
        
        if !counter.isEmpty {
            xoodyak.absorbAny(counter, rate: .counter, flag: .zero)
        }
    }
    
    private mutating func crypt<Input, Output>(
        _ input: Input,
        to output: inout Output,
        decrypt: Bool
    ) where Input: DataProtocol, Output: MutableDataProtocol {
        
        var input = input[...]
        var flag = Flag.crypt
        
        repeat {
            let block = input.prefix(Rate.keyedOutput.rawValue)
            input = input.dropFirst(Rate.keyedOutput.rawValue)
            
            xoodyak.up(flag)
            flag = .zero
            
            for (i, byte) in block.enumerated() {
                output.append(byte ^ xoodyak.state[i])
            }
            
            if decrypt {
                xoodyak.down(output.suffix(block.count), .zero)
            } else {
                xoodyak.down(block, .zero)
            }
            
        } while !input.isEmpty
    }
    
    @inline(__always)
    public mutating func absorb<Input>(_ input: Input) where Input: DataProtocol {
        xoodyak.absorbAny(input, rate: xoodyak.rates.absorb, flag: .absorb)
    }
    
    public mutating func encrypt<Input, Output>(_ plaintext: Input, to ciphertext: inout Output)
    where Input: DataProtocol, Output: MutableDataProtocol {
        self.crypt(plaintext, to: &ciphertext, decrypt: false)
    }
    
    public mutating func decrypt<Input, Output>(_ ciphertext: Input, to plaintext: inout Output)
    where Input: DataProtocol, Output: MutableDataProtocol {
        self.crypt(ciphertext, to: &plaintext, decrypt: true)
    }
    
    @inline(__always)
    public mutating func squeeze<Output>(_ count: Int, to output: inout Output)
    where Output: MutableDataProtocol {
        xoodyak.squeezeAny(count, to: &output, flag: .squeeze)
    }
    
    public mutating func squeezeKey<Output>(_ count: Int, to output: inout Output)
    where Output: MutableDataProtocol {
        xoodyak.squeezeAny(count, to: &output, flag: .squeezeKey)
    }
    
    public mutating func ratchet() {
        var buffer = [UInt8]()
        buffer.reserveCapacity(Rate.ratchet.rawValue)
        xoodyak.squeezeAny(Rate.ratchet.rawValue, to: &buffer, flag: .ratchet)
        xoodyak.absorbAny(buffer, rate: xoodyak.rates.absorb, flag: .zero)
    }
}

public extension KeyedXoodyak {
    init<Key>(key: Key) where Key: DataProtocol {
        self.init(key: key, id: [], counter: [])
    }
    
    init<Key, ID>(key: Key, id: ID) where Key: DataProtocol, ID: DataProtocol {
        self.init(key: key, id: id, counter: [])
    }
    
    init<Key, Counter>(key: Key, counter: Counter) where Key: DataProtocol, Counter: DataProtocol {
        self.init(key: key, id: [], counter: counter)
    }
    
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
    
    @inline(__always)
    mutating func squeeze(_ count: Int) -> [UInt8] {
        xoodyak.squeeze(count)
    }
    
    mutating func squeezeKey(_ count: Int) -> [UInt8] {
        var output = [UInt8]()
        output.reserveCapacity(count)
        self.squeezeKey(count, to: &output)
        return output
    }
}
