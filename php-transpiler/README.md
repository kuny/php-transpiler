# php-transpiler

S-expression (S式) から PHP コードへ変換するトランスパイラ。Racket で実装。

A transpiler that converts S-expressions to PHP code. Implemented in Racket.

## インストール / Installation

```sh
cd php-transpiler
raco pkg install
```

## 使い方 / Usage

### Racket から / From Racket

```racket
(require php-transpiler)

(sexp->php
 '(program
   (namespace (ns App Models))
   (use (ns App Database Model))

   (class User #:extends Model
     (property (protected) ((var table) "users"))
     (method (public) getName ()
       (return (-> (var this) (access name)))))))
```

出力 / Output:

```php
<?php
namespace App\Models;
use App\Database\Model;
class User extends Model {
protected $table = 'users';
public function getName() {
return $this->name;
}
}
```

### ファイルから / From a File

```racket
(require php-transpiler)

;; .sexp ファイルを読み込んで PHP 文字列に変換
;; Load a .sexp file and convert it to a PHP string
(sexp-file->php "example.sexp")
```

### ポートへ直接出力 / Direct Output to a Port

```racket
(require php-transpiler)

(emit '(program (echo "Hello, world!")) (current-output-port))
```

## S式リファレンス / S-expression Reference

### プログラム構造 / Program Structure

```racket
(program stmt ...)           ; <?php で始まるプログラム全体 / Entire program starting with <?php
```

### リテラル / Literals

```racket
42                       ; → 42
3.14                     ; → 3.14
"'hello'"                ; → 'hello'  (クォート付き文字列はそのまま出力 / quote-wrapped strings are emitted as-is)
"hello"                  ; → 'hello'  (自動的にシングルクォートで囲まれる / bare strings get single-quoted)
true                     ; → true
false                    ; → false
null                     ; → null
```

マジック定数 / Magic constants: `__CLASS__`, `__TRAIT__`, `__METHOD__`, `__FUNCTION__`, `__LINE__`, `__FILE__`, `__DIR__`, `__NAMESPACE__`

### 変数 / Variables

```racket
(var x)                  ; → $x
(var "$x")               ; → $x  ($ は自動付与 / $ prefix is auto-added if missing)
(& (var x))              ; → &$x
(array-access (var arr) 0)  ; → $arr[0]
(array-access (var arr) #f) ; → $arr[]
(indirect (var x) 1)     ; → $$x
(brace-var (var key))    ; → ${$key}
```

### 演算子 / Operators

**二項演算子 / Binary:**

```racket
(binary + 1 2)           ; → 1 + 2
(binary concat (var a) "'b'")  ; → $a . 'b'
(binary pow 2 10)        ; → 2 ** 10
(binary spaceship (var a) (var b))  ; → $a <=> $b
```

対応: `+` `-` `*` `/` `%` `pow` `concat` `&` `bw-or` `^` `shl` `shr` `&&` `or-short` `and` `or` `xor` `==` `!=` `===` `!==` `<` `<=` `>` `>=` `spaceship`

**単項演算子 / Unary:**

```racket
(unary ! (var x))        ; → !$x
(pre-inc (var i))        ; → ++$i
(post-dec (var i))       ; → $i--
```

**代入演算子 / Assignment:**

```racket
(assign = (var x) 42)    ; → $x = 42
(assign += (var x) 1)    ; → $x += 1
(assign concat= (var s) "'w'")  ; → $s .= 'w'
(assign coalesce= (var x) "'default'")  ; → $x ??= 'default'  (PHP 8.0)
```

対応: `=` `+=` `-=` `*=` `/=` `%=` `pow=` `concat=` `&=` `bw-or=` `^=` `<<=` `>>=` `coalesce=`

**キャスト / Cast:**

```racket
(cast int (var x))       ; → (int)$x
(cast string (var x))    ; → (string)$x
```

対応: `int` `float` `string` `array` `object` `bool` `binary` `unset`

**三項演算子・Null合体演算子 / Ternary & Null coalescing:**

```racket
(ternary (var a) (var b) (var c))  ; → $a ? $b : $c
(ternary (var a) #f (var c))       ; → $a ?: $c
(coalesce (var a) (var b))         ; → $a ?? $b
```

### 配列 / Arrays

```racket
(array 1 2 3)            ; → array(1, 2, 3)
(short-array 1 2 3)      ; → [1, 2, 3]
(short-array (=> "'a'" 1) (=> "'b'" 2))  ; → ['a' => 1, 'b' => 2]
(php-list (var a) (var b))  ; → list($a, $b)
(splat (var arr))         ; → ...$arr
```

### オブジェクトアクセス / Object Access

```racket
(-> (var obj) (access prop))     ; → $obj->prop
(-> (var obj) (access method) (call-chain 1 2))  ; → $obj->method(1, 2)
(-> (var obj) (access items) (index 0) (access name))  ; → $obj->items[0]->name
(:: MyClass CONST)               ; → MyClass::CONST
(call (:: MyClass method))       ; → MyClass::method()
(new DateTime "'2024-01-01'")    ; → new DateTime('2024-01-01')
(clone (var obj))                ; → clone $obj
(instanceof (var obj) Exception) ; → $obj instanceof Exception
```

