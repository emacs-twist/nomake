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
    inherit src lockDirName localPackages;
    extraPackages =
      lib.unique
        (extraPackages ++
          lib.flatten (lib.mapAttrsToList (_: xs: xs.extraPackages or [ ]) scripts)
        );
  };

  elispPackages = lib.getAttrs localPackages emacsConfig.elispPackages;

  maxVersion = versions: head (sort (a: b: compareVersions a b > 0) versions);

  minimumEmacsVersion = lib.pipe localPackages [
    (map (ename: emacsConfig.packageInputs.${ename}.packageRequires.emacs or null))
    (filter isString)
    maxVersion
  ];

  apps = emacsConfig.makeApps {
    inherit lockDirName;
  };

  update = pkgs.writeShellScriptBin "update" ''
    set -euo pipefail

    nix flake lock --update-input nomake
    ${admin.update.program}
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
        description = "Run package-lint";
        compile = (github.lint or { }).compile or false;
        matrix = (github.lint or { }).matrix or false;
        github = {
          name = "package-lint";
        };
        extraPackages = [ "package-lint" ];
        # Only a single package is supported right now.
        text = ''
          emacs -batch -l package-lint \
            --eval "(setq package-lint-main-file \"${mainFile}\")" \
            -f package-lint-batch-and-exit ${lib.escapeShellArgs lispFiles}
        '';
      };
    } // scripts);
in
{
  packages = {
    emacs = emacsConfig;
    inherit update;
    inherit (pkgs.nomake) nomake;
    github-workflows = scriptWorkflows;
  } // scriptPackages;

  apps = {
    inherit (apps) lock;
  };

  inherit elispPackages;
}
