{ lib
, json2yaml
, runCommandLocal
, linkFarm
, emacsCIVersions
}:
with builtins;
{ minimumEmacsVersion
, lockDirName
, localPackages
, lispFiles
, lispDirs
}:
let
  emacsVersions = lib.pipe (attrNames emacsCIVersions) [
    (map (name: replaceStrings [ "-" ] [ "." ] (lib.removePrefix "emacs-" name)))
    (filter (version:
      version == "snapshot"
      || compareVersions version minimumEmacsVersion >= 0))
  ];

  trimLeft = text: head (match "[[:space:]]*(.+)" text);

  trimRight = text:
    if match "(.+[^[:space:]])[[:space:]]*" text != null
    then head (match "(.+[^[:space:]])[[:space:]]*" text)
    else text;

  trim = text: trimRight (trimLeft text);

  emacsArgs = concatStringsSep " " ([
    "-l package"
    "--eval \"(push '(\\\"melpa\\\" . \\\"https://melpa.org/packages/\\\") package-archives)\""
    "--eval \"(package-initialize)\""
  ] ++ map (s: "-L " + s) lispDirs);

  # HACK
  prependEmacsArgs = cmdline:
    if match "emacs([[:space:]].+)" cmdline != null
    then "$EMACS " + head (filter isString (match "emacs([[:space:]].+)" cmdline))
    else cmdline;

  indent = n: s:
    let
      lines = filter isString (split "\n" s);
      pad = lib.fixedWidthString n " " "";
    in
    concatStringsSep "\n"
      ([(head lines)] ++ map (s: pad + s) (tail lines));

  writeYAML = import ./yaml.nix {
    inherit json2yaml runCommandLocal;
  };

  makeWorkflow = name:
    { text
    , compile ? false
    , github ? { }
    , matrix ? true
    , description ? null
    , extraPackages ? [ ]
    , ...
    }: {
      name = github.name or name;
      on = github.on or {
        push = {
          paths = [ "**.el" ];
        };
      };
      jobs = {
        ${name} = {
          runs-on = "ubuntu-latest";
          strategy = {
            matrix = {
              emacs_version = if matrix then emacsVersions else [ "snapshot" ];
            };
          };
          steps = [
            {
              uses = "purcell/setup-emacs@master";
              "with" = { version = "\${{ matrix.emacs_version }}"; };
            }
            {
              uses = "actions/checkout@v2";
            }
            {
              run = "echo LOCAL_PACKAGES=\"${concatStringsSep " " localPackages}\" >> $GITHUB_ENV";
            }
            {
              name = "Set the arguments";
              run = ''
                tmp=$(mktemp)
                cat > $tmp <<LISP
                (progn
                  (require 'package)
                  (push '("melpa" . "https://melpa.org/packages/")
                        package-archives)
                  (package-initialize))
                LISP
                echo EMACS="emacs -l $tmp ${lib.concatMapStringsSep " "
                  (s: "-L " + s) lispDirs
                }" >> $GITHUB_ENV
              '';
            }
            {
              name = "Install dependencies";
              run = ''
                packages=$(mktemp)
                echo -n "Installed packages: "
                cat <(jq -r '.nodes.root.inputs | map(.) | .[]' ${lockDirName}/flake.lock) \
                  <(jq -r 'keys | .[]' ${lockDirName}/archive.lock) \
                  <(echo ${lib.escapeShellArgs extraPackages}) \
                  | tee "$packages" | xargs echo

                script=$(mktemp)
                cat > $script <<LISP
                (progn
                  (when command-line-args-left
                    (package-refresh-contents))
                  (dolist (package-name command-line-args-left)
                    (let ((package (intern package-name)))
                       (when (and package
                                  (not (memq package '(''${LOCAL_PACKAGES}))))
                       (package-install (cadr (assq package 
                                                    package-archive-contents)))))))
               LISP

               xargs $EMACS -batch -l "$script" < "$packages"
              '';
            }
            {
              name = "Byte-compile";
              "if" = "\${{ ${lib.boolToString compile} }}";
              run = ''
                $EMACS -batch -l bytecomp \
                  --eval "(setq byte-compile-error-on-warn t)" \
                  -f batch-byte-compile ${lib.escapeShellArgs lispFiles}
              '';
            }
            {
              name = description;
              run = prependEmacsArgs (trim text);
            }
          ];
        };
      };
    };
in
scripts:
linkFarm "github-workflows"
  (lib.mapAttrsToList
    (name: options: {
      name = "${name}.yml";
      path = writeYAML "github-workflow-${name}" (makeWorkflow name options);
    })
    scripts)
