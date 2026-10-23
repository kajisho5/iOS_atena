# 宛名印刷 はがき・封筒 — 設計書 v0.1（Step 1: プロジェクト構成と画面遷移）

> ステータス: **確認待ち**。この設計の承認後に ①宛先リストとCSV取り込み の実装へ進む。
> 画面遷移図: [`screen-flow.svg`](./screen-flow.svg)

---

## 0. 設計原則（判断基準）

| 原則 | 設計への反映 |
|---|---|
| 広告なし | 広告SDK・解析SDK・トラッキング（ATT）を一切組み込まない |
| サブスクなし | StoreKit 2 の非消耗型1点のみ。自動更新サブスク商品は作らない |
| 佳境で課金画面を出さない | 課金画面（Paywall）は**ユーザーが能動的に押した時だけ**表示。印刷フロー中に自動で割り込むことはない（後述 §5） |
| 端末内のみ | SwiftData はローカルストアのみ（`cloudKitDatabase: .none`）。ネットワーク通信は StoreKit（Apple）のみ |
| HIG準拠 | 標準コンポーネント（`List` / `Form` / `NavigationSplitView` / `.toolbar` / `.sheet`）を優先し、独自UIは用紙プレビューのみに限定 |

---

## 1. 技術スタック

| 項目 | 採用 |
|---|---|
| 言語/UI | Swift 6 系 / SwiftUI（Swift Concurrency strict） |
| 最低OS | iOS 17.0 / iPadOS 17.0（Mac は Designed for iPad） |
| 永続化 | SwiftData（ローカルのみ）＋ 一部設定は `UserDefaults`（`@AppStorage`） |
| 印刷 | `UIPrintInteractionController` + 自前 `UIPrintPageRenderer` |
| PDF | `UIGraphicsPDFRenderer` |
| 連絡先 | ContactsUI（`CNContactPickerViewController`） |
| 課金 | StoreKit 2（`Product` / `Transaction.currentEntitlements` / `AppStore.sync()`） |
| レビュー依頼 | SwiftUI `@Environment(\.requestReview)` |
| プロジェクト生成 | XcodeGen（`project.yml`）。生成済み `.xcodeproj` もコミットし、XcodeGen 未導入でも開けるようにする |
| 外部ライブラリ | なし |

---

## 2. ディレクトリ構成

```
iOS_atena/
├── project.yml                      # XcodeGen 定義
├── AtenaPrint.xcodeproj/            # 生成物（コミットする）
├── AtenaPrint/
│   ├── App/
│   │   ├── AtenaPrintApp.swift      # @main, ModelContainer 構築
│   │   ├── RootView.swift           # TabView（宛先 / レイアウト / 設定）
│   │   └── AppConstants.swift       # 差し替え定数（商品ID・URL・無料上限など）
│   ├── Models/                      # SwiftData @Model と値型
│   │   ├── Recipient.swift
│   │   ├── RecipientGroup.swift
│   │   ├── PrintRecord.swift
│   │   ├── SenderProfile.swift
│   │   ├── PaperType.swift          # 用紙定義（寸法mm・郵便番号枠座標）
│   │   └── LayoutSettings.swift     # Codable, @AppStorage 保存
│   ├── Features/
│   │   ├── Recipients/              # 一覧・詳細・編集・グループ
│   │   ├── Import/                  # CSV取り込み（マッピング確認）・連絡先取り込み
│   │   ├── Layout/                  # レイアウト設定＋ライブプレビュー
│   │   ├── Print/                   # 印刷プレビュー・印刷実行・PDF書き出し
│   │   ├── Store/                   # Paywall
│   │   └── Settings/                # 差出人・位置調整・購入復元・規約
│   ├── Rendering/                   # 描画エンジン（UI非依存）
│   │   ├── AddressRenderer.swift    # CGContext に mm 単位で宛名面を描く唯一の実装
│   │   ├── VerticalTextLayout.swift # 縦書き1文字ずつのレイアウト
│   │   ├── TextFitter.swift         # 自動縮小とはみ出し判定
│   │   ├── KanjiNumeralConverter.swift
│   │   └── FontCatalog.swift
│   ├── Services/
│   │   ├── CSVParser.swift          # RFC 4180 + 文字コード自動判定
│   │   ├── CSVTemplate.swift        # テンプレート生成
│   │   ├── PrintService.swift
│   │   ├── PDFExporter.swift
│   │   ├── StoreService.swift       # @Observable, 購入状態
│   │   └── ReviewPrompter.swift
│   └── Resources/
│       ├── Assets.xcassets
│       ├── AppIcon.icon/            # fresnel で作成（⑤で追加）
│       ├── PrivacyInfo.xcprivacy
│       └── Products.storekit        # ローカル StoreKit テスト用設定
├── AtenaPrintTests/                 # CSV・漢数字・自動縮小・用紙座標のユニットテスト
├── .github/workflows/build.yml      # macOS ランナーでビルド＋テスト（§9）
├── docs/                            # 設計書・SVG
├── marketing/                       # デモモック・App Store 文案（⑤）
└── README.md
```

