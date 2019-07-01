import Foundation

extension DataProtocol {
    func blocks(rate: Int) -> Blocks<Self> {
        return Blocks<Self>(data: self, rate: rate)
    }
}

struct Blocks<D: DataProtocol>: Sequence {
    let data: D
    let rate: Int
    
    func makeIterator() -> BlocksIterator<D> {
        return BlocksIterator<D>(data, rate)
    }
}

struct BlocksIterator<D: DataProtocol>: IteratorProtocol {
    var data: D.SubSequence
    let rate: Int
    var firstBlock = true
    
    init(_ data: D, _ rate: Int) {
        self.data = data.prefix(Int.max)
        self.rate = rate
    }
    
    mutating func next() -> D.SubSequence? {
        if data.isEmpty && !firstBlock {
            return nil
        }
        firstBlock = false
        let block = data.prefix(min(data.count, rate))
        data = data.suffix(data.count - block.count)
        return block
    }
}