**Nullsafe 演算子 / Nullsafe operator (PHP 8.0):**

```racket
(?-> (var obj) (access address) (access city))  ; → $obj?->address?->city
```

### 関数呼び出し / Function Calls

```racket
(call strlen "'hello'")  ; → strlen('hello')
(call func (splat (var args)))  ; → func(...$args)
```

**名前付き引数 / Named arguments (PHP 8.0):**

```racket
(call array_slice (var arr) (named-arg offset 2) (named-arg length 3))
; → array_slice($arr, offset: 2, length: 3)
```

**第一級callableシンタックス / First-class callable syntax (PHP 8.1):**

```racket
(first-class-callable strlen)          ; → strlen(...)
(first-class-callable (:: Foo bar))    ; → Foo::bar(...)
```

### 制御構文 / Control Flow

**if / elseif / else:**

```racket
(if (var x) (block (return 1)))
(if (var x) (block (return 1)) (block (return 2)))
(if (var x) (block (return 1)) (elseif ((var y) (block (return 2)))) (block (return 3)))
```

**ループ / Loops:**

```racket
(while true (block (break)))
(do-while (var x) (block (expr-stmt (post-dec (var x)))))
(for ((assign = (var i) 0)) ((binary < (var i) 10)) ((post-inc (var i)))
  (block (echo (var i))))
(foreach (var arr) (var v) (block (echo (var v))))
(foreach (var arr) (var k) (var v) (block (echo (var k))))
```

**switch:**

```racket
(switch (var x)
  (case 1 (echo "'one'") (break))
  (default (echo "'other'")))
```

**match 式 / Match expression (PHP 8.0):**

```racket
(match (var status)
  (match-arm (200 300) "'ok'")
  (match-arm (404) "'not found'")
  (match-default "'error'"))
; → match($status) { 200, 300 => 'ok', 404 => 'not found', default => 'error', }
```

**try / catch / finally:**

```racket
(try (block (echo 1))
  (catch Exception "$e" (echo (var e)))
  (finally (echo "'done'")))

;; 複数例外キャッチ / Multi-catch
(try (block ...) (catch (TypeError ValueError) "$e" ...))

;; 変数なし catch / Catch without variable (PHP 8.0)
(try (block ...) (catch NotFoundException #f (echo "'handled'")))
```

**その他 / Other:**

```racket
(return (var x))         ; → return $x;
(return)                 ; → return;
(break)                  ; → break;
(continue)               ; → continue;
(throw (new Ex))         ; → throw new Ex;  (PHP 8.0 では式としても使用可 / also usable as expression in PHP 8.0)
(goto end)               ; → goto end;
(label end)              ; → end:
```

### 関数 / Functions

```racket
(function add ((param a) (param b))
  (return (binary + (var a) (var b))))
; → function add($a, $b) { return $a + $b; }

;; 戻り値型付き / With return type
(function greet ((param/type string name)) #:return-type string
  (return (binary concat "'Hello, '" (var name))))
; → function greet(string $name): string { return 'Hello, ' . $name; }

;; 参照返し / Reference return
(function& name ((param x)) ...)
```

**パラメータ / Parameters:**

```racket
(param x)                ; → $x
(param x 0)              ; → $x = 0
(param/type int x)       ; → int $x
(param/type int x 0)     ; → int $x = 0
(param/type (? string) s)  ; → ?string $s
(param& x)               ; → &$x
(param-rest args)         ; → ...$args
(param-rest-type int nums)  ; → int ...$nums
```

**コンストラクタプロパティ昇格 / Constructor property promotion (PHP 8.0):**

```racket
(param/promoted (private) string name)          ; → private string $name
(param/promoted (private readonly) string name)  ; → private readonly string $name
(param/promoted (protected) int age 0)          ; → protected int $age = 0
```

**ラムダ / クロージャ / Lambda / Closure:**

```racket
(lambda ((param x)) (return (binary * (var x) 2)))
; → function($x) { return $x * 2; }

(lambda ((param x)) (use (var y)) (return (binary + (var x) (var y))))
; → function($x) use ($y) { return $x + $y; }

(static-lambda ((param x)) ...)
; → static function($x) { ... }
```

**アロー関数 / Arrow function (PHP 7.4+):**

```racket
(arrow-fn ((param x)) (binary * (var x) 2))
; → fn($x) => $x * 2

(arrow-fn ((param/type int x)) #:return-type int (binary * (var x) 2))
; → fn(int $x): int => $x * 2

(static-arrow-fn ((param x)) (binary * (var x) 2))
; → static fn($x) => $x * 2
```

### 型ヒント / Type Hints

**基本型 / Basic types:** `int`, `float`, `string`, `bool`, `array`, `callable`, `void`, `self`, `iterable`, `object`, `parent`, `static`

