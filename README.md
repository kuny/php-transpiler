# php-transpiler

A transpiler that converts S-expression (S-exp) ASTs into PHP source code. Implemented in Racket.

S-expression (S-exp) で記述された AST を PHP ソースコードに変換するトランスパイラです。Racket で実装されています。


## Philosophy (or Why This Exists) / 哲学

While I respect PHP as a runtime environment, I had grown weary of writing its syntax—particularly the ubiquitous $ and $this->—by hand every day. This is an attempt to isolate the intelligence within S-expressions and redefine PHP as "assembler to be generated."

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
       (return
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

## S-expression Syntax Reference / S式リファレンス

### Literals / リテラル

```scheme
42                       ; → 42
3.14                     ; → 3.14
"'hello'"                ; → 'hello'  (quote-wrapped strings are emitted as-is)
"hello"                  ; → 'hello'  (bare strings get single-quoted)
true                     ; → true
false                    ; → false
null                     ; → null
```

Magic constants / マジック定数: `__CLASS__`, `__TRAIT__`, `__METHOD__`, `__FUNCTION__`, `__LINE__`, `__FILE__`, `__DIR__`, `__NAMESPACE__`

### Variables / 変数

```scheme
(var x)                  ; → $x
(var "$x")               ; → $x  ($ prefix is auto-added if missing)
(& (var x))              ; → &$x
(array-access (var arr) 0)  ; → $arr[0]
(array-access (var arr) #f) ; → $arr[]
(indirect (var x) 1)     ; → $$x
(brace-var (var key))    ; → ${$key}
```

### Operators / 演算子

**Binary / 二項演算子:**

```scheme
(binary + 1 2)           ; → 1 + 2
(binary concat (var a) "'b'")  ; → $a . 'b'
(binary pow 2 10)        ; → 2 ** 10
(binary spaceship (var a) (var b))  ; → $a <=> $b
```

Supported: `+` `-` `*` `/` `%` `pow` `concat` `&` `bw-or` `^` `shl` `shr` `&&` `or-short` `and` `or` `xor` `==` `!=` `===` `!==` `<` `<=` `>` `>=` `spaceship`

**Unary / 単項演算子:**

```scheme
(unary ! (var x))        ; → !$x
(pre-inc (var i))        ; → ++$i
(post-dec (var i))       ; → $i--
```

**Assignment / 代入演算子:**

```scheme
(assign = (var x) 42)    ; → $x = 42
(assign += (var x) 1)    ; → $x += 1
(assign concat= (var s) "'w'")  ; → $s .= 'w'
(assign coalesce= (var x) "'default'")  ; → $x ??= 'default'  (PHP 8.0)
```

Supported: `=` `+=` `-=` `*=` `/=` `%=` `pow=` `concat=` `&=` `bw-or=` `^=` `<<=` `>>=` `coalesce=`

**Cast / キャスト:**

```scheme
(cast int (var x))       ; → (int)$x
(cast string (var x))    ; → (string)$x
```

Supported: `int` `float` `string` `array` `object` `bool` `binary` `unset`

**Ternary & Null coalescing / 三項演算子・Null合体演算子:**

```scheme
(ternary (var a) (var b) (var c))  ; → $a ? $b : $c
(ternary (var a) #f (var c))       ; → $a ?: $c
(coalesce (var a) (var b))         ; → $a ?? $b
```

### Arrays / 配列

```scheme
(array 1 2 3)            ; → array(1, 2, 3)
(short-array 1 2 3)      ; → [1, 2, 3]
(short-array (=> "'a'" 1) (=> "'b'" 2))  ; → ['a' => 1, 'b' => 2]
(php-list (var a) (var b))  ; → list($a, $b)
(splat (var arr))         ; → ...$arr
```

### Object Access / オブジェクトアクセス

```scheme
(-> (var obj) (access prop))     ; → $obj->prop
(-> (var obj) (access method) (call-chain 1 2))  ; → $obj->method(1, 2)
(-> (var obj) (access items) (index 0) (access name))  ; → $obj->items[0]->name
(:: MyClass CONST)               ; → MyClass::CONST
(call (:: MyClass method))       ; → MyClass::method()
(new DateTime "'2024-01-01'")    ; → new DateTime('2024-01-01')
(clone (var obj))                ; → clone $obj
(instanceof (var obj) Exception) ; → $obj instanceof Exception
```

**Nullsafe operator / Nullsafe 演算子 (PHP 8.0):**

```scheme
(?-> (var obj) (access address) (access city))  ; → $obj?->address?->city
```

### Function Calls / 関数呼び出し

```scheme
(call strlen "'hello'")  ; → strlen('hello')
(call func (splat (var args)))  ; → func(...$args)
```

**Named arguments / 名前付き引数 (PHP 8.0):**

```scheme
(call array_slice (var arr) (named-arg offset 2) (named-arg length 3))
; → array_slice($arr, offset: 2, length: 3)
```

**First-class callable syntax / 第一級callableシンタックス (PHP 8.1):**

```scheme
(first-class-callable strlen)          ; → strlen(...)
(first-class-callable (:: Foo bar))    ; → Foo::bar(...)
```

### Control Flow / 制御構文

**if / elseif / else:**

```scheme
(if (var x) (block (return 1)))
(if (var x) (block (return 1)) (block (return 2)))
(if (var x) (block (return 1)) (elseif ((var y) (block (return 2)))) (block (return 3)))
```

**Loops / ループ:**

```scheme
(while true (block (break)))
(do-while (var x) (block (expr-stmt (post-dec (var x)))))
(for ((assign = (var i) 0)) ((binary < (var i) 10)) ((post-inc (var i)))
  (block (echo (var i))))
(foreach (var arr) (var v) (block (echo (var v))))
(foreach (var arr) (var k) (var v) (block (echo (var k))))
```

**switch:**

```scheme
(switch (var x)
  (case 1 (echo "'one'") (break))
  (default (echo "'other'")))
```

**Match expression / match 式 (PHP 8.0):**

```scheme
(match (var status)
  (match-arm (200 300) "'ok'")
  (match-arm (404) "'not found'")
  (match-default "'error'"))
; → match($status) { 200, 300 => 'ok', 404 => 'not found', default => 'error', }
```

**try / catch / finally:**

```scheme
(try (block (echo 1))
  (catch Exception "$e" (echo (var e)))
  (finally (echo "'done'")))

;; Multi-catch / 複数例外キャッチ
(try (block ...) (catch (TypeError ValueError) "$e" ...))

;; Catch without variable / 変数なし catch (PHP 8.0)
(try (block ...) (catch NotFoundException #f (echo "'handled'")))
```

**Other / その他:**

```scheme
(return (var x))         ; → return $x;
(return)                 ; → return;
(break)                  ; → break;
(continue)               ; → continue;
(throw (new Ex))         ; → throw new Ex;  (also usable as expression in PHP 8.0)
(goto end)               ; → goto end;
(label end)              ; → end:
```

### Functions / 関数

```scheme
(function add ((param a) (param b))
  (return (binary + (var a) (var b))))
; → function add($a, $b) { return $a + $b; }

;; With return type / 戻り値型付き
(function greet ((param/type string name)) #:return-type string
  (return (binary concat "'Hello, '" (var name))))
; → function greet(string $name): string { return 'Hello, ' . $name; }

;; Reference return / 参照返し
(function& name ((param x)) ...)
```

**Parameters / パラメータ:**

```scheme
(param x)                ; → $x
(param x 0)              ; → $x = 0
(param/type int x)       ; → int $x
(param/type int x 0)     ; → int $x = 0
(param/type (? string) s)  ; → ?string $s
(param& x)               ; → &$x
(param-rest args)         ; → ...$args
(param-rest-type int nums)  ; → int ...$nums
```

**Constructor property promotion / コンストラクタプロパティ昇格 (PHP 8.0):**

```scheme
(param/promoted (private) string name)          ; → private string $name
(param/promoted (private readonly) string name)  ; → private readonly string $name
(param/promoted (protected) int age 0)          ; → protected int $age = 0
```

**Lambda / Closure / クロージャ:**

```scheme
(lambda ((param x)) (return (binary * (var x) 2)))
; → function($x) { return $x * 2; }

(lambda ((param x)) (use (var y)) (return (binary + (var x) (var y))))
; → function($x) use ($y) { return $x + $y; }

(static-lambda ((param x)) ...)
; → static function($x) { ... }
```

**Arrow function / アロー関数 (PHP 7.4+):**

```scheme
(arrow-fn ((param x)) (binary * (var x) 2))
; → fn($x) => $x * 2

(arrow-fn ((param/type int x)) #:return-type int (binary * (var x) 2))
; → fn(int $x): int => $x * 2

(static-arrow-fn ((param x)) (binary * (var x) 2))
; → static fn($x) => $x * 2
```

### Type Hints / 型ヒント

**Basic types / 基本型:** `int`, `float`, `string`, `bool`, `array`, `callable`, `void`, `self`, `iterable`, `object`, `parent`, `static`

**PHP 8.0+ types:** `mixed`, `null`, `false`, `true`, `never`

**Nullable / Null許容型:**

```scheme
(? string)               ; → ?string
```

**Union types / ユニオン型 (PHP 8.0):**

```scheme
(union int string)       ; → int|string
(union int false)        ; → int|false
```

**Intersection types / 交差型 (PHP 8.1):**

```scheme
(intersection Countable Iterator)  ; → Countable&Iterator
```

**DNF types / DNF型 (PHP 8.2):**

```scheme
(union (intersection A B) null)  ; → (A&B)|null
```

### Classes / クラス

```scheme
(class Dog #:extends Animal #:implements (Runnable)
  (property (public) (var name))
  (method (public) __construct ((param name))
    (expr-stmt (assign = (-> (var this) (access name)) (var name))))
  (method (public) bark ()
    (return "'Woof!'")))

(abstract-class Base (method (abstract public) render ()))
(final-class Singleton)
(readonly-class Point ...)  ; PHP 8.2
```

**Properties / プロパティ:**

```scheme
(property (public) (var name))                    ; → public $name;
(property (public static) ((var count) 0))        ; → public static $count = 0;
(typed-property (public) string (var name))        ; → public string $name;
(typed-property (private) int ((var retries) 3))   ; → private int $retries = 3;
(typed-property (public readonly) string (var name))  ; → public readonly string $name;
```

**Methods / メソッド:**

```scheme
(method (public) name ((param x)) (return (var x)))
(method/rt (public) name ((param x)) string (return (var x)))  ; with return type
(method& (public) name ((param x)) ...)  ; reference return
```

**Class constants / クラス定数:**

```scheme
(class-const MAX 100)                    ; → const MAX = 100;
(class-const private SECRET "'shhh'")    ; → private const SECRET = 'shhh';
(typed-class-const string NAME "'foo'")  ; → const string NAME = 'foo';  (PHP 8.3)
(typed-class-const public int MAX 100)   ; → public const int MAX = 100;  (PHP 8.3)
```

### Interfaces / インターフェース

```scheme
(interface Loggable
  (method (public) log ((param msg))))

(interface Cacheable #:extends (Serializable)
  (method (public) cache ()))
```

### Traits / トレイト

```scheme
(trait Timestampable
  (property (protected) (var createdAt))
  (method (public) getCreatedAt ()
    (return (-> (var this) (access createdAt)))))

;; Using traits / トレイトの使用
(use-trait Bar)
(use-trait-with (TraitA TraitB)
  (insteadof (:: TraitA method) (TraitB))
  (as (:: TraitA method) public aliasName))
```

### Enums / 列挙型 (PHP 8.1)

```scheme
;; Basic enum / 基本列挙型
(enum Suit
  (enum-case Hearts)
  (enum-case Diamonds)
  (enum-case Clubs)
  (enum-case Spades))

;; Backed enum / バック型付き列挙型
(enum Color #:type string
  (enum-case Red "'red'")
  (enum-case Green "'green'"))

;; Enum with interface / インターフェース実装
(enum Suit #:implements (HasColor)
  (enum-case Hearts)
  (method (public) color ()
    (return "'red'")))
```

### Attributes / アトリビュート (PHP 8.0)

```scheme
(attribute Override)                    ; → #[Override]
(attribute Route "'/api/users'" "'GET'")  ; → #[Route('/api/users', 'GET')]
```

### Namespaces & Use / 名前空間

```scheme
(namespace (ns App Models))             ; → namespace App\Models;
(use (ns App Models User))              ; → use App\Models\User;
(use (as (ns App Models User) U))       ; → use App\Models\User as U;
(use-function (ns App Helpers helper))  ; → use function App\Helpers\helper;
(use-const (ns App Config VERSION))     ; → use const App\Config\VERSION;
(ns App Models User)                    ; → App\Models\User  (expression)
(ns-global App Models User)             ; → \App\Models\User
```

### Other / その他

```scheme
(echo "'hello'" (var x))     ; → echo 'hello', $x;
(print "'hello'")            ; → print 'hello';
(exit 1)                     ; → exit(1);
(const VERSION "'1.0'")      ; → const VERSION = '1.0';
(include "'file.php'")       ; → include 'file.php';
(require-once "'config.php'")  ; → require_once 'config.php';
(isset (var x) (var y))      ; → isset($x, $y);
(empty (var arr))            ; → empty($arr);
(global (var db) (var config))  ; → global $db, $config;
(unset (var x))              ; → unset($x);
(eval "'echo 1;'")           ; → eval('echo 1;');
(@ (call func))              ; → @func();
(declare ((strict_types 1)) (block ...))  ; → declare(strict_types = 1) { ... }
(yield (var val))            ; → yield $val;
(yield "'key'" "'val'")      ; → yield 'key' => 'val';
(yield-from (var gen))       ; → yield from $gen;
(heredoc EOT "content" EOT)  ; → <<<EOT\ncontent\nEOT
(nowdoc EOT "content" EOT)   ; → <<<'EOT'\ncontent\nEOT
```

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
