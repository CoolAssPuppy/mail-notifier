//
//  AccountIconImageTests.swift
//  MailNotifierTests
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//

import XCTest
import AppKit
@testable import Mail_Notifier

final class AccountIconImageTests: XCTestCase {

    /// A solid-colour PNG of the given pixel size.
    private func makePNG(width: Int, height: Int, color: NSColor = .systemBlue) -> Data {
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                   pixelsWide: width,
                                   pixelsHigh: height,
                                   bitsPerSample: 8,
                                   samplesPerPixel: 4,
                                   hasAlpha: true,
                                   isPlanar: false,
                                   colorSpaceName: .deviceRGB,
                                   bytesPerRow: 0,
                                   bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        color.setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()
        NSGraphicsContext.restoreGraphicsState()
        return rep.representation(using: .png, properties: [:])!
    }

    private func pixelSize(of data: Data) -> (width: Int, height: Int)? {
        guard let rep = NSBitmapImageRep(data: data) else { return nil }
        return (rep.pixelsWide, rep.pixelsHigh)
    }

    func testWideImageBecomesASquareOfTheTargetSide() {
        let result = AccountIconImage.normalizedPNG(from: makePNG(width: 400, height: 200))

        XCTAssertNotNil(result)
        XCTAssertEqual(pixelSize(of: result!)?.width, Int(AccountIconImage.side))
        XCTAssertEqual(pixelSize(of: result!)?.height, Int(AccountIconImage.side))
    }

    func testTallImageBecomesASquareOfTheTargetSide() {
        let result = AccountIconImage.normalizedPNG(from: makePNG(width: 90, height: 300))

        XCTAssertEqual(pixelSize(of: result!)?.width, Int(AccountIconImage.side))
        XCTAssertEqual(pixelSize(of: result!)?.height, Int(AccountIconImage.side))
    }

    func testOutputIsPNG() {
        let result = AccountIconImage.normalizedPNG(from: makePNG(width: 50, height: 50))!
        XCTAssertEqual(Array(result.prefix(4)), [0x89, 0x50, 0x4E, 0x47])
    }

    func testGarbageBytesReturnNil() {
        XCTAssertNil(AccountIconImage.normalizedPNG(from: Data("not an image".utf8)))
    }

    func testLargeImageStaysUnderTheCloudBudget() {
        // iCloud KVS is 1 MB across every key. A 128px RGBA icon is at most
        // 64 KB raw, so a dozen accounts fit with room to spare.
        let result = AccountIconImage.normalizedPNG(from: makePNG(width: 1000, height: 1000))!
        XCTAssertLessThan(result.count, 70_000)
    }

    func testNSImageDecodesAtTheRequestedSize() {
        let png = AccountIconImage.normalizedPNG(from: makePNG(width: 300, height: 300))!
        let image = AccountIconImage.nsImage(from: png, size: NSSize(width: 14, height: 14))

        XCTAssertEqual(image?.size, NSSize(width: 14, height: 14))
    }

    func testNSImageReturnsNilForGarbage() {
        XCTAssertNil(AccountIconImage.nsImage(from: Data([1, 2, 3]), size: NSSize(width: 14, height: 14)))
    }
}
