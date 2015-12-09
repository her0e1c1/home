(use srfi-1)
(use srfi-13)  ; string-null? string-every
(use srfi-14)  ; char-set:whitespace

(use srfi-27)  ; random
(use srfi-42)  ; range
(use srfi-43)  ; vector-*

(use util.stream)
(use util.list)
(use util.match)

(use text.tr)
(use file.util)
(use parser.peg)  ; parsec

(use gauche.cgen)
(use gauche.generator)
(use gauche.process)
(use gauche.parseopt)
(use gauche.parameter)
(use gauche.sequence)
(use gauche.termios)
(use gauche.test)

; (use gauche.internal)

(define-macro (import-only module . syms)
  `(begin
     ,@(map (lambda (sym) `(define ,sym (with-module ,module ,sym))) syms)))

(import-only gauche.internal extended-pair? extended-cons pair-attribute-get pair-attribute-set! pair-attributes)

; s '($ p $ + 1 2 3)' => 6
; d describe
; sys-lstat
(define df define)
(define p print)
(define f format)
(define b begin)
(define i iota)
(define s subseq)
; (define l lambda)  ; ^
(define m1 macroexpand-1)
(define-macro (m . body)  ; (m MACRO)
  `(macroexpand (quote ,body)))
(define-macro (m- body) ; (m (MACRO))
  `(macroexpand (quote ,body)))
; hash
(define hm make-hash-table)
(define hp hash-table-put!)
(define hg hash-table-get)
; (define pp (pa$ print))
(define rv receive)
(define exec process-output->string)
(define execl process-output->string-list)
(define IN (standard-input-port))
(define OUT (standard-output-port))
(define ERR (standard-error-port))

(define s-join string-join)

(define f? file-exists?)
; use as it is
; time
; sys-sleep

; sliceを作る
; (~ a 1)
; (~ a 1 2)

(define (path p)
  (string-append (home-directory) p))

; s '(p (string-slices "abcd" 2))' => (ab cd)
(define (string-slices str len)
    (map list->string (slices (string->list str) len)))

;; anaforic
(define-macro (aif pred t . f)
  `(let ((it ,pred))
     (if it ,t ,@f)))

; combinator
(define (~$ . selectors)
  (cut apply ~ <> selectors))
; ((~$ 1) "abc")  "b"

(define (slot-ref*$ . selectors)
  (cut apply slot-ref* <> selectors))

(define (flip f x y) (f y x))
; ((pa$ flip map) (iota 10) print)


;; path
(define (path-normalize . paths)
  ; (resolve-path)
   (expand-path
    (string-join paths "/")))
(define path-n path-normalize)

(define (path-join . ls)
  (let loop ((path ls)
             (acc '()))
    (let* ((n (null? path))
           (p (and (not n) (car path)))
           (next (and (not n) (cdr path)))
           (p0 (and p (not (string-null? p)) (char=? #\/ (~ p 0))))
           )
      (cond (n (apply path-normalize (reverse acc)))
            (p0 (loop next (list (string-append "/" (string-trim p #\/)))))
            (else (loop next (cons p acc)))
            ))))

; TODO: lazy let*
; (llet* ((a 1) (b 2)) (if #t a b))  ; 必要になってから評価

; 正規化あった
; (sys-normalize-pathname "~//a/./d/b" :expand #t :absolute #t :canonicalize #t)
; "/home/me/a/d/b"

(define rra regexp-replace-all)
(define rr regexp-replace)
(define-macro  (rl regex s vars . body)
  `(rxmatch-let (rxmatch ,regex ,s)
                ,vars
                ,@body))