**描画の一元化**: プレビュー（SwiftUI）・AirPrint・PDF の3経路すべてが `AddressRenderer.draw(in: CGContext, page:)` を呼ぶ。プレビューと実際の印刷結果がずれる原因を構造的に排除する。

---

## 3. データモデル（SwiftData）

```swift
@Model final class Recipient {
    var name: String              // 氏名
    var jointNames: [String]      // 連名（0〜2件を想定）
    var honorific: String         // 敬称（"様" 既定）
    var postalCode: String        // 数字7桁のみ保持（ハイフン除去）
    var address1: String          // 住所
    var address2: String          // 建物名等（任意）※要確認 Q4
    var memo: String              // 喪中・転居先など
    var createdAt: Date
    var updatedAt: Date
    @Relationship(inverse: \RecipientGroup.recipients) var groups: [RecipientGroup]
    @Relationship(deleteRule: .cascade, inverse: \PrintRecord.recipient) var printRecords: [PrintRecord]
}

@Model final class RecipientGroup { var name: String; var sortOrder: Int; var recipients: [Recipient] }

@Model final class PrintRecord {           // 印刷済みフラグ＋日時の実体
    var recipient: Recipient?
    var group: RecipientGroup?             // どのグループの一括印刷か（単発印刷は nil）
    var paperType: String
    var printedAt: Date
}

@Model final class SenderProfile {         // 差出人（複数）
    var label: String                      // "自宅" / "仕事"
    var name: String; var jointNames: [String]
    var postalCode: String; var address1: String; var address2: String
    var sortOrder: Int
}
```

- **印刷済みの判定**: グループ画面では「そのグループで印刷記録があるか」、全件画面では「いずれかの印刷記録があるか」で表示。翌年は新グループ（年賀状2027）を作れば未印刷から始められる。記録の手動リセットも可能にする。
- **LayoutSettings**（`Codable` を `@AppStorage` に JSON 保存）: 用紙種別 / 縦横 / フォント / 漢数字変換 ON/OFF / 差出人印刷 ON/OFF と選択中の差出人 / **用紙種別ごとの** 上下左右オフセット(mm)。オフセットはプリンタの給紙経路が用紙で変わるため用紙別に保持する。
- 敬称プリセット: 様 / 殿 / 先生 / 御中 / 行 ＋ 自由入力。

---

## 4. 画面構成と遷移

詳細は [`screen-flow.svg`](./screen-flow.svg)。

### 4.1 ルート構成

- `TabView` 3タブ: **宛先**（`person.2`） / **レイアウト**（`envelope`） / **設定**（`gearshape`）
- iPad / Mac: 宛先タブ内を `NavigationSplitView`（サイドバー＝グループ、コンテンツ＝宛先一覧、詳細＝宛先詳細＋プレビュー）
- iPhone: 同じ `NavigationSplitView` が自動で `NavigationStack` に折りたたまれる（HIG のサイドバー挙動に準拠）

### 4.2 画面一覧

