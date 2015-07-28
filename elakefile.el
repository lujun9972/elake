
(elake-task :purchaseVegetables nil
      "任务1 -- 买菜"
      (message  "到沃尔玛去买菜。"))

(elake-task :cook (:purchaseVegetables)
    "任务2 -- 做饭"
    (message  "做一顿香喷喷的饭菜。"))

(elake-task :task1 (/etc/passwd)
  "测试自动变量"
  (message "%s依赖于%s" $< $@))

(elake-namespace home
    (elake-task :write-blog (:turn-on-computer) ;注意,同一个命名空间内的依赖任务无需加命名空间前缀
      "写博客"
      (message  "在家写博客"))
  (elake-task :turn-on-computer ()
    "打开电脑"
    (message  "打开家里的电脑")))

(elake-task :set-env nil
  "设置环境变量"
  (message "UNKNOW-ENV:%s" (getenv "UNKNOW-ENV")))

(elake-task :say-hello-to  nil
    "给任务传递参数"
    (message "hello to %s" who))

(elake-task :laundry nil
  "洗衣服"
  (message "把所有衣服扔进洗衣机。"))
(elake-task :today nil
  "今天的任务"
  (elake-execute-task :home:write-blog)
  (elake-execute-task :laundry))

(elake-task :task-to-be-removed nil
  "待删除的任务"
  (message "该任务会被:remove-task删除掉,删除掉后无法执行"))
(elake-task :remove-task (:task-to-be-removed)
  "删除任务:task-to-be-removed"
  (elake-remove-task :task-to-be-removed)
  (message "%s被删除" $@))

(elake-task :execute-removed-task (:remove-task)
  "删除任务测试"
  (elake-execute-task :task-to-be-removed))

(elake-rule ":make-\\(.+\\)" ("\\1")
  "测试rule"
  (message (shell-command-to-string (format "ls -l %s" (car $@)))))

(elake-rule "[^:].*" nil
  "测试rule"
  (message "touch %s" $<)
  (message (shell-command-to-string (format "touch %s" $<))))

(elake-task :blog (index.html (let (files)
                                (dotimes (num 3 files)
                                  (push (format "file-%s.html" num) files))))
  "测试使用S-Form自动生成依赖任务"
  (message "%s的依赖任务为%s" $< $@))
