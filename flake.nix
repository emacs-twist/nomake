{
  description = "NoMake Emacs Lisp linting and testing framework";

  inputs = {
    flake-utils = {
      url = "github:numtide/flake-utils";
    };
    gitignore = {
      url = "github:hercules-ci/gitignore.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    twist.url = "github:emacs-twist/twist.nix";
    # Required for Emacs executables. You should use the same version of nixpkgs to
    # take advantage of binary cache
    emacs-ci = {
      url = "github:purcell/nix-emacs-ci";
      flake = false;
    };
    package-lint = {
      url = "github:purcell/package-lint";
      flake = false;
    };
    # elsa = {
    #   url = "github:emacs-elsa/Elsa";
    #   flake = false;
    # };

    # These inputs should follow their corresponding inputs of the caller (i.e.
    # packages under test). We don't have to update these inputs in this
    # repository regularly.
    melpa = {
      url = "github:melpa/melpa";
      flake = false;
    };
    gnu-elpa = {
      url = "git+https://git.savannah.gnu.org/git/emacs/elpa.git?ref=main";
      flake = false;
    };
    epkgs = {
      url = "github:emacsmirror/epkgs";
      flake = false;
    };
    emacs = {
      url = "github:emacs-mirror/emacs";
      flake = false;
    };
  };

  outputs =
    { self
    , nixpkgs
    , flake-utils
    , ...
    } @ inputs:
    let
      overlay = import ./pkgs/overlay.nix { inherit inputs; };

      inherit (flake-utils.lib) mkApp;
    in
    {
      inherit overlay;
      lib = import ./lib { inherit inputs overlay; };
      templates = {
        simple = {
          path = ./templates/simple;
          description = "A boilerplate for an Emacs Lisp-only project";
        };
      };
      defaultTemplate = self.templates.simple;
    } //
    flake-utils.lib.eachDefaultSystem (system:
    let
      inherit (nixpkgs) lib;

      pkgs = import nixpkgs {
        inherit system;
        overlays = [
          overlay
        ];
      };

      admin = pkgs.nomake.emacsConfigForLint.admin "./pkgs/emacs-config/lock";
    in
    {
      packages = flake-utils.lib.flattenTree {
        inherit (pkgs.nomake) nomake;
      };

      apps.lock = mkApp {
        drv = admin.lock;
      };
    }
    );
}
