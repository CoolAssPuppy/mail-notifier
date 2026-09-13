//
//  AccountIconImage.swift
//  Mail Notifier
//
//  Copyright (c) 2026 Strategic Nerds. All rights reserved.
//

import AppKit

/// Turns whatever image a person picks into the small square PNG the icon
/// store keeps, and turns those bytes back into an `NSImage` for AppKit.
enum AccountIconImage {

    /// Pixel side of a stored icon. The largest badge in the app is 38pt, so
    /// 128px covers a Retina display with room to spare, and a 128px RGBA
    /// image is at most 64 KB raw. iCloud KVS is 1 MB across every key, so a
    /// dozen accounts fit.
    static let side: CGFloat = 128

    /// Center-crops to a square, scales to `side`, and encodes as PNG.
    /// Returns `nil` when the bytes aren't an image AppKit can read.
    static func normalizedPNG(from data: Data, side: CGFloat = side) -> Data? {
        guard let source = NSImage(data: data), source.isValid,
              source.size.width > 0, source.size.height > 0 else { return nil }

        guard let canvas = NSBitmapImageRep(bitmapDataPlanes: nil,
                                            pixelsWide: Int(side),
                                            pixelsHigh: Int(side),
                                            bitsPerSample: 8,
                                            samplesPerPixel: 4,
                                            hasAlpha: true,
                                            isPlanar: false,
                                            colorSpaceName: .deviceRGB,
                                            bytesPerRow: 0,
                                            bitsPerPixel: 0),
              let context = NSGraphicsContext(bitmapImageRep: canvas) else { return nil }
        canvas.size = NSSize(width: side, height: side)

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.imageInterpolation = .high
        source.draw(in: NSRect(x: 0, y: 0, width: side, height: side),
                    from: centeredSquare(in: source.size),
                    operation: .copy,
                    fraction: 1)
        NSGraphicsContext.restoreGraphicsState()

        return canvas.representation(using: .png, properties: [:])
    }

    /// Decodes stored bytes at a display size, for `NSMenuItem.image`.
    static func nsImage(from data: Data, size: NSSize) -> NSImage? {
        guard let image = NSImage(data: data), image.isValid else { return nil }
        image.size = size
        return image
    }

    private static func centeredSquare(in size: NSSize) -> NSRect {
        let edge = min(size.width, size.height)
        return NSRect(x: (size.width - edge) / 2,
                      y: (size.height - edge) / 2,
                      width: edge,
                      height: edge)
    }
}