; ((rxmatch) 1) ; => aに束縛とかよさげ?
; #"~a~b"
; (#/REGEX/ "strng")
(define (rm rxp str)
  (if-let1 m (rxmatch rxp str)
       (list
        (m 0)
        (m 'before 0)
        (m 'after 0)

        (rxmatch-num-matches m)
        (rxmatch-named-groups m)
        (rxmatch-start m)
        (rxmatch-end m)
        (rxmatch-substring m)
        (rxmatch-substrings m)
        (rxmatch-positions m)
        (rxmatch-before m)
        (rxmatch-after m)

        (regexp->string rxp)
        (regexp-num-groups rxp)
        (regexp-named-groups rxp)

        (rxmatch->string rxp str)
        )
       #f))

(define-macro (it! value)
  `(set! it ,value))

; ... は 0 個を含む任意個の式 (,@の代わりっぽい)

; (guard (var cond) cddr)
; (guard (exc) 1)
; (guard (exc) (/ 1 0))
; (guard (exc (else 0)) (/ 1 0))

; 関数にすると、ローカル変数に代入する意味のないものになる
;; (define-macro (null! x)
;;   (guard (_ (else `(define ,x '())))
;;           x `(set! ,x '())))

(define-macro (-> x form . more)
  (if (pair? more)
      `(-> (-> ,x ,form) ,@more )
      (if (pair? form)
          `(,(car form) ,x ,@(cdr form))
          `(,form ,x))))

(define-macro (->> x form . more)
  (if (pair? more)
      `(->> (->> ,x ,form) ,@more )
      (if (pair? form)
          `(,(car form) ,@(cdr form) ,x)
                    `(,form ,x))))

(define-macro (--> x form . more)
  (if (pair? more)
      `(--> (--> ,x ,form) ,@more)
      (if (pair? form)
          `(let1 it ,x (,(car form) ,@(cdr form)))
          `(,form ,x))))

(define-macro (-?> x form . more)
  (let1 v (gensym)
        (if (pair? more)
            `(if-let1 ,v (-?> ,x ,form) (-?> ,v ,@more ) #f )
            (if (pair? form)
                `(,(car form) ,x ,@(cdr form))
                `(,form ,x)))))

(define-macro (-?>> x form . more)
  (let1 v (gensym)
        (if (pair? more)
            `(if-let1 ,v (-?>> ,x ,form) (-?>> ,v ,@more ) #f )
            (if (pair? form)
                `(,(car form) ,@(cdr form) ,x)
                            `(,form ,x)))))

(define-macro (awhile pred . body)
  `(do ((it ,pred ,pred))
       ((or (not it) (eof-object? it)) it)
     ,@body))

(define-macro (amap f ls)
  `(map (lambda (it) ,f) ,ls))

(define-macro (afilter f ls)
  `(filter (lambda (it) ,f) ,ls))

(define-macro (aeach f ls)
  `(for-each (lambda (it) ,f) ,ls))

(use srfi-13)
(define-reader-directive 'hd
  (^(sym port ctx)
    (let1 delimiter (string-trim-both (read-line port))
          (do ((line (read-line port) (read-line port))
               (document '() (cons line document)))
              ((string=? line delimiter)
               (string-concatenate-reverse (intersperse "\n" document)))))))
#|
(display #!hd END
aa
bb
END 
)
|#

; "\\0" => #!r"\0"
; #!""がいいせめて
(define-reader-directive 'r
  (^(sym port ctx)
    (if (char=? #\" (read-char port))
        (do ((ch (read-char port) (read-char port))
             (str '() (cons ch str)))
            ((char=? #\" ch) (list->string (reverse str))))
        (error "\" is needed"))))
; s '(rr #/(\w*)/ "abc" #!r"\0 ~1")'


; (clear)
(define clear
  (let1 c (process-output->string '("clear"))
        (lambda () (display c))))

(define orig~ ~)
(define-macro (~ . body)
  (case (length body)
    ((0) '())
    ((1) (car body))
    ((2) `(orig~ ,(car body) ,(cadr body)))
    ((3) `(subseq ,(car body) ,(cadr body) ,(caddr body)))
    ))



; commands
; ls/find/which/grep/xargs/csv/cat
; peco(anything)

(define (--ls . dirs)
  (let* ((keys (filter keyword? dirs))
         (opt-abs (memq :abs keys))
         (opt-c (not (memq :c keys)))
         (opt-e (not (memq :e keys)))
         (opt-a (not (memq :a keys)))
         (opt-all (not (memq :all keys)))
         (sdirs (filter string? dirs))
         (sdirs (if (null? sdirs) (list "./") sdirs)))
    (let1 lists (map (^x (--> x
                         (sys-normalize-pathname it :absolute opt-abs :canonicalize opt-c :expand opt-e)
                         (build-path it "*")
                         (glob it)
                         ))
                     sdirs)
          (if opt-a (apply append lists) lists))))

; (ls ~/.emacs.d :abs :e)
(define-macro (ls . dirs)
  `(--ls ,@(map x->string-without-keyword dirs)))

(define (x->string-without-keyword x)
  (if (keyword? x) x (x->string x)))

(define-macro (! . args)
  (let1 args (map x->string args)
        (sys-system (string-join args " "))))

(define (which cmd)
  (let1 found (filter-map (^x (and-let* ((p (build-path x cmd))
                                         (q (file-is-executable? p)))
                                        p))
                          (string-split (sys-getenv "PATH") ":"))
        (if (null? found) #f (car found))))


(define type-equals '(number? string? char? char-set?))
(define (same? a b) 1)

; (list->string (to #\あ #\ん))
; (char-set->list #[a-z])
; (char-set->list #[あ-ん])
(define (to a b)
  (let ((an (x->number a))
        (bn (x->number b)))
    (if (> an bn) (error "a < b"))
    (map integer->char (iota (+ 1 (- bn an)) an))))
        

(define (-find a)
  (map -find (--ls a)))


; (df a (lcons* 1 2 3 (sys-sleep 10) 5))
; size-of
;; (define (len obj)
;;   (cond
;;    ((string? obj) (string-length obj))
;;    ((pair? obj) (length obj))
;;    (else 0)))


;; (p (peg-parse-string ($string "abc") "abc"))
;; (p (peg-parse-string ($char #\a) "abc"))
;; (p (peg-parse-string ($one-of #[a-z]) "cd"))
;; (p (peg-parse-string ($none-of #[a-z]) "A"))
; (p (peg-parse-string anychar "a"))
; (p (peg-parse-string digit "123"))

(define (%compare test-type accessors)
  (^[e o] (and (test-type o)
               (every equal? e (map (cut <> o) accessors)))))

(define-syntax test-succ
  (syntax-rules ()
    [(_ label expect parse input)
     (test* #"~label (success)" expect
            (peg-parse-string parse input))]))

(define-syntax test-fail
  (syntax-rules ()
    [(_ label expect parse input)
     (test* #"~label (failure)" expect
            (guard (e [(<parse-error> e)
                       (list (ref e 'position) (ref e 'objects))]
                      [else e])
                   (peg-parse-string parse input)
                   (error "test-fail failed")))]))
(define-syntax test-char
  (syntax-rules ()
    ((_ parse expin unexpin message)
     (begin
       (test-succ (symbol->string 'parse)
                  (string-ref expin 0)
                  parse expin)
       (test-fail (symbol->string 'parse)
                  '(0 message)
                  parse unexpin)))))

(define pps peg-parse-string)
(define (P a b)
  (p (peg-parse-string a b)))
; (p (peg-parse-string anychar "a"))
; (p (peg-parse-string digit "123"))
; (p (peg-parse-string eof ""))
; (p (peg-parse-string anychar ""))
;; (P ($or ($string "abc")
;;          ($string "efg"))
;;     ; "abc"))
;;     "efg")
;; (p(equal? "bar"
;;             (pps
;;  ($try ($seq ($string "foo") ($string "bar")))
;;  "foobar")))

; 消費しない?
;; (P ($or ($string "abc")
;;         ($string "aef")
;;         )
;;    "aef")

; (pps ($do [x ($string "a")] [y ($string "b")] ($return (cons x y)) ) "ab")
;(pps ($lift cons ($string "a") ($string "b")) "ab")

; #[^a-b]
; (char-set-complement #[a-b])

;; (define-macro (rva a)
;;   `(recieve ret ,a ret))

; (define-values (a b . c) (values 1 2 3 4))
