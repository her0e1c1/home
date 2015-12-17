
(define (sphinx-section name :key (ch #\=) (up #f))
  (let* ((bar (make-string (string-length name) ch))
         (upbar (if up bar "")))
    #"
~upbar
~name
~bar
"))

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

(define (sphinx-run-path-ruby path)
  (let* ((file (sphinx-block-path path))
         (rslt (sphinx-block (run-ruby path) :block #t)))
    #"~file \n~path => ~rslt"))

       ;(sphinx-toctree :glob
(define (sphinx-toctree :key (maxdepth #f) (glob #f) (pattern #f) (path #f))
  (cond (glob #"
.. toctree::
    :glob:

    ~glob
")
        (path (let1 p (string-join (map string-indent (if (pair? path) path (list path)))
                                   "\n")
                    #"
.. toctree::

~p
"))
        (else (error "No"))))
;;   (let* ((m (if maxdepth #":maxdepth: ~maxdepth" "")))
;;     #"
;; .. toctree::
;;     ~m

;; ~indented
;; "))

  ;; ((flip$ filter-map) (ls "langs")
  ;;  (^x (and-let* ((_ (file-exists? #"~|x|/index.rst"))
  ;;                 (p #"~|x|/index"))
  ;;                p)))

;;    (sphinx-block (string-join it "\n") :toctree #t :maxdepth 1)

;; ;;    (toctree (let* ((m (if maxdepth #":maxdepth: ~maxdepth" "")))
;;               #"
;; .. toctree::
;;     ~m

;; ~indented
;; "))

; TODO: create a c file if it is necessary

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

(define-method sphinx-include-scm-list ((scm-path-list <pair>) (output <string>))
  (sphinx-scm->rst scm-path-list output)
  (sphinx-toctree :path output))

(define-method sphinx-scm->rst ((scm <string>))
  (if (not (file-exists? scm))
      (error #"~path.scm doesn't exist")
   (let1 rst (sphinx-ext-scm->rst scm)
         (with-output-to-file rst
           (^() (load scm))))))

(define-method sphinx-scm->rst ((scm-list <pair>) (output <string>))
  (with-output-to-file output
    (^() (for-each (^p (if (file-exists? p) (load p))) scm-list))))
