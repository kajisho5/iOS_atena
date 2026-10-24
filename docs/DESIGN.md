# 宛名印刷 はがき・封筒 — 設計書 v0.6

> ステータス: 承認済み・実装中（①〜⑤）。
> 画面遷移図: [`screen-flow.svg`](./screen-flow.svg)
> 画面デザイン（Q9）: [`design/01-iphone-core-light.svg`](./design/01-iphone-core-light.svg) ・ [`design/02-iphone-states.svg`](./design/02-iphone-states.svg) ・ [`design/03-ipad-landscape.svg`](./design/03-ipad-landscape.svg)（生成スクリプト: `tools/gen_design_svgs.py`）
>
> v0.2 変更点: 画面の向き・iPad マルチタスク要件を追加（§4.3、S07/S09、§9、Q10）
> v0.8 変更点: iPhone Duo を Apple の開発者向け案内に合わせて見直し（§13.12）
> v0.7 変更点: iPhone Duo（折りたたみ）への対応方針と確認事項を追加（§13.12）
> v0.6 変更点: 標準対応 §13.8〜13.11（キーボード・起動画面・下部の主要操作・シートの一貫性・iPad のポインタとキーボード）を追加
> v0.5 変更点: CSV取り込みを無料版でも使えるようにした（宛先の合計10件まで）。購入前に取り込み結果を確認できるようにするため（ユーザー指示）
> v0.3 変更点: Q1〜Q10 を全て A で確定（§11）。ふりがな欄を追加（Q5=A）。標準対応要件（§13）を追加。新規確認事項 Q11・Q12

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
│   │   ├── Schema/                  # SchemaV1 + SchemaMigrationPlan（§13.7）
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
│       ├── Localizable.xcstrings    # UI 文字列（§13.4）
│       ├── InfoPlist.xcstrings      # 権限用途説明などの文言
│       ├── PrivacyInfo.xcprivacy
│       └── Products.storekit        # ローカル StoreKit テスト用設定
├── AtenaPrintTests/                 # CSV・漢数字・自動縮小・用紙座標のユニットテスト
├── .github/workflows/build.yml      # macOS ランナーでビルド＋テスト（§9）
├── docs/                            # 設計書・SVG（design/ に画面デザイン）
├── marketing/                       # デモモック・App Store 文案（⑤）
└── README.md
```

**描画の一元化**: プレビュー（SwiftUI）・AirPrint・PDF の3経路すべてが `AddressRenderer.draw(in: CGContext, page:)` を呼ぶ。プレビューと実際の印刷結果がずれる原因を構造的に排除する。

---

## 3. データモデル（SwiftData）

```swift
@Model final class Recipient {
    var name: String              // 氏名
    var nameKana: String          // ふりがな（任意。並び替え用。Q5=A）
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
- 並び順: ふりがな（未入力なら氏名）の昇順 / 登録順 / 郵便番号順 を切替。
- **スキーマ版管理**: 初版から `VersionedSchema`（`SchemaV1`）と `SchemaMigrationPlan` を定義し、アップデートでのモデル変更はマイグレーションで行う（§13.7）。

---

## 4. 画面構成と遷移

詳細は [`screen-flow.svg`](./screen-flow.svg)。

### 4.1 ルート構成

- `TabView` 3タブ: **宛先**（`person.2`） / **レイアウト**（`envelope`） / **設定**（`gearshape`）
- iPad / Mac: 宛先タブ内を `NavigationSplitView`（サイドバー＝グループ、コンテンツ＝宛先一覧、詳細＝宛先詳細＋プレビュー）
- iPhone: 同じ `NavigationSplitView` が自動で `NavigationStack` に折りたたまれる（HIG のサイドバー挙動に準拠）
- 分割表示・縦積みの切替は**デバイス種別や向きではなく水平サイズクラス＋実際の表示領域で判定**する（§4.3）

### 4.2 画面一覧

| ID | 画面 | 表示形式 | 主な要素 |
|---|---|---|---|
| S01 | グループ一覧（サイドバー） | Split sidebar | すべて / 未印刷 / 各グループ、グループ追加・名称変更・並べ替え |
| S02 | 宛先一覧 | List | 検索（`.searchable`）、印刷済みバッジ、スワイプ削除、選択モード、`+` メニュー（手入力 / 連絡先から / CSVから） |
| S03 | 宛先詳細 | Push | 宛名面サムネイル、印刷履歴、「この宛先を印刷」 |
| S04 | 宛先編集 | Sheet（Form） | 氏名・ふりがな・連名・敬称・〒・住所・建物名・メモ・グループ |
| S05 | 連絡先から取り込み | システムピッカー | `CNContactPickerViewController`（複数選択）→ 取り込み確認 |
| S06 | CSV 取り込み | Sheet（3段階） | ①ファイル選択（`.fileImporter`）②列マッピング確認（先頭5行プレビュー、文字コード表示/切替）③結果（成功・スキップ・エラー行） |
| S07 | 印刷プレビュー | Full-screen cover | 縦横比が正確なプレビュー（用紙枠・郵便番号枠）、一括時は前後ページ送り、はみ出し警告、二重印刷警告、「印刷」「PDF」ボタン。**iPad 横向きでは用紙全体を表示**（§4.3） |
| S08 | AirPrint | システムUI | `UIPrintInteractionController`（iPad/Mac はポップオーバー） |
| S09 | レイアウト | Tab（Form＋プレビュー） | 用紙 / 縦横 / フォント / 漢数字変換 / 差出人ON/OFF・選択。幅が compact なら上プレビュー＋下Form、regular なら左右分割 |
| S10 | 設定 | Tab（Form） | 差出人プロフィール、印刷位置調整、Pro購入・**購入の復元**、CSVテンプレート書き出し、プライバシーポリシー・利用規約、バージョン |
| S11 | 差出人一覧・編集 | Push / Sheet | 複数登録、並べ替え |
| S12 | 印刷位置調整 | Push | 用紙ごとに上下左右 ±10mm（0.5mm刻み Stepper）、テスト印刷ボタン |
| S13 | Pro（Paywall） | Sheet | 下記 §5 の文言、価格をそのまま表示した購入ボタン、購入の復元、閉じる |

### 4.3 画面の向き・iPad マルチタスク

**要件**: iPhone は縦向き固定。iPad は回転と画面分割（Split View / Stage Manager）に対応し、レイアウトが崩れないこと。印刷プレビューは iPad 横向きで用紙全体が見えること。

| 項目 | 設定・実装 |
|---|---|
| iPhone の向き | `UISupportedInterfaceOrientations~iphone` = Portrait のみ（XcodeGen では `INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone`） |
| iPad の向き | `UISupportedInterfaceOrientations~ipad` = 4方向すべて（Portrait / UpsideDown / LandscapeLeft / LandscapeRight） |
| マルチタスク | `UIRequiresFullScreen` は**設定しない**（設定すると iPad の画面分割から外れるため） |
| Mac（Designed for iPad） | ウインドウは自由にリサイズされる前提。iPad と同じレイアウト規則で対応 |
| レイアウト判定 | `@Environment(\.horizontalSizeClass)` と `GeometryReader` の実寸で判定。`UIDevice.orientation` や `userInterfaceIdiom` によるレイアウト分岐は**使わない** |

**HIG との関係（確認済み）**: HIG「Layout」は「サイズクラスでレイアウトを決め、デバイス種別や向きで決めない」と定めている。また「アプリの向きを固定する場合でも、インターフェースがサイズ変更に正しく対応することが重要」とも書かれており、向きの固定自体は禁止されていない。iPhone を縦向きに固定する方針は HIG と矛盾しない。ただしレイアウトはサイズクラスで組み、固定されている向きに依存しない作りにする。
- 出典: https://developer.apple.com/design/human-interface-guidelines/layout
- 補足（一次情報）: WWDC26「Modernize your UIKit app」では「iOS 27 ではサポートする向きはシステムへの“希望”として扱われ、リサイズ可能な環境では無視される」と説明されている。リサイズ可能な環境とは、Mac の iPhone ミラーリングや、iPhone 用アプリを iPad で動かす場合を指す。本アプリはユニバーサルアプリで、iPad では iPad 用レイアウトで動く。ただし iPhone ミラーリングでは縦向き固定が効かない可能性がある。サイズクラス基準で組むことで、この場合も崩れないようにする（https://developer.apple.com/videos/play/wwdc2026/278/）
- 補足: iPadOS 26 以降は、画面分割が「ウインドウ化されたアプリ」（タイル配置・自由リサイズ）として提供される（HIG「Multitasking」）。iOS 17〜18 の Split View / Slide Over / Stage Manager と合わせて、任意のウインドウサイズで崩れないことを要件とする

**画面ごとの可変レイアウト**

| 画面 | 幅 compact（iPhone、iPad の狭い分割） | 幅 regular（iPad 全画面・広い分割、Mac） |
|---|---|---|
| 宛先（S01〜S03） | NavigationStack（自動で折りたたみ） | 3カラム表示。幅が足りなければ2カラムに自動で落とす（`NavigationSplitView` の標準挙動） |
| S07 印刷プレビュー | 上: 用紙（アスペクトフィット）／下: 操作バー（`safeAreaInset(edge: .bottom)`） | **左: 用紙（アスペクトフィット）／右: サイドパネル（固定幅 320pt）**。ページ送り・警告・宛先情報・「印刷」「PDF」を置く |
| S09 レイアウト | 上: プレビュー（高さ上限あり）／下: Form | 左: プレビュー／右: Form |
| S10〜S13 | Form / Sheet（標準） | 同左。Sheet は `.presentationSizing`（iOS 18+）／iOS 17 は標準のフォームシート |

**S07 で「用紙全体が見える」ことを保証する計算**
- 用紙領域 = 表示領域 −（Safe Area ＋ 余白 16pt ×2 ＋ サイドパネル幅 or 下部バー高）
- 縮尺 = min(用紙領域幅 / 用紙幅mm, 用紙領域高 / 用紙高mm)。縦横どちらにも収まる倍率を採るので、どの用紙・どの画面サイズでも全体が必ず表示される
- 試算（推測。正確な表示領域は機種と表示状態で変わる）: iPad 11インチ横向き（1194×834pt）で、ナビゲーションバー等を除いた高さを約 740pt とする。はがき（148mm）は約 5.0pt/mm、角形2号（332mm）は約 2.2pt/mm で全体が収まる
- ピンチで拡大、ダブルタップで全体表示に戻る。回転・リサイズ時は全体表示にリセット

**崩れの検証方法**: この環境では Simulator を起動できない。そのため CI（macOS）で、主要画面を代表サイズで `ImageRenderer` 描画し、PNG を CI の成果物として保存する。代表サイズは iPhone 縦、iPad 縦・横、分割の 1/3・1/2・2/3 幅相当、Mac の小さいウインドウ。画像を目視で確認でき、あわせてはみ出し判定のテストを回す。分割時の幅は機種ごとに異なるため、代表値として扱う

### 4.4 主要フロー

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
| CSV取り込み | ○（宛先の合計10件まで。取り込み前の確認画面は全件表示） | ○（件数無制限） |
| PDF出力 | × | ○ |

- 商品: 非消耗型 1点、`AppConstants.proProductID`（`com.seventhwell.AtenaPrint.pro`）
- **Paywall を出すタイミング（能動操作のみ）**:
  - 11件目の宛先を保存しようとした時（保存ボタン押下時。入力中は出さない）
  - CSV取り込みの確認画面・結果画面で、無料版の上限を超えた行があるときに表示する「Proについて」ボタンを押した時（v0.5）
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
- 各枠: 幅 5.7mm × 高さ 8.0mm。各枠の左端は先頭から 0 / 7.0 / 14.0 / 21.6 / 28.4 / 35.2 / 42.0mm、全幅 47.7mm（同ページの図「郵便番号記入枠仕様イメージ(定形郵便物)」で確認済み。寸法は枠線の内側から）。はがき（幅100mm）では先頭の枠の左端が 44.3mm になる
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
- 認識する列: 仕様の5列（氏名 / 連名 / 郵便番号 / 住所 / メモ）＋任意列（ふりがな / 住所2 / 敬称）。任意列はマッピング画面で「使わない」を選べる
- 重複: 氏名＋郵便番号が既存と一致する行は「重複の可能性」として既定でスキップ（Q7=A、行ごとに変更可）
- ファイルサイズ上限: `FileHandle.read(upToCount:)` で 5MB まで読み、超過時はエラー表示（ファイルのメタデータ API を使わないため、必須理由APIの追加申告が不要）
- テンプレートCSV（`ShareLink` で書き出し）: UTF-8 BOM付き、列 = `氏名,連名,郵便番号,住所,メモ` + 記入例1行（仕様どおり5列。任意列は README に記載）

---

## 8. プライバシー

- App Privacy: 「データを収集しない」となる構成（第三者SDKなし、通信は StoreKit のみ）
- `PrivacyInfo.xcprivacy`: 詳細は §13.6
- `NSContactsUsageDescription`: 「宛名印刷のために連絡先へアクセスします。連絡先の内容が外部に送信されることはありません」
- `CNContactPickerViewController` は権限ダイアログを出さない（**確認済み**。Apple 公式ドキュメント: “The app using contact picker view does not need access to the user’s contacts and the user will not be prompted for “grant permission” access.” https://developer.apple.com/documentation/contactsui/cncontactpickerviewcontroller）。用途説明文は仕様どおり Info.plist（`InfoPlist.xcstrings`）に入れる。権限の扱いは Q11
- ATT（`NSUserTrackingUsageDescription`）は入れない

---

## 9. ビルド検証の方針（重要な制約）

- **本作業環境は Linux コンテナで、Xcode / iOS SDK が存在しない**（`xcodebuild` `swift` コマンドなしを確認済み）。この環境ではiOSアプリのビルドを実行できない
- 対策（推奨）: GitHub Actions の macOS ランナーで `xcodegen generate` → `xcodebuild build test`（iOS Simulator 宛先）を push ごとに実行し、**CI が緑になったことを「ビルドが通った」の根拠にする**
- 画面の向き・分割表示の検証は §4.3 の代表サイズ描画で行う（実機の最終確認はユーザー側で必要）
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

**確定（v0.3）: Q1〜Q10 はすべて A を採用**（ユーザー回答「最初で」）。Q5 は推奨 B ではなく A（ふりがな欄を追加）で確定。

### 新規確認事項

| # | 論点 | 選択肢 | 推奨 |
|---|---|---|---|
| Q11 | 連絡先取り込み方式（権限拒否時導線の要否に影響） | A: `CNContactPickerViewController`（権限ダイアログなし。拒否が起きないので拒否時導線は不要） / B: `CNContactStore` で全連絡先を読み、アプリ内の一覧から選ぶ（権限ダイアログあり。拒否時は設定アプリへ誘導する画面を用意） | **A**（アクセス範囲が最小で、仕様の「端末内のみ」の原則に最も合う。大量登録は CSV で対応できる） |
| Q12 | ユーザー自身によるバックアップ手段 | A: 宛先を CSV で書き出す機能を追加（無料）。iCloud バックアップを使っていない人も機種変更で失わない / B: 追加しない（iCloud／PC へのバックアップに任せる） | **A**（「データが消えない」要件の保険。ただし仕様外の機能追加のため確認） |

**確定（v0.4）: Q11 = A（連絡先ピッカー）、Q12 = A（宛先のCSV書き出しを無料で追加）**（ユーザー回答「おまかせ」により推奨案を採用）。

### 実装時の判断（v0.4）

| 項目 | 内容 | 理由 |
|---|---|---|
| ロジックの分離 | 住所レイアウト・CSV・郵便番号・漢数字は `Packages/AtenaCore`（UIに依存しない Swift パッケージ）に置く | Linux でもテストでき、CI で毎回検証できる |
| 縦書きの描画 | Core Text の縦組み機能は使わず、1文字ずつ配置する。長音・ダッシュ・括弧は回転、小書きの仮名・句読点は位置補正 | 印刷とプレビューで同じ結果を確実に得るため（§6.3 の方針どおり） |
| 郵便番号枠 | 日本郵便マニュアルの図で寸法を確認して確定（§6.2 の未確認事項を解消） | 一次情報 |
| アプリアイコン | Icon Composer 形式（`AppIcon.icon`）。Xcode 26 以降が必要 | 仕様の Liquid Glass アイコン |
| 並行処理 | Swift 6 言語モード、既定のアクター分離は MainActor。描画・計測の型は `nonisolated` | Xcode 26 の推奨設定 |

### 確定済み（v0.2 までの確認事項）

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
| Q10 | 「実寸に近いプレビュー」の解釈 | A: 縦横比と配置を正確に保った縮小表示＋ピンチ拡大（既定は用紙全体を表示） / B: 物理的な等倍表示 | **A**（iOS には画面の物理解像度（ppi）を取得する公開APIがなく、等倍表示には機種別の値を自前で持つ必要がある［推測を含む］。等倍表示では iPad 横向きで用紙全体が見える要件とも両立しない） |

---

## 12. 現時点で不明・未確認の事項

- ¥800 が App Store の日本円価格ポイントとして選択可能か（App Store Connect で確認が必要）
- Designed for iPad での AirPrint 動作
- 分割表示時の実際の幅（機種ごとに異なる。代表値で検証）
- Apple 純正フレームワーク（SwiftData 等）の内部で呼ばれる必須理由APIがアプリ側の申告対象かどうか（申告はアプリのコードが直接呼ぶ API に必要、という理解。推測）
- 角形2号に対応する AirPrint 用紙サイズを各プリンタが提示するか
- CI で利用可能な Xcode バージョン

---

## 13. 標準対応（必須要件）

### 13.1 ダークモード
- アプリ固有の色はすべて `Assets.xcassets` の Color Set で定義する。各色に Any / Dark と、HIG「Color」の指示に従い「コントラストを上げる」用の値を用意する（Light・Dark・High Contrast Light・High Contrast Dark の4値）
- それ以外は SwiftUI のシステム色（`.primary` / `Color(.systemBackground)` / `.tint` など）を使う。コード内に RGB 値は直書きしない
- 定義する色（案）:

| 名前 | 用途 |
|---|---|
| `AccentColor` | アプリのアクセント色（藍系） |
| `PaperBackground` | 用紙プレビューの紙色。両モードで白に近い値。ダーク時は周囲を暗くし、紙だけ浮かせる |
| `PaperInk` | プレビュー内の文字（墨色） |
| `PostalFrame` | 郵便番号枠の赤（表示専用、印刷しない） |
| `PreviewGuide` | 用紙枠・余白ガイド |
| `WarningFill` | はみ出し警告の背景 |
| `SecondaryText` | 補助テキスト（住所の要約・件数など）。下記コントラストの理由で追加 |
| `SuccessText` / `WarningText` | 「印刷済み」「はみ出し」表示の文字色 |

- **システム色の `secondaryLabel` について（計算値）**: ライトモードでは rgba(60,60,67,0.6) で、白背景上の実効色は #8A8A8E 相当、コントラスト比は約 3.44:1。17pt 以下の本文に必要な 4.5:1 に届かない。住所など意味を持つ補助テキストには `SecondaryText` を使う。罫線・プレースホルダーなど装飾的な要素はシステム色のままにする
- 色の値（案）とコントラスト比（WCAG の式で計算）:

| 色 | Light | 比率（背景） | Dark | 比率（背景） |
|---|---|---|---|---|
| AccentColor | #24569B | 7.29（白） / 6.54（#F2F2F7） | #8DB3EC | 7.93（#1C1C1E） / 9.79（黒） |
| ボタン文字（Accent 上） | #FFFFFF | 7.29 | #000000 | 9.79 |
| SecondaryText | #5E5E63 | 6.45（白） / 5.78（#F2F2F7） | #AEAEB2 | 7.69（#1C1C1E） / 9.50（黒） |
| SuccessText | #1E7B34 | 5.33（白） | #5BD37A | 8.95（#1C1C1E） |
| WarningText | #B04A00 | 5.49（白） | #FFB35C | 9.60（#1C1C1E） |
| PaperInk / PaperBackground | #1A1A1A / #FFFFFF | 17.40 | 同左（紙は白のまま） | 17.40 |

- 「コントラストを上げる」用の値は、実装時に上の値より比率が高くなるよう定める

- 印刷・PDF 出力は外観モードに関係なく常に黒文字・白紙で描画する（`AddressRenderer` は外観に依存しない色を使う）
- 確認: CI で主要画面を Light / Dark の両方で画像化し、成果物として保存する（§4.3 の代表サイズ描画を流用）

### 13.2 Dynamic Type
- 文字はすべて標準テキストスタイル（`.body` / `.headline` など）で指定し、ポイント数を固定しない。独自の寸法は `@ScaledMetric` を使う
- `dynamicTypeSize.isAccessibilitySize` のとき:
  - 一覧の行は横並びから縦積みに切り替える（`AnyLayout(HStackLayout)` ⇄ `VStackLayout`）
  - 印刷プレビューの操作パネルはスクロール可能にし、ボタンを全幅で縦に並べる
  - 課金画面はスクロール可能にし、購入ボタンを画面下に固定（`safeAreaInset`）
- 文字を省略（「…」）してはいけない箇所: 氏名・敬称・価格・注意文。行数制限を付けない
- 用紙プレビュー内の文字は印刷物の縮小図なので Dynamic Type の対象外（§10）。代わりにピンチで拡大でき、VoiceOver で読み上げる
- 確認: CI で `.accessibility5`（最大）と `.large`（標準）で画像化する

### 13.3 VoiceOver・コントラスト
- アイコンだけのボタン（＋、選択、ページ送り、共有など）には `accessibilityLabel` を必ず付ける。日本語の文言は String Catalog で管理
- 用紙プレビュー: 全体を1要素にまとめ、ラベルを「はがき、縦書き。宛先 〒100-0001 東京都… 山田太郎 様」のような要約にする。はみ出しがあれば「警告: 住所が枠からはみ出しています」を付け加える
- 印刷済みや警告は色だけで伝えない（アイコンと文字を必ず併記する）
- 一括印刷のページ送りは `accessibilityAdjustableAction` で、スワイプ上下でページを移動できるようにする
- コントラスト: HIG「Accessibility」が指針とする WCAG AA の値を満たす（17pt 以下は 4.5:1、18pt 以上・太字は 3:1）。独自色は Light・Dark の両方で比率を計算し、表にして README に載せる
  - 出典: https://developer.apple.com/design/human-interface-guidelines/accessibility
- 確認: Xcode の Accessibility Inspector の Audit を使う（ユーザーの Mac で実施）。CI では UI テストに `XCUIApplication().performAccessibilityAudit()`（iOS 17 以降の XCTest API）を組み込む

### 13.4 String Catalogs
- UI 文字列は `Localizable.xcstrings`、Info.plist の文言（連絡先の用途説明など）は `InfoPlist.xcstrings` で管理する。開発言語は `ja`
- キーは意味を表す英語にする（例: `recipients.empty.title`）。コードに日本語の文字列リテラルを書かない。日本語の文言は catalog 側だけに置く（コードの識別子は英語、という要件とも合う）
- 書式付きの文字列（件数など）は catalog 内の書式指定と複数形バリエーションで扱う
- CI で「catalog にあるがコードで使われていない」「コードにあるが catalog にない」キーをテストで検出する

### 13.5 権限拒否時の導線・空状態
- 権限: Q11=A の場合、アプリが権限を求める場面はない。連絡先はピッカー、CSV は `.fileImporter`（ユーザーが選んだファイルだけ）、印刷は OS の印刷画面。B を選んだ場合は、拒否されたとき・制限付きアクセスのときに説明と「設定を開く」ボタン（`UIApplication.openSettingsURLString`）を出す画面を加える
- 空状態は `ContentUnavailableView`（iOS 17 以降の標準）で統一する

| 状況 | 表示 | 次の操作 |
|---|---|---|
| 宛先が0件 | 「宛先がありません」 | 手入力 / 連絡先から / CSVから |
| 検索結果が0件 | 標準の `ContentUnavailableView.search` | — |
| グループが空 | 「このグループに宛先はありません」 | 宛先を追加 |
| 未印刷が0件 | 「すべて印刷済みです」 | — |
| 差出人が0件（差出人印刷 ON） | プレビューに「差出人が未登録です」 | 差出人を登録 |
| CSV に有効な行がない | 原因（文字コード / 列の対応 / 空ファイル）を表示 | 文字コードを切り替える / 列の対応を見直す |
| 購入情報を取得できない（オフライン等） | 「価格を取得できませんでした」 | 再試行 |

### 13.6 プライバシーマニフェスト
`PrivacyInfo.xcprivacy`:

| キー | 値 |
|---|---|
| `NSPrivacyTracking` | `false` |
| `NSPrivacyTrackingDomains` | 空 |
| `NSPrivacyCollectedDataTypes` | 空（データを収集しない） |
| `NSPrivacyAccessedAPITypes` | `NSPrivacyAccessedAPICategoryUserDefaults` に理由 `CA92.1` |

- `CA92.1` の定義（確認済み）: 自分のアプリ（同じ App Group）だけが読み書きできる UserDefaults の情報にアクセスする場合の理由（https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitypereasons）
- ファイルのタイムスタンプ・空き容量・起動時刻などの API はアプリのコードで使わない（必要になった時点で申告を追加する）。§12 の未確認事項も参照

### 13.7 データの保全（iCloud バックアップ・アップデート・機種変更）
- SwiftData のストアは既定の場所（Application Support）に置き、`isExcludedFromBackup` は設定しない。端末の iCloud バックアップと PC へのバックアップの対象になり、機種変更（バックアップからの復元・クイックスタート）で引き継がれる
- CloudKit 同期は使わない（`ModelConfiguration(cloudKitDatabase: .none)`）。「端末内のみ」の原則を守り、iCloud への保存はユーザー自身のバックアップだけにする
- アップデート対策:
  - 初版から `VersionedSchema` と `SchemaMigrationPlan` を用意する。プロパティの追加は既定値付きの軽量マイグレーション、それ以外は独自のマイグレーションで行う
  - ストアのファイル名と場所を固定する（`ModelConfiguration` で名前を明示）
  - ストアを開けなかったとき、**ファイルを削除して作り直す処理は書かない**。エラー画面で原因を表示し、データを残したままにする
  - CI のテストで、旧スキーマで作ったストアを新スキーマで開き、件数と内容が保たれることを確かめる（スキーマを変更するときから）
- 設定（LayoutSettings 等）は UserDefaults に保存され、こちらもバックアップ対象
- 購入状態は StoreKit が管理し、端末内には保存しない（機種変更後は「購入の復元」か自動の同期で戻る）

### 13.8 ソフトウェアキーボード（v0.6）
- 入力フォーム（宛先・差出人の編集）は `Form` のスクロールでキーボードを避け、編集中の項目が隠れないようにする。スクロールするとキーボードを閉じる（`.scrollDismissesKeyboard(.interactively)`）
- キーボードの上に「次へ」「完了」を置く。Return キーでも次の項目へ進む（氏名 → ふりがな → 連名 → 郵便番号 → 住所 → 建物名 → メモ）
- 郵便番号は数字キーボードで Return キーがないため、「次へ」で住所に進めるようにする
- **確定ボタン（保存）はフォームのシートでは上部のバーに置く**。下部に置くとキーボードで隠れるため（§13.10 の例外。HIG のシートの標準配置とも一致）

### 13.9 起動画面
- `UILaunchScreen` は空の設定（システムの背景色だけ）にする。広告・ロゴのアニメーション・待ち時間の演出は入れない。起動後すぐに宛先タブを表示する

### 13.10 iPhone の操作位置とシートの一貫性
- 文字入力のない画面では、主要な操作を画面の下部（`BottomActionBar`）に置く

| 画面 | 下部の主要操作 |
|---|---|
| グループ一覧 | 宛先を追加 |
| 宛先一覧 | 宛先を追加 ／ 一括印刷 |
| 宛先詳細 | この宛先を印刷 |
| 印刷プレビュー | 印刷 ／ PDF（従来どおり） |
| CSV取り込み | n件を取り込む → 完了 |
| 選択して印刷 | n件をプレビュー |
| Pro（課金） | 購入ボタン（従来どおり） |

- iPad など幅が regular のときは、主要操作を上部のツールバーに置く（下部バーは表示しない）
- シートの閉じ方を統一する。左上に必ず閉じる操作を置く（入力のある画面は「キャンセル」、表示だけの画面は「×」または「閉じる」）。未保存の変更があるときだけ、下へのスワイプで閉じるのを止め、破棄の確認を出す

### 13.11 iPad のレイアウト・ポインタ・ハードウェアキーボード
- 幅が regular のときは、宛先タブを「グループ ＋ 宛先リスト ＋ 詳細（宛名面プレビュー付き）」の分割表示にする。印刷プレビューは「用紙 ＋ サイドパネル」、レイアウトタブは「プレビュー ＋ 設定」の2ペインにする（§4.3）
- ポインタ: 標準コントロールは自動でポインタに対応する。独自の配置をした主要ボタンには `.hoverEffect()` を付ける。行の右クリック（コンテキストメニュー）で編集・印刷・削除ができる
- ハードウェアキーボードのショートカット（⌘ を押し続けると一覧が表示される）:

| 操作 | キー |
|---|---|
| 宛先を手入力で追加 | ⌘N |
| CSVから取り込む | ⇧⌘I |
| 一括印刷 | ⇧⌘P |
| この宛先を印刷 ／ プレビューで印刷 | ⌘P |
| 宛先を編集 | ⌘E（宛先詳細） |
| PDFで書き出す | ⌘E（印刷プレビュー） |
| 保存 | ⌘S |
| キャンセル ／ 閉じる | Esc |
| 前の宛先 ／ 次の宛先（印刷プレビュー） | ← ／ → |
| 取り込む ／ プレビュー（確定） | Return（⌘Return） |

### 13.12 iPhone Duo（折りたたみ）（v0.8）
Apple の開発者向け案内に沿って対応する。出典: Tech Talk「Prepare your app for iPhone Duo」https://developer.apple.com/videos/play/tech-talks/111461/ 、「Design for iPhone Duo」https://developer.apple.com/videos/play/tech-talks/111466/ 、HIG「Designing for iPhone Duo」https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo

| Apple の案内 | このアプリでの対応 |
|---|---|
| 外側の画面は横 compact、内側の画面は縦横 regular。レイアウトはサイズクラスで判断し、端末の種類（Idiom）や画面の向きで判断しない | `horizontalSizeClass` だけで切り替えている。`userInterfaceIdiom`・向き・`UIScreen.main` はアプリのコードで使っていない |
| 内側の画面は、アプリが指定した対応向きを無視する。外側の画面は通常の iPhone と同じく対応向きに従う | iPhone は縦向き固定のまま（ユーザー指示）。内側の画面では横長の regular レイアウト（iPad と同じ分割表示）になる |
| 折り目付近（カーブの部分）に操作できる部品を置かない。スクロールする内容は置いてよい。標準のシート・アラート・メニュー・ツールバーは自動で避ける | 標準部品を使う。独自の下部ボタン（`BottomActionBar`）は、幅 regular のときは画面全幅に伸ばさず右端にまとめ、折り目にかからないようにした |
| 固定幅や特定の画面サイズに合わせた数値を使わない。レイアウトマージンと安全領域を使う | 固定幅は使っていない（用紙プレビューは表示領域に合わせて拡縮） |
| iOS 27.1 SDK でビルドすると画面の端まで使い、ナビゲーションやツールバーのボタンは縦の帯に並ぶ。独自のバーは `ReservedRegion`（SwiftUI）で領域を確保できる | CI に Xcode 27.1 と iPhone Duo シミュレータで撮影するジョブを追加した。独自の下部バーへの `ReservedRegion` の適用は、シミュレータの撮影結果を見て判断する |
| `UIScreen.main` は2画面の端末ではあいまいなので使わない | アプリでは未使用 |

- シミュレータでの実測（Xcode 27.1、閉じた状態で起動）: 外側の画面 466×678 pt、@3x、幅 compact・高さ regular、安全領域は右 84 pt・下 34 pt。タブバーと戻るボタンは右側の縦の帯に移り、独自の下部バーは安全領域に従ってその左に収まった。
- 画面キャプチャは iPhone Duo シミュレータの実際の画面サイズ・倍率・サイズクラスで撮る。Xcode 27.1 には開閉のコマンド（`simctl` など）がないため、CI では第三者製の duoctl（MIT、https://github.com/skarol/duoctl 、非公開の仕組みで Device Hub と同じ開閉イベントを送る）でシミュレータを開いて内側の画面を撮る。CI 専用でコミットを固定し、アプリには含めない。Xcode の更新で動かなくなる可能性がある（ユーザー承認済み）。
- TestFlight 配信ワークフローも Xcode 27.1（iOS 27.1 SDK）でビルドする。
- **要確認（TestFlight の実機で）**: 開閉時のレイアウトの切り替え、半開き（本のように持つ・テーブルに置く）での折り目の回避、外側の画面で縦の帯に並ぶボタンと独自の下部バーの重なり。
