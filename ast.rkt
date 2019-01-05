#lang racket

(provide (all-defined-out))

(require racket/generic)
(define f-symbol identity)

;;GRAMMAR-INFO
#|
(define-grammar hakaru
  (expr
   (mod (main fns) [expr (* (symbol . expr))])
   (fun (args ret-type body) [(* expr) symbol expr])
   (lets (types vars vals body) [symbol (* expr) (* expr) expr])
   (var (type sym orig) [symbol symbol symbol])
   (arr (type index size body) [symbol expr expr expr])
   (sum (type index start end body) [symbol expr expr expr expr])
   (prd (type index start end body) [symbol expr expr expr expr])
   (bucket (type start end reducer) [symbol expr expr reducer])
   (branch (pat body) (pat expr))
   (match (type tst branches) [symbol expr (* expr)])
   (bind (var body) (expr expr))
   (if (type tst thn els) (symbol expr expr expr))
   (app (type rator rands) (symbol expr (* expr)))
   (val (type v) (symbol symbol))
   (intrf (sym) (symbol))
   (block (type stmt body) (symbol stmt expr)))
  (reducer
   (split (e a b) [expr reducer reducer])
   (fanout (a b) [reducer reducer])
   (add (e) [expr])
   (nop () ())
   (index (n i a) (expr expr reducer)))
  (stmt
   (if (tst thn els) (expr stmt stmt))
   (elets (vars vals bstmt) ((* expr) (* expr) stmt))
   (for (i start end body) (expr expr expr stmt))
   (block (stmts) ((* stmt)))
   (assign (var val) (expr expr))
   (return (val) (expr))
   (void () ()))
  (pat
   (true () ())
   (false () ())
   (pair (a b) [pat pat])
   (var () ())
   (ident () ())))
|#

