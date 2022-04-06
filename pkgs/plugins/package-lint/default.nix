{ writers
, package-lint
}:
writers.writeBashBin "package-lint" ''
  set -euo pipefail

  files=()
  for f in *.el
  do
    if [[ "$f" =~ (.+)-autoloads.el ]]
    then
      main_file="''${BASH_REMATCH[1]}.el"
      continue
    fi
    files+=("$f")
  done

  # If the package has no autoloads, set main_file somehow
  if [[ ! -v main_file ]]
  then
    if [[ ''${#files[*]} -eq 1 ]]
    then
      main_file=''${files[*]}
    else
      # Guess the main file from the directory
      main_file=$(basename "$PWD").el
    fi
  fi

  emacs_dir="''${XDG_DATA_HOME:-$HOME/.local/share}/nomake"
  mkdir -p "''${emacs_dir}"

  echo "Checking the package with package-lint..."
  set -x
  emacs -batch -L "${package-lint}/share/emacs/site-lisp" -l package-lint \
    --eval "(setq user-emacs-directory \"''${emacs_dir}/\")" \
    --eval "(setq package-lint-main-file \"''${main_file}\")" \
    -l ${./package-lint-init.el} \
    -f package-lint-batch-and-exit \
    ''${files[@]}
''
