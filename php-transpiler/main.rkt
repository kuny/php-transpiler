#lang racket

(require "emit.rkt")

(provide emit
         emit-to-string
         sexp->php
         sexp-file->php)

;; Convert S-expression AST to PHP string
(define (sexp->php sexp)
  (emit-to-string sexp))

;; Read S-expression from file and convert to PHP
(define (sexp-file->php path)
  (define sexp (with-input-from-file path read))
  (emit-to-string sexp))

