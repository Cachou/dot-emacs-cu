(setq org-directory "~/Notes")

(setq org-default-notes-file (concat org-directory "/notes.org"))

(add-to-list 'load-path (concat dotfiles-dir "org-7.01g/lisp"))
(add-to-list 'load-path (concat dotfiles-dir "org-7.01g/contrib/lisp"))
(require 'org-install)
(add-to-list 'auto-mode-alist '("\\.org\\'" . org-mode))

;; key bindings
(add-hook 'org-mode-hook (lambda ()
			   (local-set-key (kbd "RET") 'org-return)))
(global-set-key "\C-cl" 'org-store-link)
(global-set-key "\C-ca" 'org-agenda)
(global-set-key "\C-cb" 'org-iswitchb)
(global-set-key "\C-cc" 'org-capture)

(global-set-key (kbd "<f9>") (lambda ()
			       (interactive)
			       (find-file "~/Notes/notes.org")))
(global-set-key (kbd "<f10>") (lambda ()
				(interactive)
				(find-file "~/Notes/journal.org")))

;; agenda
(setq org-agenda-files `(,org-default-notes-file))

;; capture
(setq org-capture-templates
      '(
	;; ("n" "Notes" entry (file+headline "~/Notes/notes.org" "Notes")
	;;  "* %? %^G\n %T")
	("j" "Journal" entry (file+datetree "~/Notes/journal.org")
	 "* %?\nEntered on %U\n")))

;; todo 

;; tag 
(setq org-tag-alist '((:startgroup . nil)
		      ("Emacs" . ?e) ("Elisp" . ?l)
		      (:endgroup . nil)))
;; startup

;; editing
(setq org-hide-leading-stars t)
(setq org-special-ctrl-a/e t)
(setq org-special-ctrl-k t)
(setq org-completion-use-ido t)
(setq org-return-follows-link t)
