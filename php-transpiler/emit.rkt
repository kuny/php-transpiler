#lang racket

(provide emit
         emit-to-string)

(define (~a v) (format "~a" v))

(define (emit-to-string sexp)
  (define out (open-output-string))
  (emit sexp out)
  (get-output-string out))

(define (emit sexp [port (current-output-port)])
  (cond
    [(and (pair? sexp) (eq? (car sexp) 'program))
     (display "<?php\n" port)
     (for ([s (cdr sexp)]) (emit-stmt s port))]
    [else (emit-expr sexp port)]))

;; ============================================================
;; Statements - dispatched by tag
;; ============================================================

(define (emit-stmt sexp port)
  (if (not (pair? sexp))
      (cond
        [(eq? sexp 'empty-stmt) (display ";\n" port)]
        [else (emit-expr sexp port) (display ";\n" port)])
      (let ([tag (car sexp)] [args (cdr sexp)])
        (case tag
          [(expr-stmt) (emit-expr (car args) port) (display ";\n" port)]
          [(echo) (display "echo " port) (emit-comma-sep args port) (display ";\n" port)]
          [(return) (if (null? args)
                        (display "return;\n" port)
                        (begin (display "return " port) (emit-expr (car args) port) (display ";\n" port)))]
          [(break) (if (null? args)
                       (display "break;\n" port)
                       (begin (display "break " port) (emit-expr (car args) port) (display ";\n" port)))]
          [(continue) (if (null? args)
                          (display "continue;\n" port)
                          (begin (display "continue " port) (emit-expr (car args) port) (display ";\n" port)))]
          [(throw) (display "throw " port) (emit-expr (car args) port) (display ";\n" port)]
          [(if) (emit-if args port)]
          [(while) (display "while (" port) (emit-expr (car args) port)
                   (display ") " port) (emit-block-or-stmt (cadr args) port)]
          [(do-while) (display "do " port) (emit-block-or-stmt (cadr args) port)
                      (display " while (" port) (emit-expr (car args) port) (display ");\n" port)]
          [(for) (emit-for-loop args port)]
          [(foreach) (emit-foreach args port)]
          [(switch) (emit-switch args port)]
          [(try) (emit-try args port)]
          [(block) (emit-block sexp port)]
          [(global) (display "global " port) (emit-comma-sep args port) (display ";\n" port)]
          [(static-vars) (display "static " port) (emit-static-vars args port) (display ";\n" port)]
          [(unset) (display "unset(" port) (emit-comma-sep args port) (display ");\n" port)]
          [(goto) (fprintf port "goto ~a;\n" (car args))]
          [(label) (fprintf port "~a:\n" (car args))]
          [(declare) (display "declare(" port) (emit-declare-list (car args) port)
                     (display ") " port) (emit-block-or-stmt (cadr args) port)]
          [(namespace) (emit-namespace args port)]
          [(use) (display "use " port) (emit-use-decls args port) (display ";\n" port)]
          [(use-function) (display "use function " port) (emit-use-decls args port) (display ";\n" port)]
          [(use-const) (display "use const " port) (emit-use-decls args port) (display ";\n" port)]
          [(function) (emit-func-dcl #f args port)]
          [(function&) (emit-func-dcl #t args port)]
          [(class) (emit-class-dcl '() (car args) (cdr args) port)]
          [(abstract-class) (emit-class-dcl '(abstract) (car args) (cdr args) port)]
          [(final-class) (emit-class-dcl '(final) (car args) (cdr args) port)]
          [(interface) (emit-interface-dcl (car args) (cdr args) port)]
          [(trait) (display "trait " port) (display (car args) port) (display " {\n" port)
                   (for ([s (cdr args)]) (emit-class-member s port)) (display "}\n" port)]
          [(const) (display "const " port) (display (car args) port) (display " = " port)
                   (emit-expr (cadr args) port) (display ";\n" port)]
          [else (emit-expr sexp port) (display ";\n" port)]))))

;; ============================================================
;; Expressions - dispatched by tag
;; ============================================================

(define (emit-expr sexp port)
  (cond
    [(number? sexp) (display sexp port)]
    [(symbol? sexp) (emit-symbol sexp port)]
    [(string? sexp) (emit-string sexp port)]
    [(not (pair? sexp)) (error 'emit-expr "unknown: ~a" sexp)]
    [else
     (let ([tag (car sexp)] [args (cdr sexp)])
       (case tag
         [(var) (display (ensure-dollar (car args)) port)]
         [(&) (display "&" port) (emit-expr (car args) port)]
         [(array-access) (emit-expr (car args) port) (display "[" port)
                         (when (cadr args) (emit-expr (cadr args) port)) (display "]" port)]
         [(brace-access) (emit-expr (car args) port) (display "{" port)
                         (emit-expr (cadr args) port) (display "}" port)]
         [(->) (emit-chain args port)]
         [(::) (emit-expr (car args) port) (display "::" port) (emit-expr (cadr args) port)]
         [(binary) (emit-expr (cadr args) port) (display " " port)
                   (display (binary-op->php (car args)) port) (display " " port)
                   (emit-expr (caddr args) port)]
         [(unary) (display (unary-op->php (car args)) port) (emit-expr (cadr args) port)]
         [(pre-inc) (display "++" port) (emit-expr (car args) port)]
         [(pre-dec) (display "--" port) (emit-expr (car args) port)]
         [(post-inc) (emit-expr (car args) port) (display "++" port)]
         [(post-dec) (emit-expr (car args) port) (display "--" port)]
         [(assign) (emit-expr (cadr args) port) (display " " port)
                   (display (assign-op->php (car args)) port) (display " " port)
                   (emit-expr (caddr args) port)]
         [(cast) (fprintf port "(~a)" (cast-type->php (car args)))
                 (emit-expr (cadr args) port)]
         [(ternary) (emit-expr (car args) port)
                    (if (cadr args)
                        (begin (display " ? " port) (emit-expr (cadr args) port) (display " : " port))
                        (display " ?: " port))
                    (emit-expr (caddr args) port)]
         [(coalesce) (emit-expr (car args) port) (display " ?? " port) (emit-expr (cadr args) port)]
         [(instanceof) (emit-expr (car args) port) (display " instanceof " port) (emit-expr (cadr args) port)]
         [(call) (emit-expr (car args) port) (display "(" port) (emit-call-args (cdr args) port) (display ")" port)]
         [(new) (display "new " port) (emit-expr (car args) port)
                (unless (null? (cdr args))
                  (display "(" port) (emit-call-args (cdr args) port) (display ")" port))]
         [(clone) (display "clone " port) (emit-expr (car args) port)]
         [(array) (display "array(" port) (emit-array-items args port) (display ")" port)]
         [(short-array) (display "[" port) (emit-array-items args port) (display "]" port)]
         [(php-list) (display "list(" port) (emit-comma-sep args port) (display ")" port)]
         [(lambda) (emit-lambda-expr #f args port)]
         [(static-lambda) (emit-lambda-expr #t args port)]
         [(yield) (emit-yield args port)]
         [(yield-from) (display "yield from " port) (emit-expr (car args) port)]
         [(exit) (if (null? args) (display "exit" port)
                     (begin (display "exit(" port) (emit-expr (car args) port) (display ")" port)))]
         [(print) (display "print " port) (emit-expr (car args) port)]
         [(@) (display "@" port) (emit-expr (car args) port)]
         [(include) (display "include " port) (emit-expr (car args) port)]
         [(include-once) (display "include_once " port) (emit-expr (car args) port)]
         [(require) (display "require " port) (emit-expr (car args) port)]
         [(require-once) (display "require_once " port) (emit-expr (car args) port)]
         [(eval) (display "eval(" port) (emit-expr (car args) port) (display ")" port)]
         [(isset) (display "isset(" port) (emit-comma-sep args port) (display ")" port)]
         [(empty) (display "empty(" port) (emit-expr (car args) port) (display ")" port)]
         [(backtick) (display (car args) port)]
         [(indirect) (for ([_ (in-range (cadr args))]) (display "$" port)) (emit-expr (car args) port)]
         [(brace-var) (display "${" port) (emit-expr (car args) port) (display "}" port)]
         [(splat) (display "..." port) (emit-expr (car args) port)]
         [(ns) (display (string-join (map ~a args) "\\") port)]
         [(ns-global) (display "\\" port) (display (string-join (map ~a args) "\\") port)]
         [(paren) (display "(" port) (emit-expr (car args) port) (display ")" port)]
         [(heredoc) (fprintf port "<<<~a\n~a\n~a" (car args) (cadr args) (car args))]
         [(nowdoc) (fprintf port "<<<'~a'\n~a\n~a" (car args) (cadr args) (car args))]
         [(=>) (emit-expr (car args) port) (display " => " port) (emit-expr (cadr args) port)]
         [else (error 'emit-expr "unknown expression: ~a" sexp)]))]))

(define (emit-symbol s port)
  (case s
    [(true) (display "true" port)]
    [(false) (display "false" port)]
    [(null) (display "null" port)]
    [(__CLASS__) (display "__CLASS__" port)]
    [(__TRAIT__) (display "__TRAIT__" port)]
    [(__METHOD__) (display "__METHOD__" port)]
    [(__FUNCTION__) (display "__FUNCTION__" port)]
    [(__LINE__) (display "__LINE__" port)]
    [(__FILE__) (display "__FILE__" port)]
    [(__DIR__) (display "__DIR__" port)]
    [(__NAMESPACE__) (display "__NAMESPACE__" port)]
    [else (display s port)]))

(define (emit-string s port)
  (cond
    [(string-prefix? s "'") (display s port)]
    [(string-prefix? s "\"") (display s port)]
    [else (fprintf port "'~a'" (escape-single-quote s))]))

;; ============================================================
;; Statement helpers
;; ============================================================

(define (emit-if args port)
  (define test (car args))
  (define rest (cdr args))
  (display "if (" port)
  (emit-expr test port)
  (display ") " port)
  (cond
    ;; (if test then (elseif ...) else)
    [(and (= (length rest) 3)
          (pair? (cadr rest))
          (eq? (car (cadr rest)) 'elseif))
     (emit-block-or-stmt (car rest) port)
     (for ([ei (cdr (cadr rest))])
       (display " elseif (" port)
       (emit-expr (car ei) port)
       (display ") " port)
       (emit-block-or-stmt (cadr ei) port))
     (define else-part (caddr rest))
     (when (not (equal? else-part '()))
       (display " else " port)
       (emit-block-or-stmt else-part port))]
    ;; (if test then else)
    [(= (length rest) 2)
     (emit-block-or-stmt (car rest) port)
     (display " else " port)
     (emit-block-or-stmt (cadr rest) port)]
    ;; (if test then)
    [else
     (emit-block-or-stmt (car rest) port)]))

(define (emit-for-loop args port)
  (display "for (" port)
  (emit-for-exprs (car args) port)
  (display "; " port)
  (emit-for-exprs (cadr args) port)
  (display "; " port)
  (emit-for-exprs (caddr args) port)
  (display ") " port)
  (emit-block-or-stmt (cadddr args) port))

(define (emit-foreach args port)
  (display "foreach (" port)
  (emit-expr (car args) port)
  (display " as " port)
  (cond
    ;; (foreach expr key val body) - 4 args
    [(= (length args) 4)
     (emit-expr (cadr args) port)
     (display " => " port)
     (emit-expr (caddr args) port)
     (display ") " port)
     (emit-block-or-stmt (cadddr args) port)]
    ;; (foreach expr val body) - 3 args
    [else
     (emit-expr (cadr args) port)
     (display ") " port)
     (emit-block-or-stmt (caddr args) port)]))

(define (emit-switch args port)
  (display "switch (" port)
  (emit-expr (car args) port)
  (display ") {\n" port)
  (for ([c (cdr args)])
    (cond
      [(eq? (car c) 'case)
       (display "case " port)
       (emit-expr (cadr c) port)
       (display ":\n" port)
       (for ([s (cddr c)]) (emit-stmt s port))]
      [(eq? (car c) 'default)
       (display "default:\n" port)
       (for ([s (cdr c)]) (emit-stmt s port))]))
  (display "}\n" port))

(define (emit-try args port)
  (display "try " port)
  (emit-block (car args) port)
  (for ([c (cdr args)])
    (cond
      [(eq? (car c) 'catch)
       (display " catch (" port)
       (emit-catch-types (cadr c) port)
       (display " " port)
       (display (caddr c) port)
       (display ") " port)
       (emit-block (cons 'block (cdddr c)) port)]
      [(eq? (car c) 'finally)
       (display " finally " port)
       (emit-block (cons 'block (cdr c)) port)])))

(define (emit-namespace args port)
  (display "namespace " port)
  (emit-namespace-name (car args) port)
  (if (null? (cdr args))
      (display ";\n" port)
      (begin
        (display " {\n" port)
        (for ([s (cdr args)]) (emit-stmt s port))
        (display "}\n" port))))

(define (emit-func-dcl ref? args port)
  (define name (car args))
  (define params (cadr args))
  (define rest (cddr args))
  (define-values (rtype body) (parse-return-type rest))
  (display "function " port)
  (when ref? (display "&" port))
  (display name port)
  (emit-params params port)
  (when rtype (display ": " port) (emit-type-hint rtype port))
  (display " {\n" port)
  (for ([s body]) (emit-stmt s port))
  (display "}\n" port))

;; ============================================================
;; Expression helpers
;; ============================================================

(define (emit-chain args port)
  (for ([p args] [i (in-naturals)])
    (when (and (> i 0) (needs-arrow? p))
      (display "->" port))
    (emit-chain-part p port)))

(define (needs-arrow? p)
  (and (pair? p)
       (not (memq (car p) '(call-chain index brace)))))

(define (emit-chain-part p port)
  (cond
    [(and (pair? p) (eq? (car p) 'access)) (display (cadr p) port)]
    [(and (pair? p) (eq? (car p) 'call-chain))
     (display "(" port) (emit-call-args (cdr p) port) (display ")" port)]
    [(and (pair? p) (eq? (car p) 'index))
     (display "[" port) (when (cadr p) (emit-expr (cadr p) port)) (display "]" port)]
    [(and (pair? p) (eq? (car p) 'brace))
     (display "{" port) (emit-expr (cadr p) port) (display "}" port)]
    [else (emit-expr p port)]))

(define (emit-yield args port)
  (cond
    [(null? args) (display "yield" port)]
    [(= (length args) 1) (display "yield " port) (emit-expr (car args) port)]
    [else (display "yield " port) (emit-expr (car args) port)
          (display " => " port) (emit-expr (cadr args) port)]))

(define (emit-lambda-expr static? args port)
  (define params (car args))
  (define rest (cdr args))
  (define lexicals '())
  (when (and (pair? rest) (pair? (car rest)) (eq? (caar rest) 'use))
    (set! lexicals (cdar rest))
    (set! rest (cdr rest)))
  (when static? (display "static " port))
  (display "function" port)
  (emit-params params port)
  (when (not (null? lexicals))
    (display " use (" port)
    (for ([l lexicals] [i (in-naturals)])
      (when (> i 0) (display ", " port))
      (emit-expr l port))
    (display ")" port))
  (display " {\n" port)
  (for ([s rest]) (emit-stmt s port))
  (display "}" port))

;; ============================================================
;; Block helpers
;; ============================================================

(define (emit-block sexp port)
  (cond
    [(and (pair? sexp) (eq? (car sexp) 'block))
     (display "{\n" port)
     (for ([s (cdr sexp)]) (emit-stmt s port))
     (display "}\n" port)]
    [else
     (display "{\n" port)
     (emit-stmt sexp port)
     (display "}\n" port)]))

(define (emit-block-or-stmt sexp port)
  (if (and (pair? sexp) (eq? (car sexp) 'block))
      (emit-block sexp port)
      (emit-stmt sexp port)))

;; ============================================================
;; Common helpers
;; ============================================================

(define (emit-comma-sep exprs port)
  (for ([e exprs] [i (in-naturals)])
    (when (> i 0) (display ", " port))
    (emit-expr e port)))

(define (emit-for-exprs exprs port)
  (cond
    [(null? exprs) (void)]
    [(list? exprs)
     (for ([e exprs] [i (in-naturals)])
       (when (> i 0) (display ", " port))
       (emit-expr e port))]
    [else (emit-expr exprs port)]))

(define (emit-call-args args port)
  (for ([a args] [i (in-naturals)])
    (when (> i 0) (display ", " port))
    (if (and (pair? a) (eq? (car a) 'splat))
        (begin (display "..." port) (emit-expr (cadr a) port))
        (emit-expr a port))))

(define (emit-array-items items port)
  (for ([item items] [i (in-naturals)])
    (when (> i 0) (display ", " port))
    (if (and (pair? item) (eq? (car item) '=>))
        (begin (emit-expr (cadr item) port) (display " => " port) (emit-expr (caddr item) port))
        (emit-expr item port))))

(define (emit-static-vars pairs port)
  (for ([p pairs] [i (in-naturals)])
    (when (> i 0) (display ", " port))
    (if (and (pair? p) (= (length p) 2))
        (begin (emit-expr (car p) port) (display " = " port) (emit-expr (cadr p) port))
        (emit-expr p port))))

(define (emit-declare-list decls port)
  (for ([d decls] [i (in-naturals)])
    (when (> i 0) (display ", " port))
    (display (car d) port)
    (display " = " port)
    (emit-expr (cadr d) port)))

(define (emit-namespace-name name port)
  (cond
    [(and (pair? name) (eq? (car name) 'ns))
     (display (string-join (map ~a (cdr name)) "\\") port)]
    [(and (pair? name) (eq? (car name) 'ns-global))
     (display "\\" port)
     (display (string-join (map ~a (cdr name)) "\\") port)]
    [(string? name) (display name port)]
    [(symbol? name) (display name port)]
    [else (emit-expr name port)]))

(define (emit-use-decls decls port)
  (for ([d decls] [i (in-naturals)])
    (when (> i 0) (display ", " port))
    (if (and (pair? d) (eq? (car d) 'as))
        (begin (emit-namespace-name (cadr d) port) (fprintf port " as ~a" (caddr d)))
        (emit-namespace-name d port))))

(define (emit-catch-types types port)
  (if (list? types)
      (for ([t types] [i (in-naturals)])
        (when (> i 0) (display " | " port))
        (emit-expr t port))
      (emit-expr types port)))

;; ============================================================
;; Parameters & Type hints
;; ============================================================

(define (ensure-dollar name)
  (define s (~a name))
  (if (string-prefix? s "$") s (string-append "$" s)))

(define (emit-param p port)
  (if (not (pair? p))
      (emit-expr p port)
      (case (car p)
        [(param) (display (ensure-dollar (cadr p)) port)
                 (when (> (length p) 2)
                   (display " = " port) (emit-expr (caddr p) port))]
        [(param/type) (emit-type-hint (cadr p) port) (display " " port) (display (ensure-dollar (caddr p)) port)
                      (when (> (length p) 3)
                        (display " = " port) (emit-expr (cadddr p) port))]
        [(param&) (display "&" port) (display (ensure-dollar (cadr p)) port)
                  (when (> (length p) 2)
                    (display " = " port) (emit-expr (caddr p) port))]
        [(param-rest) (display "..." port) (display (ensure-dollar (cadr p)) port)]
        [(param-rest-type) (emit-type-hint (cadr p) port) (display " ..." port) (display (ensure-dollar (caddr p)) port)]
        [else (emit-expr p port)])))

(define (emit-params params port)
  (display "(" port)
  (for ([p params] [i (in-naturals)])
    (when (> i 0) (display ", " port))
    (emit-param p port))
  (display ")" port))

(define (emit-type-hint type port)
  (case type
    [(array) (display "array" port)]
    [(callable) (display "callable" port)]
    [(int) (display "int" port)]
    [(float) (display "float" port)]
    [(string) (display "string" port)]
    [(bool) (display "bool" port)]
    [(void) (display "void" port)]
    [(self) (display "self" port)]
    [(iterable) (display "iterable" port)]
    [else
     (if (and (pair? type) (eq? (car type) '?))
         (begin (display "?" port) (emit-type-hint (cadr type) port))
         (emit-expr type port))]))

;; ============================================================
;; Class / Interface
;; ============================================================

(define (parse-return-type rest)
  (cond
    [(and (>= (length rest) 2) (equal? (car rest) '#:return-type))
     (values (cadr rest) (cddr rest))]
    [else (values #f rest)]))

(define (parse-keyword-args rest)
  (let loop ([r rest] [extends #f] [implements '()])
    (cond
      [(and (>= (length r) 2) (equal? (car r) '#:extends))
       (loop (cddr r) (cadr r) implements)]
      [(and (>= (length r) 2) (equal? (car r) '#:implements))
       (loop (cddr r) extends (cadr r))]
      [else (values extends implements r)])))

(define (emit-class-dcl modifiers name rest port)
  (for ([m modifiers])
    (display (string-downcase (~a m)) port)
    (display " " port))
  (display "class " port)
  (display name port)
  (define-values (extends implements body) (parse-keyword-args rest))
  (when extends
    (display " extends " port)
    (emit-expr extends port))
  (when (not (null? implements))
    (display " implements " port)
    (for ([iface implements] [i (in-naturals)])
      (when (> i 0) (display ", " port))
      (emit-expr iface port)))
  (display " {\n" port)
  (for ([s body]) (emit-class-member s port))
  (display "}\n" port))

(define (emit-interface-dcl name rest port)
  (display "interface " port)
  (display name port)
  (define-values (extends _impl body) (parse-keyword-args rest))
  (when extends
    (display " extends " port)
    (for ([e (if (list? extends) extends (list extends))] [i (in-naturals)])
      (when (> i 0) (display ", " port))
      (emit-expr e port)))
  (display " {\n" port)
  (for ([s body]) (emit-class-member s port))
  (display "}\n" port))

;; ============================================================
;; Class members
;; ============================================================

(define (emit-class-member member port)
  (if (not (pair? member))
      (emit-stmt member port)
      (case (car member)
        [(property)
         (emit-modifiers (cadr member) port)
         (for ([v (cddr member)] [i (in-naturals)])
           (when (> i 0) (display ", " port))
           (if (and (pair? v) (= (length v) 2) (not (memq (car v) '(var & array-access))))
               (begin (emit-expr (car v) port) (display " = " port) (emit-expr (cadr v) port))
               (emit-expr v port)))
         (display ";\n" port)]
        [(method)
         (emit-modifiers (cadr member) port)
         (display "function " port)
         (display (caddr member) port)
         (emit-params (cadddr member) port)
         (define body (cddddr member))
         (if (null? body)
             (display ";\n" port)
             (begin (display " {\n" port) (for ([s body]) (emit-stmt s port)) (display "}\n" port)))]
        [(method/rt)
         (emit-modifiers (cadr member) port)
         (display "function " port)
         (display (caddr member) port)
         (emit-params (cadddr member) port)
         (display ": " port)
         (define rest (cddddr member))
         (emit-type-hint (car rest) port)
         (define body (cdr rest))
         (if (null? body)
             (display ";\n" port)
             (begin (display " {\n" port) (for ([s body]) (emit-stmt s port)) (display "}\n" port)))]
        [(method&)
         (emit-modifiers (cadr member) port)
         (display "function &" port)
         (display (caddr member) port)
         (emit-params (cadddr member) port)
         (define body (cddddr member))
         (if (null? body)
             (display ";\n" port)
             (begin (display " {\n" port) (for ([s body]) (emit-stmt s port)) (display "}\n" port)))]
        [(class-const)
         (define args (cdr member))
         (if (= (length args) 2)
             (begin (display "const " port) (display (car args) port) (display " = " port)
                    (emit-expr (cadr args) port) (display ";\n" port))
             (begin (display (string-downcase (~a (car args))) port) (display " const " port)
                    (display (cadr args) port) (display " = " port)
                    (emit-expr (caddr args) port) (display ";\n" port)))]
        [(use-trait)
         (display "use " port)
         (for ([t (cdr member)] [i (in-naturals)])
           (when (> i 0) (display ", " port))
           (emit-expr t port))
         (display ";\n" port)]
        [(use-trait-with)
         (display "use " port)
         (define ts (cadr member))
         (for ([t (if (list? ts) ts (list ts))] [i (in-naturals)])
           (when (> i 0) (display ", " port))
           (emit-expr t port))
         (display " {\n" port)
         (for ([a (cddr member)])
           (cond
             [(eq? (car a) 'insteadof)
              (display "    " port) (emit-expr (cadr a) port) (display " insteadof " port)
              (for ([il (caddr a)] [i (in-naturals)])
                (when (> i 0) (display ", " port))
                (emit-expr il port))
              (display ";\n" port)]
             [(eq? (car a) 'as)
              (display "    " port) (emit-expr (cadr a) port) (display " as " port)
              (if (= (length a) 3)
                  (display (caddr a) port)
                  (begin (display (string-downcase (~a (caddr a))) port) (display " " port)
                         (display (cadddr a) port)))
              (display ";\n" port)]))
         (display "}\n" port)]
        [else (emit-stmt member port)])))

(define (emit-modifiers mods port)
  (for ([m mods])
    (display (string-downcase (~a m)) port)
    (display " " port)))

;; ============================================================
;; Operator mappings
;; ============================================================

(define (binary-op->php op)
  (case op
    [(+) "+"] [(-) "-"] [(*) "*"] [(/) "/"] [(%) "%"]
    [(pow) "**"]
    [(concat) "."]
    [(&) "&"] [(bw-or) "|"] [(^) "^"] [(shl) "<<"] [(shr) ">>"]
    [(&&) "&&"] [(or-short) "||"]
    [(and) "and"] [(or) "or"] [(xor) "xor"]
    [(==) "=="] [(!=) "!="] [(===) "==="] [(!==) "!=="]
    [(<) "<"] [(<=) "<="] [(>) ">"] [(>=) ">="]
    [(spaceship) "<=>"]
    [else (~a op)]))

(define (unary-op->php op)
  (case op
    [(+) "+"] [(-) "-"] [(!) "!"] [(~) "~"]
    [else (~a op)]))

(define (assign-op->php op)
  (case op
    [(=) "="]
    [(+=) "+="] [(-=) "-="] [(*=) "*="] [(/=) "/="]
    [(%=) "%="] [(pow=) "**="]
    [(concat=) ".="]
    [(&=) "&="] [(bw-or=) "|="] [(^=) "^="]
    [(<<=) "<<="] [(>>=) ">>="]
    [else (~a op)]))

(define (cast-type->php type)
  (case type
    [(int integer) "int"]
    [(float double real) "float"]
    [(string) "string"]
    [(array) "array"]
    [(object) "object"]
    [(bool boolean) "bool"]
    [(binary) "binary"]
    [(unset) "unset"]
    [else (~a type)]))

(define (escape-single-quote s)
  (string-replace (string-replace s "\\" "\\\\") "'" "\\'"))


(define (cddddr l) (cdr (cdddr l)))
