# CLAUDE.md（作業メモ・毎回読み込まれる）

## 前提（ユーザー確認済み）
- 返答は日本語で行う。
- Apple Developer Program には登録済み。バンドルIDは `com.seventhwell.AtenaPrint`、課金の製品IDは `com.seventhwell.AtenaPrint.pro`。
- 実機テストは TestFlight で行う。GitHub と連携した Runway から TestFlight に配信できる。
  - GitHub Actions の `TestFlight` ワークフロー（手動実行、`.github/workflows/testflight.yml`）からも配信できる。必要な Secrets: `ASC_KEY_ID` `ASC_ISSUER_ID` `ASC_KEY_P8` `APPLE_TEAM_ID`。
  - 実機確認が必要な項目は「TestFlight で確認」として扱い、「Mac で Xcode から実機に入れる」前提の提案はしない。

## 開発ルール
- 新しいファイルを追加したら `xcodegen generate` で `AtenaPrint.xcodeproj` を作り直す（CI の `tools/check_project.py` が漏れを検出する）。
- UI 文字列は `AtenaPrint/Resources/Localizable.xcstrings` で管理する（`tools/check_strings.py` で整合を確認）。
- 秘密情報（API キー、証明書、.p8 など）はコミットしない。
