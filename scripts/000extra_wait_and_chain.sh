pstree -p | grep screen -C3

#  > screen(186380)---zsh(186381)---sh(121277)---bash(121665)-+-bash(121725)---python3.11(122759)
# get PID of the sh process: 121277

# wait for process to finish and start next one:
tail --pid=121277 -f /dev/null  ; ./scripts/03-04_loop_days.sh 2017 01 12
