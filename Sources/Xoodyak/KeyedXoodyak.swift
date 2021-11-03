import Duplex

fileprivate extension Rate {
    static let keyedInput  = Self(rawValue: 44)
    static let keyedOutput = Self(rawValue: 24)
    static let ratchet     = Self(rawValue: 16)
    static let counter     = Self(rawValue:  1)
}

public struct KeyedXoodyak: KeyedDuplexProtocol {
    public typealias Output = Xoodyak.Output
    
    public typealias EncryptionOutput = [UInt8]
    
    public typealias DecryptionOutput = [UInt8]
    
    public static var defaultOutputByteCount = Xoodyak.defaultOutputByteCount
    
    private var xoodyak: Xoodyak = .init()
    
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
        
        xoodyak.absorbAny(contentsOf: buffer, rate: xoodyak.rates.absorb, flag: .absorbKey)
        
        if !counter.isEmpty {
            xoodyak.absorbAny(contentsOf: counter, rate: .counter, flag: .zero)
        }
    }
    
    private mutating func crypt<Bytes, Output>(
        contentsOf bytes: Bytes,
        to output: inout Output,
        decrypt: Bool
    ) where
        Bytes: Collection, Bytes.Element == UInt8,
        Output: RangeReplaceableCollection, Output.Element == UInt8
    {
        var bytes = bytes[...]
        var flag = Flag.crypt
        
        repeat {
            let block = bytes.prefix(Rate.keyedOutput.rawValue)
            bytes = bytes.dropFirst(Rate.keyedOutput.rawValue)
            
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
            
        } while !bytes.isEmpty
    }
    
    public mutating func absorb<Bytes>(contentsOf bytes: Bytes)
    where Bytes: Sequence, Bytes.Element == UInt8 {
        xoodyak.absorb(contentsOf: bytes)
    }
    
    public mutating func absorb<Bytes>(contentsOf bytes: Bytes)
    where Bytes: Collection, Bytes.Element == UInt8 {
        xoodyak.absorb(contentsOf: bytes)
    }
    
    public mutating func encrypt<Bytes, Output>(contentsOf bytes: Bytes, to output: inout Output)
    where
        Bytes: Sequence, Bytes.Element == UInt8,
        Output: RangeReplaceableCollection, Output.Element == UInt8
    {
        self.encrypt(contentsOf: Array(bytes), to: &output)
    }
    
    public mutating func encrypt<Bytes, Output>(contentsOf bytes: Bytes, to output: inout Output)
    where
        Bytes: Collection, Bytes.Element == UInt8,
        Output: RangeReplaceableCollection, Output.Element == UInt8
    {
        self.crypt(contentsOf: bytes, to: &output, decrypt: false)
    }
    
    public mutating func encrypt<Bytes>(contentsOf bytes: Bytes) -> Self.EncryptionOutput
    where Bytes: Sequence, Bytes.Element == UInt8 {
        var output: [UInt8] = []
        self.encrypt(contentsOf: bytes, to: &output)
        return output
    }
    
    public mutating func decrypt<Bytes, Output>(contentsOf bytes: Bytes, to output: inout Output)
    where
        Bytes: Sequence, Bytes.Element == UInt8,
        Output: RangeReplaceableCollection, Output.Element == UInt8
    {
        self.decrypt(contentsOf: Array(bytes), to: &output)
    }
    
    public mutating func decrypt<Bytes, Output>(contentsOf bytes: Bytes, to output: inout Output)
    where
        Bytes: Collection, Bytes.Element == UInt8,
        Output: RangeReplaceableCollection, Output.Element == UInt8
    {
        self.crypt(contentsOf: bytes, to: &output, decrypt: true)
    }
    
    public mutating func decrypt<Bytes>(contentsOf bytes: Bytes) -> Self.DecryptionOutput
    where Bytes: Sequence, Bytes.Element == UInt8 {
        var output: [UInt8] = []
        self.decrypt(contentsOf: bytes, to: &output)
        return output
    }
    
    public mutating func squeeze<Output>(to output: inout Output, outputByteCount: Int
    ) where Output: RangeReplaceableCollection, Output.Element == UInt8 {
        xoodyak.squeeze(to: &output, outputByteCount: outputByteCount)
    }
    
    public mutating func squeeze(outputByteCount: Int) -> Self.Output {
        xoodyak.squeeze(outputByteCount: outputByteCount)
    }
    
    public mutating func squeezeKey<Output>(
        to output: inout Output,
        outputByteCount: Int = Self.defaultOutputByteCount
    ) where Output: RangeReplaceableCollection, Output.Element == UInt8 {
        xoodyak.squeezeAny(to: &output, count: outputByteCount, flag: .squeezeKey)
    }
    
    mutating func squeezeKey(outputByteCount: Int = Self.defaultOutputByteCount) -> [UInt8] {
        var output: [UInt8] = []
        output.reserveCapacity(outputByteCount)
        self.squeezeKey(to: &output, outputByteCount: outputByteCount)
        return output
    }
    
    public mutating func ratchet() {
        var buffer: [UInt8] = []
        buffer.reserveCapacity(Rate.ratchet.rawValue)
        xoodyak.squeezeAny(to: &buffer, count: Rate.ratchet.rawValue, flag: .ratchet)
        xoodyak.absorbAny(contentsOf: buffer, rate: xoodyak.rates.absorb, flag: .zero)
    }
}

public extension KeyedXoodyak {
    init<Key>(key: Key) where Key: Collection, Key.Element == UInt8 {
        self.init(key: key, id: [], counter: [])
    }
    
    init<Key, ID>(key: Key, id: ID)
    where Key: Collection, Key.Element == UInt8, ID: Collection, ID.Element == UInt8 {
        self.init(key: key, id: id, counter: [])
    }
    
    init<Key, Counter>(key: Key, counter: Counter)
    where Key: Collection, Key.Element == UInt8, Counter: Collection, Counter.Element == UInt8 {
        self.init(key: key, id: [], counter: counter)
    }
}
