# 宛名印刷 はがき・封筒

広告なし・サブスクなし（買い切り）の iPhone / iPad 向け宛名印刷アプリ。
住所データは端末内だけに保存し、外部サーバーには送信しない。

- 設計書: [docs/DESIGN.md](docs/DESIGN.md)
- 画面遷移図: [docs/screen-flow.svg](docs/screen-flow.svg)
- 画面デザイン: [docs/design/](docs/design/)
- アプリアイコン: [docs/icon/](docs/icon/)（元データは `AtenaPrint/Resources/AppIcon.icon`）
- デモモック: [marketing/mockups/](marketing/mockups/)
- App Store 掲載文の下書き: [marketing/AppStore.md](marketing/AppStore.md)

## 動作環境

| 項目 | 値 |
|---|---|
| 対応OS | iOS / iPadOS 17.0 以上。Mac は「Designed for iPad」 |
| 開発環境 | Xcode 26 以降（アプリアイコンが Icon Composer 形式の `.icon` のため） |
| 言語 | Swift 6（言語モード 6、既定のアクター分離は MainActor） |
| 外部ライブラリ | なし（Apple 純正フレームワークのみ） |

## ビルド手順

1. リポジトリを取得する。
   ```sh
   git clone https://github.com/kajisho5/iOS_atena.git
   cd iOS_atena
   ```
2. `AtenaPrint.xcodeproj` を Xcode で開く（生成済みのプロジェクトをコミットしてある）。
3. ターゲット **AtenaPrint** の Signing & Capabilities で、自分の Team を選ぶ。必要ならバンドルIDも変更する（下の「差し替えが必要な定数」を参照）。
4. スキーム **AtenaPrint** を選び、実機かシミュレータで Run（⌘R）。
5. テストは ⌘U。アプリのテスト（`AtenaPrintTests`）とロジックのテスト（`AtenaCoreTests`）が実行される。

### プロジェクトを作り直す場合（XcodeGen）

`project.yml` を変更したときは、XcodeGen でプロジェクトを再生成する。

```sh
brew install xcodegen
xcodegen generate
```

`AtenaPrint/Info.plist` も `project.yml` の `info.properties` から生成される。直接編集せず `project.yml` を変更すること。

### ロジックだけをテストする

住所レイアウト、CSV、郵便番号、漢数字の処理はローカルパッケージ `Packages/AtenaCore` にまとめてあり、Linux でもテストできる。

```sh
swift test --package-path Packages/AtenaCore
python3 tools/check_strings.py   # String Catalog とコードのキーの整合チェック
```

### CI

`.github/workflows/ci.yml` が push のたびに次を実行する。

- Linux: `AtenaCore` のテストと、String Catalog のキー整合チェック
- macOS（`macos-26` ランナー）: iOS シミュレータでのビルドとテスト。実フォントで描いた宛名面の PNG を `snapshots` という成果物に保存する

### TestFlight への配信（runway）