**PHP 8.0+ の型:** `mixed`, `null`, `false`, `true`, `never`

**Null許容型 / Nullable:**

```racket
(? string)               ; → ?string
```

**ユニオン型 / Union types (PHP 8.0):**

```racket
(union int string)       ; → int|string
(union int false)        ; → int|false
```

**交差型 / Intersection types (PHP 8.1):**

```racket
(intersection Countable Iterator)  ; → Countable&Iterator
```

**DNF型 / DNF types (PHP 8.2):**

```racket
(union (intersection A B) null)  ; → (A&B)|null
```

### クラス / Classes

```racket
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

**プロパティ / Properties:**

```racket
(property (public) (var name))                    ; → public $name;
(property (public static) ((var count) 0))        ; → public static $count = 0;
(typed-property (public) string (var name))        ; → public string $name;
(typed-property (private) int ((var retries) 3))   ; → private int $retries = 3;
(typed-property (public readonly) string (var name))  ; → public readonly string $name;
```

**メソッド / Methods:**

```racket
(method (public) name ((param x)) (return (var x)))
(method/rt (public) name ((param x)) string (return (var x)))  ; 戻り値型付き / with return type
(method& (public) name ((param x)) ...)  ; 参照返し / reference return
```

**クラス定数 / Class constants:**

```racket
(class-const MAX 100)                    ; → const MAX = 100;
(class-const private SECRET "'shhh'")    ; → private const SECRET = 'shhh';
(typed-class-const string NAME "'foo'")  ; → const string NAME = 'foo';  (PHP 8.3)
(typed-class-const public int MAX 100)   ; → public const int MAX = 100;  (PHP 8.3)
```

### インターフェース / Interfaces

```racket
(interface Loggable
  (method (public) log ((param msg))))

(interface Cacheable #:extends (Serializable)
  (method (public) cache ()))
```

### トレイト / Traits

```racket
(trait Timestampable
  (property (protected) (var createdAt))
  (method (public) getCreatedAt ()
    (return (-> (var this) (access createdAt)))))

;; トレイトの使用 / Using traits
(use-trait Bar)
(use-trait-with (TraitA TraitB)
  (insteadof (:: TraitA method) (TraitB))
  (as (:: TraitA method) public aliasName))
```

### 列挙型 / Enums (PHP 8.1)

```racket
;; 基本列挙型 / Basic enum
(enum Suit
  (enum-case Hearts)
  (enum-case Diamonds)
  (enum-case Clubs)
  (enum-case Spades))

;; バック型付き列挙型 / Backed enum
(enum Color #:type string
  (enum-case Red "'red'")
  (enum-case Green "'green'"))

;; インターフェース実装 / Enum with interface
(enum Suit #:implements (HasColor)
  (enum-case Hearts)
  (method (public) color ()
    (return "'red'")))
```

### アトリビュート / Attributes (PHP 8.0)

```racket
(attribute Override)                    ; → #[Override]
(attribute Route "'/api/users'" "'GET'")  ; → #[Route('/api/users', 'GET')]
```

### 名前空間 / Namespaces & Use

```racket
(namespace (ns App Models))             ; → namespace App\Models;
(use (ns App Models User))              ; → use App\Models\User;
(use (as (ns App Models User) U))       ; → use App\Models\User as U;
(use-function (ns App Helpers helper))  ; → use function App\Helpers\helper;
(use-const (ns App Config VERSION))     ; → use const App\Config\VERSION;
(ns App Models User)                    ; → App\Models\User  (式として / expression)
(ns-global App Models User)             ; → \App\Models\User
```

### その他 / Other

```racket
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

## 公開 API / Public API

| 関数 / Function | 説明 / Description |
|------|------|
| `(sexp->php sexp)` | S式を PHP 文字列に変換 / Convert S-expression to PHP string |
| `(sexp-file->php path)` | `.sexp` ファイルを読み込んで PHP 文字列に変換 / Load a `.sexp` file and convert to PHP string |
| `(emit sexp [port])` | S式を指定ポートに PHP として出力 / Output S-expression as PHP to the specified port |
| `(emit-to-string sexp)` | S式を PHP 文字列に変換 (`sexp->php` と同等) / Convert S-expression to PHP string (equivalent to `sexp->php`) |

## テスト / Tests

```sh
racket php-transpiler/test-emit.rkt
```

## 完全な例 / Full Example

```racket
(sexp->php
 '(program
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
              (call compact "users"))))

     (method (public) show ((param/type int id))
       (expr-stmt
        (assign = (var user)
                (call (:: User findOrFail) (var id))))
       (return
        (call view "users.show"
              (call compact "user")))))))
```

出力 / Output:

```php
<?php
namespace App\Http\Controllers;
use App\Models\User;
use Illuminate\Http\Request;
class UserController extends Controller {
public function index(Request $request) {
$users = User::all();
return view('users.index', compact('users'));
}
public function show(int $id) {
$user = User::findOrFail($id);
return view('users.show', compact('user'));
}
}
```


