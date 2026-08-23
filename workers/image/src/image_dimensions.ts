// 画像バイナリのヘッダーだけを手で解析して、実寸 (px) と色の階調を取り出す。
// 画質担保 (issue #73) の判定に必要なのは幅・高さ・色の階調だけで画素のデコードは不要なため、
// Worker に画像デコードライブラリを持ち込まず、形式ごとのヘッダー構造を直接読む。

/** 画像バイナリのヘッダーから読み取った実寸と色の階調。 */
export interface ImageDimensions {
  /** 画像の幅 (px)。 */
  imageWidth: number;
  /** 画像の高さ (px)。 */
  imageHeight: number;
  /** RGB 256階調以上 (チャンネルあたり 8bit 以上のカラー) か。ヘッダーから判定できない場合は null。 */
  hasFullColorDepth: boolean | null;
}

/** 画質基準を満たすかの判定結果。画像を解析できず判定できなかった場合は "unknown"。 */
export type ScannerRequirementJudgement = "true" | "false" | "unknown";

// スキャナ保存の解像度基準 (200dpi 相当以上) を満たすとみなす画素数の下限。
// 国税庁「電子帳簿保存法一問一答 (スキャナ保存関係)」で、スマートフォン等で読み取る場合は
// 「A4 サイズの書類を 200dpi で読み取った場合の画素数 (約387万画素) 以上」であれば解像度要件を満たすとされているため、
// その画素数をそのまま下限にする。画像からはレシートの実寸 (= 実際の dpi) を判定できないため、
// 書類サイズを問わず使える A4 基準の画素数を近似基準として採用している。
// 出典: https://www.nta.go.jp/law/joho-zeikaishaku/sonota/jirei/tokusetsu/03.htm
export const scannerResolutionMinimumPixelCount = 3_870_000;

/**
 * 画像バイナリの先頭のヘッダーから実寸と色の階調を読み取る。JPEG・PNG・WebP・HEIC に対応する。
 * 未対応形式・途中で切れたファイル・壊れたヘッダーでは null を返す (アップロード自体は拒否しないため throw しない)。
 */
export function readImageDimensions(imageBytes: ArrayBuffer): ImageDimensions | null {
  try {
    const imageDimensions = readImageDimensionsBySignature(new DataView(imageBytes));
    // 0 や負の寸法は壊れたヘッダーを読んだ結果のため、解析できなかった扱いに畳む
    if (imageDimensions === null || imageDimensions.imageWidth <= 0 || imageDimensions.imageHeight <= 0) {
      return null;
    }
    return imageDimensions;
  } catch (error) {
    // 範囲外アクセス (RangeError) 等はすべて「解析できなかった」に畳み、アップロードを失敗させない
    return null;
  }
}

/** 解像度基準 (scannerResolutionMinimumPixelCount 以上の画素数) を満たすかの判定。 */
export function judgeScannerResolution(imageDimensions: ImageDimensions | null): ScannerRequirementJudgement {
  if (imageDimensions === null) {
    return "unknown";
  }
  return imageDimensions.imageWidth * imageDimensions.imageHeight >= scannerResolutionMinimumPixelCount
    ? "true"
    : "false";
}

/** 色の階調基準 (RGB 256階調以上) を満たすかの判定。 */
export function judgeScannerColor(imageDimensions: ImageDimensions | null): ScannerRequirementJudgement {
  if (imageDimensions === null || imageDimensions.hasFullColorDepth === null) {
    return "unknown";
  }
  return imageDimensions.hasFullColorDepth ? "true" : "false";
}

