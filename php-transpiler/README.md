# php-transpiler

S-expression (S式) から PHP コードへ変換するトランスパイラ。Racket で実装。

## インストール

```sh
cd php-transpiler
raco pkg install
```

## 使い方

### Racket から

```racket
(require php-transpiler)

(sexp->php
 '(program
   (namespace (ns App Models))
   (use (ns App Database Model))

   (class User #:extends Model
     (property (protected) (var "$table") "'users'")
     (method (public) getName ()
       (return (-> (var "$this") (access name)))))))
```

出力:

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

### ファイルから

```racket
(require php-transpiler)

;; .sexp ファイルを読み込んで PHP 文字列に変換
(sexp-file->php "example.sexp")
```

### ポートへ直接出力

```racket
(require php-transpiler)

(emit '(program (echo "'Hello, world!'")) (current-output-port))
```

## S式リファレンス

### プログラム構造

```racket
(program stmt ...)           ; <?php で始まるプログラム全体
```

### リテラル

| S式 | PHP |
|-----|-----|
| `42` | `42` |
| `3.14` | `3.14` |
| `"'hello'"` | `'hello'` |
| `"\"hello\""` | `"hello"` |
| `true` | `true` |
| `false` | `false` |
| `null` | `null` |
| `__LINE__` | `__LINE__` |
| `__FILE__` | `__FILE__` |
| `__DIR__` | `__DIR__` |
| `__CLASS__` | `__CLASS__` |
| `__FUNCTION__` | `__FUNCTION__` |
| `__METHOD__` | `__METHOD__` |
| `__NAMESPACE__` | `__NAMESPACE__` |

文字列は `'` または `"` で始まる場合はそのまま出力される。それ以外は自動的にシングルクォートで囲まれる。

### 変数

| S式 | PHP |
|-----|-----|
| `(var "$x")` | `$x` |
| `(& (var "$x"))` | `&$x` |
| `(array-access (var "$a") 0)` | `$a[0]` |
| `(array-access (var "$a") #f)` | `$a[]` |
| `(brace-access (var "$s") 0)` | `$s{0}` |
| `(indirect (var "$x") 1)` | `$$x` |
| `(brace-var (var "$key"))` | `${$key}` |

### 演算子

#### 二項演算子

```racket
(binary op left right)
```

| `op` | PHP |
|------|-----|
| `+` `-` `*` `/` `%` | `+` `-` `*` `/` `%` |
| `pow` | `**` |
| `concat` | `.` |
| `&` `bw-or` `^` `shl` `shr` | `&` `\|` `^` `<<` `>>` |
| `&&` `or-short` | `&&` `\|\|` |
| `and` `or` `xor` | `and` `or` `xor` |
| `==` `!=` `===` `!==` | `==` `!=` `===` `!==` |
| `<` `<=` `>` `>=` | `<` `<=` `>` `>=` |
| `spaceship` | `<=>` |

Racket のリーダーで `.` `**` `||` `|` `<<` `>>` `<=>` がシンボルとして使えないため、それぞれ `concat` `pow` `or-short` `bw-or` `shl` `shr` `spaceship` を使う。

#### 単項演算子

```racket
(unary op expr)  ; op: + - ! ~
```

#### インクリメント / デクリメント

```racket
(pre-inc (var "$i"))   ; ++$i
(pre-dec (var "$i"))   ; --$i
(post-inc (var "$i"))  ; $i++
(post-dec (var "$i"))  ; $i--
```

#### 代入

```racket
(assign op left right)
```

| `op` | PHP |
|------|-----|
| `=` `+=` `-=` `*=` `/=` `%=` | `=` `+=` `-=` `*=` `/=` `%=` |
| `pow=` | `**=` |
| `concat=` | `.=` |
| `&=` `bw-or=` `^=` `<<=` `>>=` | `&=` `\|=` `^=` `<<=` `>>=` |

#### キャスト

```racket
(cast type expr)  ; type: int float string array object bool binary unset
```

#### 三項演算子 / Null 合体

```racket
(ternary test then else)     ; $test ? $then : $else
(ternary test #f else)       ; $test ?: $else
(coalesce left right)        ; $left ?? $right
```

### オブジェクト / スタティックアクセス

```racket
;; $obj->name
(-> (var "$obj") (access name))

;; $obj->method(1, 2)
(-> (var "$obj") (access method) (call-chain 1 2))

;; $obj->items[0]->name
(-> (var "$obj") (access items) (index 0) (access name))

;; MyClass::CONST
(:: MyClass CONST)

;; MyClass::method()
(call (:: MyClass method))
```

チェーン内の要素:

| S式 | 意味 |
|-----|------|
| `(access name)` | プロパティ/メソッド名 (-> が前置される) |
| `(call-chain args ...)` | メソッド呼び出しの引数 (直前の access に続く) |
| `(index expr)` | 配列インデックス `[expr]` |
| `(brace expr)` | ブレースアクセス `{expr}` |

### 関数呼び出し / new / clone

```racket
(call strlen "'hello'")                  ; strlen('hello')
(call array_merge (var "$a") (splat (var "$b")))  ; array_merge($a, ...$b)
(new DateTime "'2024-01-01'")            ; new DateTime('2024-01-01')
(new DateTime)                           ; new DateTime
(clone (var "$obj"))                     ; clone $obj
(instanceof (var "$obj") Exception)      ; $obj instanceof Exception
```

### 配列

```racket
(array 1 2 3)                           ; array(1, 2, 3)
(short-array (=> "'a'" 1) (=> "'b'" 2)) ; ['a' => 1, 'b' => 2]
(php-list (var "$a") (var "$b"))         ; list($a, $b)
```

### 文

