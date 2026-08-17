#!/usr/bin/env swift

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Flutter が出力する RGBA PNG を、見た目と寸法を保った RGB PNG に置き換える。
/// App Store のスクリーンショットで alpha チャンネルが拒否されるのを防ぐために使う。
func stripAlphaChannel(filePath: String) throws {
    let fileURL = URL(fileURLWithPath: filePath)
    guard
        let imageSource = CGImageSourceCreateWithURL(fileURL as CFURL, nil),
        let sourceImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
    else {
        throw NSError(
            domain: "AppStoreScreenshotAlphaStripper",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "PNG を読み込めません: \(filePath)"]
        )
    }

    guard
        let context = CGContext(
            data: nil,
            width: sourceImage.width,
            height: sourceImage.height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        )
    else {
        throw NSError(
            domain: "AppStoreScreenshotAlphaStripper",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: "RGB 描画領域を作成できません: \(filePath)"]
        )
    }

    context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    context.fill(
        CGRect(x: 0, y: 0, width: sourceImage.width, height: sourceImage.height)
    )
    context.draw(
        sourceImage,
        in: CGRect(x: 0, y: 0, width: sourceImage.width, height: sourceImage.height)
    )
    guard let rgbImage = context.makeImage() else {
        throw NSError(
            domain: "AppStoreScreenshotAlphaStripper",
            code: 3,
            userInfo: [NSLocalizedDescriptionKey: "RGB 画像を作成できません: \(filePath)"]
        )
    }

    let temporaryURL = fileURL.appendingPathExtension("rgb-temporary")
    if FileManager.default.fileExists(atPath: temporaryURL.path) {
        try FileManager.default.removeItem(at: temporaryURL)
    }
    guard
        let destination = CGImageDestinationCreateWithURL(
            temporaryURL as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        )
    else {
        throw NSError(
            domain: "AppStoreScreenshotAlphaStripper",
            code: 4,
            userInfo: [NSLocalizedDescriptionKey: "PNG 出力先を作成できません: \(filePath)"]
        )
    }
    CGImageDestinationAddImage(destination, rgbImage, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw NSError(
            domain: "AppStoreScreenshotAlphaStripper",
            code: 5,
            userInfo: [NSLocalizedDescriptionKey: "PNG を書き出せません: \(filePath)"]
        )
    }

    _ = try FileManager.default.replaceItemAt(fileURL, withItemAt: temporaryURL)
}

do {
    guard CommandLine.arguments.count > 1 else {
        throw NSError(
            domain: "AppStoreScreenshotAlphaStripper",
            code: 64,
            userInfo: [NSLocalizedDescriptionKey: "PNG ファイルを1つ以上指定してください"]
        )
    }
    for filePath in CommandLine.arguments.dropFirst() {
        try stripAlphaChannel(filePath: filePath)
    }
} catch {
    FileHandle.standardError.write(Data("\(error.localizedDescription)\n".utf8))
    exit(1)
}
