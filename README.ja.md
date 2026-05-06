# pb-talk（日本語補足）

> English version: [README.md](README.md).

`pb-talk` は [Pandorabots](https://www.pandorabots.com/docs/api-endpoints/) の公開APIに対するシェル製の対話REPLです。かつて業務で使っていた手元のシェルツールを、個人OSSとして整備し直したものです。

英語版（[README.md](README.md)）が主ドキュメントです。本ファイルは日本語ユーザー向けの補足、特に分かち書き（テキスト前処理）の連携方法をまとめます。

## 概要（要点だけ）

- 主機能・コマンド一覧・設定（`.env`）・トレース整形は英語版に記載しています。
- 主要コマンド: `<input>` / `--trace <input>` / `--reset <input>` / `--reload <input>` / `--atalk <input>` / `topic` / `traceon` / `traceoff` / `seg` / `noseg` / `history*` / `retype` / `resession` / `clear` / `q` / `h`。
- 必要な環境変数: `PB_APP_ID` / `PB_USER_KEY` / `PB_BOTNAME`（必須）、`PB_HOST` / `PB_BOT_KEY` / `PB_CLIENT_NAME` / `PB_SEG_CMD`（任意）。
- 依存: `bash` 4+（または `zsh` 5+）、`curl`、`jq`。

## ボットの作成・デプロイ

英語版 README の Quickstart で、`curl` でボットを作成してから AIML をアップロード→コンパイルする手順を紹介しています。それ以外に、より高レベルな CLI として [`pb-migrate`](https://github.com/knlab/pb-migrate) もあります（`composer global require knlab/pb-migrate`）。`add` / `bot:create` / `push` / `compile` / `pull` / `diff` などボットライフサイクル全般をカバーしているので、AIML パッケージを継続的に開発・デプロイする場合はこちらが便利です。`pb-talk` は `pb-migrate` に依存していないため、どちらか軽い方を選んでください。組み合わせ運用も自然で、`pb-migrate` でボットを作成・更新→`pb-talk` で会話・トレース確認、という分担が定番です。

## 分かち書き（テキスト前処理）の連携

日本語のように、AIML パターンが分かち書きされた語彙で書かれているボットに talk を投げる場合、入力文を**サーバへ送る前にこちら側で分かち書き**しておく必要があります。`pb-talk` はこのための単一のフック点を持ちます。

### 仕様

- REPL で `seg` と入力すると分かち書きが有効化、`noseg` で無効化（既定）。
- 有効時、`pbtalk` は環境変数 `PB_SEG_CMD`（既定: `pbseg`）で指定されたコマンドを `argv[1]` に入力文を渡して呼び出します。
- そのコマンドの **stdout の文字列**（空白区切り想定）が talk リクエストの `input` として送られます。
- `PB_SEG_CMD` が PATH に見つからない状態で `seg` を有効化しようとすると、警告 1 行を出して有効化を拒否し、無効モードを維持します。
- 有効化時には存在したが実行中に失敗した場合は、その回だけ警告を出して **生の入力文をそのまま** 送信します。
- `pbtalk` 自体は、分かち書きコマンドの不在やエラーで落とさない設計です。

### 入出力契約

- **入力**: `argv[1]` に UTF-8 の日本語文（または対象言語の文）。
- **出力**: `stdout` に空白区切りの文字列（末尾の改行は無視されます）。
- **終了コード**: 成功で 0、それ以外は失敗扱い（その回はフォールバック）。

つまり実装は何でもよく、`pbseg` という名前で PATH に置いておくか、`PB_SEG_CMD` で別名を指すだけで切り替えられます。以下に最小サンプルを示します（pb-talk は同梱しません）。

### 例 1: MeCab ベースの `pbseg`

[MeCab](https://taku910.github.io/mecab/) がインストールされている前提のシェルワンライナーです。`~/.local/bin/pbseg` などに保存し、実行権を付与してください。

```sh
#!/usr/bin/env bash
# pbseg — MeCab-based segmenter wrapper
set -e
input="${1-}"
[[ -z "$input" ]] && { printf '\n'; exit 0; }
printf '%s' "$input" | mecab -Owakati
```

`mecab -Owakati` は分かち書き専用の出力モードで、空白区切りの一行を返します。

インストール:

- macOS: `brew install mecab mecab-ipadic`
- Ubuntu/Debian: `sudo apt install mecab mecab-ipadic-utf8`

### 例 2: SudachiPy ベースの `pbseg`

Python と [SudachiPy](https://github.com/WorksApplications/SudachiPy) がインストールされている前提のスクリプトです。同様に `~/.local/bin/pbseg` に保存します（先頭の shebang を環境に合わせて調整してください）。

```python
#!/usr/bin/env python3
# pbseg — SudachiPy-based segmenter
import sys
from sudachipy import dictionary, tokenizer

if len(sys.argv) < 2 or not sys.argv[1]:
    print("")
    sys.exit(0)

mode = tokenizer.Tokenizer.SplitMode.C
tok = dictionary.Dictionary().create()
tokens = [m.surface() for m in tok.tokenize(sys.argv[1], mode)]
print(" ".join(tokens))
```

> Python は macOS には標準で同梱されないため、別途インストールが必要です（例: `brew install python` ）。`pip install sudachipy sudachidict_core` で SudachiPy 本体と辞書を入れます。

### 別名で使う

複数の実装を同居させたいときは、`PB_SEG_CMD` を `.env` で切り替えてください。

```env
# 例: pbseg-mecab / pbseg-sudachi の両方を PATH に置いて切り替える
PB_SEG_CMD=pbseg-sudachi
```

## バージョニング方針

詳細は英語版 README の「Versioning」を参照してください。要点だけ:

- **現行 `0.x.y`（公開ベータ）**: REPL コマンド・環境変数・`pbtrace` 出力は調整中。`0.x` 系列内の**マイナー上げ（例: 0.9.x → 0.10.x）は破壊的変更を含むことがあります**。パッチ上げ（0.9.0 → 0.9.1）はバグ修正のみ。
- **`1.0.0` 以降は厳格な [SemVer](https://semver.org/lang/ja/spec/v2.0.0.html)**: REPL コマンド削除/改名や `pbtrace` の出力構造変更などの非互換変更はメジャー、後方互換な追加はマイナー、互換維持のバグ修正はパッチ。

リリースはすべて [`CHANGELOG.md`](CHANGELOG.md) に記録し、git では `vX.Y.Z` 形式でタグ付けします。`0.9.x` から `1.0.0` への昇格は、外部ユーザーから破壊的変更を要さないことが確認できた時点で行います。

## ライセンス

[MIT](LICENSE)。
