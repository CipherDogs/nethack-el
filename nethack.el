;;; nethack.el -- run Nethack as an inferior process in Emacs
;;; Author: Ryan Yeske (rcyeske@sfu.ca)
;;; Date: Sat Mar 18 11:31:52 2000

;;; Requires: a copy of Nethack 3.3.x with the lisp window port


(require 'gamegrid)
(require 'nethack-api)
;;(require 'nethack-cmd)
;;(require 'nethack-keys)


(defun nethack ()
  "Start a game of Nethack.

The variable `nethack-program' is the name of the executable to run."
  (interactive)
  (if (and (processp nethack-process)
	   (eq (process-status nethack-process) 'run))
      (message "Nethack process already running...")
    (setq nethack-process (nethack-start-program))))


(defun nethack-quit ()
  "Quit nethack."
  (interactive)
  (kill-process nethack-process))

;;; Process code to communicate with the Nethack executable
(defvar nethack-process nil)

(defvar nethack-program "nethack"
  "* Program to run to start a game of Nethack.")

(defvar nethack-program-args nil
  "* Arguments to pass to `nethack-program'.")

(defvar nethack-process-buffer-name "*nethack-process*"
  "Name of the buffer used to communicate with `nethack-program'.")

(defvar nethack-process-name "nethack")

(defvar nethack-end-of-command-string "\n"
  "String used to terminate a command sent to a running Nethack
process.")

(defun nethack-start-program ()
  "Start `nethack-program' with `nethack-program-args' as an
asynchronous subprocess.  Returns a process object."
  (let ((proc (apply 'start-process nethack-process-name
		     nethack-process-buffer-name
		     nethack-program nethack-program-args)))
    (set-process-filter proc 'nethack-process-filter)
    proc))


(defun nethack-send-command (command)
  "Send a COMMAND to `nethack-process'."
  (nethack-process-send-string 
   (concat "(" command ")" nethack-end-of-command-string)))
				       

(defun nethack-process-send-string (string)
  "Send a STRING to the running `nethack-process'.  Appends a newline
char to the STRING."
  (let ((string-to-send (concat string "\n")))
    (if (and (processp nethack-process)
	     (eq (process-status nethack-process) 'run))
	(progn
	  ;; log the command in the process buffer
	  (nethack-log-string (concat "SEND: " string-to-send))

	  ;; send it...
	  (process-send-string nethack-process string-to-send))
      (error "Nethack process not running"))))


(defun nethack-process-filter (proc command)
  "Handle command output from `nethack-process' and copy the text to
the `nethack-process-buffer' for debugging."

  ;; log received command in the process-buffer
  (nethack-log-string (concat "RECV: " command))
	      
  ;; handle command
  (nethack-parse-command command))


(defun nethack-log-string (string)
  "Write STRING into `nethack-process-buffer'."
  (with-current-buffer (process-buffer nethack-process)
    (let ((moving (= (point) (process-mark nethack-process))))
      (save-excursion		       
	(goto-char (process-mark nethack-process))
	(insert string)
	(set-marker (process-mark nethack-process) (point)))
      (if moving (goto-char (process-mark nethack-process)))))())


(defun nethack-parse-command (command)
  "Parse and COMMAND and do it."
  (message (concat "Parsing: " command))
  (eval (car (read-from-string command))))


;;; Buffer code (aka windows in Nethack)
(defvar nethack-buffer-alist
  '((nhw-message . "*nhw-message*")
    (nhw-status  . "*nhw-status*")
    (nhw-map     . "*nhw-map*")
    (nhw-menu    . "*nhw-menu*")
    (nhw-text    . "*nhw-text*"))
  "Buffer names for each window type.")

;; digit ids to send back to nethack to refer to windows
(defvar nethack-buffer-id-alist
  '((0 . nhw-message)
    (1 . nhw-status)
    (2 . nhw-map)
    (3 . nhw-menu)
    (4 . nhw-text)))

;;; Main Map Buffer code
(defvar nethack-map-width 80 "Max width of the map")
(defvar nethack-map-height 22 "Max height of the map")

(defun nethack-create-buffer (type)
  "Create a buffer for a Nethack window of TYPE."
  (let ((buffer-name (cdr (assq type nethack-buffer-name-alist))))
    (get-buffer-create buffer-name)
    (save-excursion
      (set-buffer buffer-name)
      (erase-buffer)
      (if (eq type 'nhw-map)
	  (progn
	    (gamegrid-init (make-vector 256 nil))
	    (gamegrid-init-buffer nethack-map-width 
				  nethack-map-height
				  ?.))))))
