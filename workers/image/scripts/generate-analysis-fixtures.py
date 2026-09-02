#!/usr/bin/env python3
# 解析原価の実測 (issue #50) に使う合成テスト画像と正解データを生成する。
# 実レシートをリポジトリに含めると店舗・購買履歴等の実情報が混入するため、
# 実物のレイアウトを模した合成画像 (紙レシート単体2枚・複数レシート/分割レシート/同一決済の複数控えの写真4枚・アプリ明細スクショ2枚) を使う。
# 出力先: workers/image/tmp/analysis-fixtures/ (git 管理外)。
# 実行: python3 scripts/generate-analysis-fixtures.py
# 冪等: 同じ内容のファイルを毎回上書き生成する。
import json
import os
import random

from PIL import Image, ImageDraw, ImageFilter, ImageFont

# クライアントの撮影・選択設定 (lib/features/capture/capture_image_picker.dart: 長辺1600 / JPEG品質85) に合わせる
CAPTURED_IMAGE_MAX_LONG_SIDE = 1600
CAPTURED_IMAGE_JPEG_QUALITY = 85

# macOS 標準の日本語フォント。レシート印字・アプリ UI のどちらの描画にも使う
JAPANESE_FONT_PATH = "/System/Library/Fonts/ヒラギノ角ゴシック W3.ttc"

OUTPUT_DIRECTORY = os.path.join(os.path.dirname(__file__), "..", "tmp", "analysis-fixtures")


def font(size: int) -> ImageFont.FreeTypeFont:
    """指定サイズの日本語フォントを返す。"""
    return ImageFont.truetype(JAPANESE_FONT_PATH, size)


def draw_receipt_paper(lines: list[tuple[str, str, int]], paper_width: int) -> Image.Image:
    """レシート紙面 (白地) を描画して返す。lines は (左テキスト, 右テキスト, フォントサイズ) の並び。"""
    line_height_ratio = 1.7
    top_margin = 40
    height = top_margin * 2 + sum(int(size * line_height_ratio) for _, _, size in lines)
    paper = Image.new("RGB", (paper_width, height), (252, 252, 250))
    paper_draw = ImageDraw.Draw(paper)
    y = top_margin
    for left_text, right_text, size in lines:
        line_font = font(size)
        # 中央寄せ: 右テキストが空で左テキストが「※」始まりでない見出し行はセンタリングする
        if right_text == "" and left_text.startswith("<center>"):
            centered_text = left_text.removeprefix("<center>")
            text_width = paper_draw.textlength(centered_text, font=line_font)
            paper_draw.text(((paper_width - text_width) / 2, y), centered_text, font=line_font, fill=(30, 30, 30))
        else:
            paper_draw.text((40, y), left_text, font=line_font, fill=(30, 30, 30))
            if right_text:
                right_width = paper_draw.textlength(right_text, font=line_font)
                paper_draw.text((paper_width - 40 - right_width, y), right_text, font=line_font, fill=(30, 30, 30))
        y += int(size * line_height_ratio)
    return paper


