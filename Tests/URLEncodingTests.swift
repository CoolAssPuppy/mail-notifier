//
//  URLEncodingTests.swift
//  MailNotifierTests
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//

import XCTest
@testable import Mail_Notifier

final class URLEncodingTests: XCTestCase {

    func testUrlPathComponentAllowedExcludesSlash() {
        XCTAssertFalse(CharacterSet.urlPathComponentAllowed.contains("/"))
    }

    func testUrlPathComponentAllowedKeepsAtSign() {
        // The whole point of this set: encode email addresses inside a path
        // segment without breaking the path structure.
        let encoded = "user@example.com".addingPercentEncoding(withAllowedCharacters: .urlPathComponentAllowed)
        XCTAssertEqual(encoded, "user@example.com")
    }

    func testUrlPathComponentAllowedEncodesSlash() {
        let encoded = "msg/with/slashes".addingPercentEncoding(withAllowedCharacters: .urlPathComponentAllowed)
        XCTAssertEqual(encoded, "msg%2Fwith%2Fslashes")
    }
}
