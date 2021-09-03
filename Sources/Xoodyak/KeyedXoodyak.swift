fileprivate extension Rate {
    static let keyedInput  = Self(rawValue: 44)
    static let keyedOutput = Self(rawValue: 24)
    static let ratchet     = Self(rawValue: 16)
    static let counter     = Self(rawValue:  1)
}

public struct KeyedXoodyak {
    private var xoodyak = Xoodyak()
    
    public init<Key, ID, Counter>(key: Key, id: ID, counter: Counter)
    where
        Key: Collection, Key.Element == UInt8,
        ID: Collection, ID.Element == UInt8,
        Counter: Collection, Counter.Element == UInt8
   {
        precondition(!key.isEmpty)
        precondition(key.count + id.count + 1 <= Rate.keyedInput.rawValue)
        
        xoodyak.mode = .keyed
        xoodyak.rates = (absorb: .keyedInput, squeeze: .keyedOutput)
        
        var buffer: [UInt8] = []
        buffer.reserveCapacity(key.count + id.count + 1)
        buffer.append(contentsOf: key)
        buffer.append(contentsOf: id)
        buffer.append(UInt8(truncatingIfNeeded: id.count))
        
        xoodyak.absorbAny(buffer, rate: xoodyak.rates.absorb, flag: .absorbKey)
        
        if !counter.isEmpty {
            xoodyak.absorbAny(counter, rate: .counter, flag: .zero)
        }
    }
    
    private mutating func crypt<Input, Output>(
        _ input: Input,
        to output: inout Output,
        decrypt: Bool
    ) where
        Input: Collection, Input.Element == UInt8,
        Output: RangeReplaceableCollection, Output.Element == UInt8
    {
        var input = input[...]
        var flag = Flag.crypt
        
        repeat {
            let block = input.prefix(Rate.keyedOutput.rawValue)
            input = input.dropFirst(Rate.keyedOutput.rawValue)
            
            xoodyak.up(flag)
            flag = .zero
            
            for (byte, stateByte) in zip(block, xoodyak.state) {
                output.append(byte ^ stateByte)
            }
            
            if decrypt {
                xoodyak.down(output.suffix(block.count), .zero)
            } else {
                xoodyak.down(block, .zero)
            }
            
        } while !input.isEmpty
    }
    
    @inline(__always)
    public mutating func absorb<Input>(_ input: Input)
    where Input: Collection, Input.Element == UInt8 {
        xoodyak.absorbAny(input, rate: xoodyak.rates.absorb, flag: .absorb)
    }
    
    @inline(__always)
    public mutating func encrypt<Input, Output>(_ plaintext: Input, to ciphertext: inout Output)
    where
        Input: Collection, Input.Element == UInt8,
        Output: RangeReplaceableCollection, Output.Element == UInt8
    {
        self.crypt(plaintext, to: &ciphertext, decrypt: false)
    }
    
    @inline(__always)
    public mutating func decrypt<Input, Output>(_ ciphertext: Input, to plaintext: inout Output)
    where
        Input: Collection, Input.Element == UInt8,
        Output: RangeReplaceableCollection, Output.Element == UInt8
    {
        self.crypt(ciphertext, to: &plaintext, decrypt: true)
    }
    
    @inline(__always)
    public mutating func squeeze<Output>(to output: inout Output, count: Int)
    where Output: RangeReplaceableCollection, Output.Element == UInt8 {
        xoodyak.squeezeAny(to: &output, count: count, flag: .squeeze)
    }
    
    @inline(__always)
    public mutating func squeezeKey<Output>(to output: inout Output, count: Int)
    where Output: RangeReplaceableCollection, Output.Element == UInt8 {
        xoodyak.squeezeAny(to: &output, count: count, flag: .squeezeKey)
    }
    
    public mutating func ratchet() {
        var buffer = [UInt8]()
        buffer.reserveCapacity(Rate.ratchet.rawValue)
        xoodyak.squeezeAny(to: &buffer, count: Rate.ratchet.rawValue, flag: .ratchet)
        xoodyak.absorbAny(buffer, rate: xoodyak.rates.absorb, flag: .zero)
    }
}

public extension KeyedXoodyak {
    @inline(__always)
    init<Key>(key: Key) where Key: Collection, Key.Element == UInt8 {
        self.init(key: key, id: [], counter: [])
    }
    
    @inline(__always)
    init<Key, ID>(key: Key, id: ID)
    where Key: Collection, Key.Element == UInt8, ID: Collection, ID.Element == UInt8 {
        self.init(key: key, id: id, counter: [])
    }
    
    @inline(__always)
    init<Key, Counter>(key: Key, counter: Counter)
    where Key: Collection, Key.Element == UInt8, Counter: Collection, Counter.Element == UInt8 {
        self.init(key: key, id: [], counter: counter)
    }
    
    mutating func encrypt<Input>(_ plaintext: Input) -> [UInt8]
    where Input: Collection, Input.Element == UInt8 {
        var output = [UInt8]()
        output.reserveCapacity(plaintext.count + 16)
        self.encrypt(plaintext, to: &output)
        return output
    }
    
    mutating func decrypt<Input>(_ ciphertext: Input) -> [UInt8]
    where Input: Collection, Input.Element == UInt8 {
        var output = [UInt8]()
        output.reserveCapacity(ciphertext.count + 16)
        self.decrypt(ciphertext, to: &output)
        return output
    }
    
    @inline(__always)
    mutating func squeeze(count: Int) -> [UInt8] {
        xoodyak.squeeze(count: count)
    }
    
    mutating func squeezeKey(count: Int) -> [UInt8] {
        var output = [UInt8]()
        output.reserveCapacity(count)
        self.squeezeKey(to: &output, count: count)
        return output
    }
}
