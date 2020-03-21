;;; wlog.el --- Voice logging for work -*- lexical-binding: t; -*-

;; Copyright (c) 2020 Abhinav Tushar

;; Author: Abhinav Tushar <abhinav@lepisma.xyz>
;; Version: 0.0.1
;; Package-Requires: ((emacs "26") (eredis "0.9.6"))
;; URL: https://github.com/lepisma/wlog

;;; Commentary:

;; Voice logging for work
;; This file is not a part of GNU Emacs.

;;; License:

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program. If not, see <http://www.gnu.org/licenses/>.

;;; Code:

(require 'eredis)
(require 'subr-x)

(defcustom wlog-redis-host "127.0.0.1"
  "Host for the redis server for keeping data in.")

(defcustom wlog-redis-port 6379
  "Port for redis server.")

(defcustom wlog-redis-channel "wlog-channel"
  "Channel name to publish things in.")

(defcustom wlog-source "wlog-user"
  "Structure for identifying who the sender is. Right now it's
only name. Ideally this would be tied to a key pair and the
packet will be signed.")

(defcustom wlog-arecord-args (list "-f" "S16_LE" "-c" "1" "-d" "600")
  "Arguments to send to arecord while recording. We put a max
duration limit so that an accident doesn't throw us out of memory.")

(defvar wlog--arecord-proc nil
  "Variable holding the process used for recording.")

(defun wlog-start-recording (&optional sample-rate)
  "Start recording audio. SAMPLE-RATE defaults to 8000."
  (let* ((tmp-file (make-temp-file "wlog-raw-audio"))
         (args (append wlog-arecord-args (list "-r" (number-to-string (or sample-rate 8000)) ">" (shell-quote-argument tmp-file)))))
    (setq wlog--arecord-proc (start-process-shell-command "arecord" nil (string-join (cons "arecord" args) " ")))
    (process-put wlog--arecord-proc 'output-file tmp-file)))

(defun wlog-stop-recording ()
  "Stop recording and return generated wav bytes."
  ;; NOTE: arecord takes kill (almost) gracefully but leaves the recording time
  ;;       wrong, so we fix it manually using sox
  (kill-process wlog--arecord-proc)
  (let ((tmp-file (process-get wlog--arecord-proc 'output-file)))
    (with-temp-buffer
      (call-process "sox" nil t nil "--ignore-length" tmp-file "-V1" "-t" "wav" "-")
      (setq wlog--arecord-proc nil)
      (delete-file tmp-file)
      (buffer-string))))

(defun wlog-record (&optional sample-rate)
  "Ask for audio from user and return wav bytes."
  (wlog-start-recording sample-rate)
  (read-string "Press RET when done speaking ")
  (wlog-stop-recording))

(defun wlog-connect ()
  "Prepare connection"
  (eredis-connect wlog-redis-host wlog-redis-port))

(defun wlog-prepare-packet (audio-bytes)
  "Serialize data along with other metadata"
  (let ((packet `((audio . ,(base64-encode-string (encode-coding-string audio-bytes 'utf-8) t)) (source . ,wlog-source))))
    (prin1-to-string packet)))

;;;###autoload
(defun wlog ()
  (interactive)
  (unless eredis--current-process
    (message "No connection to server. Connecting.")
    (wlog-connect))
  (let ((packet (wlog-prepare-packet (wlog-record))))
    (eredis-publish wlog-redis-channel packet))
  (message "wlogged"))

(provide 'wlog)

;;; wlog.el ends here
