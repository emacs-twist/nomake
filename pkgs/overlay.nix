{ inputs }:
final: prev:
let
  inherit (prev) lib;
  inherit (inputs.gitignore.lib) gitignoreSource;

  # HACK: Access niv sources of nix-emacs-ci
  pinnedNixpkgs = (import (inputs.emacs-ci + "/nix/sources.nix") {
    inherit (prev) system;
  }).nixpkgs;

  # Use the same version of nixpkgs as nix-emacs-ci to utilize binary cache on CI
  emacsPackages = import pinnedNixpkgs {
    inherit (prev) system;
    overlays = [
      (import (inputs.emacs-ci + "/overlay.nix"))
    ];
  };

  pkgs = lib.composeManyExtensions [
    inputs.twist.overlays.default
  ] final prev;
in {
  nomake = lib.makeScope prev.newScope (self: {
    emacs = emacsPackages.emacs-snapshot;

    emacsCIVersions = lib.getAttrs emacsPackages.emacs-ci-versions emacsPackages;

    emacsConfigForLint = self.callPackage ./emacs-config {
      inherit (pkgs) emacsTwist;
      inherit inputs;

      extraPackages = [
        "package-lint"
        # "elsa"
      ];
      lockDir = ./emacs-config/lock;
      # Allow the user to update lint packages
      inputOverrides = {
        package-lint = _: _: {
          src = inputs.package-lint;
        };
        # elsa = _: _: {
        #   src = inputs.elsa;
        # };
      };
    };

    # elsa = self.callPackage ./elsa {
    #   emacsWithElsa = self.emacsConfigForLint;
    # };

    nomake = lib.makeOverridable (self.callPackage ./nomake { }) {
      # TODO: Use a proper module API
      plugins = {
        package-lint = self.callPackage ./plugins/package-lint {
          inherit (self.emacsConfigForLint.elispPackages) package-lint;
        };
        check-declare = self.callPackage ./plugins/check-declare { };
        byte-compile-and-load = self.callPackage ./plugins/byte-compile { };
        # elsa = self.callPackage ./plugins/elsa { };
      };

      enabledPlugins = [ "package-lint" "check-declare" "byte-compile-and-load" ];
    };

    mkEmacsConfigForDevelopment =
      { src, lockDirName
      , localPackages, extraPackages
      , emacs ? self.emacs
      , compile ? false
      }:
      self.callPackage ./emacs-config ({
        inherit (pkgs) emacsTwist;
        inherit inputs;
        inherit emacs;

        extraPackages = localPackages ++ extraPackages;
        lockDir = src + "/${lockDirName}";
        # Allow the user to update lint packages
        inputOverrides = lib.genAttrs localPackages (_: _: _: {
          src = gitignoreSource src;
        });
      } // lib.optionalAttrs compile {
        elispPackageOverrides = _eself: esuper:
          lib.genAttrs localPackages (ename: esuper.${ename}.overrideAttrs (_: {
            dontByteCompile = false;
            errorOnWarn = true;
          }));
      }
      );

    makeScriptPackage = self.callPackage ./script { };

    makeGitHubWorkflows = self.callPackage ./github-workflows { };
  });
}
