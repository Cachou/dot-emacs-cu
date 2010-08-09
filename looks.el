;; Turn off mouse interface early in startup to avoid momentary display

; (if (fboundp 'menu-bar-mode) (menu-bar-mode -1))
(if (fboundp 'tool-bar-mode) (tool-bar-mode 0))
(if (fboundp 'scroll-bar-mode) (scroll-bar-mode -1))

;; Font setting
(setq prefered-font "Monospace-14")

(if (font-info prefered-font)
    (set-frame-font prefered-font)
  (set-frame-font "Monospace-12"))

;; color-theme
(add-to-list 'load-path (concat dotfiles-dir "looks"))
(add-to-list 'load-path (concat dotfiles-dir "looks/color-theme-6.6.0"))

(require 'color-theme)
(setq color-theme-load-all-themes nil)

(require 'color-theme-tangotango)

;; select theme - first list element is for windowing system, second is for console/terminal
;; ;; Source : http://www.emacswiki.org/emacs/ColorTheme#toc9
(setq color-theme-choices 
      '(color-theme-tangotango color-theme-tangotango))

;; default-start
(funcall (lambda (cols)
    	   (let ((color-theme-is-global nil))
    	     (eval 
    	      (append '(if (window-system))
    		      (mapcar (lambda (x) (cons x nil)) 
    			      cols)))))
    	 color-theme-choices)

;; test for each additional frame or console
(require 'cl)
(fset 'test-win-sys 
      (funcall (lambda (cols)
    		 (lexical-let ((cols cols))
    		   (lambda (frame)
    		     (let ((color-theme-is-global nil))
		       ;; must be current for local ctheme
		       (select-frame frame)
		       ;; test winsystem
		       (eval 
			(append '(if (window-system frame)) 
				(mapcar (lambda (x) (cons x nil)) 
					cols)))))))
    	       color-theme-choices ))
;; hook on after-make-frame-functions
(add-hook 'after-make-frame-functions 'test-win-sys)

(color-theme-tangotango)


;;;; MISC.

(defalias 'yes-or-no-p 'y-or-n-p)

(setq visible-bell nil)

(setq inhibit-startup-message t)

(setq initial-scratch-message nil)

(setq scroll-margin 3
      scroll-conservatively 100000)

(show-paren-mode t)
(setq show-paren-style 'parentheses)

(mouse-avoidance-mode 'banish)

(setq frame-title-format "emacs@%b")

(auto-image-file-mode)

(global-font-lock-mode t)

(blink-cursor-mode -1)

;;;; Mode Line

(line-number-mode 1)

(column-number-mode 1)

(size-indication-mode 1)

;;; Frame Size
(add-to-list 'default-frame-alist '(height . 24))
(add-to-list 'default-frame-alist '(width . 80))

;; linum
(global-linum-mode 1)

;; fringe-mode
(set-fringe-mode 'minimal)