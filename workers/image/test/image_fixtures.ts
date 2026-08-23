// 画質判定 (実寸・色の階調) のテストで使う画像バイト列。
// 形式ごとの本物のヘッダーを検証するため、実際のエンコーダが出力した 1x1 画像
// (macOS の sips で PNG から JPEG / HEIC へ変換、cwebp で WebP の 3 形式へ変換したもの) を base64 で持つ。
// 実寸・色の階調を変えたケースは実ファイルを用意できないため、仕様どおりのヘッダーを組み立てて作る。

/** base64 の画像フィクスチャをバイト列に戻す。 */
export function decodeBase64ToBytes(base64Text: string): Uint8Array {
  return Uint8Array.from(atob(base64Text), (base64Character) => base64Character.charCodeAt(0));
}

/** 実ファイルの 1x1 PNG (8bit truecolor + alpha)。 */
export const onePixelPngBytes = decodeBase64ToBytes(
  "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==",
);

/** 実ファイルの 1x1 JPEG (Exif・Photoshop リソース等のセグメントを SOF の手前に持つ)。 */
export const onePixelJpegBytes = decodeBase64ToBytes(
  "/9j/4AAQSkZJRgABAQAASABIAAD/4QBMRXhpZgAATU0AKgAAAAgAAYdpAAQAAAABAAAAGgAAAAAAA6ABAAMAAAABAAEAAKACAAQAAAABAAAAAaADAAQAAAABAAAAAQAAAAD/7QA4UGhvdG9zaG9wIDMuMAA4QklNBAQAAAAAAAA4QklNBCUAAAAAABDUHYzZjwCyBOmACZjs+EJ+/8AAEQgAAQABAwEiAAIRAQMRAf/EAB8AAAEFAQEBAQEBAAAAAAAAAAABAgMEBQYHCAkKC//EALUQAAIBAwMCBAMFBQQEAAABfQECAwAEEQUSITFBBhNRYQcicRQygZGhCCNCscEVUtHwJDNicoIJChYXGBkaJSYnKCkqNDU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6g4SFhoeIiYqSk5SVlpeYmZqio6Slpqeoqaqys7S1tre4ubrCw8TFxsfIycrS09TV1tfY2drh4uPk5ebn6Onq8fLz9PX29/j5+v/EAB8BAAMBAQEBAQEBAQEAAAAAAAABAgMEBQYHCAkKC//EALURAAIBAgQEAwQHBQQEAAECdwABAgMRBAUhMQYSQVEHYXETIjKBCBRCkaGxwQkjM1LwFWJy0QoWJDThJfEXGBkaJicoKSo1Njc4OTpDREVGR0hJSlNUVVZXWFlaY2RlZmdoaWpzdHV2d3h5eoKDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uLj5OXm5+jp6vLz9PX29/j5+v/bAEMAAgICAgICAwICAwUDAwMFBgUFBQUGCAYGBgYGCAoICAgICAgKCgoKCgoKCgwMDAwMDA4ODg4ODw8PDw8PDw8PD//bAEMBAgICBAQEBwQEBxALCQsQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEP/dAAQAAf/aAAwDAQACEQMRAD8A+mKKKK/Kz/QA/9k=",
);

/** 実ファイルの 1x1 WebP (非可逆・VP8 チャンク)。 */
export const onePixelVp8WebpBytes = decodeBase64ToBytes(
  "UklGRjgAAABXRUJQVlA4ICwAAACQAQCdASoBAAEAAgA0JaACdLoAA5gA/u3tZ4hd7Ic//oSf/E2f8TZ8AAAAAA==",
);

/** 実ファイルの 1x1 WebP (可逆・VP8L チャンク)。 */
export const onePixelVp8lWebpBytes = decodeBase64ToBytes("UklGRhwAAABXRUJQVlA4TA8AAAAvAAAAEAcQ/Y/+BSKi/wEA");

