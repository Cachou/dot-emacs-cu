;; Personal Information

(setq user-full-name "Tang Tong")
(setq user-mail-address "tangtong123@gmail.com")

;; Load path etc.

(setq dotfiles-dir (file-name-directory
                    (or (buffer-file-name) load-file-name)))

(add-to-list 'load-path dotfiles-dir)

;; auto-mode-alist 


;; load looks
(load "looks")


;; load edit
(load "edit")

;; ido mode
(require 'ido)
(ido-mode t)

;; org-mode
(add-to-list 'load-path (concat dotfiles-dir "org-7.01g/lisp"))
(add-to-list 'load-path (concat dotfiles-dir "org-7.01g/contrib/lisp"))
(require 'org-install)
(add-to-list 'auto-mode-alist '("\\.org\\'" . org-mode))
(add-hook 'org-mode-hook 'turn-on-font-lock)
(global-set-key "\C-cl" 'org-store-link)
(global-set-key "\C-ca" 'org-agenda)
(global-set-key "\C-cb" 'org-iswitchb)
(setq org-agenda-files '("~/test/elisp"))


;; paredit-mode
(mapc (lambda (hook)
	(add-hook hook 'paredit-mode))
      '(emacs-lisp-mode-hook))

;; CEDET
(add-to-list 'load-path (concat dotfiles-dir "cedet/common"))
(require 'cedet)
(semantic-load-enable-code-helpers)
(semantic-load-enable-semantic-debugging-helpers)

(global-set-key (kbd "<M-right>") 'semantic-ia-fast-jump)
(global-set-key (kbd "<M-left>") 'semantic-mrub-switch-tags)







;;;;;;;;;;;;;;;; ELPA ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; This was installed by package-install.el.
;;; This provides support for the package system and
;;; interfacing with ELPA, the package archive.
;;; Move this code earlier if you want to reference
;;; packages in your .emacs.
(when
    (load
     (expand-file-name "~/.emacs.d/elpa/package.el"))
  (package-initialize))
