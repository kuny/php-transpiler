#lang racket

(require "compiler.rkt")

(module+ main
  (compile-all "sexp" "build"))
