{
  description = "FIXME: Your package description";

  nixConfig.extra-substituters = "https://emacs-ci.cachix.org";
  nixConfig.extra-trusted-public-keys = "emacs-ci.cachix.org-1:B5FVOrxhXXrOL0S+tQ7USrhjMT5iOPH+QN9q0NItom4=";

  inputs = {
    gnu-elpa = {
      url = "git+https://git.savannah.gnu.org/git/emacs/elpa.git?ref=main";
      flake = false;
    };
    melpa = {
      # If your package is not on MELPA, fork github:melpa/melpa, create a new
      # branch for your package, add a recipe, and push it to GitHub.
      url = "github:melpa/melpa";
      # url = "github:OWNER/melpa/BRANCH";
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

    nomake = {
      url = "github:emacs-twist/nomake";
      inputs.gnu-elpa.follows = "gnu-elpa";
      inputs.melpa.follows = "melpa";
      inputs.epkgs.follows = "epkgs";
      inputs.emacs.follows = "emacs";
    };
  };

  outputs =
    { self
    , nomake
    , ...
    } @ inputs:
    nomake.lib.mkFlake {
      src = ./.;
      localPackages = [
        (builtins.throw "FIXME: Put your package name here.")
      ];
    };
}