`.github/workflows/testflight.yml` は、共通ワークフロー [kajisho5/runway](https://github.com/kajisho5/runway) の `apple-testflight.yml` を呼ぶだけの設定。署名・ビルド番号・アップロードは runway が行う（手順と Secrets は runway の README）。

初回だけ:

1. runway の `repos.txt` に `kajisho5/iOS_atena` を1行足す（保存すると sync-secrets が Secrets を配る）。
2. App Store Connect に Bundle ID `com.seventhwell.AtenaPrint` のアプリ記録と、TestFlight の内部テストグループがあることを確認する。

配信: Actions タブ → testflight → Run workflow（`v*` のタグを push しても動く）。Xcode 27.1（`xcode-27` ランナー）でビルドする。

## 操作のしかた（iPhone / iPad）

- iPhone では、主な操作（宛先を追加、一括印刷、この宛先を印刷、取り込む、印刷）を画面の下にまとめている。
- 宛先や差出人の入力画面では、キーボードの上の「次へ」「完了」で項目を移動できる。「保存」は上のバーにあり、キーボードで隠れない。
- シートは、どの画面も左上のボタン（キャンセル／×）で閉じる。入力中に変更があるときは、下へのスワイプでは閉じず、破棄するかを確認する。
- iPad は横幅を活かし、宛先は「グループ＋一覧＋詳細」、印刷プレビューは「用紙＋サイドパネル」の分割表示になる。ポインタ操作にも対応している。

### キーボードショートカット（iPad・Mac）

| 操作 | キー |
|---|---|
| 宛先を手入力で追加 | ⌘N |
| CSVから取り込む | ⇧⌘I |
| 一括印刷 | ⇧⌘P |
| この宛先を印刷／プレビューで印刷 | ⌘P |
| 宛先を編集（宛先詳細） | ⌘E |
| PDFで書き出す（印刷プレビュー） | ⌘E |
| 保存 | ⌘S |
| キャンセル／閉じる | Esc |
| 前／次の宛先（印刷プレビュー） | ← ／ → |
| 確定（取り込む・プレビュー） | Return |

## StoreKit（アプリ内課金）の設定

課金は StoreKit 2 の**非消耗型 1点のみ**。サブスクリプションは作らない。

| 機能 | 無料版 | Pro（買い切り） |
|---|---|---|
| 宛先の登録 | 10件まで | 無制限 |
| 印刷（AirPrint） | 無制限・透かしなし | 同左 |
| CSV取り込み | 使える（宛先の合計10件まで。取り込み前の確認画面は全件表示） | 件数無制限 |
| PDF出力 | × | ○ |

1. App Store Connect でアプリを作成し、「アプリ内課金」で **非消耗型** を1つ作る。
   - 参照名: `Pro`
   - 製品ID: `AppConstants.proProductID` と同じ値（初期値は `com.seventhwell.AtenaPrint.pro`）
   - 価格: 800円。日本円の価格ポイントとして選べるかは、App Store Connect の価格設定画面で確認すること
   - 表示名・説明: 下の例を参照。「無料お試し」「期間限定」などの表現は使わない
2. ファミリー共有を有効にする（設計上の決定事項 Q6）。
3. ローカルで課金をテストするときは、スキームの Run → Options → StoreKit Configuration に `AtenaPrint/Resources/Products.storekit` を指定する（`project.yml` で設定済み）。製品IDを変えた場合は、このファイルの `productID` も合わせる。
   - **要確認**: `Products.storekit` は Xcode なしで手書きしたファイル。CI のテスト（`SKTestSession`）では製品を読み込めなかった（製品一覧が空）。Xcode で開いて製品が表示されない場合は、File → New → File → StoreKit Configuration File で作り直し、非消耗型（製品ID・価格800・日本語の表示名）を追加して同じファイル名で保存する。

表示名・説明の例:

| 項目 | 内容 |
|---|---|
| 表示名 | Pro（買い切り） |
| 説明 | 宛先無制限・CSV件数無制限・PDF出力（買い切り） |

アプリ側の仕様:

- 購入状態は StoreKit の検証済みトランザクションだけで判定し、端末には保存しない。
- 「購入の復元」（`AppStore.sync()`）は課金画面と設定画面の両方にある。
- 課金画面は、ユーザーが操作したときだけ開く。開くのは次の4つの場面で、印刷中に割り込むことはない。
  - 11件目の宛先を保存しようとしたとき
  - CSV取り込みで無料版の上限を超えた行があり、「Proについて」を押したとき
  - 「PDFで書き出す」を押したとき
  - 設定の「Pro」を押したとき

## 差し替えが必要な定数

| 場所 | 項目 | 初期値 | 内容 |
|---|---|---|---|
| `AtenaPrint/App/AppConstants.swift` | `proProductID` | `com.seventhwell.AtenaPrint.pro` | App Store Connect の製品ID |
| 〃 | `privacyPolicyURL` | `https://example.com/atena-print/privacy` | プライバシーポリシーの公開URL |
| 〃 | `termsOfUseURL` | `https://example.com/atena-print/terms` | 利用規約の公開URL |
| 〃 | `freeRecipientLimit` | `10` | 無料版の登録上限（`AtenaCore` の `FreeTier.recipientLimit` と一致させる。テストで確認している） |
| 〃 | `reviewRequestThreshold` | `5` | この回数を超えて印刷が成功した後、1回だけレビューを依頼する |
| 〃 | `storeName` | `AtenaPrint` | SwiftData のストア名。**リリース後は変更しない**（既存データが読めなくなる） |
| `project.yml` | `PRODUCT_BUNDLE_IDENTIFIER` | `com.seventhwell.AtenaPrint` | バンドルID。変更後に `xcodegen generate` |
| 〃 | `DEVELOPMENT_TEAM` | 空 | 署名チーム（Xcode 上で設定してもよい） |
| `AtenaPrint/Resources/Products.storekit` | `productID` | `com.seventhwell.AtenaPrint.pro` | ローカル課金テスト用。`proProductID` と一致させる |

秘密情報（APIキー、証明書、プロビジョニングプロファイル）はリポジトリに含めない。`.gitignore` で主な拡張子を除外している。

## CSV テンプレートの仕様

設定 → 「CSVテンプレートを書き出す」で共有シートから書き出せる。

| 項目 | 仕様 |
|---|---|
| 文字コード | 取り込み: UTF-8（BOM あり・なし）と Shift_JIS（Windows 版 Excel の「CSV（コンマ区切り）」）。自動判定し、取り込み画面で切り替えもできる。書き出し: UTF-8（BOM 付き。Excel で文字化けしないため） |
| 区切り・改行 | カンマ区切り。改行は CRLF / LF / CR のどれでもよい。ダブルクォートで囲んだセル内の改行・カンマ・`""`（引用符）に対応（RFC 4180） |
| 1行目 | 見出し行（「1行目は見出し」をオフにすると、見出しなしとして扱う） |
| サイズ上限 | 5MB |

列（テンプレートの5列）:

| 列名 | 内容 | 例 |
|---|---|---|
| 氏名 | 必須。空の行は取り込まない | 山田 太郎 |
| 連名 | 複数あるときは「・」「、」「/」で区切る | 花子・一郎 |
| 郵便番号 | ハイフン・〒・全角数字があってもよい。7桁でない場合は警告を出したうえで取り込む | 104-0061 |
| 住所 | | 東京都中央区見本町1-13-3 サンプルハイツ203 |
| メモ | 喪中・転居先など | 喪中 |

任意の列（見出しが一致すれば自動で対応付ける。取り込み画面で手動でも選べる）:

| 列名（別名） | 内容 |
|---|---|
| ふりがな（フリガナ、よみ） | 並び替えに使う |
| 住所2（建物名） | 建物名・部屋番号。縦書きで改行して配置する |
| 敬称 | 空のときは「様」 |

見出しの別名の例: 氏名 = 名前・宛名・会社名、郵便番号 = 〒・郵便、住所 = 住所1・address、メモ = 備考。

重複: 氏名（空白は無視）と郵便番号が既存の宛先と一致する行は「重複の可能性」として、初期状態では取り込まない（行ごとに変更できる）。

「宛先をCSVで書き出す」で書き出したファイルには任意の列も含まれ、そのまま取り込み直せる。表計算ソフトで数式として実行されないように、`=` `+` `@` で始まるセルには先頭に `'` を付けて書き出す。取り込み時にはこの `'` を取り除く。

## 宛名面のレイアウト

- 郵便番号枠: 日本郵便「郵便番号・バーコードマニュアル」の記入枠仕様1（JIS）に準拠し、上端 12.0mm・右端 8.0mm、枠 5.7×8.0mm、各枠の左端は 0 / 7.0 / 14.0 / 21.6 / 28.4 / 35.2 / 42.0mm（[出典](https://www.post.japanpost.jp/service/search/zipcode/zipmanual/p05.html)）。封筒にも同じ位置を使う。
- 用紙: はがき 100×148mm、長形3号 120×235mm、長形4号 90×205mm、洋形2号 114×162mm（縦向き）、角形2号 240×332mm（A4 より大きいため、対応プリンタのみ）。
- 縦書き: 1文字ずつ配置する。長音・ダッシュ・括弧は回転させ、小書きの仮名と句読点は位置を補正する。住所の数字を1桁ずつ漢数字に変換するオプションがある（例: 1-13-3 → 一―一三―三）。
- 自動縮小: 収まらないときは、まず住所を改行し、それでも収まらなければ文字を縮小する。最小サイズでも収まらない場合は、はみ出し警告を出す。
- 印刷位置の微調整: 上下左右を 0.5mm 単位で調整でき、用紙ごとに保存される。PDF には反映しない。

## プライバシー

- トラッキングなし（ATT を表示しない）、解析 SDK なし、広告 SDK なし。
- `PrivacyInfo.xcprivacy`: 収集するデータなし。必須理由 API は `UserDefaults`（理由 `CA92.1`）だけを申告している。
- 連絡先は `CNContactPickerViewController` で、ユーザーが選んだ連絡先だけを読む。アプリが連絡先へのアクセス許可を求めることはない。
- データは SwiftData のローカルストア（CloudKit 同期なし）に保存する。端末の iCloud バックアップ・PC バックアップの対象になる。
