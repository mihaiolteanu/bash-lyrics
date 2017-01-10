(setq lyrics-source "https://makeitpersonal.co/lyrics?artist=%s&title=%s")

(defun get-tag(tag-name)
  (let ((tag (shell-command-to-string (format "cmus-remote -Q | grep \"%s\"" tag-name))))
    (replace-regexp-in-string tag-name "" (replace-regexp-in-string "\n" "" tag))))

(defun get-artist ()
  (replace-regexp-in-string " " "+" (get-tag "tag artist ")))

(defun get-song ()
  (replace-regexp-in-string " " "+" (get-tag "tag title ")))

(defun get-lyrics ()
  (shell-command-to-string
   (format "curl -s \'%s\' 2>&1" (format lyrics-source (get-artist) (get-song)))))

(defun display-lyrics (artist song lyrics)
  (let ((lyrics-buffer (get-buffer-create (format "%s - %s" artist song))))
    (with-current-buffer lyrics-buffer
      (insert lyrics))
    (switch-to-buffer lyrics-buffer)))

(display-lyrics (get-artist) (get-song) (get-lyrics))


