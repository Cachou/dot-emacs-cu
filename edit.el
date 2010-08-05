(global-set-key (kbd "C-x C-j") 'ffap)

(global-set-key (kbd "<f4>") '(lambda ()
				(interactive)
				(kill-buffer (current-buffer))))

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