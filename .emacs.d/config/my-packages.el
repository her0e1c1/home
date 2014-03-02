(defvar my/installing-package-list
  '(
    ;w3m  ; w3mコマンドが必須
    ;icalendar
    php-mode
    ;scala-mode
    ;markdown-mode
    scss-mode
    haskell-mode
    ;google-c-style
    yaml-mode
    ;open-junk-file
    ;ace-jump-mode  ; evil-ace-jump-modeで代用
    expand-region
    multiple-cursors
    projectile
    zenburn-theme
    rainbow-delimiters
    flycheck
    yasnippet
    dash
    s
    f
    ht
    helm
    helm-swoop
    smartparens
    auto-complete
    bookmark+
    recentf-ext
    dired+
    js2-mode
    evil
    key-chord
    ))

(defvar my/package-archives 
  '(("melpa" . "http://melpa.milkbox.net/packages/")
    ("marmalade" . "http://marmalade-repo.org/packages/")))

(provide 'my-packages)
