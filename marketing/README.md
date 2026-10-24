# マーケティング素材

| ファイル | 内容 |
|---|---|
| `AppStore.md` | App Store 掲載文の下書き（タイトル・サブタイトル・説明文・キーワード） |
| `mockups/iphone-1〜4.png` | iPhone 6.9インチ用（1290×2796）のスクリーンショット素材 |
| `mockups/ipad-1〜2.png` | iPad 13インチ用（2752×2064、横向き）の素材 |
| `mockups/mac-1.png` | Mac（Designed for iPad）のウインドウ表示のモック（2880×1800） |
| `mockups/iphone-duo.png` / `iphone-duo-dark.png` | iPhone 2台並び（ライト / ダーク） |
| `screenshots/` | 元の画面キャプチャ（CI のシミュレータで撮影。架空のサンプルデータ） |

## 作り直し方

1. CI（GitHub Actions）の成果物 `snapshots` をダウンロードして展開する（画面キャプチャ `screen-*.png` が入っている）。
2. 次を実行する（Node.js と Playwright が必要）。

```sh
python3 tools/mockups/build.py <snapshots のフォルダ> /tmp/mock
node tools/mockups/render.js /tmp/mock marketing/mockups
```

## 注意

- 画面はシミュレータで撮影したもの。ステータスバー（9:41 など）はモック側で重ねて描いている。
- 課金画面は、CI のテスト環境で価格を読み込めなかったため素材に含めていない（README の StoreKit 設定の「要確認」を参照）。
- Mac のモックは iPad 版の画面をウインドウに入れたもの。Mac での印刷は実機で未確認。
