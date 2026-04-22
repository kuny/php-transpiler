# php-transpiler

S-expression (S-exp) で記述された AST を PHP ソースコードに変換するトランスパイラです。Racket で実装されています。

## 変換例

**入力** (`sexp/App/Http/Controllers/UserController.sexp`):

```scheme
(program
   (namespace (ns App Http Controllers))
   (use (ns App Models User))
   (use (ns Illuminate Http Request))

   (class UserController #:extends Controller
     (method (public) index ((param/type Request "$request"))
       (expr-stmt
        (assign = (var "$users")
                (call (:: User all))))
       (return
        (call view "'users.index'"
              (call compact "'users'"))))))
```

**出力** (`build/App/Http/Controllers/UserController.php`):

```php
<?php

namespace App\Http\Controllers;

use App\Models\User;
use Illuminate\Http\Request;

class UserController extends Controller
{
    public function index(Request $request)
    {
        $users = User::all();
        return view('users.index', compact('users'));
    }
}
```

## 必要なもの

- Docker & Docker Compose

## セットアップ

```bash
# Composer の依存関係をインストール (php-cs-fixer)
make install

# Racket イメージをビルド
make image
```

## 使い方

`sexp/` ディレクトリに `.sexp` ファイルを配置し、以下のコマンドでビルドします。

```bash
# トランスパイル + php-cs-fixer による整形
make build
```

ディレクトリ構造は `sexp/` から `build/` にそのまま維持されます。

```
sexp/App/Http/Controllers/UserController.sexp
  → build/App/Http/Controllers/UserController.php
```

## Make ターゲット一覧

| コマンド | 説明 |
|---|---|
| `make install` | Composer の依存関係をインストール |
| `make image` | Racket コンテナイメージを再ビルド |
| `make doctor` | Racket コンテナの arch を確認 |
| `make transpile` | `sexp/` → `build/` に PHP を生成 |
| `make fix` | `build/` の PHP を php-cs-fixer で整形 |
| `make build` | transpile + fix |
| `make rebuild` | clean + build |
| `make clean` | `build/` 配下を削除 |
| `make check` | php-cs-fixer の dry-run (差分表示) |
| `make shell-racket` | Racket コンテナでシェルを起動 |
| `make shell-composer` | Composer コンテナでシェルを起動 |

## プロジェクト構成

```
├── sexp/                  # 入力: S-expression ソースファイル
├── build/                 # 出力: 生成された PHP ファイル
├── src/
│   ├── main.rkt           # エントリポイント
│   └── compiler.rkt       # コンパイル処理のオーケストレーション
├── php-transpiler/        # Racket パッケージ本体
│   ├── emit.rkt           # コア: S-exp → PHP 変換ロジック
│   └── test-emit.rkt      # テストスイート
├── Dockerfile             # Racket 実行環境
├── docker-compose.yml     # transpiler / composer サービス定義
├── Makefile               # ビルド自動化
├── composer.json           # PHP 依存関係 (php-cs-fixer)
└── .php-cs-fixer.dist.php # コードスタイル設定
```