def compose_receipt_photo(paper: Image.Image, output_path: str) -> None:
    """レシート紙面を撮影写真風 (背景・微回転・ノイズ) に合成して JPEG 保存する。"""
    # 撮影写真の再現度を安定させるため乱数は固定シード
    random.seed(50)
    canvas_width = 1200
    canvas_height = max(paper.height + 200, int(canvas_width * 4 / 3))
    # 木目テーブル風の背景色
    canvas = Image.new("RGB", (canvas_width, canvas_height), (168, 136, 105))
    rotated_paper = paper.rotate(1.5, expand=True, fillcolor=(168, 136, 105), resample=Image.BICUBIC)
    canvas.paste(rotated_paper, ((canvas_width - rotated_paper.width) // 2, (canvas_height - rotated_paper.height) // 2))
    # 実写に近づけるための弱いブラー (印字の滲み)
    canvas = canvas.filter(ImageFilter.GaussianBlur(0.6))
    save_as_captured_jpeg(canvas, output_path)


def compose_multi_paper_photo(papers: list[Image.Image], output_path: str) -> None:
    """複数のレシート紙片を 1 枚の撮影写真風に並べて合成し JPEG 保存する (issue #82)。

    実際の撮影 (机の上にレシートを並べて撮る) を再現するため、背景の小物 (スマホ・ペン) も描き込み、
    背景の映り込みを無視して紙面だけを抽出できるかを検査する。
    """
    random.seed(52)
    paper_gap = 60
    canvas_width = sum(paper.width for paper in papers) + paper_gap * (len(papers) + 1)
    canvas_height = max(paper.height for paper in papers) + 320
    canvas = Image.new("RGB", (canvas_width, canvas_height), (168, 136, 105))
    canvas_draw = ImageDraw.Draw(canvas)
    # 背景の映り込み: スマホ (左下の暗い角丸矩形) とペン (上部の細長い矩形)
    canvas_draw.rounded_rectangle(
        [40, canvas_height - 240, 360, canvas_height - 60], radius=30, fill=(28, 30, 34), outline=(70, 72, 78), width=4
    )
    canvas_draw.rounded_rectangle([canvas_width - 520, 40, canvas_width - 80, 78], radius=18, fill=(40, 60, 130))
    x = paper_gap
    for paper_index, paper in enumerate(papers):
        # 手置きのばらつきを再現するため紙片ごとに逆向きへ少し回転させる
        rotated_paper = paper.rotate(
            1.5 if paper_index % 2 == 0 else -1.8, expand=True, fillcolor=(168, 136, 105), resample=Image.BICUBIC
        )
        canvas.paste(rotated_paper, (x, (canvas_height - rotated_paper.height) // 2))
        x += paper.width + paper_gap
    canvas = canvas.filter(ImageFilter.GaussianBlur(0.6))
    save_as_captured_jpeg(canvas, output_path)


def save_as_captured_jpeg(image: Image.Image, output_path: str) -> None:
    """クライアントの撮影設定 (長辺1600 / JPEG品質85) に合わせて縮小・保存する。"""
    scale = CAPTURED_IMAGE_MAX_LONG_SIDE / max(image.size)
    if scale < 1:
        image = image.resize((int(image.width * scale), int(image.height * scale)), Image.LANCZOS)
    image.save(output_path, "JPEG", quality=CAPTURED_IMAGE_JPEG_QUALITY)


def generate_convenience_store_receipt(output_path: str) -> list[dict]:
    """コンビニレシート (1明細 = 支払総額) を生成し、正解明細を返す。"""
    lines = [
        ("<center>セブン-イレブン", "", 44),
        ("<center>目黒駅前店", "", 32),
        ("<center>東京都品川区上大崎2-16-9", "", 24),
        ("<center>電話 03-1234-5678", "", 24),
        ("2026年8月15日(土) 19:42", "", 26),
        ("レジ#3 責001", "", 24),
        ("", "", 16),
        ("おにぎり ツナマヨネーズ", "¥138", 28),
        ("ミックスサンド", "¥298", 28),
        ("お〜いお茶 600ml", "¥140", 28),
        ("ガーナミルクチョコレート", "¥216", 28),
        ("からあげ弁当", "¥498", 28),
        ("", "", 16),
        ("小計", "¥1,290", 28),
        ("消費税等(8%対象 ¥1,290)", "¥103", 26),
        ("合計", "¥1,393", 36),
        ("現金", "¥1,500", 28),
        ("お釣り", "¥107", 28),
        ("", "", 16),
        ("<center>お買い上げありがとうございます", "", 24),
    ]
    compose_receipt_photo(draw_receipt_paper(lines, 820), output_path)
    return [
        {"title": "セブン-イレブン", "amount": 1393, "transactionDate": "2026-08-15", "type": "expense", "category": "food"},
    ]


def generate_supermarket_receipt(output_path: str) -> list[dict]:
    """スーパーのレシート (品目多め・1明細 = 支払総額) を生成し、正解明細を返す。"""
    lines = [
        ("<center>スーパーライフ", "", 44),
        ("<center>大崎ニューシティ店", "", 30),
        ("2026年8月2日(日) 11:08", "", 26),
        ("", "", 16),
        ("国産豚こま切れ 300g", "¥398", 28),
        ("キャベツ 1玉", "¥158", 28),
        ("たまご 10個", "¥278", 28),
        ("牛乳 1000ml", "¥238", 28),
        ("食パン 6枚切", "¥148", 28),
        ("納豆 3パック", "¥98", 28),
        ("バナナ", "¥198", 28),
        ("鶏むね肉 2枚", "¥458", 28),
        ("トマト 3個", "¥298", 28),
        ("ヨーグルト 400g", "¥178", 28),
        ("冷凍うどん 5食", "¥248", 28),
        ("味噌 750g", "¥328", 28),
        ("", "", 16),
        ("小計(税抜)", "¥3,026", 28),
        ("消費税等(8%)", "¥242", 26),
        ("合計", "¥3,268", 36),
        ("クレジット", "¥3,268", 28),
        ("", "", 16),
        ("<center>ポイントカード 123-456", "", 24),
    ]
    compose_receipt_photo(draw_receipt_paper(lines, 820), output_path)
    return [
        {"title": "スーパーライフ", "amount": 3268, "transactionDate": "2026-08-02", "type": "expense", "category": "food"},
    ]


def generate_two_receipts_photo(output_path: str) -> list[dict]:
    """別々の支払いのレシート 2 枚が 1 枚の画像に写った写真 (レシートごとに 1 明細 = 2 明細。issue #82) を生成し、正解明細を返す。"""
    drugstore_lines = [
        ("<center>サニードラッグ", "", 40),
        ("<center>五反田駅前店", "", 28),
        ("2026年8月11日(火) 20:15", "", 24),
        ("", "", 14),
        ("衣料用洗剤 詰替", "¥328", 26),
        ("シャンプー 450ml", "¥548", 26),
        ("ボックスティッシュ 5箱", "¥98", 26),
        ("", "", 14),
        ("小計", "¥974", 26),
        ("消費税等(10%)", "¥78", 24),
        ("合計", "¥1,052", 34),
        ("現金", "¥1,052", 26),
    ]
    cafe_lines = [
        ("<center>喫茶こもれび", "", 40),
        ("2026年8月12日(水) 14:30", "", 24),
        ("", "", 14),
        ("ブレンドコーヒー", "¥480", 26),
        ("チーズケーキ", "¥520", 26),
        ("", "", 14),
        ("合計(税込)", "¥1,100", 34),
        ("現金", "¥1,100", 26),
        ("", "", 14),
        ("<center>またのご来店をお待ちしております", "", 22),
    ]
    compose_multi_paper_photo(
        [draw_receipt_paper(drugstore_lines, 640), draw_receipt_paper(cafe_lines, 640)], output_path
    )
    return [
        {"title": "サニードラッグ", "amount": 1052, "transactionDate": "2026-08-11", "type": "expense", "category": "dailyGoods"},
        {"title": "喫茶こもれび", "amount": 1100, "transactionDate": "2026-08-12", "type": "expense", "category": "eatingOut"},
    ]


def generate_same_store_two_receipts_photo(output_path: str) -> list[dict]:
    """同じ店・同じ日付の完結したレシート 2 枚 (それぞれに合計あり) が写った写真を生成し、正解明細を返す。

    店名・日付が同じでも、各紙片が合計を持つ完結したレシートなら分割紙片として統合せず
    2 明細に分けられるか (issue #82。PR #83 のレビュー指摘) を検査する。
    """
    first_visit_lines = [
        ("<center>まちのパン屋 こむぎ", "", 40),
        ("2026年8月25日(火) 08:12", "", 24),
        ("", "", 14),
        ("クロワッサン", "¥205", 26),
        ("食パン 1斤", "¥246", 26),
        ("", "", 14),
        ("合計(税込)", "¥451", 34),
        ("現金", "¥451", 26),
    ]
    second_visit_lines = [
        ("<center>まちのパン屋 こむぎ", "", 40),
        ("2026年8月25日(火) 12:47", "", 24),
        ("", "", 14),
        ("サンドイッチ", "¥378", 26),
        ("カフェオレ", "¥180", 26),
        ("メロンパン", "¥224", 26),
        ("", "", 14),
        ("合計(税込)", "¥782", 34),
        ("現金", "¥782", 26),
    ]
    compose_multi_paper_photo(
        [draw_receipt_paper(first_visit_lines, 640), draw_receipt_paper(second_visit_lines, 640)], output_path
    )
    # ベーカリーはイートイン併設か否かで食費/外食のどちらにも読めるため、実物ベンチマーク (cascade) と同じく両方を正解にする
    return [
        {"title": "まちのパン屋 こむぎ", "amount": 451, "transactionDate": "2026-08-25", "type": "expense", "category": "food", "categoryAliases": ["eatingOut"]},
        {"title": "まちのパン屋 こむぎ", "amount": 782, "transactionDate": "2026-08-25", "type": "expense", "category": "food", "categoryAliases": ["eatingOut"]},
    ]


def generate_receipt_with_card_slip_photo(output_path: str) -> list[dict]:
    """同じ 1 回の決済のレシートとクレジットカード利用控え (売上票) が写った写真を生成し、正解明細を返す。

    どちらも同じ合計額を持つ完結した紙だが、同一決済の控えのため二重計上せず
    1 明細にまとめられるか (issue #82。PR #83 のレビュー指摘) を検査する。
    """
    receipt_lines = [
        ("<center>洋食キッチンひまわり", "", 40),
        ("2026年8月18日(火) 19:32", "", 24),
        ("", "", 14),
        ("ハンバーグ定食", "¥1,480", 26),
        ("エビフライ定食", "¥1,580", 26),
        ("ウーロン茶", "¥180", 26),
        ("", "", 14),
        ("合計(税込)", "¥3,240", 34),
        ("クレジット", "¥3,240", 26),
    ]
    card_slip_lines = [
        ("<center>クレジット売上票", "", 34),
        ("<center>洋食キッチンひまわり", "", 30),
        ("2026年8月18日 19:33", "", 24),
        ("", "", 14),
        ("VISA ************1234", "", 24),
        ("承認番号 012345", "", 24),
        ("支払区分 一括", "", 24),
        ("", "", 14),
        ("金額", "¥3,240", 34),
        ("", "", 14),
        ("<center>ご署名不要", "", 22),
    ]
    compose_multi_paper_photo(
        [draw_receipt_paper(receipt_lines, 640), draw_receipt_paper(card_slip_lines, 640)], output_path
    )
    return [
        {"title": "洋食キッチンひまわり", "amount": 3240, "transactionDate": "2026-08-18", "type": "expense", "category": "eatingOut"},
    ]


def generate_split_long_receipt_photo(output_path: str) -> list[dict]:
    """長いレシート 1 枚が 2 つの紙片に分かれて写った写真 (全体で 1 明細。issue #82) を生成し、正解明細を返す。

    紙片 1 に店名・日付と品目の前半、紙片 2 に品目の後半と合計を置き、
    行の連続性から同一支払いと判断してまとめられるかを検査する。
    """
    first_piece_lines = [
        ("<center>フレッシュマート", "", 40),
        ("<center>青葉台店", "", 28),
        ("2026年8月20日(木) 18:05", "", 24),
        ("", "", 14),
        ("牛乳 1000ml", "¥238", 26),
        ("たまご 10個", "¥278", 26),
        ("食パン 6枚切", "¥158", 26),
        ("豚ロース 400g", "¥698", 26),
        ("カットサラダ", "¥398", 26),
        ("りんご 3個", "¥348", 26),
        ("豆腐 2丁", "¥88", 26),
    ]
    second_piece_lines = [
        ("ほうれん草", "¥178", 26),
        ("鶏もも肉 2枚", "¥512", 26),
        ("スライスチーズ", "¥428", 26),
        ("お米 5kg", "¥2,180", 26),
        ("", "", 14),
        ("小計(税抜)", "¥5,504", 26),
        ("消費税等(8%)", "¥440", 24),
        ("合計", "¥5,944", 34),
        ("クレジット", "¥5,944", 26),
        ("", "", 14),
        ("<center>お買い上げありがとうございます", "", 22),
    ]
    compose_multi_paper_photo(
        [draw_receipt_paper(first_piece_lines, 640), draw_receipt_paper(second_piece_lines, 640)], output_path
    )
    return [
        {"title": "フレッシュマート", "amount": 5944, "transactionDate": "2026-08-20", "type": "expense", "category": "food"},
    ]


def draw_app_screenshot(title: str, header_lines: list[str], rows: list[tuple[str, str, str]], output_path: str) -> None:
    """スマホアプリ風の明細スクショ (取引ごとの行) を描画して JPEG 保存する。rows は (日付, 摘要, 金額)。"""
    width, height = 780, 1688
    screenshot = Image.new("RGB", (width, height), (245, 246, 248))
    screenshot_draw = ImageDraw.Draw(screenshot)
    # ステータスバー + ヘッダー
    screenshot_draw.rectangle([0, 0, width, 210], fill=(21, 62, 118))
    screenshot_draw.text((32, 40), "9:41", font=font(28), fill=(255, 255, 255))
    screenshot_draw.text((32, 96), title, font=font(40), fill=(255, 255, 255))
    y = 152
    for header_line in header_lines:
        screenshot_draw.text((32, y), header_line, font=font(26), fill=(210, 220, 235))
        y += 40
    # 取引行
    y = 250
    for row_date, row_title, row_amount in rows:
        screenshot_draw.rectangle([16, y, width - 16, y + 130], fill=(255, 255, 255))
        screenshot_draw.text((40, y + 18), row_date, font=font(24), fill=(120, 126, 134))
        screenshot_draw.text((40, y + 58), row_title, font=font(30), fill=(35, 38, 42))
        amount_width = screenshot_draw.textlength(row_amount, font=font(32))
        screenshot_draw.text((width - 40 - amount_width, y + 44), row_amount, font=font(32), fill=(35, 38, 42))
        y += 146
    save_as_captured_jpeg(screenshot, output_path)


def generate_card_statement_screenshot(output_path: str) -> list[dict]:
    """クレジットカード明細アプリのスクショ (取引5件) を生成し、正解明細を返す。"""
    draw_app_screenshot(
        "ご利用明細",
        ["三井住友カード / 2026年8月ご利用分"],
        [
            ("2026/08/01", "JR東日本 モバイルSuicaチャージ", "¥3,000"),
            ("2026/08/03", "AMAZON.CO.JP", "¥2,480"),
            ("2026/08/05", "NETFLIX.COM", "¥1,490"),
            ("2026/08/10", "スターバックス コーヒー", "¥680"),
            ("2026/08/12", "マツモトキヨシ 五反田店", "¥1,280"),
        ],
        output_path,
    )
    return [
        {"title": "JR東日本 モバイルSuicaチャージ", "amount": 3000, "transactionDate": "2026-08-01", "type": "expense", "category": "transportation"},
        {"title": "AMAZON.CO.JP", "amount": 2480, "transactionDate": "2026-08-03", "type": "expense", "category": "other"},
        {"title": "NETFLIX.COM", "amount": 1490, "transactionDate": "2026-08-05", "type": "expense", "category": "subscription"},
        {"title": "スターバックス コーヒー", "amount": 680, "transactionDate": "2026-08-10", "type": "expense", "category": "eatingOut"},
        {"title": "マツモトキヨシ 五反田店", "amount": 1280, "transactionDate": "2026-08-12", "type": "expense", "category": "dailyGoods"},
    ]


def generate_ec_history_screenshot(output_path: str) -> list[dict]:
    """EC 購入履歴のスクショ (注文2件) を生成し、正解明細を返す。"""
    draw_app_screenshot(
        "注文履歴",
        ["Amazon.co.jp"],
        [
            ("2026年8月9日 注文", "ワイヤレスイヤホン Bluetooth 5.4", "¥3,980"),
            ("2026年7月28日 注文", "USB-C 充電ケーブル 2m 2本セット", "¥1,280"),
        ],
        output_path,
    )
    return [
        {"title": "ワイヤレスイヤホン Bluetooth 5.4", "amount": 3980, "transactionDate": "2026-08-09", "type": "expense", "category": "other"},
        {"title": "USB-C 充電ケーブル 2m 2本セット", "amount": 1280, "transactionDate": "2026-07-28", "type": "expense", "category": "other"},
    ]


def write_variant_sets(ground_truth: dict) -> None:
    """劣化版 (手ブレ・ノイズ相当) と縮小版 (長辺1024) の派生セットを生成する。
    劣化版は media resolution・軽量モデルの実写ロバスト性の比較、縮小版はクライアント縮小強化の効果測定に使う。"""
    random.seed(51)
    degraded_directory = OUTPUT_DIRECTORY + "-degraded"
    resized_directory = OUTPUT_DIRECTORY + "-1024"
    os.makedirs(degraded_directory, exist_ok=True)
    os.makedirs(resized_directory, exist_ok=True)
    for fixture_name in ground_truth:
        original = Image.open(os.path.join(OUTPUT_DIRECTORY, fixture_name))
        # 劣化版: 撮影距離が遠い (縮小 70%) + 手ブレ (ブラー) + センサーノイズ
        degraded = original.resize((int(original.width * 0.7), int(original.height * 0.7)), Image.LANCZOS)
        degraded = degraded.filter(ImageFilter.GaussianBlur(1.1))
        # センサーノイズ: 画素ごとに変動するガウシアンノイズ (mean 128 / sigma 18) を 12% ブレンドして粒状ノイズを加える
        noise_rgb = Image.merge("RGB", [Image.effect_noise(degraded.size, 18).convert("L")] * 3)
        degraded = Image.blend(degraded, noise_rgb, 0.12)
        degraded.save(os.path.join(degraded_directory, fixture_name), "JPEG", quality=70)
        # 縮小版: 長辺 1024 (クライアント縮小を 1600 -> 1024 に強化した場合の入力)
        resize_scale = 1024 / max(original.size)
        original.resize((int(original.width * resize_scale), int(original.height * resize_scale)), Image.LANCZOS).save(
            os.path.join(resized_directory, fixture_name), "JPEG", quality=CAPTURED_IMAGE_JPEG_QUALITY
        )
    for variant_directory in (degraded_directory, resized_directory):
        with open(os.path.join(variant_directory, "ground-truth.json"), "w") as ground_truth_file:
            json.dump(ground_truth, ground_truth_file, ensure_ascii=False, indent=2)
        print(f"生成: {variant_directory}/")


def main() -> None:
    """8枚のテスト画像と正解データ (ground-truth.json)、劣化版・縮小版の派生セットを生成する。"""
    os.makedirs(OUTPUT_DIRECTORY, exist_ok=True)
    ground_truth = {
        "receipt_convenience.jpg": generate_convenience_store_receipt(os.path.join(OUTPUT_DIRECTORY, "receipt_convenience.jpg")),
        "receipt_supermarket.jpg": generate_supermarket_receipt(os.path.join(OUTPUT_DIRECTORY, "receipt_supermarket.jpg")),
        "receipt_two_receipts.jpg": generate_two_receipts_photo(os.path.join(OUTPUT_DIRECTORY, "receipt_two_receipts.jpg")),
        "receipt_same_store_two_receipts.jpg": generate_same_store_two_receipts_photo(os.path.join(OUTPUT_DIRECTORY, "receipt_same_store_two_receipts.jpg")),
        "receipt_with_card_slip.jpg": generate_receipt_with_card_slip_photo(os.path.join(OUTPUT_DIRECTORY, "receipt_with_card_slip.jpg")),
        "receipt_split_long.jpg": generate_split_long_receipt_photo(os.path.join(OUTPUT_DIRECTORY, "receipt_split_long.jpg")),
        "screenshot_card_statement.jpg": generate_card_statement_screenshot(os.path.join(OUTPUT_DIRECTORY, "screenshot_card_statement.jpg")),
        "screenshot_ec_history.jpg": generate_ec_history_screenshot(os.path.join(OUTPUT_DIRECTORY, "screenshot_ec_history.jpg")),
    }
    with open(os.path.join(OUTPUT_DIRECTORY, "ground-truth.json"), "w") as ground_truth_file:
        json.dump(ground_truth, ground_truth_file, ensure_ascii=False, indent=2)
    for fixture_name in ground_truth:
        print(f"生成: {os.path.join(OUTPUT_DIRECTORY, fixture_name)}")
    write_variant_sets(ground_truth)


if __name__ == "__main__":
    main()
