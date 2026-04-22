#lang racket

(require rackunit
         "emit.rkt")

(define (php sexp)
  (emit-to-string sexp))

;; ============================================================
;; Literals
;; ============================================================

(check-equal? (php '(program (echo 1))) "<?php\necho 1;\n")
(check-equal? (php '(program (echo "'hello'"))) "<?php\necho 'hello';\n")
(check-equal? (php '(program (echo true false null))) "<?php\necho true, false, null;\n")

;; ============================================================
;; Variables & Assignment
;; ============================================================

(check-equal? (php '(program (expr-stmt (assign = (var "$x") 42))))
              "<?php\n$x = 42;\n")

(check-equal? (php '(program (expr-stmt (assign += (var "$x") 1))))
              "<?php\n$x += 1;\n")

(check-equal? (php '(program (expr-stmt (assign concat= (var "$s") "'world'"))))
              "<?php\n$s .= 'world';\n")

;; ============================================================
;; Binary / Unary / Infix / Postfix
;; ============================================================

(check-equal? (php '(program (expr-stmt (binary + 1 2))))
              "<?php\n1 + 2;\n")

(check-equal? (php '(program (expr-stmt (binary concat (var "$a") "'b'"))))
              "<?php\n$a . 'b';\n")

(check-equal? (php '(program (expr-stmt (binary pow 2 10))))
              "<?php\n2 ** 10;\n")

(check-equal? (php '(program (expr-stmt (unary ! (var "$x")))))
              "<?php\n!$x;\n")

(check-equal? (php '(program (expr-stmt (pre-inc (var "$i")))))
              "<?php\n++$i;\n")

(check-equal? (php '(program (expr-stmt (post-dec (var "$i")))))
              "<?php\n$i--;\n")

;; ============================================================
;; Cast
;; ============================================================

(check-equal? (php '(program (expr-stmt (cast int (var "$x")))))
              "<?php\n(int)$x;\n")

(check-equal? (php '(program (expr-stmt (cast string (var "$x")))))
              "<?php\n(string)$x;\n")

;; ============================================================
;; Ternary / Coalesce
;; ============================================================

(check-equal? (php '(program (expr-stmt (ternary (var "$a") (var "$b") (var "$c")))))
              "<?php\n$a ? $b : $c;\n")

(check-equal? (php '(program (expr-stmt (ternary (var "$a") #f (var "$c")))))
              "<?php\n$a ?: $c;\n")

(check-equal? (php '(program (expr-stmt (coalesce (var "$a") (var "$b")))))
              "<?php\n$a ?? $b;\n")

;; ============================================================
;; Array access
;; ============================================================

(check-equal? (php '(program (expr-stmt (array-access (var "$arr") 0))))
              "<?php\n$arr[0];\n")

(check-equal? (php '(program (expr-stmt (array-access (var "$arr") #f))))
              "<?php\n$arr[];\n")

;; ============================================================
;; Object chain
;; ============================================================

(check-equal? (php '(program (expr-stmt (-> (var "$obj") (access prop)))))
              "<?php\n$obj->prop;\n")

(check-equal? (php '(program (expr-stmt (-> (var "$obj") (access method) (call-chain 1 2)))))
              "<?php\n$obj->method(1, 2);\n")

;; ============================================================
;; Static access
;; ============================================================

(check-equal? (php '(program (expr-stmt (:: MyClass CONST_VAL))))
              "<?php\nMyClass::CONST_VAL;\n")

;; ============================================================
;; Function call
;; ============================================================

(check-equal? (php '(program (expr-stmt (call strlen "'hello'"))))
              "<?php\nstrlen('hello');\n")

(check-equal? (php '(program (expr-stmt (call array_merge (var "$a") (splat (var "$b"))))))
              "<?php\narray_merge($a, ...$b);\n")

;; ============================================================
;; New
;; ============================================================

(check-equal? (php '(program (expr-stmt (new DateTime))))
              "<?php\nnew DateTime;\n")

(check-equal? (php '(program (expr-stmt (new DateTime "'2024-01-01'"))))
              "<?php\nnew DateTime('2024-01-01');\n")

;; ============================================================
;; Array / Short Array
;; ============================================================

(check-equal? (php '(program (expr-stmt (array 1 2 3))))
              "<?php\narray(1, 2, 3);\n")

(check-equal? (php '(program (expr-stmt (short-array (=> "'a'" 1) (=> "'b'" 2)))))
              "<?php\n['a' => 1, 'b' => 2];\n")

;; ============================================================
;; Instanceof
;; ============================================================

(check-equal? (php '(program (expr-stmt (instanceof (var "$obj") Exception))))
              "<?php\n$obj instanceof Exception;\n")

;; ============================================================
;; If / Elseif / Else
;; ============================================================

(check-equal? (php '(program (if (var "$x") (block (return 1)))))
              "<?php\nif ($x) {\nreturn 1;\n}\n")

(check-equal? (php '(program (if (var "$x")
                                 (block (return 1))
                                 (block (return 2)))))
              "<?php\nif ($x) {\nreturn 1;\n}\n else {\nreturn 2;\n}\n")

(check-equal? (php '(program (if (var "$x")
                                 (block (return 1))
                                 (elseif ((var "$y") (block (return 2))))
                                 (block (return 3)))))
              "<?php\nif ($x) {\nreturn 1;\n}\n elseif ($y) {\nreturn 2;\n}\n else {\nreturn 3;\n}\n")

;; ============================================================
;; While / Do-while
;; ============================================================

(check-equal? (php '(program (while true (block (break)))))
              "<?php\nwhile (true) {\nbreak;\n}\n")

(check-equal? (php '(program (do-while (var "$x") (block (expr-stmt (post-dec (var "$x")))))))
              "<?php\ndo {\n$x--;\n}\n while ($x);\n")

;; ============================================================
;; For / Foreach
;; ============================================================

(check-equal? (php '(program (for ((assign = (var "$i") 0))
                                  ((binary < (var "$i") 10))
                                  ((post-inc (var "$i")))
                                  (block (echo (var "$i"))))))
              "<?php\nfor ($i = 0; $i < 10; $i++) {\necho $i;\n}\n")

(check-equal? (php '(program (foreach (var "$arr") (var "$v") (block (echo (var "$v"))))))
              "<?php\nforeach ($arr as $v) {\necho $v;\n}\n")

(check-equal? (php '(program (foreach (var "$arr") (var "$k") (var "$v") (block (echo (var "$k"))))))
              "<?php\nforeach ($arr as $k => $v) {\necho $k;\n}\n")

;; ============================================================
;; Switch
;; ============================================================

(check-equal? (php '(program (switch (var "$x")
                               (case 1 (echo "'one'") (break))
                               (default (echo "'other'")))))
              "<?php\nswitch ($x) {\ncase 1:\necho 'one';\nbreak;\ndefault:\necho 'other';\n}\n")

;; ============================================================
;; Try / Catch / Finally
;; ============================================================

(check-equal? (php '(program (try (block (echo 1))
                                  (catch Exception "$e" (echo (var "$e")))
                                  (finally (echo "'done'")))))
              "<?php\ntry {\necho 1;\n}\n catch (Exception $e) {\necho $e;\n}\n finally {\necho 'done';\n}\n")

;; ============================================================
;; Function declaration
;; ============================================================

(check-equal? (php '(program (function add ((param "$a") (param "$b"))
                               (return (binary + (var "$a") (var "$b"))))))
              "<?php\nfunction add($a, $b) {\nreturn $a + $b;\n}\n")

(check-equal? (php '(program (function greet ((param/type string "$name")) #:return-type string
                               (return (binary concat "'Hello, '" (var "$name"))))))
              "<?php\nfunction greet(string $name): string {\nreturn 'Hello, ' . $name;\n}\n")

;; ============================================================
;; Lambda / Closure
;; ============================================================

(check-equal? (php '(program (expr-stmt (assign = (var "$f")
                               (lambda ((param "$x"))
                                 (return (binary * (var "$x") 2)))))))
              "<?php\n$f = function($x) {\nreturn $x * 2;\n};\n")

(check-equal? (php '(program (expr-stmt (assign = (var "$f")
                               (lambda ((param "$x"))
                                 (use (var "$y"))
                                 (return (binary + (var "$x") (var "$y"))))))))
              "<?php\n$f = function($x) use ($y) {\nreturn $x + $y;\n};\n")

;; ============================================================
;; Class
;; ============================================================

(check-equal? (php '(program (class Dog #:extends Animal #:implements (Runnable)
                               (property (public) (var "$name"))
                               (method (public) __construct ((param "$name"))
                                 (expr-stmt (assign = (-> (var "$this") (access name)) (var "$name"))))
                               (method (public) bark ()
                                 (return "'Woof!'")))))
              (string-append
               "<?php\n"
               "class Dog extends Animal implements Runnable {\n"
               "public $name;\n"
               "public function __construct($name) {\n"
               "$this->name = $name;\n"
               "}\n"
               "public function bark() {\n"
               "return 'Woof!';\n"
               "}\n"
               "}\n"))

;; ============================================================
;; Interface
;; ============================================================

(check-equal? (php '(program (interface Loggable
                               (method (public) log ((param "$msg"))))))
              "<?php\ninterface Loggable {\npublic function log($msg);\n}\n")

;; ============================================================
;; Trait
;; ============================================================

(check-equal? (php '(program (trait Timestampable
                               (property (protected) (var "$createdAt"))
                               (method (public) getCreatedAt ()
                                 (return (-> (var "$this") (access createdAt)))))))
              (string-append
               "<?php\n"
               "trait Timestampable {\n"
               "protected $createdAt;\n"
               "public function getCreatedAt() {\n"
               "return $this->createdAt;\n"
               "}\n"
               "}\n"))

;; ============================================================
;; Namespace / Use
;; ============================================================

(check-equal? (php '(program (namespace (ns App Models))))
              "<?php\nnamespace App\\Models;\n")

(check-equal? (php '(program (use (ns App Models User))))
              "<?php\nuse App\\Models\\User;\n")

(check-equal? (php '(program (use (as (ns App Models User) U))))
              "<?php\nuse App\\Models\\User as U;\n")

;; ============================================================
;; Const
;; ============================================================

(check-equal? (php '(program (const VERSION "'1.0'")))
              "<?php\nconst VERSION = '1.0';\n")

;; ============================================================
;; Class const
;; ============================================================

(check-equal? (php '(program (class Foo
                               (class-const MAX 100)
                               (class-const private SECRET "'shhh'"))))
              "<?php\nclass Foo {\nconst MAX = 100;\nprivate const SECRET = 'shhh';\n}\n")

;; ============================================================
;; Include / Require
;; ============================================================

(check-equal? (php '(program (expr-stmt (require "'config.php'"))))
              "<?php\nrequire 'config.php';\n")

(check-equal? (php '(program (expr-stmt (include-once "'helpers.php'"))))
              "<?php\ninclude_once 'helpers.php';\n")

;; ============================================================
;; Isset / Empty
;; ============================================================

(check-equal? (php '(program (expr-stmt (isset (var "$x") (var "$y")))))
              "<?php\nisset($x, $y);\n")

(check-equal? (php '(program (expr-stmt (empty (var "$arr")))))
              "<?php\nempty($arr);\n")

;; ============================================================
;; Global / Static / Unset
;; ============================================================

(check-equal? (php '(program (global (var "$db") (var "$config"))))
              "<?php\nglobal $db, $config;\n")

(check-equal? (php '(program (unset (var "$x"))))
              "<?php\nunset($x);\n")

;; ============================================================
;; Yield
;; ============================================================

(check-equal? (php '(program (expr-stmt (yield (var "$val")))))
              "<?php\nyield $val;\n")

(check-equal? (php '(program (expr-stmt (yield "'key'" "'val'"))))
              "<?php\nyield 'key' => 'val';\n")

;; ============================================================
;; Print / Exit / Clone
;; ============================================================

(check-equal? (php '(program (expr-stmt (print "'hello'"))))
              "<?php\nprint 'hello';\n")

(check-equal? (php '(program (expr-stmt (exit 1))))
              "<?php\nexit(1);\n")

(check-equal? (php '(program (expr-stmt (clone (var "$obj")))))
              "<?php\nclone $obj;\n")

;; ============================================================
;; Error suppression
;; ============================================================

(check-equal? (php '(program (expr-stmt (@ (call file_get_contents "'f.txt'")))))
              "<?php\n@file_get_contents('f.txt');\n")

;; ============================================================
;; Eval
;; ============================================================

(check-equal? (php '(program (expr-stmt (eval "'echo 1;'"))))
              "<?php\neval('echo 1;');\n")

;; ============================================================
;; Goto / Label
;; ============================================================

(check-equal? (php '(program (goto end) (label end) (echo "'done'")))
              "<?php\ngoto end;\nend:\necho 'done';\n")

;; ============================================================
;; Abstract / Final class
;; ============================================================

(check-equal? (php '(program (abstract-class Base
                               (method (abstract public) render ()))))
              "<?php\nabstract class Base {\nabstract public function render();\n}\n")

(check-equal? (php '(program (final-class Singleton)))
              "<?php\nfinal class Singleton {\n}\n")

;; ============================================================
;; Use trait in class
;; ============================================================

(check-equal? (php '(program (class Foo (use-trait Bar))))
              "<?php\nclass Foo {\nuse Bar;\n}\n")

;; ============================================================
;; Variadic parameter
;; ============================================================

(check-equal? (php '(program (function sum ((param-rest "$nums"))
                               (return (call array_sum (var "$nums"))))))
              "<?php\nfunction sum(...$nums) {\nreturn array_sum($nums);\n}\n")

;; ============================================================
;; Typed variadic
;; ============================================================

(check-equal? (php '(program (function sum ((param-rest-type int "$nums"))
                               (return (call array_sum (var "$nums"))))))
              "<?php\nfunction sum(int ...$nums) {\nreturn array_sum($nums);\n}\n")

;; ============================================================
;; Reference parameter
;; ============================================================

(check-equal? (php '(program (function inc ((param& "$x"))
                               (expr-stmt (pre-inc (var "$x"))))))
              "<?php\nfunction inc(&$x) {\n++$x;\n}\n")

;; ============================================================
;; Nullable type hint
;; ============================================================

(check-equal? (php '(program (function test ((param/type (? string) "$s"))
                               (return (var "$s")))))
              "<?php\nfunction test(?string $s) {\nreturn $s;\n}\n")

(displayln "All tests passed!")
