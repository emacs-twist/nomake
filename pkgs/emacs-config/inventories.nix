{ gnu-elpa, melpa, epkgs, emacs }:
[
  {
    type = "elpa";
    path = gnu-elpa.outPath + "/elpa-packages";
    core-src = emacs.outPath;
    auto-sync-only = true;
  }
  {
    type = "melpa";
    path = melpa.outPath + "/recipes";
  }
  {
    name = "emacsmirror";
    type = "gitmodules";
    path = epkgs.outPath + "/.gitmodules";
  }
]
