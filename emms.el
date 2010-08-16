(add-to-list 'load-path (concat dotfiles-dir "emms/lisp"))

(require 'emms-setup)
(emms-standard)
(setq emms-player-list '(emms-player-mplayer))
(setq emms-seek-seconds 8)


(global-set-key (kbd "M-=") (lambda ()
			      (interactive)
			      (emms-seek-forward)))
(global-set-key (kbd "M--") (lambda ()
			      (interactive)
			      (emms-seek-backward)))
(global-set-key (kbd "M-p") 'emms-pause)
(global-set-key (kbd "C-M-s") 'emms-stop)

(global-set-key (kbd "<f12>") 'emms)

(add-hook 'emms-playlist-mode-hook
	  (lambda ()
	    (local-set-key (kbd "M-r") 'emms-toggle-repeat-track)
	    (local-set-key (kbd "C-M-r") 'emms-toggle-repeat-playlist)))

(add-hook 'dired-mode-hook
	  (lambda ()
	    (local-set-key (kbd "M-a") 'emms-add-dired)))