;AG
(begin
  (begin
    (define-generics exprg (map-expr f-expr f-reducer f-stmt f-pat exprg))
    (struct expr ())
    (struct expr-mod expr (main fns)
      #:methods gen:exprg
      ((define (map-expr f-expr f-reducer f-stmt f-pat e^)
         (match-define (expr-mod main fns) e^)
         (expr-mod (f-expr main) (map (λ (f) (cons (car f) (f-expr (cdr f)))) fns)))))
    (struct expr-cvar expr (var val)
      #:methods gen:exprg
      ((define (map-expr f-expr f-reducer f-stmt f-pat e^)
         (match-define (expr-cvar var val) e^)
         (expr-cvar var (f-expr val)))))
    (struct expr-fun expr (name args ret-type body)
      #:methods gen:exprg
      ((define (map-expr f-expr f-reducer f-stmt f-pat e^)
         (match-define (expr-fun name args ret-type body) e^)
         (expr-fun name (map f-expr args) (f-symbol ret-type) (if (stmt? body) (f-stmt body) (f-expr body))))))
    (struct expr-lets expr (types vars vals stmt body)
      #:methods gen:exprg
      ((define (map-expr f-expr f-reducer f-stmt f-pat e^)
         (match-define (expr-lets types vars vals st body) e^)
         (expr-lets
          types
          (map f-expr vars)
          (map f-expr vals)
          (f-stmt st)
          (f-expr body)))))
    (struct expr-var expr ([type #:mutable] sym [info #:mutable])
      ;; orig is also used to tag mutable and constants for inlining
      #:methods gen:equal+hash
      ((define (equal-proc v1 v2 _)
         (equal? (expr-var-sym v1) (expr-var-sym v2)))
       (define (hash-proc v _) (equal-hash-code (expr-var-sym v)))
       (define (hash2-proc v _) (equal-secondary-hash-code (expr-var-sym v))))
      #:methods
      gen:exprg
      ((define (map-expr f-expr f-reducer f-stmt f-pat e^) e^)))
    (struct expr-arr expr (type index size body)
      #:methods gen:exprg
      ((define (map-expr f-expr f-reducer f-stmt f-pat e^)
         (match-define (expr-arr type index size body) e^)
         (expr-arr
          type
          (f-expr index)
          (f-expr size)
          (f-expr body)))))
    (struct expr-sum expr (type index start end body)
      #:methods gen:exprg
      ((define (map-expr f-expr f-reducer f-stmt f-pat e^)
         (match-define (expr-sum type index start end body) e^)
         (expr-sum
          type
          (f-expr index)
          (f-expr start)
          (f-expr end)
          (f-expr body)))))
    (struct expr-prd expr (type index start end body)
      #:methods gen:exprg
      ((define (map-expr f-expr f-reducer f-stmt f-pat e^)
         (match-define (expr-prd type index start end body) e^)
         (expr-prd
          type
          (f-expr index)
          (f-expr start)
          (f-expr end)
          (f-expr body)))))
    (struct expr-bucket expr (type start end reducer)
      #:methods gen:exprg
      ((define (map-expr f-expr f-reducer f-stmt f-pat e^)
         (match-define (expr-bucket type start end reducer) e^)
         (expr-bucket
          type
          (f-expr start)
          (f-expr end)
          (f-reducer reducer)))))
    (struct expr-branch expr (pat body)
      #:methods gen:exprg
      ((define (map-expr f-expr f-reducer f-stmt f-pat e^)
         (match-define (expr-branch pat body) e^)
         (expr-branch (f-pat pat) (f-expr body)))))
    (struct expr-match expr (type tst branches)
      #:methods gen:exprg
      ((define (map-expr f-expr f-reducer f-stmt f-pat e^)
         (match-define (expr-match type tst branches) e^)
         (expr-match (f-symbol type) (f-expr tst) (map f-expr branches)))))
    (struct expr-bind expr (var body)
      #:methods gen:exprg
      ((define (map-expr f-expr f-reducer f-stmt f-pat e^)
         (match-define (expr-bind var body) e^)
         (expr-bind (f-expr var) (f-expr body)))))
    (struct expr-if expr (type tst thn els)
      #:methods gen:exprg
      ((define (map-expr f-expr f-reducer f-stmt f-pat e^)
         (match-define (expr-if type tst thn els) e^)
         (expr-if (f-symbol type) (f-expr tst) (f-expr thn) (f-expr els)))))
    (struct expr-app expr (type rator rands)
      #:methods gen:exprg
      ((define (map-expr f-expr f-reducer f-stmt f-pat e^)
         (match-define (expr-app type rator rands) e^)
         (expr-app (f-symbol type) (f-expr rator) (map f-expr rands)))))
    (struct expr-val expr (type v)
      #:methods gen:exprg
      ((define (map-expr f-expr f-reducer f-stmt f-pat e^)
         (match-define (expr-val type v) e^)
         (expr-val (f-symbol type) (f-symbol v)))))
    (struct expr-intrf expr (sym)
      #:methods gen:exprg
      ((define (map-expr f-expr f-reducer f-stmt f-pat e^) e^))))

  (begin
    (define-generics
      reducerg
      (map-reducer f-expr f-reducer f-stmt f-pat reducerg))
    (struct reducer ())
    (struct reducer-split reducer (e a b)
      #:methods gen:reducerg
      ((define (map-reducer f-expr f-reducer f-stmt f-pat e^)
         (match-define (reducer-split e a b) e^)
         (reducer-split (f-expr e) (f-reducer a) (f-reducer b)))))
    (struct reducer-fanout reducer (a b)
      #:methods gen:reducerg
      ((define (map-reducer f-expr f-reducer f-stmt f-pat e^)
         (match-define (reducer-fanout a b) e^)
         (reducer-fanout (f-reducer a) (f-reducer b)))))
    (struct reducer-add reducer (e)
      #:methods gen:reducerg
      ((define (map-reducer f-expr f-reducer f-stmt f-pat e^)
         (match-define (reducer-add e) e^)
         (reducer-add (f-expr e)))))
    (struct reducer-nop reducer ()
      #:methods gen:reducerg
      ((define (map-reducer f-expr f-reducer f-stmt f-pat e^)
         (match-define (reducer-nop) e^)
         (reducer-nop))))
    (struct reducer-index reducer (n i a)
      #:methods gen:reducerg
      ((define (map-reducer f-expr f-reducer f-stmt f-pat e^)
         (match-define (reducer-index n i a) e^)
         (reducer-index (f-expr n) (f-expr i) (f-reducer a))))))


  (begin
    (define-generics stmtg (map-stmt f-expr f-reducer f-stmt f-pat stmtg))
    (struct stmt ())
    (struct stmt-return stmt (val)
      #:methods gen:stmtg
      ((define (map-stmt f-expr f-reducer f-stmt f-pat e^)
         (match-define (stmt-return val) e^)
         (stmt-return (f-expr val)))))
    (struct stmt-if stmt (tst thn els)
      #:methods gen:stmtg
      ((define (map-stmt f-expr f-reducer f-stmt f-pat e^)
         (match-define (stmt-if tst thn els) e^)
         (stmt-if (f-expr tst) (f-stmt thn) (f-stmt els)))))
    (struct stmt-for stmt (i start end body)
      #:methods gen:stmtg
      ((define (map-stmt f-expr f-reducer f-stmt f-pat e^)
         (match-define (stmt-for i start end body) e^)
         (stmt-for (f-expr i) (f-expr start) (f-expr end) (f-stmt body)))))
    (struct stmt-expr stmt (stmt expr)
      #:methods gen:stmtg
      ((define (map-stmt f-expr f-reducer f-stmt f-pat e^)
         (match-define (stmt-expr stmt expr) e^)
         (stmt-expr (f-stmt stmt) (f-expr expr)))))
    (struct stmt-block stmt (stmts)
      #:methods gen:stmtg
      ((define (map-stmt f-expr f-reducer f-stmt f-pat e^)
         (match-define (stmt-block stmts) e^)
         (stmt-block (map f-stmt stmts)))))
    (struct stmt-assign stmt (var val)
      #:methods gen:stmtg
      ((define (map-stmt f-expr f-reducer f-stmt f-pat e^)
         (match-define (stmt-assign var val) e^)
         (stmt-assign (f-expr var) (f-expr val)))))
    (struct stmt-void stmt ()
      #:methods gen:stmtg
      ((define (map-stmt f-expr f-reducer f-stmt f-pat e^)
         (match-define (stmt-void) e^)
         (stmt-void)))))
  (begin
    (define-generics patg (map-pat f-expr f-reducer f-stmt f-pat patg))
    (struct pat ())
    (struct pat-true pat ()
      #:methods gen:patg
      ((define (map-pat f-expr f-reducer f-stmt f-pat e^)
         (match-define (pat-true) e^)
         (pat-true))))
    (struct pat-false pat ()
      #:methods gen:patg
      ((define (map-pat f-expr f-reducer f-stmt f-pat e^)
         (match-define (pat-false) e^)
         (pat-false))))
    (struct pat-pair pat (a b)
      #:methods gen:patg
      ((define (map-pat f-expr f-reducer f-stmt f-pat e^)
         (match-define (pat-pair a b) e^)
         (pat-pair (f-pat a) (f-pat b)))))
    (struct pat-var pat ()
      #:methods gen:patg
      ((define (map-pat f-expr f-reducer f-stmt f-pat e^)
         (match-define (pat-var) e^)
         (pat-var))))
    (struct pat-ident pat ()
      #:methods gen:patg
      ((define (map-pat f-expr f-reducer f-stmt f-pat e^)
         (match-define (pat-ident) e^)
         (pat-ident))))))

(define-syntax (create-rpass stx)
  (syntax-case stx (expr reducer stmt pat)
    ((_
      (expr mat-expr ...)
      (reducer mat-reducer ...)
      (stmt mat-stmt ...)
      (pat mat-pat ...))
     #`(letrec ((f-expr (λ (e)
                          (define ne (map-expr f-expr f-reducer f-stmt f-pat e))
                          (match ne mat-expr ... (else ne))))
                (f-reducer (λ (e)
                             (define ne (map-reducer f-expr f-reducer f-stmt f-pat e))
                             (match ne mat-reducer ... (else ne))))
                (f-stmt (λ (e)
                          (define ne (map-stmt f-expr f-reducer f-stmt f-pat e))
                          (match ne mat-stmt ... (else ne))))
                (f-pat (λ (e)
                         (define ne (map-pat f-expr f-reducer f-stmt f-pat e))
                         (match ne mat-pat ... (else ne)))))
         (λ (e) (if (expr? e)
                    (map-expr f-expr f-reducer f-stmt f-pat e)
                    (map-stmt f-expr f-reducer f-stmt f-pat e)))))))

