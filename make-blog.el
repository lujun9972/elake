(package-initialize)
(require 'org)
(require 'htmlize nil t)

(defun files-in-directory-with-subdir (dir &optional full match nosort)
  "类似directory-files,但是会递归搜索子目录,且不返回目录"
  (when (file-directory-p dir)
	(let* ((files (remove-if #'file-directory-p (directory-files dir t match)))
		   (dirs (remove-if (lambda (dir)
						   (string-match-p "/\\..*$" dir)) (remove-if-not #'file-directory-p (directory-files dir t)))))
	  (setq files (append files (mapcan (lambda (dir)
										  (files-in-directory-with-subdir dir t match)) dirs)))
	  (unless full
	  	(setq files (mapcar (lambda (file)
							  (file-relative-name file dir))
							files)))
	  (unless nosort
		(setq files (sort files #'string<)))
	  files)))

(elake-task index.html ((mapcar (lambda (x)
								  (replace-regexp-in-string "\\.org$" "\.html" x))
								(files-in-directory-with-subdir default-directory nil "\.org$")))
  ""
  (message "%s:%s" $< $@)
  (with-temp-file (format "%s" $<)
	(insert "<?xml version=\"1.0\" encoding=\"utf-8\"?>")
	(insert "<center>")
	(dolist (link $@)
	  (insert (format "<a href='%s'>%s</a><br>\n" link link)))
	(insert "</center>")))

(elake-task :clean ()
  ""
  (dolist (link (mapcar (lambda (x)
						  (replace-regexp-in-string "\\.org$" "\.html" x))
						(files-in-directory-with-subdir default-directory nil "\.org$")))
	(message "rm %s" link)
	(ignore-errors
	  (delete-file (format "%s" link)))))

(elake-rule "\\([^:].*\\)\\.html" ("\\1.org")
  "将org导出为html"
  (message "使用 %s 生成 %s" $@ $<)
  (let ((buf (find-file (format "%s" (car $@)))))
	(switch-to-buffer buf)
	(ignore-errors (org-html-export-to-html))
	(kill-buffer buf)))