/** 実ファイルの 1x1 WebP (アルファ付きで VP8X チャンクの拡張形式になったもの)。 */
export const onePixelVp8xWebpBytes = decodeBase64ToBytes(
  "UklGRlgAAABXRUJQVlA4WAoAAAAQAAAAAAAAAAAAQUxQSAIAAAAAf1ZQOCAwAAAA0AEAnQEqAQABAAFAJiWgAnS6AfgAA7AA/vLrf/zYFc1z7/f/0uD9Lg/S4P/SkAAA",
);

// 実ファイルの HEIC。1x1 の PNG を sips で変換したものだが、HEVC の符号化単位に合わせて 2x2 で保存される
export const twoPixelHeicBytes = decodeBase64ToBytes(
  "AAAAGGZ0eXBoZWljAAAAAGhlaWNtaWYxAAACrG1ldGEAAAAAAAAAIWhkbHIAAAAAAAAAAHBpY3QAAAAAAAAAAAAAAAAAAAAAJGRpbmYAAAAcZHJlZgAAAAAAAAABAAAADHVybCAAAAABAAAADnBpdG0AAAAAAAEAAAA4aWluZgAAAAAAAgAAABVpbmZlAgAAAAABAABodmMxAAAAABVpbmZlAgAAAQACAABodmMxAAAAABppcmVmAAAAAAAAAA5hdXhsAAIAAQABAAABz2lwcnAAAAGkaXBjbwAAABNjb2xybmNseAACAAIABoAAAAAMY2xsaQDLAEAAAAAUaXNwZQAAAAAAAAACAAAAAgAAAChjbGFwAAAAAQAAAAEAAAABAAAAAf/AAAAAgAAA/8AAAACAAAAAAAAJaXJvdAAAAAAQcGl4aQAAAAADCAgIAAAADnBpeGkAAAAAAQgAAAA3YXV4QwAAAAB1cm46bXBlZzpoZXZjOjIwMTU6YXV4aWQ6MQAAAAAMAAAACE4BpQQAAf5AAAAAcmh2Y0MBA3AAAACwAAAAAAAe8AD8/fj4AAALA6AAAQAXQAEMAf//A3AAAAMAsAAAAwAAAwAecCShAAEAJEIBAQNwAAADALAAAAMAAAMAHqAUIEHAoQQYh7kWVTcCAgYAgKIAAQAJRAHAYXLIRFNkAAAAcWh2Y0MBBAgAAAC/yAAAAAAe8AD8/Pj4AAALA6AAAQAXQAEMAf//BAgAAAMAv8gAAAMAAB4XAkChAAEAI0IBAQQIAAADAL/IAAADAAAewFCBBwE/B/iBe5FlU3AgICAIogABAAlEAcBh0shEU2QAAAAjaXBtYQAAAAAAAAACAAEHgQIDBomEhQACBgMHiIqEhQAAACxpbG9jAAAAAEQAAAIAAQAAAAEAAALUAAAAUAACAAAAAQAAAyQAAAA1AAAAAW1kYXQAAAAAAAAAlQAAAEwoAa+jYxGV0gXBMVXzC4n/motjhLKp//+VGy42Z+D5jqo7BTT0rMf/J/zT9gX1vzH/aANmTK4sGufssfYuWjarjP9N2WPd+yGseAhoAAAAMSgBr0X8Jx4exbIztS+Qm4CT93EYNXw/Vha/JW/ldf/5AqcLhUAyMwm+p2l2qkgIb4A=",
);

/**
 * 指定した実寸・色で PNG の署名と IHDR チャンクを組み立てる (画素データは持たない)。
 * IHDR の CRC は実寸・色の解析では読まないため 0 のままにしている。
 */