(define-syntax (create-pass stx)
  (syntax-case stx (expr reducer stmt pat)
    ((_ (expr mat-expr ...)
        (reducer mat-reducer ...)
        (stmt mat-stmt ...)
        (pat mat-pat ...))
     #`(letrec ((f-expr (λ (e)
                          (define ne (match e mat-expr ... (else e)))
                          (map-expr f-expr f-reducer f-stmt f-pat ne)))
                (f-reducer (λ (e) (define ne (match e mat-reducer ... (else e)))
                              (map-reducer f-expr f-reducer f-stmt f-pat ne)))
                (f-stmt (λ (e)
                          (define ne (match e mat-stmt ... (else e)))
                          (map-stmt f-expr f-reducer f-stmt f-pat ne)))
                (f-pat (λ (e)
                         (define ne (match e mat-pat ... (else e)))
                         (map-pat f-expr f-reducer f-stmt f-pat ne))))
         (λ (e) (map-expr f-expr f-reducer f-stmt f-pat e))))))
(define-syntax (create-pass/state stx)
  (syntax-case stx (expr reducer stmt pat)
    ((_ si
        (expr mat-expr ...)
        (reducer mat-reducer ...)
        (stmt mat-stmt ...)
        (pat mat-pat ...))
     #`(letrec ((f-expr (λ (s e)
                          (define ne (match e mat-expr ... (else e)))
                          (map-expr f-expr f-reducer f-stmt f-pat ne)))
                (f-reducer (λ (s e) (define ne (match e mat-reducer ... (else e)))
                              (map-reducer f-expr f-reducer f-stmt f-pat ne)))
                (f-stmt (λ (s e)
                          (define ne (match e mat-stmt ... (else e)))
                          (map-stmt f-expr f-reducer f-stmt f-pat ne)))
                (f-pat (λ (s e)
                         (define ne (match e mat-pat ... (else e)))
                         (map-pat f-expr f-reducer f-stmt f-pat ne))))
         (λ (e) (map-expr (curry f-expr si)
                          (curry f-reducer si)
                          (curry f-stmt si)
                          (curry f-pat si)
                          e))))))
