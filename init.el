;; Personal Information

(setq user-full-name "Tang Tong")
(setq user-mail-address "tangtong123@gmail.com")

(global-set-key (kbd "<f2>") (lambda ()
			       (interactive)
			       (find-file "~/.emacs.d/init.el")))

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

(load "org")

;; emms
(load "emms")


;; browser function
(setq browse-url-browser-function 'browse-url-generic
      browse-url-generic-program "google-chrome")


;; paredit-mode
(mapc (lambda (hook)
	(add-hook hook 'paredit-mode))
      '(emacs-lisp-mode-hook))

;; CEDET
(add-to-list 'load-path (concat dotfiles-dir "cedet/common"))
(require 'cedet)
(semantic-load-enable-code-helpers)
(semantic-load-enable-semantic-debugging-helpers)

(global-set-key (kbd "C-.") 'semantic-ia-fast-jump)
(global-set-key (kbd "C-,") 'semantic-mrub-switch-tags)
(global-set-key (kbd "C-\\") 'senator-fold-tag-toggle)









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


