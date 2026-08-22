import Foundation

struct LittleEndianWriter {
    private(set) var data: Data

    init(capacity: Int) {
        data = Data()
        data.reserveCapacity(capacity)
    }

    mutating func appendASCII(_ value: String) {
        data.append(contentsOf: value.utf8)
    }

    mutating func append(_ value: UInt16) {
        var littleEndian = value.littleEndian
        withUnsafeBytes(of: &littleEndian) { data.append(contentsOf: $0) }
    }

    mutating func append(_ value: UInt32) {
        var littleEndian = value.littleEndian
        withUnsafeBytes(of: &littleEndian) { data.append(contentsOf: $0) }
    }
}

struct LittleEndianReader {
    let data: Data

    func ascii(at offset: Int, count: Int) -> String? {
        guard contains(offset: offset, count: count) else { return nil }
        return String(data: data[offset..<(offset + count)], encoding: .ascii)
    }

    func uint16(at offset: Int) -> UInt16 {
        guard contains(offset: offset, count: 2) else { return 0 }
        return data[offset..<(offset + 2)].enumerated().reduce(0) { result, element in
            result | UInt16(element.element) << UInt16(element.offset * 8)
        }
    }

    func uint32(at offset: Int) -> UInt32 {
        guard contains(offset: offset, count: 4) else { return 0 }
        return data[offset..<(offset + 4)].enumerated().reduce(0) { result, element in
            result | UInt32(element.element) << UInt32(element.offset * 8)
        }
    }

    private func contains(offset: Int, count: Int) -> Bool {
        offset >= 0 && count >= 0 && offset <= data.count - count
    }
}
