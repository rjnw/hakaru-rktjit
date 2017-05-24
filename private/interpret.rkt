#lang racket

(require "ast.rkt")
(require "utils.rkt")

(provide interpret)

(define (prod-vector-of-type vec t)
  (define pf (if (equal? t 'prob)
                 +
                 *))
  (for/fold ([prod (one-of-type t)])
            ([v vec])
    (pf prod v)))

(define (sum-vector-of-type vec t)
  (define sf (if (equal? t 'prob)
                 logspace-add
                 +))
  (for/fold ([sum (zero-of-type t)])
            ([v vec])
    (sf sum v)))

(define intr-map
  (make-immutable-hash
   `((== . ,equal?)
     (not . ,not)
     (< . ,<)
     (and . ,(λ (a b) (and a b)))
     (or . ,(λ (a b) (or a b)))
     (index . ,vector-ref)
     (size . ,vector-length)
     (nat2prob . ,(λ (a) (real2prob (* a 1.0))))
     (logspace-+ . ,logspace-add)
     (logspace-* . ,+)
     (+ . ,+)
     (- . ,-))))

(define (intr-lookup sym)
  (hash-ref intr-map sym))

(define (e ast env)
  (match ast
    [(expr-fun args ret-type body)
     'fn]
    [(expr-if t tst thn els)
     (if (e tst env)
         (e thn env)
         (e els env))]
    [(expr-app t rt rds)
     (apply (e rt env) (map (curryr e env) rds))]
    [(expr-let t var val b)
     (e b (hash-set env (expr-var-sym var) (e val env)))]
    [(expr-sum t i start end b)
     (sum-vector-of-type
      (for/vector ([iv (in-range (e start env)
                                 (e end env))])
        (e b (hash-set env (expr-var-sym i) iv)))
      t)]
    [(expr-prd t i start end b)
     (prod-vector-of-type
      (for/vector ([iv (in-range (e start env)
                                 (e end env))])
        (e b (hash-set env (expr-var-sym i) iv)))
      t)]
    [(expr-arr t i end b)
     (for/vector ([iv (in-range 0 (e end env))])
       (e b (hash-set env (expr-var-sym i) iv)))]
    [(expr-val t v)
     v]
    [(expr-intr s)
     (intr-lookup s)]
    [(expr-var t s o)
     (hash-ref env s)]))

(define (evaluate-function-body ast args-val)
  (e (expr-fun-body ast)
     (for/hash [(arg-val args-val)
                (arg (expr-fun-args ast))]
       (values (expr-var-sym arg) arg-val))))

(define ((interpret args-val) ast)
  (if (equal? (length args-val) (length (expr-fun-args ast)))
      (evaluate-function-body ast args-val)
      (error "argument size mismatch in interpreting.")))