# NEON CITY 2099 を iPhone にネイティブアプリとして入れる手順（AltStore Classic）

全体の流れ： ①Muse が必要ファイルを GitHub に push → ②かいとが GitHub でワークフローを1つ作る → ③Actions が .ipa をビルド → ④Windows PC の AltServer 経由で AltStore を iPhone に入れる → ⑤AltStore で .ipa をインストール

---

## 用意するもの

- iPhone 16 Pro（インストール先）
- Windows ノートPC（AltServer 用。インストールと7日ごとの更新に使う）
- iPhone と PC が同じ Wi-Fi にいること
- Apple ID（無料のままでOK）
- USB ケーブル（AltStore の初回インストール時のみ）
- GitHub アカウント（kaito0109、ログイン済みのブラウザ）

## Step 1：必要ファイルの push（Muse 側）

- セーブ機能 v6.1 と iOS 用設定（export_presets.cfg、ios-deploy.yml.txt、SPEC.md）を Muse が push する
- かいとは承認カードをタップするだけ

## Step 2：GitHub でワークフローを作る（かいと・PCかスマホのブラウザ）

1. https://github.com/kaito0109/neon-city-2099 を開く
2. 上部の「Add file」→「Create new file」
3. ファイル名の欄に `.github/workflows/ios-deploy.yml` と入力（スラッシュを打つと自動でフォルダになる）
4. 中身に、リポジトリ内の `ios-deploy.yml.txt` の内容を全部コピペする
   （先に別タブで ios-deploy.yml.txt を開いて全文コピーしておくと楽）
5. 「Commit changes」で保存

## Step 3：Actions で .ipa をビルドする（かいと）

1. リポジトリの「Actions」タブを開く
2. 左の一覧から「Build iOS app (unsigned .ipa for AltStore)」を選ぶ
3. 「Run workflow」ボタン → もう一度「Run workflow」で実行開始
4. 数分〜十数分待つ（Mac ランナーのビルド。終わると緑のチェックが付く）
5. 実行結果のページ下部「Artifacts」から `NeonCity2099-ipa` をダウンロード
6. zip を解凍すると `NeonCity2099.ipa` が出てくる

※初回は xcodebuild の段で失敗する可能性もある。その場合は Muse にログを見せる（Actions の失敗ログを Muse が確認して直す）。

## Step 4：PC に AltServer を入れる（かいと・Windows）

前提ソフト（Microsoft Store 版ではダメ。Apple 公式サイトから落としたものが必要）：

1. iTunes を Apple のサイトからダウンロードしてインストール
2. iCloud for Windows も Apple のサイトからダウンロードしてインストール
3. AltStore 公式（https://altstore.io）の「AltServer for Windows」をダウンロードしてインストール
4. PC を再起動（ドライバ反映のため推奨）

AltStore 本体を iPhone に入れる：

5. USB ケーブルで iPhone を PC につなぎ、iPhone 側で「このコンピュータを信頼」を押す
6. iTunes を開き、iPhone の設定で「Wi-Fi 経由でこの iPhone と同期」にチェックを入れる（更新を無線でやるため）
7. AltServer を起動 → タスクトレイ（画面右下）の AltServer アイコン →「Install AltStore」→ 自分の iPhone を選ぶ
8. Apple ID とパスワードを入力（2段階認証の確認コードを求められたら入力）
9. iPhone のホーム画面に AltStore が現れる

iPhone 側の追加設定：

10. 「設定」→「一般」→「VPN とデバイス管理」→ 自分の Apple ID をタップして「信頼」
11. 「設定」→「プライバシーとセキュリティ」→「デベロッパモード」を ON（再起動が要る。iOS 16 以降で必須）

## Step 5：NEON CITY をインストール（かいと）

1. Step 3 で落とした `NeonCity2099.ipa` を iCloud Drive に置く（PC からアップロード）
2. iPhone の「ファイル」アプリで ipa が見える状態にする
3. AltStore を開く → 下部「My Apps」→ 左上の「＋」
4. ファイルから `NeonCity2099.ipa` を選ぶ → インストール開始
5. ホーム画面に NEON CITY 2099 が現れたら完了。セーブデータはファイルアプリの「このiPhone内 > NEON CITY 2099」に見える

## 知っておくこと（制限）

- 無料 Apple ID の署名は **7 日で期限切れ**。切れる前に、PC で AltServer を起動した状態（同じ Wi-Fi）で AltStore を開くと自動更新される。切れてしまったら AltStore から再インストールすれば直る（セーブはアプリ内に残る）
- サイドロードできるアプリは **最大 3 つまで**（AltStore 自身も 1 つに数えるので、実質あと 2 つ）
- アプリを削除するとセーブデータも消える。心配なら ファイルアプリから neon_save.json をコピーしてバックアップできる
- Web 版（GitHub Pages）とアプリ版のセーブは別々（引き継ぎはできない）