/** 先頭のシグネチャで形式を判別し、形式ごとのヘッダー解析へ振り分ける。 */
function readImageDimensionsBySignature(imageBytesView: DataView): ImageDimensions | null {
  if (imageBytesView.byteLength >= 8 && readAsciiText(imageBytesView, 1, 3) === "PNG") {
    return readPngDimensions(imageBytesView);
  }
  if (imageBytesView.byteLength >= 4 && imageBytesView.getUint16(0) === 0xffd8) {
    return readJpegDimensions(imageBytesView);
  }
  if (
    imageBytesView.byteLength >= 16 &&
    readAsciiText(imageBytesView, 0, 4) === "RIFF" &&
    readAsciiText(imageBytesView, 8, 4) === "WEBP"
  ) {
    return readWebpDimensions(imageBytesView);
  }
  // HEIC は ISOBMFF で、先頭が ftyp ボックス (4バイトの長さ + "ftyp") から始まる
  if (imageBytesView.byteLength >= 8 && readAsciiText(imageBytesView, 4, 4) === "ftyp") {
    return readHeicDimensions(imageBytesView);
  }
  return null;
}

/** PNG の IHDR チャンクから実寸とカラータイプを読む。 */
function readPngDimensions(imageBytesView: DataView): ImageDimensions | null {
  // IHDR は PNG 仕様で必ず最初のチャンク (署名8バイト + 長さ4バイト + タイプ4バイトの直後が内容)
  if (imageBytesView.byteLength < 26 || readAsciiText(imageBytesView, 12, 4) !== "IHDR") {
    return null;
  }
  return {
    imageWidth: imageBytesView.getUint32(16),
    imageHeight: imageBytesView.getUint32(20),
    // カラータイプ 2 (truecolor) と 6 (truecolor + alpha) 以外はグレースケール・パレットで、
    // チャンネルあたりの bit 深度が 8 以上でも RGB 256階調のカラーにはならない
    hasFullColorDepth:
      (imageBytesView.getUint8(25) === 2 || imageBytesView.getUint8(25) === 6) && imageBytesView.getUint8(24) >= 8,
  };
}

/** JPEG のマーカーを辿り、フレームの寸法を持つ SOF マーカーから実寸と精度・コンポーネント数を読む。 */
function readJpegDimensions(imageBytesView: DataView): ImageDimensions | null {
  // SOI (0xFFD8) の直後から、マーカーとセグメント長を辿って SOF まで進む
  for (let markerOffset = 2; markerOffset + 4 <= imageBytesView.byteLength; ) {
    if (imageBytesView.getUint8(markerOffset) !== 0xff) {
      // マーカー境界がずれている = 壊れたファイルなので、当てずっぽうに読み進めない
      return null;
    }
    // 0xFF の詰め物 (fill byte) は 1 バイトずつ読み飛ばす
    if (imageBytesView.getUint8(markerOffset + 1) === 0xff) {
      markerOffset += 1;
      continue;
    }
    // TEM (0x01) と RSTn・SOI・EOI (0xD0-0xD9) はセグメント長を持たない
    if (
      imageBytesView.getUint8(markerOffset + 1) === 0x01 ||
      (imageBytesView.getUint8(markerOffset + 1) >= 0xd0 && imageBytesView.getUint8(markerOffset + 1) <= 0xd9)
    ) {
      markerOffset += 2;
      continue;
    }
    if (imageBytesView.getUint16(markerOffset + 2) < 2) {
      // セグメント長はそれ自身の 2 バイトを含むため 2 未満はありえない (壊れたファイル)
      return null;
    }
    if (isJpegStartOfFrameMarker(imageBytesView.getUint8(markerOffset + 1))) {
      if (markerOffset + 10 > imageBytesView.byteLength) {
        return null;
      }
      return {
        imageWidth: imageBytesView.getUint16(markerOffset + 7),
        imageHeight: imageBytesView.getUint16(markerOffset + 5),
        // 精度 (markerOffset + 4) はチャンネルあたりの bit 数、コンポーネント数 (markerOffset + 9) は
        // 3 以上が YCbCr / RGB / CMYK で、1 はグレースケール
        hasFullColorDepth:
          imageBytesView.getUint8(markerOffset + 4) >= 8 && imageBytesView.getUint8(markerOffset + 9) >= 3,
      };
    }
    markerOffset += 2 + imageBytesView.getUint16(markerOffset + 2);
  }
  return null;
}

