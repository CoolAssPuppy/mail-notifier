//
//  URLEncoding.swift
//  Mail Notifier
//
//  Copyright (c) 2025 Strategic Nerds. All rights reserved.
//

import Foundation

extension CharacterSet {
    /// `urlPathAllowed` minus `/`, so path *segments* can be percent-encoded
    /// without turning an email's `@` or a message id's separators into path
    /// breaks. Used when composing deep links into provider web UIs.
    static let urlPathComponentAllowed: CharacterSet = {
        var set = CharacterSet.urlPathAllowed
        set.remove(charactersIn: "/")
        return set
    }()
}
