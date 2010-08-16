(global-set-key (kbd "C-x C-j") 'ffap)

(global-set-key (kbd "<f4>") '(lambda ()
				(interactive)
				(kill-buffer (current-buffer))))

(global-set-key (kbd "<f5>") (lambda ()
			       (interactive)
			       (switch-to-buffer "*scratch*")))


(setq mouse-yank-at-point t)

(setq kill-ring-max 200)

(setq default-fill-column 60)

(setq sentence-end "\\([。！？]\\|……\\|[.?!][]\"')}]*\\($\\|[ \t]\\)\\)[ \t\n]*")
(setq sentence-end-double-space nil)

(setq enable-recursive-minibuffers t)

(setq default-major-mode 'text-mode)

(global-set-key (kbd "RET") 'newline-and-indent)

;; expand
(global-set-key (kbd "M-/") 'hippie-expand)

(setq hippie-expand-try-functions-list 
      '(try-expand-dabbrev 
	try-expand-dabbrev-visible 
	try-expand-dabbrev-all-buffers 
	try-expand-dabbrev-from-kill 
	try-complete-file-name-partially 
	try-complete-file-name 
	try-expand-all-abbrevs 
	try-expand-list 
	try-expand-line 
	try-complete-lisp-symbol-partially 
	try-complete-lisp-symbol))

;; backups
(setq backup-directory-alist '(("." . "~/.emacs-file-backups")))
(setq make-backup-files t)
(setq kept-old-versions 5)
(setq kept-new-versions 10)
(setq delete-old-versions t)
(setq backup-by-copying t)
(setq version-control t)

;; clipboard enable
(setq x-select-enable-clipboard t)

;; text-mode
(add-hook 'text-mode-hook 'turn-on-auto-fill)

;; spell check



;; change mode
(global-set-key (kbd "M-m") (make-sparse-keymap "change mode"))
(global-set-key (kbd "M-m t") 'text-mode)
(global-set-key (kbd "M-m e") 'emacs-lisp-mode)