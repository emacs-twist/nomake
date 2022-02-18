{ nixpkgs
, overlay
}:
{ system
  # Package configuration
, src
, lockDirName ? ".nomake"
, localPackages
, extraPackages ? [ ]
, scripts ? { }
, github ? { }
}:
with builtins;
let
  inherit (nixpkgs) lib;

  pkgs = import nixpkgs {
    inherit system;
    overlays = [
      overlay
    ];
  };

  inherit (pkgs.nomake) emacsCIVersions;

  emacsConfig = lib.makeOverridable pkgs.nomake.mkEmacsConfigForDevelopment {
    inherit src lockDirName localPackages extraPackages;
  };

  elispPackages = lib.getAttrs localPackages emacsConfig.elispPackages;

  maxVersion = versions: head (sort (a: b: compareVersions a b > 0) versions);

  minimumEmacsVersion = lib.pipe localPackages [
    (map (ename: emacsConfig.packageInputs.${ename}.packageRequires.emacs or null))
    (filter isString)
    maxVersion
  ];

  admin = emacsConfig.admin lockDirName;

  update = pkgs.writeShellScriptBin "update" ''
    set -euo pipefail

    nix flake lock --update-input nomake
    ${admin.update}/bin/lock
    cd ${lockDirName}
    nix flake update
  '';

  scriptPackages = lib.mapAttrs
    (pkgs.nomake.makeScriptPackage {
      inherit minimumEmacsVersion emacsConfig;
    })
    scripts;

  lispFiles = lib.pipe localPackages [
    (map (ename: emacsConfig.packageInputs.${ename}.lispFiles))
    concatLists
  ];

  lispDirs = lib.pipe lispFiles [
    (map dirOf)
    lib.unique
  ];

  mainFile = emacsConfig.packageInputs.${head localPackages}.mainFile;

  scriptWorkflows = pkgs.nomake.makeGitHubWorkflows
    {
      inherit minimumEmacsVersion lockDirName localPackages lispFiles lispDirs;
    }
    ({
      lint = {
        name = "Run package-lint";
        jobs = {
          lint = {
            compile = false;
            matrix = false;
            extraPackages = [ "package-lint" ];
            steps = [
              {
                name = "Run package-lint";
                text = ''
                  emacs -batch -l package-lint \
                    --eval "(setq package-lint-main-file \"${mainFile}\")" \
                    -f package-lint-batch-and-exit ${lib.escapeShellArgs lispFiles}
                '';
              }
            ];
          };
        } // lib.optionalAttrs ((github.lint or { }).compile or false) {
          compile = {
            compile = true;
            matrix = true;
            steps = [ ];
          };
        };
      };
    } // mapAttrs
      (scriptName:
        { compile ? false
        , matrix ? true
        , extraPackages ? [ ]
        , text
        , ...
        } @ args:
        {
          name = (args.github or { }).name or scriptName;
          on = (args.github or { }).on or null;
          jobs = {
            ${scriptName} = {
              inherit compile matrix extraPackages;
              steps = [
                {
                  inherit text;
                }
              ];
            };
          };
        })
      scripts);
in
{
  packages = {
    emacs = emacsConfig;
    inherit (admin) lock;
    inherit update;
    inherit (pkgs.nomake) nomake;
    github-workflows = scriptWorkflows;
  } // scriptPackages;

  inherit elispPackages;
}
