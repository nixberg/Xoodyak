import Foundation

extension DataProtocol {
    func blocks(rate: Int) -> Blocks<Self> {
        .init(data: self, rate: rate)
    }
}

struct Blocks<D>: Sequence where D: DataProtocol {
    struct BlocksIterator<D>: IteratorProtocol where D: DataProtocol {
        var tail: D.SubSequence
        let rate: Int
        var firstBlock = true
        
        mutating func next() -> D.SubSequence? {
            guard !tail.isEmpty || firstBlock else {
                return nil
            }
            firstBlock = false
            defer { tail = tail.dropFirst(rate) }
            return tail.prefix(rate)
        }
    }
    
    let data: D
    let rate: Int
    
    func makeIterator() -> BlocksIterator<D> {
        .init(tail: data[...], rate: rate)
    }
}
