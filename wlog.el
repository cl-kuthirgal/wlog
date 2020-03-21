;;; wlog.el --- Voice logging for work -*- lexical-binding: t; -*-

;; Copyright (c) 2020 Abhinav Tushar

;; Author: Abhinav Tushar <abhinav@lepisma.xyz>
;; Version: 0.0.1
;; Package-Requires: ((emacs "26"))
;; URL: https://github.com/lepisma/wlog.el

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
(require 'esi-record)

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

(defun wlog-connect ()
  "Prepare connection"
  (eredis-connect wlog-redis-host wlog-redis-port))

(defun wlog-prepare-packet (audio-bytes)
  "Serialize data along with other metadata"
  (let ((packet `((audio . ,audio-bytes) (source . ,wlog-source))))
    (prin1-to-string packet)))

;;;###autoload
(defun wlog ()
  (interactive)
  (unless eredis--current-process
    (message "No connection to server. Connecting.")
    (wlog-connect))
  (let ((packet (wlog-prepare-packet (esi-record))))
    (eredis-publish wlog-redis-channel packet))
  (message "wlogged"))

(provide 'wlog)

;;; wlog.el ends here