;AG-END

(define internal-ops
  (apply set '(size index recip nat2prob prob2real + * == and < or not
                    categorical)))
(define sum-prod-loops (set 'summate 'product))
(define internal-loop-ops
  (set 'summate 'product 'array))

(define (typeof ast)
  (match ast
    [(expr-fun name args ret-type body) 'fn]
    [(expr-if t _ _ _) t]
    [(expr-app t _ _) t]
    [(expr-lets _ _ _ _ b) (typeof b)]
    [(expr-sum t i start end b) t]
    [(expr-prd t i start end b) t]
    [(expr-arr t i end b) t]
    [(expr-match t tst brs) t]
    [(expr-bucket t _ _ _) t]
    [(expr-val t v) t]
    [(expr-intrf s) '!]
    [(expr-cvar var val) (typeof var)]
    [(expr-var t s o) t]
    [(expr-bucket t s e b) t]))

(define hakrit-print-debug (make-parameter #f))
(define (pe e)
  (match e
    [(expr-mod main fns)
     `((main ,(pe main) ,(map pe fns)))]
    [(expr-fun name args ret-type body)
     #:when (stmt? body)
     `(function ,name ,(map pe args) ,(ps body))]
    [(expr-fun name args ret-type body)
     `(function ,name ,(map pe args) ,(pe body))]
    [(expr-cvar var val)
     `(constant ,(pe var) _)]
    [(expr-var type sym orig)
     (if (hakrit-print-debug)
         `(,sym : ,type)
         sym)]
    [(expr-arr type index size body)
     `(array ,(pe index) ,(pe size) ,(pe body))]
    [(expr-sum type index start end body)
     `(summate (,(pe index) ,(pe start) ,(pe end)) ,(pe body))]
    [(expr-prd type index start end body)
     `(product (,(pe index) ,(pe start) ,(pe end)) ,(pe body))]
    [(expr-bucket type start end reducer)
     (if (hakrit-print-debug)
         `(bucket ,type ,(pe start) ,(pe end) ,(pr reducer))
         `(bucket ,(pe start) ,(pe end) ,(pr reducer)))]
    [(expr-bind var body)
     `(/ ,(pe var) -> ,(pe body))]
    [(expr-match type tst branches)
     `(match ,(pe tst) ,@(map pe branches))]
    [(expr-branch pat body)
     `[,(pp pat) ,(pe body)]]
    [(expr-if type tst thn els)
     `(if ,(pe tst) ,(pe thn) ,(pe els))]
    [(expr-app type rator rands)
     (if (hakrit-print-debug)
          `(,(pe rator) ,type ,@(map pe rands))
         `(,(pe rator) ,@(map pe rands)))]
    [(expr-lets '() '() '() s (expr-val t 0))
     (ps s)]
    [(expr-lets '() '() '() (stmt-void) e)
     (pe e)]
    [(expr-lets types vars vals stmt (expr-val t 0))
     `(lets (,@(for/list ([var vars] [val vals] [t types])
                 `(,(pe var) ,(pe val) : ,t)))
            ,(ps stmt))]
    [(expr-lets types vars vals stmt body)
     `(elets (,@(for/list ( [var vars] [val vals] [t types])
                  `(,(pe var) ,(pe val) : ,t)))
             ,(ps stmt)
             ,(pe body))]
    [(expr-intrf s) s]
    [(expr-val t v)
     (if (hakrit-print-debug)
         `(,v : ,t)
         v)]
    [else '?]))
(define print-expr pe)
(define display-expr (compose pretty-display print-expr))
(define (pr red)
  (match red
    [(reducer-split e a b) `(split ,(pe e) ,(pr a) ,(pr b))]
    [(reducer-fanout a b) `(fanout ,(pr a) ,(pr b))]
    [(reducer-add i) `(add ,(pe i))]
    [(reducer-nop) `(nop)]
    [(reducer-index i e b) `(index ,(pe i) ,(pe e) ,(pr b))]))
(define print-reducer pr)
(define display-reducer (compose pretty-display print-reducer))
(define (pp pat)
  (match pat
    [(pat-var) 'var]
    [(pat-true) 'true]
    [(pat-false) 'false]
    [(pat-pair a b) `(pair ,(pp a) ,(pp b))]
    [(pat-ident) 'rec]))
(define print-pattern pp)
(define display-pattern (compose pretty-display print-pattern))
(define (ps stmt)
  (match stmt
    [(stmt-if tst thn els) `(if-stmt ,(pe tst) ,(ps thn) ,(ps els))]
    [(stmt-for i start end body) `(for-stmt (,(pe i) ,(pe start) ,(pe end)) ,(ps body))]
    [(stmt-block stmts) `($ ,@(map ps stmts))]
    [(stmt-assign var val) `(set! ,(pe var) ,(pe val))]
    [(stmt-return val) `(return ,(pe val))]
    [(stmt-expr (stmt-void) e) (pe e)]
    [(stmt-expr s e) `(se ,(ps s) ,(pe e))]
    [(stmt-void) '<svoid>]
    [else `(unknown-stmt ,stmt)]))
(define print-stmt ps)
(define display-stmt (compose pretty-display print-stmt))

(define (find-free-variables expr)
  (define ffv^ find-free-variables)
  (match expr
    [(expr-fun name args ret-type b)
     (define bfree (ffv^ b))
     (set-subtract bfree (apply set args))]
    [(expr-lets ts vars vals s b)
     (define total-free-vars
       (set-union (ffv^ s) (ffv^ b)
                  (if (empty? vals) (set) (apply set-union (map ffv^ vals)))))
     (set-subtract total-free-vars
                   (apply set vars))]
    [(expr-sum t i start end b)
     (set-union (ffv^ start) (ffv^ end) (set-remove (ffv^ b) i))]
    [(expr-prd t i start end b)
     (set-union (ffv^ start) (ffv^ end) (set-remove (ffv^ b) i))]
    [(expr-arr t i end b)
     (set-union (ffv^ end) (set-remove (ffv^ b) i))]
    [(expr-bucket t s e r)
     (set-union (ffv^ s) (ffv^ e) (ffv^ r))]
    [(expr-match t tst brns)
     (apply set-union (cons (ffv^ tst) (map ffv^ brns)))]
    [(expr-branch pat b) (ffv^ b)]
    [(expr-if t tst thn els) (set-union (ffv^ tst) (ffv^ thn) (ffv^ els))]
    [(expr-app t rator rands)
     (apply set-union (cons (ffv^ rator) (map ffv^ rands)))]
    [(expr-val t v) (set)]
    [(expr-intrf sym) (set)]
    [(expr-var t s o) (set expr)]
    [(expr-bind s e) (set-remove (ffv^ e) s)]

    [(reducer-split e a b) (set-union (ffv^ e) (ffv^ a) (ffv^ b))]
    [(reducer-fanout a b) (set-union (ffv^ a) (ffv^ b))]
    [(reducer-add i) (set-union (ffv^ i))]
    [(reducer-nop) (set)]
    [(reducer-index i e b) (set-union (ffv^ i) (ffv^ e) (ffv^ b))]

    [(stmt-if tst thn els) (set-union (ffv^ tst) (ffv^ thn) (ffv^ els))]
    [(stmt-for i start end body)
     (set-union (ffv^ start) (ffv^ end) (set-remove (ffv^ body) i))]
    [(stmt-block stmts)
     (if (empty? stmts)
         (set)
         (apply set-union (map ffv^ stmts)))]
    [(stmt-expr s e)
     (set-union (ffv^ s) (ffv^ e))]
    [(stmt-void) (set)]
    [(stmt-return v) (ffv^ v)]
    [(stmt-assign to val)
     (set-union (ffv^ to) (ffv^ val))]))

(define (find-mutated-variables expr)
  (define fmv find-mutated-variables)
  (match expr
    [(expr-fun name args ret-type b)
     (define bfree (fmv b))
     (set-subtract bfree (apply set args))]
    [(expr-lets ts vars vals s b)
     (define total-mvars
       (set-union (fmv s) (fmv b)))
     (set-subtract total-mvars (apply set vars))]
    [(expr-if t tst thn els) (set-union (fmv tst) (fmv thn) (fmv els))]
    [(expr-app t (expr-intrf 'set-index!) rands)
     (find-free-variables (car rands))]
    [(expr-app t rator rands)
     (apply set-union (cons (fmv rator) (map fmv rands)))]
    [(expr-val t v) (set)]
    [(expr-intrf sym) (set)]
    [(expr-var t s o) (set)]
    [(stmt-if tst thn els) (set-union (fmv tst) (fmv thn) (fmv els))]
    [(stmt-for i start end body)
     (set-union (fmv start) (fmv end) (set-remove (fmv body) i))]
    [(stmt-block stmts)
     (apply set-union (cons (set) (map fmv stmts)))]
    [(stmt-expr s e)
     (set-union (fmv s) (fmv e))]
    [(stmt-void) (set)]
    [(stmt-return v) (fmv v)]
    [(stmt-assign to val)
     (find-free-variables to)]))