# php-transpiler

A transpiler that converts S-expression (S-exp) ASTs into PHP source code. Implemented in Racket.

S-expression (S-exp) で記述された AST を PHP ソースコードに変換するトランスパイラです。Racket で実装されています。


## Philosophy (or Why This Exists) / 哲学

While I respect PHP as a runtime environment, I had grown weary of writing its syntax—particularly the ubiquitous $ and $this->—by hand every day. This is an attempt to isolate the intelligence within S-expressions and redefine PHP as “assembler to be generated.”

私はPHPという実行環境を尊重しているが、その構文（特に行き渡った $ や $this->）を毎日手書きすることに疲弊していた。これは、知性を S-expression に隔離し、PHPを『生成されるべきアセンブラ』として再定義するための試みである。


## Example / 変換例

**Input** (`UserController.sexp`):

```scheme
(program
   (namespace (ns App Http Controllers))
   (use (ns App Models User))
   (use (ns Illuminate Http Request))

   (class UserController #:extends Controller
     (method (public) index ((param/type Request request))
       (expr-stmt
        (assign = (var users)
                (call (:: User all))))
       (retur:n
        (call view "users.index"
              (call compact "users"))))))
```

**Output** (`UserController.php`):

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

## Requirements / 必要なもの

- Docker & Docker Compose

## Setup / セットアップ

```bash
# Install Composer dependencies (php-cs-fixer)
# Composer の依存関係をインストール (php-cs-fixer)
make install

# Build the Racket image
# Racket イメージをビルド
make image
```

## Usage / 使い方

Place `.sexp` files in the `sexp/` directory and run the following command to build.

`sexp/` ディレクトリに `.sexp` ファイルを配置し、以下のコマンドでビルドします。

```bash
# Transpile + format with php-cs-fixer
# トランスパイル + php-cs-fixer による整形
make build
```

The directory structure is preserved from `sexp/` to `build/`.

ディレクトリ構造は `sexp/` から `build/` にそのまま維持されます。

```
sexp/App/Http/Controllers/UserController.sexp
  → build/App/Http/Controllers/UserController.php
```

## Make Targets / Make ターゲット一覧

| Command | Description |
|---|---|
| `make install` | Install Composer dependencies |
| `make image` | Rebuild the Racket container image |
| `make doctor` | Check the Racket container architecture |
| `make transpile` | Generate PHP from `sexp/` to `build/` |
| `make fix` | Format PHP in `build/` with php-cs-fixer |
| `make build` | transpile + fix |
| `make rebuild` | clean + build |
| `make clean` | Remove files under `build/` |
| `make check` | Dry-run php-cs-fixer (show diff) |
| `make shell-racket` | Open a shell in the Racket container |
| `make shell-composer` | Open a shell in the Composer container |

## Project Structure / プロジェクト構成

```
├── sexp/                  # Input: S-expression source files
├── build/                 # Output: Generated PHP files
├── src/
│   ├── main.rkt           # Entry point
│   └── compiler.rkt       # Compilation orchestration
├── php-transpiler/        # Racket package
│   ├── emit.rkt           # Core: S-exp → PHP conversion logic
│   └── test-emit.rkt      # Test suite
├── Dockerfile             # Racket runtime environment
├── docker-compose.yml     # transpiler / composer service definitions
├── Makefile               # Build automation
├── composer.json          # PHP dependencies (php-cs-fixer)
└── .php-cs-fixer.dist.php # Code style configuration
```
