//
//  VIP.swift
//  Mail Notifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import Foundation

struct VIP: Codable, Identifiable, Hashable {
    var id: String { email }
    var email: String
    var notificationSound: String

    var sound: Sound? {
        Sound(rawValue: notificationSound)
    }
}

// MARK: - Allow persisting VIPs to @AppStorage

struct VIPList: RawRepresentable, Codable, RandomAccessCollection, MutableCollection, ExpressibleByArrayLiteral {
    private var storage: [VIP]

    init(_ vips: [VIP] = []) {
        self.storage = vips
    }

    init(arrayLiteral elements: VIP...) {
        self.storage = elements
    }

    // Collection
    typealias Index = Int
    var startIndex: Int { storage.startIndex }
    var endIndex: Int { storage.endIndex }
    func index(after i: Int) -> Int { storage.index(after: i) }
    subscript(position: Int) -> VIP {
        get { storage[position] }
        set { storage[position] = newValue }
    }

    // RawRepresentable
    static let storageKey = "vipList"

    init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
              let result = try? JSONDecoder().decode([VIP].self, from: data)
        else {
            return nil
        }
        self.storage = result
    }

    var rawValue: String {
        guard let data = try? JSONEncoder().encode(storage),
              let result = String(data: data, encoding: .utf8)
        else {
            return "[]"
        }
        return result
    }

    // Helpers to mimic array behaviour
    var count: Int { storage.count }
    var isEmpty: Bool { storage.isEmpty }

    mutating func append(_ element: VIP) { storage.append(element) }
    @discardableResult mutating func remove(at index: Int) -> VIP { storage.remove(at: index) }
    mutating func move(fromOffsets source: IndexSet, toOffset destination: Int) { storage.move(fromOffsets: source, toOffset: destination) }
}

extension VIPList {
    static var `default`: VIPList {
        get {
            VIPList(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "[]") ?? []
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: storageKey)
        }
    }

    mutating func save() {
        Self.default = self
    }

    mutating func add(vip: VIP) {
        if firstIndex(where: { $0.email.lowercased() == vip.email.lowercased() }) != nil {
            return
        }
        append(vip)
        save()
    }

    mutating func delete(vip: VIP) {
        guard let index = firstIndex(where: { $0.email.lowercased() == vip.email.lowercased() }) else {
            return
        }
        remove(at: index)
        save()
    }

    mutating func update(vip: VIP) {
        guard let index = firstIndex(where: { $0.email.lowercased() == vip.email.lowercased() }) else {
            return
        }
        self[index] = vip
        save()
    }

    func find(email: String) -> VIP? {
        first { $0.email.lowercased() == email.lowercased() }
    }

    func soundForSender(_ senderEmail: String) -> Sound? {
        find(email: senderEmail)?.sound
    }
}