/**
 * フレームの寸法を持つ SOF マーカー (SOF0-SOF15) かどうか。
 * 同じ 0xC0-0xCF の範囲にある DHT (0xC4)・JPG (0xC8)・DAC (0xCC) はフレームではないため除く。
 */
function isJpegStartOfFrameMarker(jpegMarkerCode: number): boolean {
  return (
    jpegMarkerCode >= 0xc0 &&
    jpegMarkerCode <= 0xcf &&
    jpegMarkerCode !== 0xc4 &&
    jpegMarkerCode !== 0xc8 &&
    jpegMarkerCode !== 0xcc
  );
}

/**
 * WebP の RIFF ヘッダー (12バイト) 直後の最初のチャンクから実寸を読む。
 * VP8 (非可逆) は YUV 4:2:0 の 8bit、VP8L (可逆) は 8bit RGBA のため、いずれも RGB 256階調を満たす。
 */
function readWebpDimensions(imageBytesView: DataView): ImageDimensions | null {
  // チャンクヘッダー (種別4バイト + 長さ4バイト) の後ろ、オフセット 20 からがチャンクの内容
  if (readAsciiText(imageBytesView, 12, 4) === "VP8 " && imageBytesView.byteLength >= 30) {
    // 3バイトのフレームタグに続く sync code (0x9D 0x01 0x2A) の後ろに、14bit 幅・14bit 高さが並ぶ
    if (
      imageBytesView.getUint8(23) !== 0x9d ||
      imageBytesView.getUint8(24) !== 0x01 ||
      imageBytesView.getUint8(25) !== 0x2a
    ) {
      return null;
    }
    return {
      imageWidth: imageBytesView.getUint16(26, true) & 0x3fff,
      imageHeight: imageBytesView.getUint16(28, true) & 0x3fff,
      hasFullColorDepth: true,
    };
  }
  if (readAsciiText(imageBytesView, 12, 4) === "VP8L" && imageBytesView.byteLength >= 25) {
    if (imageBytesView.getUint8(20) !== 0x2f) {
      return null;
    }
    // シグネチャ (0x2F) の後ろの 32bit に、下位から 14bit ずつ (幅-1)・(高さ-1) が詰まっている
    return {
      imageWidth: (imageBytesView.getUint32(21, true) & 0x3fff) + 1,
      imageHeight: ((imageBytesView.getUint32(21, true) >>> 14) & 0x3fff) + 1,
      hasFullColorDepth: true,
    };
  }
  if (readAsciiText(imageBytesView, 12, 4) === "VP8X" && imageBytesView.byteLength >= 30) {
    // 拡張形式。フラグ4バイトの後ろに、24bit の (キャンバス幅-1)・(キャンバス高さ-1) がリトルエンディアンで並ぶ
    return {
      imageWidth: readUint24LittleEndian(imageBytesView, 24) + 1,
      imageHeight: readUint24LittleEndian(imageBytesView, 27) + 1,
      hasFullColorDepth: true,
    };
  }
  return null;
}

/**
 * HEIC (ISOBMFF) の ispe ボックスから実寸を読む。
 * HEIC の画素データは HEVC で、iOS が撮影・保存に使う Main / Main Still Picture プロファイルは
 * 8bit 以上のカラーのため、色の階調は満たす扱いにする。
 */
function readHeicDimensions(imageBytesView: DataView): ImageDimensions | null {
  const largestImageSpatialExtent = findLargestImageSpatialExtent(imageBytesView, 0, imageBytesView.byteLength);
  if (largestImageSpatialExtent === null) {
    return null;
  }
  return { ...largestImageSpatialExtent, hasFullColorDepth: true };
}

// ispe を内側に持つ ISOBMFF のコンテナボックス。meta は FullBox のため、子ボックスの前に version + flags の 4 バイトが入る
const isobmffContainerBoxTypes = ["meta", "iprp", "ipco"];

