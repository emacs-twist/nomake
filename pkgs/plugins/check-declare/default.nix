{ writers
}:
writers.writeBashBin "check-declare" ''
  set -euo pipefail

  autoloads=$(ls *-autoloads.el)

  echo "Running check-declare..."
  emacs -batch -l check-declare \
    --eval "(let ((result (apply #'check-declare-files command-line-args-left)))
               (with-current-buffer check-declare-warning-buffer
                 (message (buffer-string)))
                 (kill-emacs (if result 1 0)))" \
    *.el
''
