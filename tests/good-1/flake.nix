{
  description = "Test package";

  inputs = {
    nomake = {
      url = "github:emacs-twist/nomake";
      inputs.melpa.follows = "melpa";
      inputs.gnu-elpa.follows = "gnu-elpa";
      inputs.epkgs.follows = "epkgs";
      inputs.emacs.follows = "emacs";
    };

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
    , nomake
    , ...
    } @ inputs:
    nomake.lib.mkFlake {
      src = ./.;
      localPackages = [
        "playground"
      ];
      extraPackages = [
        "project"
      ];
      scripts = {
        test = {
          description = "Run buttercup tests";
          compile = false;
          extraPackages = [
            "buttercup"
          ];
          text = ''
            emacs -batch -l buttercup -f buttercup-run-discover "$PWD"
          '';
        };
      };
    };
}