```racket
(expr-stmt expr)             ; expr;
(echo expr ...)              ; echo expr, ...;
(return expr)                ; return expr;
(return)                     ; return;
(break)                      ; break;
(continue)                   ; continue;
(throw expr)                 ; throw expr;
(global (var "$a") ...)      ; global $a, ...;
(unset (var "$a") ...)       ; unset($a, ...);
(goto label)                 ; goto label;
(label name)                 ; name:
empty-stmt                   ; ;
```

### ブロック

```racket
(block stmt ...)             ; { stmt; ... }
```

### 制御構造

```racket
;; if
(if test (block then ...))
(if test (block then ...) (block else ...))
(if test (block then ...)
         (elseif (cond1 (block body1 ...))
                 (cond2 (block body2 ...)))
         (block else ...))

;; while / do-while
(while test (block body ...))
(do-while test (block body ...))

;; for
(for (init-exprs ...) (test-exprs ...) (step-exprs ...) (block body ...))

;; foreach
(foreach expr (var "$v") (block body ...))
(foreach expr (var "$k") (var "$v") (block body ...))

;; switch
(switch test
  (case 1 stmt ...)
  (case "'a'" stmt ...)
  (default stmt ...))

;; try / catch / finally
(try (block body ...)
  (catch ExceptionClass "$e" stmt ...)
  (catch (Type1 Type2) "$e" stmt ...)  ; multi-catch
  (finally stmt ...))
```

### 関数宣言

```racket
;; 基本
(function name (params ...) body ...)

;; 戻り値型
(function name (params ...) #:return-type type body ...)

;; 参照返し
(function& name (params ...) body ...)
```

#### パラメータ

| S式 | PHP |
|-----|-----|
| `(param "$x")` | `$x` |
| `(param "$x" 0)` | `$x = 0` |
| `(param/type int "$x")` | `int $x` |
| `(param/type int "$x" 0)` | `int $x = 0` |
| `(param/type (? string) "$s")` | `?string $s` |
| `(param& "$x")` | `&$x` |
| `(param-rest "$args")` | `...$args` |
| `(param-rest-type int "$nums")` | `int ...$nums` |

### ラムダ / クロージャ

```racket
;; 基本
(lambda (params ...) body ...)

;; use 句付き
(lambda (params ...) (use (var "$x") (var "$y")) body ...)

;; static
(static-lambda (params ...) body ...)
```

### クラス

```racket
;; 基本
(class Name body ...)

;; extends / implements
(class Name #:extends Parent #:implements (Interface1 Interface2) body ...)

;; abstract / final
(abstract-class Name body ...)
(final-class Name body ...)
```

#### クラスメンバ

```racket
;; プロパティ
(property (public) (var "$name"))
(property (protected static) (var "$count") 0)  ; デフォルト値付き

;; メソッド
(method (public) name (params ...) body ...)
(method (abstract public) name (params ...))     ; 抽象メソッド (body なし)
(method/rt (public) name (params ...) return-type body ...)
(method& (public) name (params ...) body ...)    ; 参照返し

;; 定数
(class-const NAME value)
(class-const private NAME value)                 ; アクセス修飾子付き

;; トレイト使用
(use-trait TraitName)
(use-trait Trait1 Trait2)
```

### インターフェース

```racket
(interface Name
  (method (public) doSomething ((param "$x"))))

(interface Name #:extends (ParentInterface)
  body ...)
```

### トレイト

```racket
(trait Name
  (property (protected) (var "$value"))
  (method (public) getValue ()
    (return (-> (var "$this") (access value)))))
```

### 名前空間 / use 文

```racket
(namespace (ns App Models))              ; namespace App\Models;
(namespace (ns App) body ...)            ; namespace App { ... }

(use (ns App Models User))              ; use App\Models\User;
(use (as (ns App Models User) U))       ; use App\Models\User as U;
(use-function (ns App Helpers helper))  ; use function App\Helpers\helper;
(use-const (ns App Config VERSION))     ; use const App\Config\VERSION;

;; 絶対パス
(ns-global App Models User)             ; \App\Models\User
```

### その他の式

```racket
(print expr)                 ; print expr
(exit)                       ; exit
(exit expr)                  ; exit(expr)
(eval expr)                  ; eval(expr)
(isset (var "$x") ...)       ; isset($x, ...)
(empty (var "$x"))           ; empty($x)
(include expr)               ; include expr
(include-once expr)          ; include_once expr
(require expr)               ; require expr
(require-once expr)          ; require_once expr
(@ expr)                     ; @expr (エラー抑制)
(yield expr)                 ; yield expr
(yield key val)              ; yield key => val
(yield-from expr)            ; yield from expr
(paren expr)                 ; (expr) 明示的な括弧
(splat expr)                 ; ...expr (引数アンパック)
```

### 定数

```racket
(const NAME value)           ; const NAME = value;
```

## 公開 API

| 関数 | 説明 |
|------|------|
| `(sexp->php sexp)` | S式を PHP 文字列に変換 |
| `(sexp-file->php path)` | `.sexp` ファイルを読み込んで PHP 文字列に変換 |
| `(emit sexp [port])` | S式を指定ポートに PHP として出力 |
| `(emit-to-string sexp)` | S式を PHP 文字列に変換 (`sexp->php` と同等) |

## テスト

```sh
racket php-transpiler/test-emit.rkt
```

## 完全な例

```racket
(sexp->php
 '(program
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
              (call compact "'users'"))))

     (method (public) show ((param/type int "$id"))
       (expr-stmt
        (assign = (var "$user")
                (call (:: User findOrFail) (var "$id"))))
       (return
        (call view "'users.show'"
              (call compact "'user'")))))))
```

出力:

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


