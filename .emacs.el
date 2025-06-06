;;; Basics
(require 'package)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
(add-to-list 'package-archives '("melpa-stable" . "https://stable.melpa.org/packages/") t)

;;; Backwards compatibility
(unless (package-installed-p 'use-package)
  (package-install 'use-package))
(require 'use-package)
			     
(use-package ef-themes
  :ensure t
  :config
  (load-theme 'ef-bio t))

(tool-bar-mode -1)
(scroll-bar-mode -1)
(menu-bar-mode -1)
(blink-cursor-mode -1)
(hl-line-mode)

(use-package moody
  :ensure t
  :config
  (moody-replace-mode-line-front-space)
  (moody-replace-mode-line-buffer-identification)
  (moody-replace-vc-mode))

(use-package company
  :ensure t
  :hook (prog-mode . company-mode))

(use-package vertico
  :ensure t
  :init
  (setq completion-ignore-case t)
  (add-to-list 'completion-styles 'substring)
  :config
  (vertico-mode))

(use-package marginalia
  :ensure t
  :config
  (marginalia-mode))

;;; Org setup
(require 'org)
(setq org-ellipsis "⤵") ;;; Remove this when running in terminal mode
(define-key org-mode-map (kbd "<tab>")
	    (lambda ()
	      (interactive)
	      (org-cycle-internal-local))) ;;; TODO Just modify 'org-cycle' to use 'org-cycle-internal-local' instead of doing this; this is dumb
(define-key org-mode-map (kbd "C-<tab>") 'org-cycle) ;;; Bandaid for above

(add-hook 'org-mode-hook 'org-indent-mode)
(use-package org-modern
  :ensure t
  :config
  (setopt org-modern-fold-stars
	  '(
	    ("▶" . "▼")
	    ("▷" . "▽")
	    ("◉" . "○")
	    ("▹" . "▿")
	    ("▸" . "▾")
	    ))
  (global-org-modern-mode))
(unless (package-installed-p 'org-modern-indent)
  (package-vc-install "https://github.com/jdtsmith/org-modern-indent"))
(use-package org-modern-indent
  :config
  (add-hook 'org-mode-hook #'org-modern-indent-mode 90))

(use-package xenops
  :ensure t
  :hook (org-mode . xenops-mode)
  :config
  (setq xenops-math-image-scale-factor 1.75)
  :bind (:map xenops-mode-map
	      ("C-c m r" . xenops-render)
	      ("C-c m u" . xenops-reveal)))

;;; Custom Config-Related Setup
(defvar wget-fetch-filename nil
  "For communicating between the function 'wget-fetch' and its sentinel.")
(defun wget-fetch (link)
  "Download LINK using wget, into the 'user-emacs-directory'."
  (setq wget-fetch-filename (file-name-nondirectory link))
  (if (file-exists-p (concat user-emacs-directory wget-fetch-filename))
      (let (
            (inhibit-message t)
            )
        (message (concat wget-fetch-filename " is already downloaded, so not downloading!"))
        )
    (let (
           (prev-dir default-directory)
           )
      (setq default-directory user-emacs-directory)
      (unwind-protect
          (set-process-sentinel
           (start-process "WGET-FETCH" "*WGET-FETCH*" "wget" "-q" link)
           (lambda (proc happen)
             (when (string-match "finished" happen)
               (message (concat wget-fetch-filename " has been downloaded!"))
               )
             )
           )
        (setq default-directory prev-dir)
        )
      )
    )
  )

;;; General Programming-oriented Setup
(use-package lsp-mode
  :ensure t)
(use-package consult
  :ensure t)
(use-package affe
  :ensure t
  :config
  (setq affe-count 60))
(use-package treemacs
  :ensure t
  :config
  (require 'dired)
  (define-key dired-mode-map (kbd "C-c t") 'treemacs))

(use-package yasnippet
  :ensure t
  :config
  (yas-global-mode 1))
(use-package yasnippet-snippets
  :ensure t)

(use-package magit
  :ensure t)
(use-package forge ;;; Not compatible with pre-Emacs=29 releases
  :ensure t)

;;; Haphazard, be careful with older Emacs installs (pre 29.4)
(unless (package-installed-p 'disproject)
  (package-vc-install "https://github.com/aurtzy/disproject"))
(require 'disproject)
(define-key ctl-x-map (kbd "p") 'disproject-dispatch) ;;; Overrides default binds, careful

;;; DM setup
(wget-fetch "raw.githubusercontent.com/Djiq/opendream-mode/refs/heads/master/opendream-mode.el")
(load-file (concat user-emacs-directory "opendream-mode.el"))
(let (
      (gh-link "https://github.com/SpaceManiac/SpacemanDMM/releases/download/suite-1.10/dm-langserver")
      (dest "~/.emacs.d/dm-langserver")
      )
  (if (eq system-type 'windows-nt)
      (progn
	(wget-fetch (concat gh-link ".exe"))
	(setq dest (concat dest ".exe"))
	)
    (wget-fetch gh-link))
  (lsp-register-client
   (make-lsp-client
    :new-connection (lsp-stdio-connection dest)
    :major-modes '(opendream-mode)
    :server-id 'dreammaker-server))
  )  
(add-hook 'opendream-mode-hook #'lsp-mode) ;;; If opendream-mode was loaded /before/ lsp-mode, this wouldn't be necessary, but I like everything in one place!
(add-to-list 'lsp-language-id-configuration '("opendream-mode" . "dreammaker"))

;;; C setup
(defvar compile-and-run-pass-bucket nil
  "Intermezzo var to pass directory that 'compile-c-file' is running in to 'compile-and-run-hook'.")
(defun compile-c-file ()
  "Compiles the current C file, and runs it."
  (interactive)
  (if (or
       (eq major-mode 'c-mode)
       (eq major-mode 'c-ts-mode))
      (let (
            (cur-buf-name (buffer-name (current-buffer)))
            )
        (save-buffer)
        (setq compile-and-run-pass-bucket (list (file-name-directory (buffer-file-name (current-buffer))) cur-buf-name))
        (compile (concat "gcc -O0 -g -o " (file-name-sans-extension cur-buf-name) " " cur-buf-name))
        )
    (message "This is not a C buffer!")
      )
  )

(defun compile-and-run-hook (comp-buf out-str)
  "Uses OUT-STR from COMP-BUF to run the executable generated by 'compile-c-file'."
  (when (and
         (string-match "finished" out-str)
         (not (string-match "error" out-str)))
    (let (
          (src-name (nth 1 compile-and-run-pass-bucket))
          (exec-dir (car compile-and-run-pass-bucket))
          )
      (select-window (get-buffer-window comp-buf))
      (unless (string-match "*shell*" (buffer-name (window-buffer (next-window))))
          (split-window-below nil (get-buffer-window comp-buf))
          )
      (other-window 1)
      (shell)
      (goto-char (point-max))
      (insert (concat "cd " exec-dir))
      (comint-send-input)
      (accept-process-output (get-buffer-process (current-buffer)) 1 0 t)
      (goto-char (point-max))
      (insert (concat "./" (file-name-sans-extension src-name)))
      (goto-char (point-max))
      (comint-send-input)
      (select-window (get-buffer-window src-name))
      )
    )
  )
(add-hook 'compilation-finish-functions 'compile-and-run-hook)
(add-hook 'c-mode-hook
	  (lambda ()
	    (local-set-key (kbd "C-c -") 'compile-c-file)))
(add-hook 'c-ts-mode-hook
	  (lambda ()
	    (local-set-key (kbd "C-c -") 'compile-c-file)))

;;; General Keybind Setup

(global-set-key (kbd "C-c b") 'eval-buffer)
(global-set-key (kbd "C-c m i")
		(lambda ()
		  (interactive)
		  (find-file user-init-file) ;;; TODO Add handling for byte-compiled case
		  ))

;;; Fun
;;; Tetris tweaks, (WASD tweaks)
(require 'tetris)
(define-key tetris-mode-map (kbd "w") 'tetris-rotate-prev)
(define-key tetris-mode-map (kbd "a") 'tetris-move-left)
(define-key tetris-mode-map (kbd "d") 'tetris-move-right)
(define-key tetris-mode-map (kbd "s") 'tetris-move-down)
(define-key tetris-mode-map (kbd "e") 'tetris-move-bottom)
;;; Feed setup
(use-package elfeed
  :ensure t
  :config
  (add-to-list 'elfeed-feeds "https://planet.emacslife.com/atom.xml")
  (add-to-list 'elfeed-feeds "https://xkcd.com/rss.xml")
  )
;;; Chess setup
(use-package chess
  :ensure t)

;;; The config ends here
(provide 'init)
