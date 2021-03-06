#! /usr/bin/emacs --script
;;; elake.el --- elisp make
;; Author: DarkSun <lujun9972@gmail.com>
;; Keywords: lisp, make

;; This file is NOT part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Source code
;;
;; elake's code can be found here:
;;   http://github.com/lujun9972/elake
;;; Commentary:
;; elake is an elisp make

(require 'cl)
(require 'subr-x)
;;; Code:

(eval-when-compile
  (defvar elake-task-relationship (make-hash-table)
	"存放task之间的依赖关系")
  (defvar elake-executed-task nil
	"已经执行过的task,不要重新执行")
  (defvar elake--ns nil
	"命名空间")
  (defvar elake-default-task nil
	"默认的任务")
  (defvar elake--user-params-alist nil
	"存放用户通过命令行传递过来的参数")
  (defun elake--file-task-p (task)
	"判断`task'是否为file类型的任务,这种类型的任务采取make的方式处理,需要判断依赖文件和目标文件的更新时间. 若是file类型的任务,则返回对应的file路径,否则返回nil

不已:开头的任务为file类型"
	(let ((task-name (format "%s" task)))
	  (unless (string-prefix-p ":" task-name)
		task-name)))
  (defvar elake--work-path nil
	"存储elake的启动目录")
  (defun elake--get-path-from-file-task (file-task)
	"若`task'为file类型的task,则返回对应的file 绝对路径"
	;; (message "file=[%s]" (concat (file-name-as-directory elake--work-path) (elake--file-task-p file-task)))
	(concat (file-name-as-directory elake--work-path) (elake--file-task-p file-task))
	)

  (defun elake--phony-task-p (task)
	"判断`task'是否为phony类型的任务,这种类型的任务采取ant的方式处理,单纯的执行被依赖的任务

非file类型的任务就是phony类型的任务"
	(not (elake--file-task-p task)))
  
  (defun elake--get-namespace-task (task)
	"获取task在namespace环境中的名称"
	(if (and elake--ns
			 (elake--phony-task-p task))
		(intern (format ":%s%s" elake--ns task))
	  task))
  
  (defun elake--valid-task-p (task)
	"判断`task'是否为已定义的任务,若为已定义任务则返回`task',否则返回nil"
	(cond ((elake--phony-task-p task)
		   (when (member task (hash-table-keys elake-task-relationship))
			 task))
		  ((elake--file-task-p task)
		   ;; (message (pwd))
		   (when (or (file-exists-p (elake--get-path-from-file-task task))
					 (member task (hash-table-keys elake-task-relationship)))
			 task))
		  (t (error "未知的任务类型[%s]" task)))))

;; 定义namespace
(defmacro elake-namespace (ns &rest body)
  "定义命名空间.

在命名空间内定义的task在命名空间外使用需要加上命名空间的前缀,
格式为\":NS:task-id\".
Optional argument BODY elake的其他操作."
  (declare (indent 2))
  (declare (indent 2))
  (let ((elake--ns ns))
	`(progn
	   ,@(mapcar #'macroexpand body))
	))

;; 定义task
(defmacro elake-task (task prepare-task-list &optional doc-string &rest body)
  "使用elask-task宏来定义TASK.
Argument PREPARE-TASK-LIST `TASK'的前置任务列表.
Optional argument DOC-STRING 任务`TASK'的说明.
Optional argument BODY 任务`TASK'的具体定义."
  (declare (indent defun) (doc-string 3))
  ;; 第一个任务设置为默认任务
  (unless elake-default-task
	(setq elake-default-task task))
  ;; 统一prepare-task-list为list格式
  (unless (listp prepare-task-list)
	(setq prepare-task-list (list prepare-task-list)))
  (setq prepare-task-list (mapcar (lambda (x)
									"将x变为symbol"
									(intern (format "%s" x)))
								  (mapcan (lambda (prepare-task)
											(cond ((atom prepare-task)
												   (list prepare-task))
												  ((listp prepare-task)
												   (eval prepare-task)))) prepare-task-list)))
  (setq task (elake--get-namespace-task task))
  (setq prepare-task-list (mapcar (lambda (task)
									(if (elake--file-task-p task)
										task
									  (elake--get-namespace-task task))) prepare-task-list))
  ;; 存储依赖关系到elask-task-relationship中
  (puthash task prepare-task-list elake-task-relationship)
  ;; 定义名为task-symbol的函数,以doc-string为函数说明,body为函数体
  `(defun ,task ($< $@)
	 ,doc-string
	 ,@body)
  )
;; 根据模式来自动生产任务
(defvar elake-rule-template-alist nil
  "存放定义的规则模板.")
(defmacro elake-rule (rule prepare-rule-list &rest body)
  "使用elask-rule宏来定义RULE.
Argument PREPARE-RULE-LIST 产生前置任务的规则.
Optional argument BODY 根据规则产生的任务的具体定义."
  (declare (indent defun))
  ;; 统一prepare-task-list为list格式
  (unless (stringp rule)
	(error "Rule[%s]需要使用字符串格式" rule))
  (unless (listp prepare-rule-list)
	(setq prepare-rule-list (list prepare-rule-list)))
  (unless (cl-every #'stringp prepare-rule-list)
	(error "依赖rule[%s]需要使用字符串格式" prepare-rule-list))
  ;; 存储规则模板到elask-rule-template-alist中
  `(push '(,(format "^%s$" rule) ,prepare-rule-list ,body) elake-rule-template-alist))

(defun elake--generate-task-by-rule (task)
  "根据规则模板来自动生成`TASK'任务. 若能根据规则生成任务,则返回任务,否则返回nil."
  (let* ((task-name (format "%s" task))
		 (template (assoc-if (lambda (rule)
							   (string-match-p rule task-name)) elake-rule-template-alist)))
	(when template
	  (let* ((rule (car template))
			 (prepare-rule-list (cadr template))
			 (body (caddr template))
			 (prepare-task-list (mapcar (lambda (prepare-rule)
										  (intern (replace-regexp-in-string rule prepare-rule task-name)))
										prepare-rule-list)))
		(eval (append `(elake-task ,task ,prepare-task-list) body))))))

;; 定义删除任务的函数
(defun elake--remove-task (task)
  "删除id为`TASK'的任务."
  (remhash task elake-task-relationship)
  (fmakunbound task)			;删除已定义函数
  (setq elake-executed-task (remove task elake-executed-task))
  (when (eq task elake-default-task)
	(setq elake-default-task (car (reverse (hash-table-keys elake-task-relationship))))))

(defmacro elake-remove-task (task)
  "删除id为`TASK'的任务."
  (let ((valid-task (or (elake--valid-task-p (elake--get-namespace-task task))
						(elake--valid-task-p task))))
	(unless valid-task
	  (error "%s is not a valid task" task))
	`(elake--remove-task ',valid-task)))

;; command line args处理函数
(defun command-line-get-args-to-next-option ()
  "用于获取直到下一个option为止的所有command line args,会将获取的command line args移出`command-line-args-left'变量."
  (let* ((next-option-position (or (cl-position-if (lambda (arg)
													 (string-prefix-p "-" arg)) command-line-args-left)
								   (length command-line-args-left)))
		 (args-to-next-option (subseq command-line-args-left 0 next-option-position)))
	(setq command-line-args-left (nthcdr next-option-position command-line-args-left))
	args-to-next-option))

;; 使用-f指定elakefile路径
(defvar elake--init-file "elakefile"
  "Elake的初始化文件路径,默认为elakefile.")
(defun elake--init()
  "环境初始化"
  ;; 清除之前定义的task
  (mapc #'elake--remove-task (hash-table-keys elake-task-relationship))
  (setq elake-task-relationship (make-hash-table) ;存放task之间的依赖关系
		elake-rule-template-alist nil
		elake--user-params-alist nil	  ;存放用户通过命令行传入的参数
		elake-executed-task nil ;"已经执行过的task,不要重新执行"
		elake--ns nil
		elake-default-task nil
		elake--work-path default-directory))

(defun elake--set-init-file (file)
  "设置elake的初始化文件为`FILE'."
  (setq elake--init-file file))

(defun elake-set-init-file (option)
  "设置elake的初始化文件.
Argument OPTION 无意义,纯粹为了满足elake script的调用机制."
  (elake--set-init-file (car command-line-args-left))
  (setq command-line-args-left (cdr command-line-args-left)))

;; 显示任务说明
(defun elake--show-task-documentation (task)
  "显示`TASK'指定任务的说明."
  (when (stringp task)
	(setq task (intern task)))
  (message "%s:%s" task (documentation task)))

(defun elake--show-tasks-documentation (&rest tasks)
  "显示`TASKS'指定任务的说明."
  (when (null tasks)
	(require 'subr-x)
	(setq tasks (hash-table-keys elake-task-relationship)))
  (mapc #'elake--show-task-documentation tasks))

(defun elake-show-tasks-documentation (option)
  "显示指定任务的说明文档.
Argument OPTION 无意义,纯粹为了满足elake script的调用机."
  (apply 'elake--show-tasks-documentation (command-line-get-args-to-next-option)))

;; 显示task的准备条件
(defun elake--get-task-preparations (task)
  "返回`TASK'的依赖任务."
  (gethash task elake-task-relationship))


(defun elake--show-task-preparations (task)
  "显示`TASK'指定任务的说明."
  (when (stringp task)
	(setq task (intern task)))
  (message "%s:%s" task (elake--get-task-preparations task)))

(defun elake--show-tasks-preparations (&rest tasks)
  "显示`TASKS'指定任务的说明."
  (when (null tasks)
	(setq tasks (hash-table-keys elake-task-relationship)))
  (mapc #'elake--show-task-preparations tasks))

(defun elake-show-tasks-preparations (option)
  "显示指定任务的依赖任务.
Argument OPTION 无意义,纯粹为了满足elake script的调用机."
  (apply 'elake--show-tasks-preparations (mapcar #'read (command-line-get-args-to-next-option))))

;; 帮助的函数
(defun elake--show-option-help (option)
  "根据`command-switch-alist'显示`OPTION'的帮助信息."
  (let* ((command-switch (assoc option command-switch-alist))
		 (option (car command-switch))
		 (fn (cdr command-switch))
		 (help (documentation fn)))
	(message "%s:\t%s" option help)))

(defun elake--show-options-help (&rest options)
  "根据`command-switch-alist'显示`OPTIONS'中各个option的帮助信息."
  (when (null options)
	(setq options (mapcar #'car command-switch-alist)))
  (mapc #'elake--show-option-help options))

(defun elake-show-help (option)
  "显示帮助信息.
Argument OPTION 无意义,纯粹为了满足elake script的调用机."
  (apply 'elake--show-options-help (command-line-get-args-to-next-option)))

;; 执行task函数

(defun elake--task-executed-p (task)
  "判断`TASK'是否已经执行."
  (member task elake-executed-task))

(defun elake--need-to-execute-task-p (task)
  "判断`TASK'是否需要执行."
  (let ((preparations (elake--get-task-preparations task)))
	(cond ((and (elake--phony-task-p task)
				(elake--task-executed-p task))
		   nil)								;phony任务已执行过,则不再执行
		  ((and (elake--file-task-p task)
				(file-exists-p (elake--get-path-from-file-task task)) ;file任务的file已存在
				;; (cl-notany #'elake--need-to-execute-task-p preparations) ;且不存在 "未处理的依赖任务或不存在的依赖文件"
				(cl-notany (lambda (preparation-file)
							 (file-newer-than-file-p preparation-file (elake--file-task-p task)))
						   (remove nil (mapcar #'elake--file-task-p preparations)))) ;且不存在依赖文件比目标文件更新的情况
		   nil)							;才不用执行
		  (t t))))						;否则需要执行

(defun elake--execute-task (task)
  "运行`TASK'标识的任务,会预先运行它的prepare-tasks."
  (save-excursion
	(save-restriction
	  (or (elake--valid-task-p task)
		  (elake--generate-task-by-rule task)
		  (error "未定义的任务:%s"task ))
	  (let ((prepare-task-list (elake--get-task-preparations task)))
		;; 执行预备条件
		(when prepare-task-list
		  (cond ((sequencep prepare-task-list)
				 (mapc #'elake--execute-task prepare-task-list))
				(t (error "错误的依赖类型:%s" (type-of prepare-task-list)))))
		(when (elake--need-to-execute-task-p task )
		  (push task elake-executed-task)
		  (eval `(let ,elake--user-params-alist
				   (funcall task task prepare-task-list))))))))

(defmacro elake-execute-task (task)
  "运行`TASK'标识的任务,会预先运行它的prepare-tasks."
  (let ((valid-task (or (elake--valid-task-p (elake--get-namespace-task task))
						(elake--valid-task-p task))))
	(unless valid-task
	  (error "%s is not a valide task" task))
	`(elake--execute-task (quote ,valid-task))))

;; elake环境初始化
(add-to-list 'load-path default-directory)

;; 设置参数处理函数
(add-to-list 'command-switch-alist '("-f" . elake-set-init-file))
(add-to-list 'command-switch-alist '("-t" . elake-show-tasks-documentation))
(add-to-list 'command-switch-alist '("--task" . elake-show-tasks-documentation))
(add-to-list 'command-switch-alist '("-p" . elake-show-tasks-preparations))
(add-to-list 'command-switch-alist '("--preparations" . elake-show-tasks-preparations))
(add-to-list 'command-switch-alist '("-h" . elake-show-help))
(add-to-list 'command-switch-alist '("--help" . elake-show-help))

;; 以下方式是为了兼容elake的lisp函数方式
(defun elake--elake(&rest args)
  "模拟emacs --script的运行方式"
  (elake--init)
  (let ((command-line-args-left args)
		jobs)
	(while command-line-args-left
	  (let* ((arg (car command-line-args-left))
			 (command-switch (assoc arg command-switch-alist))
			 (switch-string (car command-switch))
			 (handler-function (cdr command-switch)))
		(setq command-line-args-left (cdr command-line-args-left)) ;不管是不是所有的函数都返回nil,这里都需要删掉这个待处理的函数
		(cond (handler-function
			   (funcall handler-function switch-string))
			  ((string-match "^\\(.+\\):=\\(.+\\)" arg)
			   (setenv (match-string 1 arg) (match-string 2 arg))) ;设置环境变量
			  ((string-match "^\\(.+\\)=\\(.+\\)" arg)
			   (push (list (intern (match-string 1 arg)) (match-string 2 arg)) elake--user-params-alist)) ;设置参数
			  (t (push arg jobs)))))
	(load elake--init-file nil t)
	(when (and (cl-notany (lambda (option)
							(member option args)) '("-t" "--task -p" "--preparations" "-h" "--help"))
			   (null jobs))
	  (push (format "%s" elake-default-task) jobs))		;设置默认的任务
	(mapc #'elake--execute-task (mapcar #'intern jobs))))

(defun elake (&rest args)
  "该函数供eshell中使用elake,`ARGS'为传递給elake的各种参数."
  (setq args (mapcar (lambda (x)
					   (format "%s" x)) args)) ;统一转换为字符串格式
  (with-output-to-string
	(let ((old-message (symbol-function 'message)))
	  (unwind-protect
		  (progn
			(fset 'message (lambda (fmt &rest args)
							 (princ (apply #'format fmt args))
							 (princ "\n")))
			(apply 'elake--elake args))
		(fset 'message old-message)))))

;; 以下操作是为了兼容#!emacs --script方式
(when (member "-scriptload" command-line-args)
  (apply 'elake--elake command-line-args-left)
  (setq command-line-args-left nil))

(provide 'elake)

;;; elake.el ends here