| ID | 画面 | 表示形式 | 主な要素 |
|---|---|---|---|
| S01 | グループ一覧（サイドバー） | Split sidebar | すべて / 未印刷 / 各グループ、グループ追加・名称変更・並べ替え |
| S02 | 宛先一覧 | List | 検索（`.searchable`）、印刷済みバッジ、スワイプ削除、選択モード、`+` メニュー（手入力 / 連絡先から / CSVから） |
| S03 | 宛先詳細 | Push | 宛名面サムネイル、印刷履歴、「この宛先を印刷」 |
| S04 | 宛先編集 | Sheet（Form） | 氏名・連名・敬称・〒・住所・メモ・グループ |
| S05 | 連絡先から取り込み | システムピッカー | `CNContactPickerViewController`（複数選択）→ 取り込み確認 |
| S06 | CSV 取り込み | Sheet（3段階） | ①ファイル選択（`.fileImporter`）②列マッピング確認（先頭5行プレビュー、文字コード表示/切替）③結果（成功・スキップ・エラー行） |
| S07 | 印刷プレビュー | Full-screen cover | 実寸比プレビュー（用紙枠・郵便番号枠）、一括時は前後ページ送り、はみ出し警告、二重印刷警告、「印刷」「PDF」ボタン |
| S08 | AirPrint | システムUI | `UIPrintInteractionController`（iPad/Mac はポップオーバー） |
| S09 | レイアウト | Tab（Form＋プレビュー） | 用紙 / 縦横 / フォント / 漢数字変換 / 差出人ON/OFF・選択。iPhone は上プレビュー＋下Form、iPad は左右分割 |
| S10 | 設定 | Tab（Form） | 差出人プロフィール、印刷位置調整、Pro購入・**購入の復元**、CSVテンプレート書き出し、プライバシーポリシー・利用規約、バージョン |
| S11 | 差出人一覧・編集 | Push / Sheet | 複数登録、並べ替え |
| S12 | 印刷位置調整 | Push | 用紙ごとに上下左右 ±10mm（0.5mm刻み Stepper）、テスト印刷ボタン |
| S13 | Pro（Paywall） | Sheet | 下記 §5 の文言、価格をそのまま表示した購入ボタン、購入の復元、閉じる |

### 4.3 主要フロー

1. **1件印刷**: S02 → S03 →「印刷」→ S07 → S08 → 完了で `PrintRecord` 作成、成功回数 +1
2. **グループ一括印刷**: S01 でグループ選択 → S02 ツールバー「一括印刷」→ 未印刷のみ/全件 を選択 → S07 → S08（全ページを1ジョブで送信）→ 完了で全件に `PrintRecord`
3. **選択印刷**: S02「選択」→ 複数チェック →「印刷」→ S07
4. **CSV取り込み**: S02 `+` →「CSVから」→（未購入なら S13、購入済みなら S06）→ 取り込み後 S02 に戻り結果トースト
5. **PDF**: S07「PDF」→（未購入なら S13）→ `ShareLink` で共有シート（保存は「ファイルに保存」）

印刷完了の判定は `UIPrintInteractionController.CompletionHandler` の `completed == true`。「プリンタへ送信完了」であって実際の排紙成功は OS から取得できない（Apple API の仕様）。そのため印刷済みは「送信済み」の意味になる点をUI文言で明示する（例:「印刷済み（送信日時）」）。

---

## 5. 課金設計

| 項目 | 無料 | Pro（買い切り） |
|---|---|---|
| 宛先登録 | 10件まで | 無制限 |
| 印刷（AirPrint） | **無制限・透かしなし** | 同左 |
| CSV取り込み | × | ○ |
| PDF出力 | × | ○ |

- 商品: 非消耗型 1点、`AppConstants.proProductID`（既定 `com.example.atenaprint.pro` を README で差し替え指示）
- **Paywall を出すタイミング（能動操作のみ）**:
  - 11件目の宛先を保存しようとした時（保存ボタン押下時。入力中は出さない）
  - 「CSVから」を押した時
  - 印刷プレビューの「PDF」を押した時（「印刷」ボタンは常に無料で動作するため、印刷の邪魔にはならない）
  - 設定の「Pro」行
- 連絡先取り込みで上限を超える場合: 上限まで取り込み、残り件数を明示して「Pro について」ボタンを置く（自動では開かない）
- Paywall 必須文言: 「これは買い切りです。毎月・毎週の支払いは発生しません」「広告は今後も入れません」。購入ボタンは `product.displayPrice` をそのまま表示（例「¥800で購入」）。「無料お試し」「期間限定」等の表現は使わない
- 購入の復元: Paywall と設定の両方。`AppStore.sync()` を呼ぶ
- ファミリー共有: 未定（Q6）

---

## 6. 印刷・レイアウト仕様

### 6.1 用紙

