// image_dimensions.ts のヘッダー解析と画質判定のテスト。
// 実際のエンコーダが出力したファイル (test/image_fixtures.ts) で形式ごとのヘッダーを読めることを確認し、
// 実寸・色を変えたケースは組み立てたヘッダーで検証する。
import { describe, expect, it } from "vitest";
import {
  judgeScannerColor,
  judgeScannerResolution,
  readImageDimensions,
  scannerResolutionMinimumPixelCount,
} from "../src/image_dimensions";
import {
  buildJpegHeaderBytes,
  buildPngHeaderBytes,
  onePixelJpegBytes,
  onePixelPngBytes,
  onePixelVp8lWebpBytes,
  onePixelVp8WebpBytes,
  onePixelVp8xWebpBytes,
  twoPixelHeicBytes,
} from "./image_fixtures";

describe("画像ヘッダーからの実寸・色の読み取り", () => {
  it("実ファイルの PNG・JPEG・WebP (VP8 / VP8L / VP8X)・HEIC から実寸を読む", () => {
    for (const [formatName, imageBytes, expectedImageWidth, expectedImageHeight] of [
      ["PNG", onePixelPngBytes, 1, 1],
      ["JPEG", onePixelJpegBytes, 1, 1],
      ["WebP (VP8)", onePixelVp8WebpBytes, 1, 1],
      ["WebP (VP8L)", onePixelVp8lWebpBytes, 1, 1],
      ["WebP (VP8X)", onePixelVp8xWebpBytes, 1, 1],
      ["HEIC", twoPixelHeicBytes, 2, 2],
    ] as [string, Uint8Array, number, number][]) {
      expect(readImageDimensions(imageBytes.buffer as ArrayBuffer), formatName).toEqual({
        imageWidth: expectedImageWidth,
        imageHeight: expectedImageHeight,
        hasFullColorDepth: true,
      });
    }
  });

  it("組み立てた PNG ヘッダーの実寸を読む", () => {
    expect(
      readImageDimensions(
        buildPngHeaderBytes({ imageWidth: 3024, imageHeight: 4032, bitDepth: 8, colorType: 2 }).buffer as ArrayBuffer,
      ),
    ).toEqual({ imageWidth: 3024, imageHeight: 4032, hasFullColorDepth: true });
  });

  it("PNG のグレースケール・パレットは RGB 256階調を満たさないと判定する", () => {
    for (const [colorTypeName, colorType, bitDepth] of [
      ["グレースケール", 0, 8],
      ["パレット", 3, 8],
      ["truecolor だが 4bit", 2, 4],
    ] as [string, number, number][]) {
      expect(
        readImageDimensions(
          buildPngHeaderBytes({ imageWidth: 100, imageHeight: 100, bitDepth, colorType }).buffer as ArrayBuffer,
        ),
        colorTypeName,
      ).toEqual({ imageWidth: 100, imageHeight: 100, hasFullColorDepth: false });
    }
  });

  it("JPEG の progressive (SOF2) でも実寸を読み、コンポーネント数 1 はグレースケールと判定する", () => {
    expect(
      readImageDimensions(
        buildJpegHeaderBytes({
          imageWidth: 2000,
          imageHeight: 1500,
          colorComponentCount: 3,
          startOfFrameMarkerCode: 0xc2,
        }).buffer as ArrayBuffer,
      ),
    ).toEqual({ imageWidth: 2000, imageHeight: 1500, hasFullColorDepth: true });

    expect(
      readImageDimensions(
        buildJpegHeaderBytes({ imageWidth: 2000, imageHeight: 1500, colorComponentCount: 1 }).buffer as ArrayBuffer,
      ),
    ).toEqual({ imageWidth: 2000, imageHeight: 1500, hasFullColorDepth: false });
  });

  it("未知の形式・壊れたバイト列・実寸 0 のヘッダーでは null を返し、例外を投げない", () => {
    for (const [caseName, imageBytes] of [
      ["空", new Uint8Array(0)],
      ["画像ではないバイト列", new Uint8Array([0x6e, 0x6f, 0x74, 0x20, 0x61, 0x6e, 0x20, 0x69, 0x6d, 0x61, 0x67, 0x65])],
      ["PNG の署名だけで IHDR が無い", onePixelPngBytes.slice(0, 12)],
      ["JPEG の SOI だけ", new Uint8Array([0xff, 0xd8])],
      // SOF セグメント (オフセット 156 から始まる) の途中で切れているケース
      ["JPEG の SOF の途中で切れている", onePixelJpegBytes.slice(0, 160)],
      ["WebP の RIFF ヘッダーだけ", onePixelVp8WebpBytes.slice(0, 16)],
      ["HEIC の ftyp だけで meta が無い", twoPixelHeicBytes.slice(0, 24)],
      ["実寸 0 の PNG", buildPngHeaderBytes({ imageWidth: 0, imageHeight: 0, bitDepth: 8, colorType: 2 })],
    ] as [string, Uint8Array][]) {
      expect(readImageDimensions(imageBytes.buffer as ArrayBuffer), caseName).toBeNull();
    }
  });
});

describe("スキャナ保存の画質基準の判定", () => {
  it("A4 を 200dpi で読み取った画素数以上なら解像度基準を満たすと判定する", () => {
    // 1935 x 2000 = 3,870,000 画素で基準値ちょうど
    expect(judgeScannerResolution({ imageWidth: 1935, imageHeight: 2000, hasFullColorDepth: true })).toBe("true");
    expect(1935 * 2000).toBe(scannerResolutionMinimumPixelCount);
    expect(judgeScannerResolution({ imageWidth: 1935, imageHeight: 1999, hasFullColorDepth: true })).toBe("false");
    expect(judgeScannerResolution({ imageWidth: 3024, imageHeight: 4032, hasFullColorDepth: true })).toBe("true");
  });

  it("解析できなかった画像は解像度・色とも unknown と判定する", () => {
    expect(judgeScannerResolution(null)).toBe("unknown");
    expect(judgeScannerColor(null)).toBe("unknown");
    expect(judgeScannerColor({ imageWidth: 100, imageHeight: 100, hasFullColorDepth: null })).toBe("unknown");
  });

  it("色の階調は hasFullColorDepth をそのまま判定にする", () => {
    expect(judgeScannerColor({ imageWidth: 100, imageHeight: 100, hasFullColorDepth: true })).toBe("true");
    expect(judgeScannerColor({ imageWidth: 100, imageHeight: 100, hasFullColorDepth: false })).toBe("false");
  });
});
