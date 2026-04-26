//
//  GmailProviderErrorMappingTests.swift
//  MailNotifierTests
//
//  Verifies GmailProvider.mapGmailError classifies errors correctly so the UI
//  doesn't show "Authorization expired" on transient network failures.
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//

import XCTest
import GoogleAPIClientForREST_Gmail
@testable import Mail_Notifier

final class GmailProviderErrorMappingTests: XCTestCase {

    func testTimeoutMapsToNetworkError() {
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)
        let mapped = GmailProvider.mapGmailError(error)
        switch mapped {
        case .networkError: break
        default: XCTFail("Expected .networkError, got \(mapped)")
        }
    }

    func testNotConnectedMapsToNetworkError() {
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)
        switch GmailProvider.mapGmailError(error) {
        case .networkError: break
        default: XCTFail("Expected .networkError")
        }
    }

    func testHttp401MapsToAuthenticationRequired() {
        let error = NSError(domain: kGTLRErrorObjectDomain, code: 401)
        switch GmailProvider.mapGmailError(error) {
        case .authenticationRequired: break
        default: XCTFail("Expected .authenticationRequired for HTTP 401")
        }
    }

    func testHttp403MapsToAuthenticationRequired() {
        let error = NSError(domain: kGTLRErrorObjectDomain, code: 403)
        switch GmailProvider.mapGmailError(error) {
        case .authenticationRequired: break
        default: XCTFail("Expected .authenticationRequired for HTTP 403")
        }
    }

    func testHttp500MapsToHttpError() {
        let error = NSError(domain: kGTLRErrorObjectDomain, code: 500)
        switch GmailProvider.mapGmailError(error) {
        case .httpError(let status): XCTAssertEqual(status, 500)
        default: XCTFail("Expected .httpError for HTTP 500")
        }
    }

    func testUnknownDomainMapsToParsingError() {
        let error = NSError(domain: "com.example.unknown", code: 42)
        switch GmailProvider.mapGmailError(error) {
        case .parsingError: break
        default: XCTFail("Expected .parsingError for unknown error domain")
        }
    }
}