/**
 * 指定範囲の ISOBMFF ボックスを辿り、見つかった ispe (画像の空間サイズ) のうち画素数が最大のものを返す。
 * HEIC はサムネイル等の副画像も ispe を持つため、最大のものを主画像とみなす。
 */
function findLargestImageSpatialExtent(
  imageBytesView: DataView,
  rangeStartOffset: number,
  rangeEndOffset: number,
): { imageWidth: number; imageHeight: number } | null {
  let largestImageSpatialExtent: { imageWidth: number; imageHeight: number } | null = null;
  for (let boxOffset = rangeStartOffset; boxOffset + 8 <= rangeEndOffset; ) {
    // ボックス長 1 は 64bit 長 (ヘッダー直後の largesize)、0 は範囲の末尾までを表す
    const boxEndOffset =
      imageBytesView.getUint32(boxOffset) === 0
        ? rangeEndOffset
        : boxOffset +
          (imageBytesView.getUint32(boxOffset) === 1
            ? Number(imageBytesView.getBigUint64(boxOffset + 8))
            : imageBytesView.getUint32(boxOffset));
    if (boxEndOffset <= boxOffset || boxEndOffset > rangeEndOffset) {
      // 長さが壊れている場合は、それ以降を読まずにここまでの結果を返す
      return largestImageSpatialExtent;
    }
    const boxContentOffset = boxOffset + (imageBytesView.getUint32(boxOffset) === 1 ? 16 : 8);
    if (readAsciiText(imageBytesView, boxOffset + 4, 4) === "ispe") {
      // ispe は FullBox のため version + flags の 4 バイトを飛ばした先に幅・高さが並ぶ
      largestImageSpatialExtent = largerImageSpatialExtent(largestImageSpatialExtent, {
        imageWidth: imageBytesView.getUint32(boxContentOffset + 4),
        imageHeight: imageBytesView.getUint32(boxContentOffset + 8),
      });
    } else if (isobmffContainerBoxTypes.includes(readAsciiText(imageBytesView, boxOffset + 4, 4))) {
      largestImageSpatialExtent = largerImageSpatialExtent(
        largestImageSpatialExtent,
        findLargestImageSpatialExtent(
          imageBytesView,
          readAsciiText(imageBytesView, boxOffset + 4, 4) === "meta" ? boxContentOffset + 4 : boxContentOffset,
          boxEndOffset,
        ),
      );
    }
    boxOffset = boxEndOffset;
  }
  return largestImageSpatialExtent;
}

/** 2つの ispe の実寸のうち画素数が大きい方 (null は候補なし)。 */
function largerImageSpatialExtent(
  currentImageSpatialExtent: { imageWidth: number; imageHeight: number } | null,
  candidateImageSpatialExtent: { imageWidth: number; imageHeight: number } | null,
): { imageWidth: number; imageHeight: number } | null {
  if (candidateImageSpatialExtent === null) {
    return currentImageSpatialExtent;
  }
  if (currentImageSpatialExtent === null) {
    return candidateImageSpatialExtent;
  }
  return candidateImageSpatialExtent.imageWidth * candidateImageSpatialExtent.imageHeight >
    currentImageSpatialExtent.imageWidth * currentImageSpatialExtent.imageHeight
    ? candidateImageSpatialExtent
    : currentImageSpatialExtent;
}

/** WebP の VP8X が使う 24bit リトルエンディアン整数を読む (DataView に専用の読み出しが無いため組み立てる)。 */
function readUint24LittleEndian(imageBytesView: DataView, byteOffset: number): number {
  return (
    imageBytesView.getUint8(byteOffset) |
    (imageBytesView.getUint8(byteOffset + 1) << 8) |
    (imageBytesView.getUint8(byteOffset + 2) << 16)
  );
}

/** バイナリ中のチャンク種別・ボックス種別を表す ASCII 文字列を読む。 */
function readAsciiText(imageBytesView: DataView, byteOffset: number, byteLength: number): string {
  return String.fromCharCode(
    ...new Uint8Array(imageBytesView.buffer, imageBytesView.byteOffset + byteOffset, byteLength),
  );
}
