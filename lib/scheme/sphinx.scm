; (group みたにして囲むべきかな(階層))
; (links 'ghc 'list)

(define (sphinx-section name :key (ch #\=) (up #f))
  (let* ((bar (make-string (* 3 (string-length name)) ch))
         (upbar (if up bar "")))
    #"
~upbar
~name
~bar
"))

(define (sphinx-list ls) 0)

(define (sphinx-section-test path :key (language #f))
  (define language (if (not language) language (path-extension path)))
  (and-let* ((ok (file-exists? path))
             (section (sphinx-section "test" :ch #\-))
             (file (sphinx-block (file->string path) :code-block language))
             (content ((get-run-process language) path))
             (result (sphinx-block content :block #t))
             )
   #"
~section
~file
~result
"))

(define (sphinx-warn msg)
  (let* ((indented (string-indent msg)))
  #"
.. warning::

~indented
"))

(define (sphinx-block-path path :key (linenos #f))
  (let1 code (path-extension path)
        (sphinx-block (file->string path) :code-block code :linenos linenos)))

(define (sphinx-block-js code id :key (onload #f))
  (let1 block (sphinx-block code :code-block "javascript")
  #"
~block

.. raw:: html

   <button id='~|id|'>RUN</button>
   <script>
     $('#~|id|').on('click', function(){ ~code });
   </script> 
"))

(define (sphinx-block-html code)
  (let* ((block (sphinx-block code :code-block "html"))
         (indented (string-indent code)))
  #"
~block

.. raw:: html

~indented
"))

(define (sphinx-block s :key (code-block #f) (block #f) (linenos #f) (toctree #f) (maxdepth #f))
  (define indented (s-indent s))
  (define arg-linenos (if linenos ":linenos:" ""))
  (cond
   ((string-null? indented) "")
   (block #"
::

~indented
")
   (code-block #"
.. code-block:: ~|code-block|
   ~arg-linenos

~indented
")
   (toctree (let* ((m (if maxdepth #":maxdepth: ~maxdepth" "")))
              #"
.. toctree::
    ~m

~indented
"))

;; .. literalinclude:: ~|sphinx-abspath|
;;    :language: c
;;    :lines: ~lines"
   )
)

(define (sphinx sphinx-abspath :key (grammer %cc) (cd (current-directory)))
  (define filepath (if (#/^\// sphinx-abspath)
                       #"~|cd|~sphinx-abspath"
                       (f-join cd sphinx-abspath)))
  (define file-string (file->string filepath))
  ((pa$ generator-from-file filepath grammer)
   (^[alist]
     (let*-values (((body) (assoc-ref alist 'body))
                   ((start end) (string-line-range file-string body))
                   ((start) (- start 1))
                   ((lines) (cond ((= start -1) "")
                                  ((= end -1) #"~|start|-")
                                  (else #"~|start|-~|end|")))
                   )
       alist)
     )))

; (define (sphinx-toctree-directory. :optional (dir "."))
(define-method sphinx-toctree-directory. (:optional (dir "."))
  (if (not (file-is-directory? dir))
      ""
  (let1 rsts (glob (build-path dir "*.rst"))
        (sphinx-block (string-join rsts "\n") :toctree #t :maxdepth 1))))

(define-method sphinx-toctree-directory. ((dirs <list>))
  (string-join-line (map sphinx-toctree-directory. dirs)))

; この関数は2回目以降有効っぽいは(１回目ではrstファイルが生成されてない)
(define (sphinx-toctree-directory :optional (dir "."))
  (--> 
   ((flip$ filter-map) (--ls dir)
    (^x (and-let* ((_ (file-exists? #"~|x|/index.rst"))
                   (p #"~|x|/index"))
                  p)))
   (sort it)
   (sphinx-block (string-join it "\n") :toctree #t :maxdepth 1)))

(define (sphinx-toctree :key (maxdepth #f) (glob #f) (pattern #f) (path #f))
  (set! maxdepth (if maxdepth (string-indent #":maxdepth: ~maxdepth") ""))
  (cond (glob #"
.. toctree::
~maxdepth
    :glob:

    ~glob
")
        (path (let1 p (string-join (map string-indent (if (pair? path) path (list path)))
                                   "\n")
                    #"
.. toctree::
~maxdepth

~p
"))
        (else (error "No"))))

(define (sphinx-todo s) #".. todo:: ~s")
(define (sphinx-contents :key (depth #f) (label #f))
  (let* ((d (if (number? depth) (string-indent #":depth: ~|depth|") "")))
    #".. contents::
~d
"))

(define (sphinx-ext-scm->rst scm)
  (regexp-replace #/\.scm/ scm ".rst"))

; [Filepath] -> IO String
(define-method sphinx-include-scm-list ((scm-path-list <pair>))
  (for-each sphinx-scm->rst scm-path-list)
  (sphinx-toctree :path (map sphinx-ext-scm->rst scm-path-list)))

(define-method sphinx-include-scm-list ((scm-path-list <pair>) (output <string>) :key header)
  (sphinx-scm->rst scm-path-list output :header header)
  (sphinx-toctree :path output))

(define (sphinx-load path)
  (let1 abspath (abs path)
        (if (not (file-exists? abspath))
            (error #"ERROR: ~abspath doesn't exist\n")
            (guard (e (else (format (standard-error-port) #"ERROR: ~abspath => ~e\n")))
                   (print (sphinx-section (sys-basename path)))

  ; TODO: use macro
  ;; (let1 old-path (current-directory)
  ;;       (current-directory (sys-dirname abspath))
        (load abspath)
         ;; (current-directory old-path))

            ))))

(define-method sphinx-scm->rst ((scm <string>) :key (header ""))
  (sphinx-scm->rst (list scm) (sphinx-ext-scm->rst scm) :header header))

(define-method sphinx-scm->rst ((scm-list <pair>) (output <string>) :key (header ""))
  (with-output-to-file output
    (^()
      (print header)
      (for-each sphinx-load scm-list))))

; create index.rst file in the dir
(define-method sphinx-create-index-in-directory ((dir <string>))
  (if (file-is-directory? dir)
  (let* ((header (string-join-line (list (sphinx-section dir :up #t) (sphinx-contents :depth 2))))
         (index #"~|dir|/index.rst")
         (files (glob #"~|dir|/*.scm")))
    (cond ((file-exists? index) (format (standard-error-port) #"SKIP: ~|index| already exists\n"))
          ((null? files) (format (standard-error-port) #"EMPTY: ~dir\n"))
          (else (sphinx-include-scm-list (sort files) index :header header))))))

(define-method sphinx-create-index-in-directory ((dirs <list>))
  (map sphinx-create-index-in-directory dirs))

(define (template$ str)
  (pa$ regexp-replace #/REPLACE/ str))

(define (template-map proc list template)
  (map (^x (proc ((template$ template) x))) list))

(define (language->command lang)
  (match (x->string lang)
         ("cpp" "cpe")
         ("c" "ce")
         ("node" "ne")
         ("py" "py")
         ("gosh" "s")
         ("emacs" "ee")
         ("java" "je")

         ("perl" "perl -E")
         ("php" "php -r")
         ("ruby" "ruby -e")
         ("ghc" "ghc -e")
         ("sh" "sh -c")
         ("zsh" "zsh -c")
         ))

(define (code->cmd code :key quote language argv)
  (let* ((esc (if (eq? quote #\')
                  (escape-single-quote code)
                  ; double quote でカコッた場合を記述
                  code))
         (quoted #"~|quote|~|esc|~|quote|")
         (cmd (language->command language)))
    #"~cmd ~quoted ~argv"))

(define (oneliner-run-str cmd :key language argv result-only)
  (let* ((ret (run-from-string cmd language argv))
         (bcmd (sphinx-block #"~cmd" :code-block language))
         (bret (sphinx-block #"~ret" :code-block "sh")))
    (if result-only
        bret
        (format "~a~a" bcmd bret))))

(define (oneliner-run-line cmd :key language quote argv)
  (let* ((line (if language (code->cmd cmd :quote quote :language language :argv argv) cmd))
         (ret (oneliner-run line)))
    (sphinx-block #"$ ~line\n~ret" :code-block "sh")))

(define (oneliner-run-path cmd :key language path)
  (let* ((ret (oneliner-run cmd)))
    (format "~a~a"
            (sphinx-block (file->string path) :code-block language)
            (sphinx-block #"~cmd\n~ret" :code-block "sh"))))

; TODO: quoteを自動識別  
; TODO: expected追加
(define (oneliner-run+ cmd :key (msg #f) (warn #f) (quote #\') (language #f) (path #f) (str #f) (argv "")
                       (result-only #f))
  (if msg (print msg))
  (if warn (print (sphinx-warn warn)))
  (print (cond (str (oneliner-run-str cmd :language language :argv argv :result-only result-only))
               (path (oneliner-run-path cmd :language language :path path))
               (else (oneliner-run-line cmd :language language :quote quote :argv argv)))))

; for typeless
(define ptodo ($ print $ sphinx-todo $))
(define (ps msg) (print (sphinx-section msg :ch #\-)))
(define pw ($ print $ sphinx-warn $))
(define run oneliner-run+)

(define-macro (sphinx-setup-function name)
  `(define (,name code . rest) (apply run code :language ',name rest)))

(let1 langs '(c cpp node perl php ruby py ghc sh zsh java)
      (eval-null `(begin ,@(map (^x `(sphinx-setup-function ,x)) langs))))

(define-macro (gosh cmd :key (str #f) (msg #f) (warn #f) :rest rest)
  (let1 c (if str cmd (format "~s" cmd))
   `(apply run ,c :language "gosh" :str ,str ',rest)))

(define-macro (emacs cmd :key (str #f) (msg #f) (warn #f) :rest rest)
  (let1 c (if str cmd (format "~s" cmd))
   `(apply run ,c :language "emacs" :str ,str ',rest)))

(define (js cmd :key (id #f) (onload #f) (msg #f) (warn #f))
  (let* ((id (if id id (x->string (gensym)))))
    (if msg (print msg))
    (if warn (print (sphinx-warn warn)))
    (print (sphinx-block-js cmd id :onload onload))))

(define (html cmd :key (id #f) (onload #f) (msg #f) (warn #f))
  (let* ((id (if id id (x->string (gensym)))))
    (if msg (print msg))
    (if warn (print (sphinx-warn warn)))
    (print (sphinx-block-html cmd))))

(define (sphinx-math-escape s)
  (-->
   s
   (regexp-replace-all #/\n/ it "\n$$")
   (regexp-replace-all #/\$/ it "\\")
  ))

;; TODO: 以下の拡張も追加できるようにする
;; \\newcommand{\\argmax}{\\mathop{\\rm arg~max}\\limits}
;; \\newcommand{\\argmin}{\\mathop{\\rm arg~min}\\limits}

(define (sphinx-block-math s)
  (let1 indented (string-indent (sphinx-math-escape s))
#"
.. math::
    :nowrap:

    \\begin{eqnarray}
    ~indented
    \\end{eqnarray}
"))

(define (math s)
  (print (sphinx-block-math s)))

; TODO: (group . body) (ps . body)みたいにして、グループ化する

(define (sphinx-run-from-path path :key (language #f) (argv #f))
  (set! language (if language language (path-extension path)))
  (let1 ret (run-from-path path :language language :argv argv)
        (print (sphinx-section (sys-basename path)))
        (print (format "~a~a"
                       (sphinx-block (file->string path) :code-block language)
                       (sphinx-block #"~ret" :code-block "sh")))))
