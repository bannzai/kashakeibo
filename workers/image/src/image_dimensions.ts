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

// PNG 仕様が定める先頭 8 バイトの固定シグネチャ。転送経路での改変を検出するための値がそのまま並ぶ
// (0x89 + "PNG" + CRLF + EOF + LF)。
// 出典: https://www.w3.org/TR/png/#5PNG-file-signature
const pngSignatureBytes = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];

/** 先頭のシグネチャで形式を判別し、形式ごとのヘッダー解析へ振り分ける。 */
function readImageDimensionsBySignature(imageBytesView: DataView): ImageDimensions | null {
  if (hasPngSignature(imageBytesView)) {
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

/** 先頭が PNG の固定シグネチャで始まるか。 */
function hasPngSignature(imageBytesView: DataView): boolean {
  return (
    imageBytesView.byteLength >= pngSignatureBytes.length &&
    pngSignatureBytes.every(
      (signatureByte, signatureByteIndex) => imageBytesView.getUint8(signatureByteIndex) === signatureByte,
    )
  );
}

// PNG の IHDR チャンクの内容の長さ。PNG 仕様で 13 バイト固定 (幅4 + 高さ4 + 深度1 + カラータイプ1 +
// 圧縮1 + フィルタ1 + インターレース1)。宣言長がこれ以外の IHDR は壊れたファイルとして扱う
const pngIhdrContentByteLength = 13;

/** PNG の IHDR チャンクから実寸とカラータイプを読む。 */
function readPngDimensions(imageBytesView: DataView): ImageDimensions | null {
  // IHDR は PNG 仕様で必ず最初のチャンク (署名8バイト + 長さ4バイト + タイプ4バイトの直後が内容)。
  // 署名8 + 長さ4 + タイプ4 + 内容13 + CRC4 = 33 バイトがチャンク全体としてバッファ内に収まり、
  // 宣言長も仕様どおりであることを検証する (宣言上チャンク外のバイトを寸法として読まないため)
  if (
    imageBytesView.byteLength < 33 ||
    imageBytesView.getUint32(8) !== pngIhdrContentByteLength ||
    readAsciiText(imageBytesView, 12, 4) !== "IHDR"
  ) {
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
      // SOF は固定部 (長さ2 + 精度1 + 高さ2 + 幅2 + コンポーネント数1 = 8 バイト) の後ろに、
      // 宣言したコンポーネント数ぶんの情報を 3 バイトずつ持つ。それに満たない長さや、
      // バッファからはみ出す末尾を持つセグメントは壊れており、読めた幅・高さも信用できない
      if (
        imageBytesView.getUint16(markerOffset + 2) < 8 + imageBytesView.getUint8(markerOffset + 9) * 3 ||
        markerOffset + 2 + imageBytesView.getUint16(markerOffset + 2) > imageBytesView.byteLength
      ) {
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
  // RIFF ヘッダーが宣言するファイル長 (自身の 8 バイトを含まない) に届かないバッファは途中で切れている。
  // どの分岐でも、宣言と実体が食い違うファイルの所定位置を寸法として読まないよう先に検証する
  if (imageBytesView.byteLength < 20 || imageBytesView.getUint32(4, true) + 8 > imageBytesView.byteLength) {
    return null;
  }
  // 先頭チャンク (種別4バイト + 長さ4バイト) の内容はオフセット 20 から。宣言長がその内容の長さ
  const firstChunkDeclaredByteLength = imageBytesView.getUint32(16, true);
  // チャンクの宣言長が最低限の内容 (VP8: フレームタグ3 + sync code 3 + 寸法4、VP8L: シグネチャ1 + 寸法4) を含み、
  // 宣言どおりの末尾がバッファ内に収まることも各分岐で検証する
  if (readAsciiText(imageBytesView, 12, 4) === "VP8 " && imageBytesView.byteLength >= 30) {
    if (firstChunkDeclaredByteLength < 10 || 20 + firstChunkDeclaredByteLength > imageBytesView.byteLength) {
      return null;
    }
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
    if (firstChunkDeclaredByteLength < 5 || 20 + firstChunkDeclaredByteLength > imageBytesView.byteLength) {
      return null;
    }
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
    // RIFF ヘッダーが宣言するファイル長 (自身の 8 バイトを含まない) に届かないバッファは途中で切れており、
    // VP8X が宣言するキャンバスの寸法どおりの画像が入っているとは限らない
    if (imageBytesView.getUint32(4, true) + 8 > imageBytesView.byteLength) {
      return null;
    }
    // VP8X はキャンバスの寸法とフラグだけを持つヘッダーで、画素は後続のチャンクにある。
    // 実画像チャンクが無い (ヘッダーだけの) ファイルは寸法・階調とも実体を伴わないため解析できなかった扱いにする
    if (!hasWebpImageDataChunk(imageBytesView)) {
      return null;
    }
    // フラグ4バイトの後ろに、24bit の (キャンバス幅-1)・(キャンバス高さ-1) がリトルエンディアンで並ぶ
    return {
      imageWidth: readUint24LittleEndian(imageBytesView, 24) + 1,
      imageHeight: readUint24LittleEndian(imageBytesView, 27) + 1,
      hasFullColorDepth: true,
    };
  }
  return null;
}

/**
 * RIFF のチャンクを辿り、画素を持つチャンクがバッファの範囲内にあるかを返す。
 *
 * アニメーション (ANIM/ANMF) はレシート・明細スクショの保存経路では作られないため、
 * フレーム内のチャンクまでは辿らず、静止画の VP8 (非可逆)・VP8L (可逆) だけを実画像として扱う。
 */
function hasWebpImageDataChunk(imageBytesView: DataView): boolean {
  // RIFF ヘッダーが宣言するファイル末尾より先は RIFF の外で、そこにあるバイト列はチャンクとして扱わない
  const riffDeclaredEndOffset = Math.min(imageBytesView.getUint32(4, true) + 8, imageBytesView.byteLength);
  // RIFF のチャンクは種別4バイト + 長さ4バイトのヘッダーを持ち、内容が奇数長のチャンクは 1 バイトのパディングで詰められる
  for (let chunkOffset = 12; chunkOffset + 8 <= riffDeclaredEndOffset; ) {
    const chunkContentByteLength = imageBytesView.getUint32(chunkOffset + 4, true);
    if (chunkOffset + 8 + chunkContentByteLength > riffDeclaredEndOffset) {
      // 内容が RIFF の宣言範囲からはみ出すチャンクは途中で切れており、その先にチャンクは無い
      return false;
    }
    const chunkType = readAsciiText(imageBytesView, chunkOffset, 4);
    // 実画像として認めるのは、最低限の内容 (VP8: フレームタグ3 + sync code 3 + 寸法4、VP8L: シグネチャ1 + 寸法4) を
    // 宣言し、シグネチャも一致するチャンクだけ。空・切り詰められた VP8/VP8L チャンクを画素の実体として数えない
    if (
      chunkType === "VP8 " &&
      chunkContentByteLength >= 10 &&
      imageBytesView.getUint8(chunkOffset + 11) === 0x9d &&
      imageBytesView.getUint8(chunkOffset + 12) === 0x01 &&
      imageBytesView.getUint8(chunkOffset + 13) === 0x2a
    ) {
      return true;
    }
    if (chunkType === "VP8L" && chunkContentByteLength >= 5 && imageBytesView.getUint8(chunkOffset + 8) === 0x2f) {
      return true;
    }
    chunkOffset += 8 + chunkContentByteLength + (chunkContentByteLength % 2);
  }
  return false;
}

/**
 * HEIC (ISOBMFF) の ispe ボックスから実寸を、pixi ボックスから色の階調を読む。
 * pixi を持たない・pixi が壊れている HEIC は色の階調を判定できないため null (unknown) にする。
 */
function readHeicDimensions(imageBytesView: DataView): ImageDimensions | null {
  const heicImageProperties = findHeicImageProperties(imageBytesView, 0, imageBytesView.byteLength);
  if (heicImageProperties.largestImageSpatialExtent === null) {
    return null;
  }
  return {
    ...heicImageProperties.largestImageSpatialExtent,
    hasFullColorDepth: heicImageProperties.hasFullColorDepth,
  };
}

/** HEIC のプロパティボックスから読み取った主画像の実寸と色の階調。 */
interface HeicImageProperties {
  /** 見つかった ispe のうち画素数が最大のもの。ispe が 1 つも無ければ null。 */
  largestImageSpatialExtent: { imageWidth: number; imageHeight: number } | null;
  /** pixi から判定した RGB 256階調以上か。pixi が無い・壊れている場合は null。 */
  hasFullColorDepth: boolean | null;
}

// ispe・pixi を内側に持つ ISOBMFF のコンテナボックス。meta は FullBox のため、子ボックスの前に version + flags の 4 バイトが入る
const isobmffContainerBoxTypes = ["meta", "iprp", "ipco"];

/**
 * 指定範囲の ISOBMFF ボックスを辿り、主画像の ispe (画像の空間サイズ) と pixi (画素の構成) を集める。
 *
 * ispe は HEIC がサムネイル等の副画像ぶんも持つため、画素数が最大のものを主画像とみなす。
 * pixi はどの画像のプロパティかがボックス単位では対応付けられないため、最初に判定できたものを採用する
 * (iOS の HEIC は主画像・サムネイルとも同じチャンネル構成で保存される)。
 */
function findHeicImageProperties(
  imageBytesView: DataView,
  rangeStartOffset: number,
  rangeEndOffset: number,
): HeicImageProperties {
  const heicImageProperties: HeicImageProperties = {
    largestImageSpatialExtent: null,
    hasFullColorDepth: null,
  };
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
      return heicImageProperties;
    }
    const boxContentOffset = boxOffset + (imageBytesView.getUint32(boxOffset) === 1 ? 16 : 8);
    const boxType = readAsciiText(imageBytesView, boxOffset + 4, 4);
    if (boxType === "ispe") {
      // ispe は FullBox のため version + flags の 4 バイトを飛ばした先に幅・高さが並ぶ
      heicImageProperties.largestImageSpatialExtent = largerImageSpatialExtent(
        heicImageProperties.largestImageSpatialExtent,
        {
          imageWidth: imageBytesView.getUint32(boxContentOffset + 4),
          imageHeight: imageBytesView.getUint32(boxContentOffset + 8),
        },
      );
    } else if (boxType === "pixi") {
      heicImageProperties.hasFullColorDepth =
        heicImageProperties.hasFullColorDepth ??
        readPixelInformationFullColorDepth(imageBytesView, boxContentOffset, boxEndOffset);
    } else if (isobmffContainerBoxTypes.includes(boxType)) {
      const nestedHeicImageProperties = findHeicImageProperties(
        imageBytesView,
        boxType === "meta" ? boxContentOffset + 4 : boxContentOffset,
        boxEndOffset,
      );
      heicImageProperties.largestImageSpatialExtent = largerImageSpatialExtent(
        heicImageProperties.largestImageSpatialExtent,
        nestedHeicImageProperties.largestImageSpatialExtent,
      );
      heicImageProperties.hasFullColorDepth =
        heicImageProperties.hasFullColorDepth ?? nestedHeicImageProperties.hasFullColorDepth;
    }
    boxOffset = boxEndOffset;
  }
  return heicImageProperties;
}

/**
 * pixi (FullBox) の内容から RGB 256階調以上かを判定する。
 * 途中で切れている pixi は判定できないため null を返す。
 */
function readPixelInformationFullColorDepth(
  imageBytesView: DataView,
  boxContentOffset: number,
  boxEndOffset: number,
): boolean | null {
  // FullBox の version + flags の 4 バイトの後ろにチャンネル数、その後ろにチャンネルごとの bit 数が 1 バイトずつ並ぶ
  if (boxContentOffset + 5 > boxEndOffset) {
    return null;
  }
  const channelCount = imageBytesView.getUint8(boxContentOffset + 4);
  if (boxContentOffset + 5 + channelCount > boxEndOffset) {
    return null;
  }
  // チャンネルが 3 未満はモノクロ等で、bit 深度が足りていても RGB のカラーにはならない
  if (channelCount < 3) {
    return false;
  }
  for (let channelIndex = 0; channelIndex < channelCount; channelIndex += 1) {
    if (imageBytesView.getUint8(boxContentOffset + 5 + channelIndex) < 8) {
      return false;
    }
  }
  return true;
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
