#lang racket

(provide compile-all)

(require racket/file
         racket/path
         racket/string
         php-transpiler)

(define (sexp-file? p)
  (and (file-exists? p)
       (regexp-match? #rx"[.]sexp$" (path->string p))))

(define (relative-path base target)
  (find-relative-path base target))

(define (sexp->php-path rel-path)
  (define rel-str
    (cond
      [(path? rel-path) (path->string rel-path)]
      [(bytes? rel-path) (bytes->string/utf-8 rel-path)]
      [else rel-path]))
  (string->path
   (regexp-replace #rx"[.]sexp$" rel-str ".php")))

(define (ensure-parent-directory path-value)
  (define-values (base _name _dir?) (split-path path-value))
  (when (path? base)
    (make-directory* base)))

(define (compile-one src-root out-root sexp-file)
  (define rel (relative-path src-root sexp-file))
  (define out-file (build-path out-root (sexp->php-path rel)))
  (define php-src (sexp-file->php (path->string sexp-file)))

  (ensure-parent-directory out-file)

  (displayln
   (format "compile: ~a -> ~a"
           (path->string sexp-file)
           (path->string out-file)))

  (with-output-to-file out-file
    #:exists 'replace
    (lambda ()
      (display php-src))))

(define (compile-all src-root out-root)
  (make-directory* out-root)
  (for ([p (in-directory src-root)])
    (when (sexp-file? p)
      (compile-one src-root out-root p)))
  (displayln "done."))