| 用紙 | 寸法 (mm) | 備考 |
|---|---|---|
| はがき（通常・年賀） | 100 × 148 | |
| 長形3号 | 120 × 235 | |
| 長形4号 | 90 × 205 | |
| 洋形2号 | 114 × 162 | |
| 角形2号 | 240 × 332 | **A4 より大きい**。一般的な A4 家庭用プリンタでは給紙できない機種が多い（推測）。対応プリンタでのみ印刷可能と UI で注記 |

封筒寸法は JIS S 5502 の値として広く流通している数値。実装時（②）に一次情報で再確認する。

### 6.2 郵便番号枠

日本郵便「郵便番号・バーコードマニュアル」の記入枠仕様（一次情報）:
- 仕様1（JIS）: 上端から 12.0mm、右端から 8.0mm（許容 ±1.5mm）
- 仕様2（日本郵便推薦様式）: 上端から 18.0mm、右端から 18.0mm（許容 ±1.5mm）
- 各枠の幅・高さ・枠間隔は同ページの図にのみ記載され、テキストでは確認できていない → **②の実装時に図を確認して確定**。官製はがきの実測値との突き合わせも行う
- 出典: https://www.post.japanpost.jp/service/search/zipcode/zipmanual/p05.html

印刷プレビューでは郵便番号枠を赤の細線で表示（**プレビュー専用、印刷されない**）。

### 6.3 文字組み

- 縦書き: Core Text の自動縦組みには依存せず、`VerticalTextLayout` で1文字ずつ配置（句読点・長音・括弧・ハイフンの回転/位置補正テーブルを持つ）。印刷の再現性を優先した判断
- 漢数字変換（縦書き時のみ有効なオプション）: 半角/全角数字を1桁ずつ漢数字に置換（`1-13-3` → `一-一三-三`）。「十」を使う位取り表記や「丁目」化は行わない（仕様どおり）。ハイフンは縦書き時に縦棒相当へ回転
- フォント（iOS 標準搭載フォントのみ、ライセンス問題なし）: ヒラギノ明朝 ProN / ヒラギノ角ゴシック / ヒラギノ丸ゴ ProN。実機での搭載確認は②で行う
- 自動縮小: 各フィールド（住所・氏名・連名・差出人）に枠（mm）を定義し、最大サイズから最小サイズ（可読性下限）まで二分探索で縮小。最小でも収まらない場合は **はみ出し警告**（S02 一覧にも ⚠︎ 表示、S07 で該当ページを強調）
- 位置オフセット: 描画前に CTM を平行移動（用紙ごとの設定値）

### 6.4 AirPrint

- `UIPrintInfo.outputType = .general`、ページサイズは用紙寸法から `printInteractionController(_:choosePaper:)` で `UIPrintPaper.bestPaper(forPageSize:withPapersFrom:)` を使用
- 一括印刷は 1ジョブ複数ページ
- Mac（Designed for iPad）で `UIPrintInteractionController` が動作するかは**未確認**。⑤の仕上げで実機確認し、問題があれば報告する

---

## 7. CSV 取り込み仕様

- 対応文字コード: UTF-8（BOM有無）/ Shift_JIS（Windows Excel 日本語版の「CSV（コンマ区切り）」保存形式を想定）。自動判定＋マッピング画面で手動切替
- 区切り: カンマ。RFC 4180 のダブルクォート・改行含みセルに対応
- 1行目をヘッダーとして列名から自動推定（「氏名」「名前」「連名」「郵便番号」「〒」「住所」「メモ」「備考」など同義語辞書）。ヘッダーなしCSVはトグルで切替
- マッピング確認画面: 各アプリ項目 ← CSV列 を `Picker` で選択、先頭5行のプレビュー、取り込み先グループ選択
- バリデーション: 氏名が空の行はスキップ。郵便番号は数字7桁に正規化（ハイフン・全角数字・〒記号を除去）、不正値は取り込むが警告
- テンプレートCSV（`ShareLink` で書き出し）: UTF-8 BOM付き、列 = `氏名,連名,郵便番号,住所,メモ` + 記入例1行

---

## 8. プライバシー

- App Privacy: 「データを収集しない」となる構成（第三者SDKなし、通信は StoreKit のみ）
- `PrivacyInfo.xcprivacy`: `NSPrivacyTracking = false`、収集データなし、Required Reason API は `UserDefaults`（`CA92.1`）を宣言
- `NSContactsUsageDescription`: 「宛名印刷のために連絡先へアクセスします。連絡先の内容が外部に送信されることはありません」
- `CNContactPickerViewController` はアウトプロセスで動作し、アプリに連絡先全体へのアクセス許可を求めない（Apple ドキュメント記載の仕様として認識しているが、本セッションでは原文を取得できていない → ①実装時に再確認）。用途説明文は仕様どおり Info.plist に入れる
- ATT（`NSUserTrackingUsageDescription`）は入れない

