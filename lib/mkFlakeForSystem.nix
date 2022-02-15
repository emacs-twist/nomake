{ nixpkgs
, overlay
}:
{ system
  # Package configuration
, src
, lockDirName ? "lock"
, localPackages
, extraPackages ? [ ]
, scripts ? { }
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

  inherit (pkgs.elinter) emacsCIVersions;

  emacsConfig = lib.makeOverridable pkgs.elinter.mkEmacsConfigForDevelopment {
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

    nix flake lock --update-input elinter
    ${admin.update}/bin/lock
    cd ${lockDirName}
    nix flake update
  '';

  scriptPackages = lib.mapAttrs (pkgs.elinter.makeScriptPackage {
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

  scriptWorkflows = pkgs.elinter.makeGitHubWorkflows {
    inherit minimumEmacsVersion lockDirName localPackages lispFiles lispDirs;
  } ({
    lint = {
      description = "Run package-lint";
      compile = false;
      matrix = false;
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
    inherit (admin) lock;
    inherit update;
    inherit (pkgs.elinter) elinter;
    github-workflows = scriptWorkflows;
  } // scriptPackages;

  inherit elispPackages;
}
