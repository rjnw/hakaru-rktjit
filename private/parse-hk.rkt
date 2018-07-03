#lang racket

(require "ast.rkt"
         "pass/utils.rkt")

(provide parse)
(define debug-curry (make-parameter #f))
;; (define dp (debug-printf debug-curry))

(define (dp . a) (void))

(define (get-value v)
  (match v
    [(? number?) v]
    [`(,n) #:when (number? n) n]))

(define (remove-curry src args)
  (match src
    [`((fn ,var ,ret-type ,body) : ,fn-type)
     (remove-curry body (append args (list (expr-var  (car fn-type) var '())) ))]
    [`(,body : ,t)
     (expr-fun 'prog args t src)]))

(define (parse-fun prg)
  (define (parse e env)
    (match e
      [(expr-fun name args ret-type body)
       (define nenv
         (for/fold [(env env)]
                   [(arg args)]
           (hash-set env (expr-var-sym arg) arg)))
       (define new-body (parse body nenv))
       (expr-fun name args ret-type new-body)]
      [`((let (,var ,type ,val) ,body) : ,t)
       (define nval (parse val env))
       (define nvart (typeof nval))
       (define nvar (expr-var nvart var '()))
       (define nbody (parse body (hash-set env var nvar)))
       (expr-lets (list nvart) (list nvar) (list nval) (stmt-void) nbody)]

      [`((summate (,index ,start ,end) ,body) : ,type)
       (define ie (expr-var 'nat (gensym^ 'si) `((orig . ,index))))
       (define nstart (parse start env))
       (define nend (parse end env))
       (expr-sum type ie nstart nend (parse body (hash-set env index ie)))]

      [`((product (,index ,start ,end) ,body) : ,type)
       (define ie (expr-var 'nat (gensym^ 'pi) `((orig . ,index))))
       (define nstart (parse start env))
       (define nend (parse end env))
       (expr-prd type ie nstart nend (parse body (hash-set env index ie)))]

      [`((array (,index ,size) ,body) : ,type)
       (define ie (expr-var 'nat (gensym^ 'pi) `((orig . ,index))))
       (define nsize (parse size env))
       (expr-arr type ie nsize (parse body (hash-set env index ie)))]

      [`((bucket ,start ,end ,reducer) : ,type)
       (expr-bucket type (parse start env) (parse end env) (parse-reducer reducer env (list (expr-var 'nat (gensym^ 'bki) '_))))]

      [`((match ,tst ,brnchs ...) : ,type)
       (expr-match type (parse tst env) (map (curryr parse-branch env) brnchs))]
      [`(bind ,v ,e)
       (define ve (expr-var '? (gensym^ 'bi) `((orig . ,v))))
       (expr-bind ve (parse e (hash-set env v ve)))]

      [`((superpose (,p ,m) ...) : ,type)
       (define nm (map (curryr parse env) m))
       (define np (map (curryr parse env) p))
       (expr-app type (expr-intrf 'superpose) (apply append (map list np nm)))]

      [`((datum ,k ,v) : ,typ)
       (dp "parse: datum: k ~a, v ~a, typ: ~a\n" k v typ)
       (define (get-datum kind val type)
         (match kind
           ['pair
            (match val
              [`(inl (et (konst ,v1) (et (konst ,v2) done)))
               (expr-app typ (expr-intrf 'cons) (list (parse v1 env) (parse v2 env)))])]
           ['true (expr-val typ 1)]
           ['false (expr-val typ 0)]))
       (get-datum k v typ)]

      [`((prob_ ,v1 % ,v2) : prob)
       (expr-app 'prob (expr-intrf 'real2prob)
                 (list (expr-val 'real (exact->inexact
                                        (/ (get-value v1) (get-value v2))))))]
      [`((real_ ,v1 % ,v2) : real)
       (expr-val 'real (exact->inexact (/ (get-value v1) (get-value v2))))]
      [`((nat_ ,v) : nat)
       (expr-val 'nat v)]
      [`((int_ ,v) : int)
       (expr-val 'int v)]
      [`((,rator ,rands ...) : ,type)
       (define randse (map (curryr parse env) rands))
       (expr-app type (expr-intrf rator) randse)]

      [`(,s : ,type)
       #:when (number? s)
       (expr-val type s)]
      [`(,s : ,type)
       #:when (and (symbol? s) (hash-has-key? env s))
       (define sb (hash-ref env s))
       (when (and (equal? (expr-var-type sb) 'bind)
                  (not (equal? type 'bind)))
         ;; (dp "parse: got new type for bind: ~a : ~a\n" s type)
         (set-expr-var-type! sb type))
       sb]
      ;; [`(,s : ,type)
      ;;  #:when (symbol? s)
      ;;  ;; (define s-info (hash-ref info s))
      ;;  (get-constant-value s-info type)]
      [s (hash-ref env s)]))

  ;; (define (get-constant-value sinfo t)
  ;;   (match t
  ;;     [`(array ,tarr)
  ;;      (define ainfo (assocv 'arrayinfo sinfo))
  ;;      (define constant? (assocv 'constant ainfo))
  ;;      (unless constant? (error "found non constant array value already removed"))
  ;;      (define tinfo (assocv 'typeinfo ainfo))
  ;;      (expr-app (get-type-with-info t sinfo)
  ;;                (expr-intrf 'constant-value-array)
  ;;                (list (expr-val 'nat  (assocv 'size ainfo)) (get-constant-value tinfo tarr)))]
  ;;     ['prob
  ;;      (define pinfo (assocv 'probinfo sinfo))
  ;;      (define cv (assocv 'constant pinfo))
  ;;      (unless cv (error "found non constant prob for constant value"))
  ;;      (expr-val 'prob cv)]
  ;;     ['nat
  ;;      (define ninfo (assocv 'natinfo sinfo))
  ;;      (define cv (assocv 'constant ninfo))
  ;;      (unless cv (error "found non constant prob for constant value"))
  ;;      (expr-val 'nat cv)]
  ;;     ['int
  ;;      (define ninfo (assocv 'intinfo sinfo))
  ;;      (define cv (assocv 'constant ninfo))
  ;;      (unless cv (error "found non constant prob for constant value"))
  ;;      (expr-val 'int cv)]
  ;;     ['real
  ;;      (define ninfo (assocv 'realinfo sinfo))
  ;;      (define cv (assocv 'constant ninfo))
  ;;      (unless cv (error "found non constant prob for constant value"))
  ;;      (expr-val 'real cv)]))


  (define (parse-reducer r env bind-vars)
    (define (use-bind-vars e env bind-vars)
      (match* (e bind-vars)
        [(`(bind ,v ,be) (cons bv rst))
         (expr-bind bv (use-bind-vars be (hash-set env v bv) rst))]
        [(ne bvs)
         #:when (not (equal? (car ne) 'bind))
         (parse ne env)]))
    (match r
      [`(r_split ,e ,ra ,rb)
       (reducer-split (use-bind-vars e env bind-vars) (parse-reducer ra env bind-vars) (parse-reducer rb env bind-vars))]
      [`(r_fanout ,ra ,rb)
       (reducer-fanout (parse-reducer ra env bind-vars) (parse-reducer rb env bind-vars))]
      [`(r_add ,i)
       (reducer-add (use-bind-vars i env bind-vars))]
      [`r_nop
       (reducer-nop)]
      [`(r_index ,i ,e ,rb)
       (define ni (use-bind-vars i env (cdr bind-vars)))
       (define ne (use-bind-vars e env bind-vars))
       (define nr (parse-reducer rb env (append bind-vars (list  (expr-var 'nat (gensym^ 'bi) '_)))))
       (reducer-index ni ne nr)]
      [else (error "unknown reducer " r)]))

  (define (parse-branch b env)
    (match b
      [`(,pat ,e)
       (expr-branch (parse-pat pat env) (parse e env))]
      [else (error "unknown match branch format " b)]))

  (define (parse-pat pat env)
    (define (pf f)
      (match f
        [`(pf_konst var) (pat-var)]
        [`(pf_ident) (pat-ident)]))
    (define (ps s)
      (match s
        [`(ps_et ,f ,s) (cons (pf f) (ps s))]
        [`(ps_done) '()]))
    (define (pc c)
      (match c
        [`(pc_inr ,c) (pc c)]
        [`(pc_inl ,s) (ps s)]))
    (match pat
      [`(pdatum true ,_)  (pat-true)]
      [`(pdatum false ,_) (pat-false)]
      [`(pdatum pair ,c)  (match-define (list a b) (pc c)) (pat-pair a b)]))
  (parse prg (make-immutable-hash)))

(define (parse s)
  (parse-fun (remove-curry s '())))