---

## 9. ビルド検証の方針（重要な制約）

- **本作業環境は Linux コンテナで、Xcode / iOS SDK が存在しない**（`xcodebuild` `swift` コマンドなしを確認済み）。この環境ではiOSアプリのビルドを実行できない
- 対策（推奨）: GitHub Actions の macOS ランナーで `xcodegen generate` → `xcodebuild build test`（iOS Simulator 宛先）を push ごとに実行し、**CI が緑になったことを「ビルドが通った」の根拠にする**
- `.icon`（Liquid Glass）バンドルは Xcode 26 以降が必要（fresnel README 記載）。CI で使う Xcode のバージョンはランナーイメージの提供状況を①着手時に確認する

---

## 10. HIG 準拠ポイント

- タップ領域 44×44pt 以上（Stepper・ツールバー・リスト行は標準コンポーネントで担保）
- Safe Area 尊重、プレビューのみ `GeometryReader` で縮尺計算
- Dynamic Type: Form/List は標準テキストスタイル。**用紙プレビュー内の文字は実寸比の図版であり Dynamic Type の対象外**（印刷物の縮小表示のため）。代わりにピンチズーム＋VoiceOver で宛名テキストを読み上げ
- ダークモード: UI はシステムカラー。用紙プレビューは紙を表すため白背景固定（写真や文書のプレビューと同じ扱い）
- SF Symbols のみ使用、独自アイコンは作らない
- 破壊的操作（削除・印刷記録リセット）は `.confirmationDialog`

---

## 11. 確認事項（選択肢と推奨案）

| # | 論点 | 選択肢 | 推奨 |
|---|---|---|---|
| Q1 | リポジトリ | A: 仕様どおり新規パブリック `atena-print` を作成 / B: 本セッションに用意された `kajisho5/iOS_atena` を使う | **B**（本セッションの GitHub 権限は `iOS_atena` に限定されている。名称は後から GitHub 上で変更可能） |
| Q2 | ビルド検証 | A: GitHub Actions macOS ランナーで CI ビルド / B: お手元の Mac で都度ビルドしてもらう | **A**（パブリックリポジトリなら標準ランナーは無料枠対象。プライベート化後は分数課金の対象になる点に注意） |
| Q3 | 印刷済みの単位 | A: 印刷記録（履歴）方式・グループ文脈で判定 / B: 宛先ごとの単一フラグ | **A**（翌年に流用でき、二重印刷防止にも有効） |
| Q4 | 住所欄 | A: 住所＋建物名の2欄 / B: 仕様どおり1欄 | **A**（縦書きで建物名を改行・字下げするのに必要。CSV は「住所」→住所1、任意で「住所2」列も認識） |
| Q5 | ふりがな | A: 任意の「ふりがな」欄を追加（並び替え用） / B: 追加しない | **B**（仕様外のため。並び順は登録順・氏名順） |
| Q6 | ファミリー共有 | A: 有効 / B: 無効 | **A**（買い切りの価値訴求と整合。App Store Connect で設定） |
| Q7 | CSV重複 | A: 氏名＋郵便番号一致を「重複の可能性」として既定でスキップ / B: すべて取り込む | **A**（スキップ対象はマッピング画面で確認・変更可） |
| Q8 | iCloud バックアップ | A: 端末バックアップ対象のまま / B: バックアップから除外 | **A**（機種変更時の住所録消失を防ぐ。端末バックアップは開発者によるデータ収集に当たらない） |
| Q9 | 高精度SVGデザイン | A: 承認後、①着手前に主要画面のSVGを提示して再度確認 / B: SVGは省略し本書で実装開始 | **A**（ご指定の開発手順に沿う） |

---

## 12. 現時点で不明・未確認の事項

- 郵便番号枠の各枠寸法・間隔（図のみ記載）
- ¥800 が App Store の日本円価格ポイントとして選択可能か（App Store Connect で確認が必要）
- Designed for iPad での AirPrint 動作
- 角形2号に対応する AirPrint 用紙サイズを各プリンタが提示するか
- CI で利用可能な Xcode バージョン
