;;; emms-lastfm-client.el --- Last.FM Music API

;; Copyright (C) 2009, 2010  Free Software Foundation, Inc.

;; Author: Yoni Rabkin <yonirabkin@member.fsf.org>

;; Keywords: emms, lastfm

;; EMMS is free software; you can redistribute it and/or modify it
;; under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.
;;
;; EMMS is distributed in the hope that it will be useful, but WITHOUT
;; ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
;; or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
;; License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with EMMS; see the file COPYING.  If not, write to the Free
;; Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
;; MA 02110-1301, USA.

;;; Commentary:
;;
;; Definitive information on how to setup and use this package is
;; provided in the wonderful Emms manual, in the /doc directory of the
;; Emms distribution.

;;; Code:

(require 'md5)
(require 'parse-time)
(require 'emms)
(require 'emms-source-file)
(require 'xml)

(defvar emms-lastfm-client-username nil
  "Valid Last.fm account username.")

(defvar emms-lastfm-client-api-key nil
  "Key for the Last.fm API.")

(defvar emms-lastfm-client-api-secret-key nil
  "Secret key for the Last.fm API.")

(defvar emms-lastfm-client-api-session-key nil
  "Session key for the Last.fm API.")

(defvar emms-lastfm-client-token nil
  "Authorization token for API.")

(defvar emms-lastfm-client-api-base-url
  "http://ws.audioscrobbler.com/2.0/"
  "URL for API calls.")

(defvar emms-lastfm-client-session-key-file
  (concat (file-name-as-directory emms-directory)
	  "emms-lastfm-client-sessionkey")
  "File for storing the Last.fm API session key.")

(defvar emms-lastfm-client-playlist-valid nil
  "True if the playlist hasn't expired.")

(defvar emms-lastfm-client-playlist-timer nil
  "Playlist timer object.")

(defvar emms-lastfm-client-playlist nil
  "Latest Last.fm playlist.")

(defvar emms-lastfm-client-track nil
  "Latest Last.fm track.")

(defvar emms-lastfm-client-original-next-function nil
  "Original `-next-function'.")

(defvar emms-lastfm-client-playlist-buffer-name "*Emms Last.fm*"
  "Name for non-interactive Emms Last.fm buffer.")

(defvar emms-lastfm-client-playlist-buffer nil
  "Non-interactive Emms Last.fm buffer.")

(defvar emms-lastfm-client-client-identifier "emm"
  "Client identifier for Emms (Last.fm define this, not us).")

(defvar emms-lastfm-client-submission-protocol-number "1.2.1"
  "Version of the submissions protocol to which Emms conforms.")

(defvar emms-lastfm-client-published-version "1.0"
  "Version of this package published to the Last.fm service.")

(defvar emms-lastfm-client-submission-session-id nil
  "Scrobble session id, for now-playing and submission requests.")

(defvar emms-lastfm-client-submission-now-playing-url nil
  "URL that should be used for a now-playing request.")

(defvar emms-lastfm-client-submission-url nil
  "URL that should be used for submissions")

(defvar emms-lastfm-client-track-play-start-timestamp nil
  "UTC timestamp.")

(defvar emms-lastfm-client-submission-api t
  "Use the Last.fm submission API if true, otherwise don't.")

(defvar emms-lastfm-client-inhibit-cleanup nil
  "If true, do not perform clean-up after `emms-stop'.")

(defvar emms-lastfm-client-api-method-dict
  '((auth-get-token    . ("auth.gettoken"
			  emms-lastfm-client-auth-get-token-ok
			  emms-lastfm-client-auth-get-token-failed))
    (auth-get-session  . ("auth.getsession"
			  emms-lastfm-client-auth-get-session-ok
			  emms-lastfm-client-auth-get-session-failed))
    (radio-tune        . ("radio.tune"
			  emms-lastfm-client-radio-tune-ok
			  emms-lastfm-client-radio-tune-failed))
    (radio-getplaylist . ("radio.getplaylist"
			  emms-lastfm-client-radio-getplaylist-ok
			  emms-lastfm-client-radio-getplaylist-failed))
    (track-love        . ("track.love"
			  emms-lastfm-client-track-love-ok
			  emms-lastfm-client-track-love-failed))
    (track-ban         . ("track.ban"
			  emms-lastfm-client-track-ban-ok
			  emms-lastfm-client-track-ban-failed)))
  "Mapping symbols to method calls. This is a list of cons pairs
  where the CAR is the symbol name of the method and the CDR is a
  list whose CAR is the method call string, CADR is the function
  to call on a success and CADDR is the function to call on
  failure.")

;;; ------------------------------------------------------------------
;;; API method call
;;; ------------------------------------------------------------------

(defun emms-lastfm-client-get-method (method)
  "Return the associated method cons for the symbol METHOD."
  (let ((m (cdr (assoc method emms-lastfm-client-api-method-dict))))
    (if (not m)
	(error "method not in dictionary: %s" method)
      m)))

(defun emms-lastfm-client-get-method-name (method)
  "Return the associated method string for the symbol METHOD."
  (let ((this (nth 0 (emms-lastfm-client-get-method method))))
    (if (not this)
	(error "no name string registered for method: %s" method)
      this)))

(defun emms-lastfm-client-get-method-ok (method)
  "Return the associated OK function for METHOD.

This function is called when the method call returns
successfully."
  (let ((this (nth 1 (emms-lastfm-client-get-method method))))
    (if (not this)
	(error "no OK function registered for method: %s" method)
      this)))

(defun emms-lastfm-client-get-method-fail (method)
  "Return the associated fail function for METHOD.

This function is called when the method call returns a failure
status message."
  (let ((this (nth 2 (emms-lastfm-client-get-method method))))
    (if (not this)
	(error "no fail function registered for method: %s" method)
      this)))

(defun emms-lastfm-client-encode-arguments (arguments)
  "Encode ARGUMENTS in UTF-8 for the Last.fm API."
  (let ((result nil))
    (while arguments
      (setq result
	    (append result
		    (list
		     (cons
		      (encode-coding-string (caar arguments) 'utf-8)
		      (encode-coding-string (cdar arguments) 'utf-8)))))
      (setq arguments (cdr arguments)))
    result))

(defun emms-lastfm-client-construct-arguments (str arguments)
  "Return a concatenation of arguments for the URL."
  (cond ((not arguments) str)
	(t (emms-lastfm-client-construct-arguments
	    (concat str "&" (caar arguments) "=" (url-hexify-string (cdar arguments)))
	    (cdr arguments)))))

(defun emms-lastfm-client-construct-method-call (method arguments)
  "Return a complete URL method call for METHOD with ARGUMENTS.

This function includes the cryptographic signature."
  (concat emms-lastfm-client-api-base-url "?"
	  "method=" (emms-lastfm-client-get-method-name method)
	  (emms-lastfm-client-construct-arguments
	   "" arguments)
	  "&api_sig="
	  (emms-lastfm-client-construct-signature method arguments)))

(defun emms-lastfm-client-construct-write-method-call (method arguments)
  "Return a complete POST body method call for METHOD with ARGUMENTS.

This function includes the cryptographic signature."
  (concat "method=" (emms-lastfm-client-get-method-name method)
	  (emms-lastfm-client-construct-arguments
	   "" arguments)
	  "&api_sig="
	  (emms-lastfm-client-construct-signature method arguments)))

;;; ------------------------------------------------------------------
;;; Response handler
;;; ------------------------------------------------------------------

(defun emms-lastfm-client-handle-response (method xml-response)
  "Dispatch the handler functions of METHOD for XML-RESPONSE."
  (let ((status (cdr (assoc 'status (nth 1 (car xml-response)))))
	(data (cdr (cdr (car xml-response)))))
    (when (not status)
      (error "error parsing status from: %s" xml-response))
    (cond ((string= status "failed")
	   (funcall (emms-lastfm-client-get-method-fail method) data))
	  ((string= status "ok")
	   (funcall (emms-lastfm-client-get-method-ok method) data))
	  (t (error "unknown response status %s" status)))))

;;; ------------------------------------------------------------------
;;; Unathorized request token for an API account
;;; ------------------------------------------------------------------

(defun emms-lastfm-client-construct-urt ()
  "Return a request for an Unauthorized Request Token."
  (let ((arguments
	 (emms-lastfm-client-encode-arguments
	  `(("api_key" . ,emms-lastfm-client-api-key)))))
    (emms-lastfm-client-construct-method-call
     'auth-get-token arguments)))

(defun emms-lastfm-client-make-call-urt ()
  "Make method call for Unauthorized Request Token."
  (let* ((url-request-method "POST"))
    (let ((response
	   (url-retrieve-synchronously
	    (emms-lastfm-client-construct-urt))))
      (emms-lastfm-client-handle-response
       'auth-get-token
       (with-current-buffer response
	 (xml-parse-region (point-min) (point-max)))))))

;; example response: ((lfm ((status . \"ok\")) \"\" (token nil
;; \"31cab3398a9b46cf7231ef84d73169cf\")))

;;; ------------------------------------------------------------------
;;; Signatures
;;; ------------------------------------------------------------------
;;
;; From [http://www.last.fm/api/desktopauth]:
;;
;; Construct your api method signatures by first ordering all the
;; parameters sent in your call alphabetically by parameter name and
;; concatenating them into one string using a <name><value>
;; scheme. So for a call to auth.getSession you may have:
;;
;;   api_keyxxxxxxxxmethodauth.getSessiontokenxxxxxxx
;;
;; Ensure your parameters are utf8 encoded. Now append your secret
;; to this string. Finally, generate an md5 hash of the resulting
;; string. For example, for an account with a secret equal to
;; 'mysecret', your api signature will be:
;;
;;   api signature = md5("api_keyxxxxxxxxmethodauth.getSessiontokenxxxxxxxmysecret")
;;
;; Where md5() is an md5 hashing operation and its argument is the
;; string to be hashed. The hashing operation should return a
;; 32-character hexadecimal md5 hash.

(defun emms-lastfm-client-construct-lexi (arguments)
  "Return ARGUMENTS sorted in lexicographic order."
  (let ((lexi (sort arguments
		    '(lambda (a b) (string< (car a) (car b)))))
	(out ""))
    (while lexi
      (setq out (concat out (caar lexi) (cdar lexi)))
      (setq lexi (cdr lexi)))
    out))

(defun emms-lastfm-client-construct-signature (method arguments)
  "Return request signature for METHOD and ARGUMENTS."
  (let ((complete-arguments
	 (append arguments
		 `(("method" .
		    ,(emms-lastfm-client-get-method-name method))))))
    (md5
     (concat (emms-lastfm-client-construct-lexi complete-arguments)
	     emms-lastfm-client-api-secret-key))))

;;; ------------------------------------------------------------------
;;; General error handling
;;; ------------------------------------------------------------------

;; Each method call provides its own error codes, but if we don't want
;; to code a handler for a method we call this instead:
(defun emms-lastfm-client-default-error-handler (data)
  "Default method failure handler."
  (let ((errorcode (cdr (assoc 'code (nth 1 (cadr data)))))
	(message (nth 2 (cadr data))))
    (when (not (and errorcode message))
      (error "failed to read errorcode or message: %s %s"
	     errorcode message))
    (error "method call failed with code %s: %s"
	   errorcode message)))

;;; ------------------------------------------------------------------
;;; Request authorization from the user
;;; ------------------------------------------------------------------

(defun emms-lastfm-client-ask-for-auth ()
  "Open a Web browser for authorizing the application."
  (when (not (and emms-lastfm-client-api-key
		  emms-lastfm-client-token))
    (error "API key and authorization token needed."))
  (browse-url
   (format "http://www.last.fm/api/auth/?api_key=%s&token=%s"
	   emms-lastfm-client-api-key
	   emms-lastfm-client-token)))

;;; ------------------------------------------------------------------
;;; Parse XSPF
;;; ------------------------------------------------------------------

(defun emms-lastfm-client-xspf-header (data)
  "Return an alist representing the XSPF header of DATA."
  (let (out
	(orig data))
    (setq data (cadr data))
    (while data
      (when (and (car data)
		 (listp (car data))
		 (= (length (car data)) 3))
	(setq out (append out (list (cons (nth 0 (car data))
					  (nth 2 (car data)))))))
      (setq data (cdr data)))
    (if (not out)
	(error "failed to parse XSPF header from: %s" orig)
      out)))

(defun emms-lastfm-client-xspf-tracklist (data)
  "Return the start of the track-list in DATE."
  (nthcdr 3 (nth 11 (cadr data))))

(defun emms-lastfm-client-xspf-header-date (header-alist)
  "Return the date parameter from HEADER-ALIST."
  (let ((out (cdr (assoc 'date header-alist))))
    (if (not out)
	(error "could not read date from header alist: %s"
	       header-alist)
      out)))

(defun emms-lastfm-client-xspf-header-expiry (header-alist)
  "Return the expiry parameter from HEADER-ALIST."
  (let ((out (cdr (assoc 'link header-alist))))
    (if (not out)
	(error "could not read expiry from header alist: %s"
	       header-alist)
      out)))

(defun emms-lastfm-client-xspf-header-creator (header-alist)
  "Return the creator parameter from HEADER-ALIST."
  (let ((out (cdr (assoc 'creator header-alist))))
    (if (not out)
	(error "could not read creator from header alist: %s"
	       header-alist)
      out)))

(defun emms-lastfm-client-xspf-playlist (data)
  "Return the playlist from the XSPF DATA."
  (let ((playlist (car (nthcdr 11 data))))
    (if (not playlist)
	(error "could not read playlist from: %s" data)
      playlist)))

;; note: the result of this function can be used with
;; `emms-lastfm-client-xspf-get' as well
(defun emms-lastfm-client-xspf-extension (track)
  "Return the Extension portion of TRACK."
  (let ((this (copy-sequence track))
	(cont t))
    (while (and cont this)
      (when (consp this)
	(let ((head (car this)))
	  (when (consp head)
	    (when (equal 'extension (car head))
	      (setq cont nil)))))
      (when cont
	(setq this (cdr this))))
    (if this
	(car this)
      (error "could not find track extension data"))))

(defun emms-lastfm-client-xspf-get (node track)
  "Return data associated with NODE in TRACK."
  (let ((result nil))
    (while track
      (when (consp track)
	(let ((this (car track)))
	  (when (and (consp this)
		     (= (length this) 3)
		     (symbolp (nth 0 this))
		     (stringp (nth 2 this))
		     (equal (nth 0 this) node))
	    (setq result (nth 2 this)))))
      (setq track (cdr track)))
    (if (not result)
	nil
      result)))

;;; ------------------------------------------------------------------
;;; Timers
;;; ------------------------------------------------------------------

;; timed playlist invalidation is a part of the Last.fm API
(defun emms-lastfm-client-set-timer (header)
  "Start timer countdown to playlist invalidation"
  (when (not header)
    (error "can't set timer with no header data"))
  (let ((expiry (parse-integer
		 (emms-lastfm-client-xspf-header-expiry header))))
    (setq emms-lastfm-client-playlist-valid t)
    (when emms-lastfm-client-playlist-timer
      (cancel-timer emms-lastfm-client-playlist-timer))
    (setq emms-lastfm-client-playlist-timer
	  (run-at-time
	   expiry nil
	   '(lambda ()
	      (cancel-timer emms-lastfm-client-playlist-timer)
	      (setq emms-lastfm-client-playlist-valid nil))))))

;;; ------------------------------------------------------------------
;;; Player
;;; ------------------------------------------------------------------

;; this should return `nil' to the track-manager when the playlist has
;; been exhausted
(defun emms-lastfm-client-consume-next-track ()
  "Pop and return the next track from the playlist or nil."
  (when emms-lastfm-client-playlist
    (if emms-lastfm-client-playlist-valid
	(let ((track (car emms-lastfm-client-playlist)))
	  ;; we can only request each track once so we pop it off the
	  ;; playlist
	  (setq emms-lastfm-client-playlist
		(if (stringp (cdr emms-lastfm-client-playlist))
		    (cddr emms-lastfm-client-playlist)
		  (cdr emms-lastfm-client-playlist)))
	  track)
      (error "playlist invalid"))))

(defun emms-lastfm-client-set-lastfm-playlist-buffer ()
  "Set `emms-playlist-buffer' to a be an Emms lastfm buffer."
  (when (buffer-live-p emms-lastfm-client-playlist-buffer)
    (kill-buffer emms-lastfm-client-playlist-buffer))
  (setq emms-lastfm-client-playlist-buffer
	(emms-playlist-new
	 emms-lastfm-client-playlist-buffer-name))
  (setq emms-playlist-buffer emms-lastfm-client-playlist-buffer))

(defun emms-lastfm-client-timestamp ()
  "Return a UNIX UTC timestamp."
  (format-time-string "%s" (current-time) t))

(defun emms-lastfm-client-load-next-track ()
  "Queue the next track from Last.fm."
  (with-current-buffer emms-lastfm-client-playlist-buffer
    (let ((inhibit-read-only t))
      (widen)
      (delete-region (point-min)
		     (point-max)))
    (if emms-lastfm-client-playlist
	(let ((track (emms-lastfm-client-consume-next-track)))
	  (setq emms-lastfm-client-track track)
	  (setq emms-lastfm-client-track-play-start-timestamp
		(emms-lastfm-client-timestamp))
	  (let ((emms-lastfm-client-inhibit-cleanup t))
	    (emms-play-url
	     (emms-lastfm-client-xspf-get 'location track))))
      (emms-lastfm-client-make-call-radio-getplaylist)
      (emms-lastfm-client-load-next-track))))

(defun emms-lastfm-client-love-track ()
  "Submit the currently playing track with a `love' rating."
  (interactive)
  (if emms-lastfm-client-track
      (let ((result (emms-lastfm-client-make-async-submission-call
		     emms-lastfm-client-track 'love)))
	;; the following submission API call looks redundant but
	;; isn't; indeed, it might be done away with in a future
	;; version of the Last.fm API (see API docs)
	(emms-lastfm-client-make-call-track-love)
	(when (equal result 'track-successfully-submitted)
	  (message "track sucessfully submitted with a `love' rating")))
    (error "no current track")))

(defun emms-lastfm-client-ban-track ()
  "Submit currently playing track with a `ban' rating and skip."
  (interactive)
  (if emms-lastfm-client-track
      (let ((result (emms-lastfm-client-make-async-submission-call
		     emms-lastfm-client-track 'ban)))
	(emms-lastfm-client-make-call-track-ban)
	(when (equal result 'track-successfully-submitted)
	  (message "track sucessfully submitted with a `ban' rating"))
	(emms-lastfm-client-load-next-track))
    (error "no current track")))

;; call this `-track-advance' to avoid confusion with Emms'
;; `-next-track-' mechanism
(defun emms-lastfm-client-track-advance (&optional first)
  "Move to the next track in the playlist."
  (interactive)
  (when (equal emms-playlist-buffer
	       emms-lastfm-client-playlist-buffer)
    (when (and emms-lastfm-client-submission-api
	       (not first))
      (let ((result (emms-lastfm-client-make-async-submission-call
		     emms-lastfm-client-track nil)))
	(when (equal result 'track-successfully-submitted)
	  (message "track sucessfully submitted"))))
    (emms-lastfm-client-load-next-track)))

(defun emms-lastfm-client-next-function ()
  "Replacement function for `emms-next-noerror'."
  (if (equal emms-playlist-buffer
	     emms-lastfm-client-playlist-buffer)
      (emms-lastfm-client-track-advance)
    (funcall emms-lastfm-client-original-next-function)))

(defun emms-lastfm-client-clean-after-stop ()
  "Kill the emms-lastfm buffer."
  (when (and (equal emms-playlist-buffer
		    emms-lastfm-client-playlist-buffer)
	     (not emms-lastfm-client-inhibit-cleanup))
    (kill-buffer emms-lastfm-client-playlist-buffer)
    (setq emms-lastfm-client-playlist-buffer nil)))

(defun emms-lastfm-client-play-playlist ()
  "Entry point to play tracks from Last.fm."
  (emms-lastfm-client-set-lastfm-playlist-buffer)
  (when (not (equal emms-player-next-function
		    'emms-lastfm-client-next-function))
    (add-to-list 'emms-player-stopped-hook
		 'emms-lastfm-client-clean-after-stop)
    (setq emms-lastfm-client-original-next-function
	  emms-player-next-function)
    (setq emms-player-next-function
	  'emms-lastfm-client-next-function))
  (emms-lastfm-client-track-advance t))

;; stolen from Tassilo Horn's original emms-lastfm.el
(defun emms-lastfm-client-read-artist ()
  "Read an artist name from the user."
  (let ((artists nil))
    (when (boundp 'emms-cache-db)
      (maphash
       #'(lambda (file track)
	   (let ((artist (emms-track-get track 'info-artist)))
	     (when artist
	       (add-to-list 'artists artist))))
       emms-cache-db))
    (if artists
	(emms-completing-read "Artist: " artists)
      (read-string "Artist: "))))

(defun emms-lastfm-client-initialize-session ()
  "Run per-session functions."
  (emms-lastfm-client-check-session-key))

;;; ------------------------------------------------------------------
;;; Stations
;;; ------------------------------------------------------------------

(defun emms-lastfm-client-play-user-station (username url)
  "Play URL for USERNAME."
  (when (not (and username url))
    (error "username and url must be set"))
  (emms-lastfm-client-initialize-session)
  (emms-lastfm-client-make-call-radio-tune
   (format url username))
  (emms-lastfm-client-make-call-radio-getplaylist)
  (emms-lastfm-client-handshake)
  (emms-lastfm-client-play-playlist))

(defun emms-lastfm-client-play-similar-artists (artist)
  "Play a Last.fm station with music similar to ARTIST."
  (interactive (list (emms-lastfm-client-read-artist)))
  (when (not (stringp artist))
    (error "not a string: %s" artist))
  (emms-lastfm-client-initialize-session)
  (emms-lastfm-client-make-call-radio-tune
   (format "lastfm://artist/%s/similarartists" artist))
  (emms-lastfm-client-make-call-radio-getplaylist)
  (emms-lastfm-client-handshake)
  (emms-lastfm-client-play-playlist))

(defun emms-lastfm-client-play-loved ()
  "Play a Last.fm station with \"loved\" tracks."
  (interactive)
  (emms-lastfm-client-play-user-station
   emms-lastfm-client-username
   "lastfm://user/%s/loved"))

(defun emms-lastfm-client-play-neighborhood ()
  "Play a Last.fm station with \"neighborhood\" tracks."
  (interactive)
  (emms-lastfm-client-play-user-station
   emms-lastfm-client-username
   "lastfm://user/%s/neighbours"))

(defun emms-lastfm-client-play-library ()
  "Play a Last.fm station with \"library\" tracks."
  (interactive)
  (emms-lastfm-client-play-user-station
   emms-lastfm-client-username
   "lastfm://user/%s/personal"))

(defun emms-lastfm-client-play-user-loved (user)
  (interactive "sLast.fm username: ")
  (emms-lastfm-client-play-user-station
   user
   "lastfm://user/%s/loved"))

(defun emms-lastfm-client-play-user-neighborhood (user)
  (interactive "sLast.fm username: ")
  (emms-lastfm-client-play-user-station
   user
   "lastfm://user/%s/neighbours"))

(defun emms-lastfm-client-play-user-library (user)
  (interactive "sLast.fm username: ")
  (emms-lastfm-client-play-user-station
   user
   "lastfm://user/%s/personal"))

;;; ------------------------------------------------------------------
;;; Information
;;; ------------------------------------------------------------------

(defun emms-lastfm-client-convert-track (track)
  "Convert a Last.fm track to an Emms track."
  (let ((emms-track (emms-dictionary '*track*)))
    (emms-track-set emms-track 'name
		    (emms-lastfm-client-xspf-get 'location track))
    (emms-track-set emms-track 'info-artist
		    (emms-lastfm-client-xspf-get 'creator track))
    (emms-track-set emms-track 'info-title
		    (emms-lastfm-client-xspf-get 'title track))
    (emms-track-set emms-track 'info-album
		    (emms-lastfm-client-xspf-get 'album track))
    (emms-track-set emms-track 'info-playing-time
		    (/
		     (parse-integer
		      (emms-lastfm-client-xspf-get 'duration track))
		     1000))
    emms-track))

(defun emms-lastfm-client-show-track (track)
  "Return description of TRACK."
  (decode-coding-string
   (format emms-show-format
	   (emms-track-description
	    (emms-lastfm-client-convert-track track)))
   'utf-8))

(defun emms-lastfm-client-show ()
  "Display a description of the current track."
  (interactive)
  (if emms-player-playing-p
      (message
       (emms-lastfm-client-show-track emms-lastfm-client-track))
    nil))

;;; ------------------------------------------------------------------
;;; Desktop application authorization [http://www.last.fm/api/desktopauth]
;;; ------------------------------------------------------------------

(defun emms-lastfm-client-user-authorization ()
  "Ask user to authorize the application."
  (interactive)
  (emms-lastfm-client-make-call-urt)
  (emms-lastfm-client-ask-for-auth))

(defun emms-lastfm-client-get-session ()
  "Retrieve and store session key."
  (interactive)
  (emms-lastfm-client-make-call-get-session)
  (emms-lastfm-client-save-session-key
   emms-lastfm-client-api-session-key))

;;; ------------------------------------------------------------------
;;; method: auth.getToken [http://www.last.fm/api/show?service=265]
;;; ------------------------------------------------------------------

(defun emms-lastfm-client-auth-get-token-ok (data)
  "Function called when auth.getToken succeeds."
  (setq emms-lastfm-client-token
	(nth 2 (cadr data)))
  (if (or (not emms-lastfm-client-token)
	  (not (= (length emms-lastfm-client-token) 32)))
      (error "could not read token from response %s" data)
    (message "Emms Last.FM auth.getToken method call success.")))

(defun emms-lastfm-client-auth-get-token-failed (data)
  "Function called when auth.getToken fails."
  (emms-lastfm-client-default-error-handler data))

;;; ------------------------------------------------------------------
;;; method: auth.getSession [http://www.last.fm/api/show?service=125]
;;; ------------------------------------------------------------------

(defun emms-lastfm-client-construct-get-session ()
  "Return an auth.getSession request string."
  (let ((arguments
	 (emms-lastfm-client-encode-arguments
	  `(("token"   . ,emms-lastfm-client-token)
	    ("api_key" . ,emms-lastfm-client-api-key)))))
    (emms-lastfm-client-construct-method-call
     'auth-get-session arguments)))

(defun emms-lastfm-client-make-call-get-session ()
  "Make auth.getSession call."
  (let* ((url-request-method "POST"))
    (let ((response
	   (url-retrieve-synchronously
	    (emms-lastfm-client-construct-get-session))))
      (emms-lastfm-client-handle-response
       'auth-get-session
       (with-current-buffer response
	 (xml-parse-region (point-min) (point-max)))))))

(defun emms-lastfm-client-save-session-key (key)
  "Store KEY."
  (let ((buffer (find-file-noselect
		 emms-lastfm-client-session-key-file)))
    (set-buffer buffer)
    (erase-buffer)
    (insert key)
    (save-buffer)
    (kill-buffer buffer)))

(defun emms-lastfm-client-load-session-key ()
  "Return stored session key."
  (let ((file (expand-file-name emms-lastfm-client-session-key-file)))
    (setq emms-lastfm-client-api-session-key
	  (if (file-readable-p file)
	      (with-temp-buffer
		(emms-insert-file-contents file)
		(goto-char (point-min))
		(buffer-substring-no-properties
		 (point) (point-at-eol)))
	    nil))))

(defun emms-lastfm-client-check-session-key ()
  "Signal an error condition if there is no session key."
  (if emms-lastfm-client-api-session-key
      emms-lastfm-client-api-session-key
    (if (emms-lastfm-client-load-session-key)
	emms-lastfm-client-api-session-key
      (error "no session key for API access"))))

(defun emms-lastfm-client-auth-get-session-ok (data)
  "Function called on DATA if auth.getSession succeeds."
  (let ((session-key (nth 2 (nth 5 (cadr data)))))
    (cond (session-key
	   (setq emms-lastfm-client-api-session-key session-key)
	   (message "Emms Last.fm session key retrieval successful"))
	  (t (error "failed to parse session key data %s" data)))))

(defun emms-lastfm-client-auth-get-session-failed (data)
  "Function called on DATA if auth.getSession fails."
  (emms-lastfm-client-default-error-handler data))

;;; ------------------------------------------------------------------
;;; method: radio.tune [http://www.last.fm/api/show?service=160]
;;; ------------------------------------------------------------------

(defun emms-lastfm-client-construct-radio-tune (station)
  "Return a request to tune to STATION."
  (let ((arguments
	 (emms-lastfm-client-encode-arguments
	  `(("sk"   . ,emms-lastfm-client-api-session-key)
	    ("station" . ,station)
	    ("api_key" . ,emms-lastfm-client-api-key)))))
    (emms-lastfm-client-construct-write-method-call
     'radio-tune arguments)))

(defun emms-lastfm-client-make-call-radio-tune (station)
  "Make call to tune to STATION."
  (let ((url-request-method "POST")
	(url-request-extra-headers
	 `(("Content-type" . "application/x-www-form-urlencoded")))
	(url-request-data
	 (emms-lastfm-client-construct-radio-tune station)))
    (let ((response
	   (url-retrieve-synchronously
	    emms-lastfm-client-api-base-url)))
      (emms-lastfm-client-handle-response
       'radio-tune
       (with-current-buffer response
	 (xml-parse-region (point-min) (point-max)))))))

(defun emms-lastfm-client-radio-tune-failed (data)
  "Function called on DATA when tuning fails."
  (emms-lastfm-client-default-error-handler data))

(defun emms-lastfm-client-radio-tune-ok (data)
  "Set the current radio station according to DATA."
  (let ((response (cdr (cadr data)))
	data)
    (while response
      (when (and (listp (car response))
		 (car response)
		 (= (length (car response)) 3))
	(add-to-list 'data (cons (caar response)
				 (car (cdr (cdr (car response)))))))
      (setq response (cdr response)))
    (when (not data)
      (error "could not parse station information %s" data))
    data))

;;; ------------------------------------------------------------------
;;; method: radio.getPlaylist [http://www.last.fm/api/show?service=256]
;;; ------------------------------------------------------------------

(defun emms-lastfm-client-construct-radio-getplaylist ()
  "Return a request for a playlist from the tuned station."
  (let ((arguments
	 (emms-lastfm-client-encode-arguments
	  `(("sk"   . ,emms-lastfm-client-api-session-key)
	    ("api_key" . ,emms-lastfm-client-api-key)))))
    (emms-lastfm-client-construct-write-method-call
     'radio-getplaylist arguments)))

(defun emms-lastfm-client-make-call-radio-getplaylist ()
  "Make call for playlist from the tuned station."
  (let ((url-request-method "POST")
	(url-request-extra-headers
	 `(("Content-type" . "application/x-www-form-urlencoded")))
	(url-request-data
	 (emms-lastfm-client-construct-radio-getplaylist)))
    (let ((response
	   (url-retrieve-synchronously
	    emms-lastfm-client-api-base-url)))
      (emms-lastfm-client-handle-response
       'radio-getplaylist
       (with-current-buffer response
	 (xml-parse-region (point-min) (point-max)))))))

(defun emms-lastfm-client-radio-getplaylist-failed (data)
  "Function called on DATA when retrieving a playlist fails."
  'stub-needs-to-handle-playlist-issues
  (emms-lastfm-client-default-error-handler data))

(defun emms-lastfm-client-list-filter (l)
  "Remove strings from the roots of list L."
  (let (acc)
    (while l
      (when (listp (car l))
	(push (car l) acc))
      (setq l (cdr l)))
    (reverse acc)))

(defun emms-lastfm-client-radio-getplaylist-ok (data)
  "Function called on DATA when retrieving a playlist succeeds."
  (let ((header (emms-lastfm-client-xspf-header data))
	(tracklist (emms-lastfm-client-xspf-tracklist data)))
    (emms-lastfm-client-set-timer header)
    (setq emms-lastfm-client-playlist
	  (emms-lastfm-client-list-filter tracklist))))

;;; ------------------------------------------------------------------
;;; method: track.love [http://www.last.fm/api/show?service=260]
;;; ------------------------------------------------------------------

(defun emms-lastfm-client-construct-track-love ()
  "Return a request for setting current track rating to `love'."
  (let ((arguments
	 (emms-lastfm-client-encode-arguments
	  `(("sk"      . ,emms-lastfm-client-api-session-key)
	    ("api_key" . ,emms-lastfm-client-api-key)
	    ("track"   . ,(emms-lastfm-client-xspf-get
			   'title emms-lastfm-client-track))
	    ("artist"  . ,(emms-lastfm-client-xspf-get
			   'creator emms-lastfm-client-track))))))
    (emms-lastfm-client-construct-write-method-call
     'track-love arguments)))

(defun emms-lastfm-client-make-call-track-love ()
  "Make call for setting track rating to `love'."
  (let ((url-request-method "POST")
	(url-request-extra-headers
	 `(("Content-type" . "application/x-www-form-urlencoded")))
	(url-request-data
	 (emms-lastfm-client-construct-track-love)))
    (let ((response
	   (url-retrieve-synchronously
	    emms-lastfm-client-api-base-url)))
      (emms-lastfm-client-handle-response
       'track-love
       (with-current-buffer response
	 (xml-parse-region (point-min) (point-max)))))))

(defun emms-lastfm-client-track-love-failed (data)
  "Function called with DATA when setting `love' rating fails."
  'stub-needs-to-handle-track-love-issues
  (emms-lastfm-client-default-error-handler data))

(defun emms-lastfm-client-track-love-ok (data)
  "Function called with DATA after `love' rating succeeds."
  'track-love-succeed)

;;; ------------------------------------------------------------------
;;; method: track.ban [http://www.last.fm/api/show?service=261]
;;; ------------------------------------------------------------------

(defun emms-lastfm-client-construct-track-ban ()
  "Return a request for setting current track rating to `ban'."
  (let ((arguments
	 (emms-lastfm-client-encode-arguments
	  `(("sk"      . ,emms-lastfm-client-api-session-key)
	    ("api_key" . ,emms-lastfm-client-api-key)
	    ("track"   . ,(emms-lastfm-client-xspf-get
			   'title emms-lastfm-client-track))
	    ("artist"  . ,(emms-lastfm-client-xspf-get
			   'creator emms-lastfm-client-track))))))
    (emms-lastfm-client-construct-write-method-call
     'track-ban arguments)))

(defun emms-lastfm-client-make-call-track-ban ()
  "Make call for setting track rating to `ban'."
  (let ((url-request-method "POST")
	(url-request-extra-headers
	 `(("Content-type" . "application/x-www-form-urlencoded")))
	(url-request-data
	 (emms-lastfm-client-construct-track-ban)))
    (let ((response
	   (url-retrieve-synchronously
	    emms-lastfm-client-api-base-url)))
      (emms-lastfm-client-handle-response
       'track-ban
       (with-current-buffer response
	 (xml-parse-region (point-min) (point-max)))))))

(defun emms-lastfm-client-track-ban-failed (data)
  "Function called with DATA when setting `ban' rating fails."
  'stub-needs-to-handle-track-ban-issues
  (emms-lastfm-client-default-error-handler data))

(defun emms-lastfm-client-track-ban-ok (data)
  "Function called with DATA after `ban' rating succeeds."
  'track-ban-succeed)

;;; ------------------------------------------------------------------
;;; Submission API [http://www.last.fm/api/submissions]
;;; ------------------------------------------------------------------

;; 1.3 Authentication Token for Web Services Authentication: token =
;; md5(shared_secret + timestamp)

(defun emms-lastfm-client-make-token-for-web-services (timestamp)
  (when (not (and emms-lastfm-client-api-secret-key timestamp))
    (error "secret and timestamp needed to make an auth token"))
  (md5 (concat emms-lastfm-client-api-secret-key timestamp)))

;; Handshake: The initial negotiation with the submissions server to
;; establish authentication and connection details for the session.

(defun emms-lastfm-client-make-handshake-call ()
  "Return a submission protocol handshake string."
  (when (not (and emms-lastfm-client-submission-protocol-number
		  emms-lastfm-client-client-identifier
		  emms-lastfm-client-published-version
		  emms-lastfm-client-username))
    (error "missing variables to generate handshake call"))
  (let ((timestamp (format-time-string "%s")))
    (concat
     "http://post.audioscrobbler.com/?hs=true"
     "&p=" emms-lastfm-client-submission-protocol-number
     "&c=" emms-lastfm-client-client-identifier
     "&v=" emms-lastfm-client-published-version
     "&u=" emms-lastfm-client-username
     "&t=" timestamp
     "&a=" (emms-lastfm-client-make-token-for-web-services timestamp)
     "&api_key=" emms-lastfm-client-api-key
     "&sk=" emms-lastfm-client-api-session-key)))

(defun emms-lastfm-client-handshake ()
  "Make handshake call."
  (if emms-lastfm-client-playlist-valid
      (let* ((url-request-method "GET"))
	(let ((response
	       (url-retrieve-synchronously
		(emms-lastfm-client-make-handshake-call))))
	  (emms-lastfm-client-handle-handshake
	   (with-current-buffer response
	     (buffer-substring-no-properties
	      (point-min) (point-max))))))
    (error "cannot handshake without initializing the client")))

(defun emms-lastfm-client-handle-handshake (response)
  (let ((ok200 "HTTP/1.1 200 OK"))
    (when (not (string= ok200 (substring response 0 15)))
      (error "server not responding correctly"))
    (with-temp-buffer
      (insert response)
      (goto-char (point-min))
      (re-search-forward "\n\n")
      (let ((status (buffer-substring-no-properties
		     (point-at-bol) (point-at-eol))))
	(cond ((string= status "OK")
	       (forward-line)
	       (setq emms-lastfm-client-submission-session-id
		     (buffer-substring-no-properties
		      (point-at-bol) (point-at-eol)))
	       (forward-line)
	       (setq emms-lastfm-client-submission-now-playing-url
		     (buffer-substring-no-properties
		      (point-at-bol) (point-at-eol)))
	       (forward-line)
	       (setq emms-lastfm-client-submission-url
		     (buffer-substring-no-properties
		      (point-at-bol) (point-at-eol))))
	      ((string= status "BANNED")
	       (error "this version of Emms has been BANNED"))
	      ((string= status "BADAUTH")
	       (error "bad authentication paramaters to handshake"))
	      ((string= status "BADTIME")
	       (error "handshake timestamp diverges too much"))
	      (t
	       (error "unhandled handshake failure")))))))

(defun emms-lastfm-client-assert-submission-handshake ()
  (when (not (and emms-lastfm-client-submission-session-id
		  emms-lastfm-client-submission-now-playing-url
		  emms-lastfm-client-submission-url))
    (error "cannot use submission API before handshake")))

(defun emms-lastfm-client-hexify-encode (str)
  "UTF-8 encode and URL-hexify STR."
  (url-hexify-string (encode-coding-string str 'utf-8)))

(defun emms-lastfm-client-submission-data (track rating)
  (emms-lastfm-client-assert-submission-handshake)
  (setq rating
	(cond ((equal 'love rating) "L")
	      ((equal 'ban rating) "B")
	      ((equal 'skip rating) "S")
	      (t "")))
  (concat
   "s=" (emms-lastfm-client-hexify-encode
	 emms-lastfm-client-submission-session-id)
   "&a[0]=" (emms-lastfm-client-hexify-encode
	     (emms-lastfm-client-xspf-get 'creator track))
   "&t[0]=" (emms-lastfm-client-hexify-encode
	     (emms-lastfm-client-xspf-get 'title track))
   ;; warning: won't extend to submitting multiple tracks
   "&i[0]=" (emms-lastfm-client-hexify-encode
	     emms-lastfm-client-track-play-start-timestamp)
   "&o[0]=L" (emms-lastfm-client-hexify-encode
	      (emms-lastfm-client-xspf-get
	       'trackauth
	       (emms-lastfm-client-xspf-extension track)))
   "&r[0]=" (emms-lastfm-client-hexify-encode rating)
   "&l[0]=" "" ; empty string to be explicit
   "&b[0]=" "" ; empty string to be explicit
   "&n[0]=" "" ; empty string to be explicit
   "&m[0]=" "" ; empty string to be explicit
   ))

(defun emms-lastfm-client-handle-submission-response (response track rating)
  (let ((ok200 "HTTP/1.1 200 OK"))
    (when (not (string= ok200 (substring response 0 15)))
      (error "submission server not responding correctly"))
    (with-temp-buffer
      (insert response)
      (goto-char (point-min))
      (re-search-forward "\n\n")
      (let ((status (buffer-substring-no-properties
		     (point-at-bol) (point-at-eol))))
	(cond ((string= status "OK")
	       ;; From the API docs: This indicates that the
	       ;; submission request was accepted for processing. It
	       ;; does not mean that the submission was valid, but
	       ;; only that the authentication and the form of the
	       ;; submission was validated.
	       (message "successfully submitted %s"
			(emms-lastfm-client-xspf-get 'title track)))
	      ((string= status "BADSESSION")
	       (emms-lastfm-client-handshake)
	       (emms-lastfm-client-make-async-submission-call track rating))
	      (t
	       (error "unhandled submission failure")))))))

(defun emms-lastfm-client-submit ()
  "Submit the current track as having been played."
  (if emms-lastfm-client-track
      (emms-lastfm-client-make-async-submission-call
       emms-lastfm-client-track nil)
    (error "no current track")))

;;; ------------------------------------------------------------------
;;; Asynchronous Submission
;;; ------------------------------------------------------------------

(defun emms-lastfm-client-async-submission-callback (status &optional cbargs)
  "Pass response of asynchronous submission call to handler."
  (let ((response (copy-sequence
		   (buffer-substring-no-properties
		    (point-min) (point-max)))))
    (emms-lastfm-client-handle-submission-response
     response
     (car cbargs) ; track
     (cdr cbargs) ; rating
     )))

(defun emms-lastfm-client-make-async-submission-call (track rating)
  "Make asynchronous submission call."
  (if emms-lastfm-client-playlist-valid
      (let* ((url-request-method "POST")
	     (url-request-data
	      (emms-lastfm-client-submission-data track rating))
	     (url-request-extra-headers
	      `(("Content-type" . "application/x-www-form-urlencoded"))))
	(url-retrieve emms-lastfm-client-submission-url
		      #'emms-lastfm-client-async-submission-callback
		      (list (cons track rating))))
    (error "cannot make submission call without initializing the client")))

(provide 'emms-lastfm-client)

;;; emms-lastfm-client.el ends here
