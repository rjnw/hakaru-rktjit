#lang racket
(require ffi/unsafe
         racket/runtime-path)

(require "../../jit.rkt"
         sham)

(define vs-topics (list 2 1 0 2 1 0 0))
(define vs-words (list 0 3 3 2 1 2 0 1 2 3 3 0 0 3 2 1 0))
(define vs-docs (list 0 0 1 1 1 2 2 2 3 4 4 5 5 5 6 6 6))

(define empty-nbinfo (list '() '() '() '() '() '()))

(define-runtime-path current-dir "./")





(define (run-test module-env topics words docs output-hs)
  ;; (printf "running naive bayes:\n\t topics: ~a\n\t words: ~a\n\t docs: ~a\n" topics words docs)

  (define prog (jit-get-function 'prog module-env))

  (define make-prob-array      (jit-get-function (string->symbol (format "make$array<prob>")) module-env))
  (define new-sized-prob-array (jit-get-function (string->symbol (format "new-sized$array<prob>")) module-env))
  (define free-prob-array      (jit-get-function (string->symbol (format "free-sized$array<prob>")) module-env))
  (define set-index-prob-array (jit-get-function (string->symbol (format "set-index!$array<prob>")) module-env))
  (define get-index-prob-array (jit-get-function (string->symbol (format "get-index$array<prob>")) module-env))
  (define get-size-prob-array (jit-get-function (string->symbol (format "get-size$array<prob>")) module-env))


  (define make-nat-array      (jit-get-function (string->symbol (format "make$array<nat>")) module-env))
  (define new-sized-nat-array (jit-get-function (string->symbol (format "new-sized$array<nat>")) module-env))
  (define free-nat-array      (jit-get-function (string->symbol (format "free-sized$array<nat>")) module-env))
  (define set-index-nat-array (jit-get-function (string->symbol (format "set-index!$array<nat>")) module-env))
  (define get-index-nat-array (jit-get-function (string->symbol (format "get-index$array<nat>")) module-env))
  (define get-size-nat-array (jit-get-function (string->symbol (format "get-size$array<nat>")) module-env))

  (define get-size-nat-array-array  (jit-get-function (string->symbol (format "get-size$array<array<nat>*>")) module-env))
  (define get-index-nat-array-array (jit-get-function (string->symbol (format "get-index$array<array<nat>*>")) module-env))

  (define make-real-array      (jit-get-function (string->symbol (format "make$array<real>")) module-env))
  (define new-sized-real-array (jit-get-function (string->symbol (format "new-sized$array<real>")) module-env))
  (define free-real-array      (jit-get-function (string->symbol (format "free-sized$array<real>")) module-env))
  (define set-index-real-array (jit-get-function (string->symbol (format "set-index!$array<real>")) module-env))
  (define get-index-real-array (jit-get-function (string->symbol (format "get-index$array<real>")) module-env))
  (define get-size-real-array  (jit-get-function (string->symbol (format "get-size$array<real>")) module-env))

  (define real2prob (jit-get-function (string->symbol "real2prob") module-env))
  (define prob2real (jit-get-function (string->symbol "prob2real") module-env))

  (define num-topics (add1 (argmax identity topics)))
  (define num-words (add1 (argmax identity words)))
  (define num-docs (add1 (last docs)))

  (define (make-const-prob-array size val)
    (define as (new-sized-prob-array size))
    (for ([i (in-range size)])
      (set-index-prob-array as i val))
    as)

  (define topic-prior (make-const-prob-array num-topics 0.0))
  (define word-prior (make-const-prob-array num-words 0.0))

  (define (make-c-nat-array lst)
    (define arr (new-sized-nat-array (length lst)))
    (for ([v lst]
          [i (in-range (length lst))])
      (set-index-nat-array arr i  v))
    arr)

  (define (make-c-real-array lst)
    (define arr (new-sized-real-array (length lst)))
    (for ([v lst]
          [i (in-range (length lst))])
      (set-index-real-array arr i (exact->inexact v)))
    arr)

  (define c-words (make-c-nat-array words))
  (define c-docs (make-c-nat-array docs))

  (define zs (make-c-nat-array topics))
  (define doc 0)

  (define output-c (prog topic-prior word-prior zs c-words c-docs doc ))
  ;; (define output-list
  ;;   (for/list ([i (in-range (get-size-nat-array-array output-c))])
  ;;     (define as (get-index-nat-array-array output-c i))
  ;;     (for/list ([j (in-range (get-size-nat-array as))])
  ;;       (get-index-nat-array as j))))

  (printf "output from prog: ~a\n" output-c)
  (printf "output from haskell: ~a\n" output-hs))

(define env (compile-file (build-path current-dir "partial-arr22.hkr") empty-nbinfo))

(run-test env vs-topics vs-words vs-docs 0)