export function buildPngHeaderBytes({
  imageWidth,
  imageHeight,
  bitDepth,
  colorType,
}: {
  imageWidth: number;
  imageHeight: number;
  bitDepth: number;
  colorType: number;
}): Uint8Array {
  const pngHeaderBytes = new Uint8Array(33);
  const pngHeaderBytesView = new DataView(pngHeaderBytes.buffer);
  pngHeaderBytes.set([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
  pngHeaderBytesView.setUint32(8, 13);
  pngHeaderBytes.set([0x49, 0x48, 0x44, 0x52], 12);
  pngHeaderBytesView.setUint32(16, imageWidth);
  pngHeaderBytesView.setUint32(20, imageHeight);
  pngHeaderBytes[24] = bitDepth;
  pngHeaderBytes[25] = colorType;
  return pngHeaderBytes;
}

/** ISOBMFF (HEIC) のボックス 1 つ分のバイト列を組み立てる。 */
function buildIsobmffBoxBytes(boxType: string, boxContentBytes: number[]): number[] {
  return [
    ...buildUint32Bytes(8 + boxContentBytes.length),
    ...Array.from(boxType, (boxTypeCharacter) => boxTypeCharacter.charCodeAt(0)),
    ...boxContentBytes,
  ];
}

/** ISOBMFF・PNG が使うビッグエンディアンの 32bit 整数のバイト列。 */
function buildUint32Bytes(value: number): number[] {
  return [(value >> 24) & 0xff, (value >> 16) & 0xff, (value >> 8) & 0xff, value & 0xff];
}

/**
 * 指定した実寸・画素の構成で HEIC の ftyp と meta > iprp > ipco > ispe (+ pixi) を組み立てる (画素データは持たない)。
 * bitsPerChannel に null を渡すと pixi ボックス自体を持たない HEIC になる。
 * declaredChannelCount に bitsPerChannel より多い数を渡すと、内容が足りない (壊れた) pixi になる。
 */
export function buildHeicHeaderBytes({
  imageWidth,
  imageHeight,
  bitsPerChannel,
  // pixi が宣言するチャンネル数は、既定では実際に並べる bit 数の個数と一致させる (正常な pixi)
  declaredChannelCount = bitsPerChannel?.length ?? 0,
}: {
  imageWidth: number;
  imageHeight: number;
  bitsPerChannel: number[] | null;
  declaredChannelCount?: number;
}): Uint8Array {
  return new Uint8Array([
    ...buildIsobmffBoxBytes("ftyp", [
      ...Array.from("heic", (brandCharacter) => brandCharacter.charCodeAt(0)),
      ...buildUint32Bytes(0),
      ...Array.from("mif1", (brandCharacter) => brandCharacter.charCodeAt(0)),
    ]),
    // meta は FullBox のため、子ボックスの前に version + flags の 4 バイトが入る
    ...buildIsobmffBoxBytes("meta", [
      ...buildUint32Bytes(0),
      ...buildIsobmffBoxBytes("iprp", [
        ...buildIsobmffBoxBytes("ipco", [
          ...buildIsobmffBoxBytes("ispe", [
            ...buildUint32Bytes(0),
            ...buildUint32Bytes(imageWidth),
            ...buildUint32Bytes(imageHeight),
          ]),
          ...(bitsPerChannel === null
            ? []
            : buildIsobmffBoxBytes("pixi", [...buildUint32Bytes(0), declaredChannelCount, ...bitsPerChannel])),
        ]),
      ]),
    ]),
  ]);
}

/**
 * 指定した実寸・コンポーネント数で JPEG の SOI・ダミーの APP0・SOF セグメントを組み立てる (画素データは持たない)。
 * startOfFrameMarkerCode で baseline (0xC0) と progressive (0xC2) を切り替える。
 */
export function buildJpegHeaderBytes({
  imageWidth,
  imageHeight,
  colorComponentCount,
  startOfFrameMarkerCode = 0xc0,
}: {
  imageWidth: number;
  imageHeight: number;
  colorComponentCount: number;
  startOfFrameMarkerCode?: number;
}): Uint8Array {
  return new Uint8Array([
    0xff,
    0xd8,
    // SOF の手前のセグメントが読み飛ばされることを確認するためのダミー APP0
    0xff,
    0xe0,
    0x00,
    0x04,
    0x00,
    0x00,
    0xff,
    startOfFrameMarkerCode,
    0x00,
    8 + 3 * colorComponentCount,
    // 精度 (チャンネルあたりの bit 数)
    0x08,
    (imageHeight >> 8) & 0xff,
    imageHeight & 0xff,
    (imageWidth >> 8) & 0xff,
    imageWidth & 0xff,
    colorComponentCount,
    ...Array.from({ length: colorComponentCount * 3 }, () => 0x11),
  ]);
}
