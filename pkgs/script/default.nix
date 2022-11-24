{ lib
, writeShellApplication
, emacsCIVersions
}:
# Arguments specific to a repository
{ minimumEmacsVersion
, emacsConfig
# pkgs with user overlays applied
, pkgs
}:
with builtins;
let
  emacsVersions = lib.pipe (attrNames emacsCIVersions) [
    (filter (name:
      name == "emacs-snapshot"
      || compareVersions
        (replaceStrings [ "-" ] [ "." ] (lib.removePrefix "emacs-" name))
        minimumEmacsVersion >= 0))
  ];

  makeScriptDerivation = { name, emacs, runtimeInputs, text }: writeShellApplication {
    inherit name;
    runtimeInputs = runtimeInputs ++ [
      emacs
    ];
    inherit text;
  };
in
prefix:
{ text
, compile ? false
, runtimeInputsFromPkgs ? (_: [])
, ...
}:
let
  origDerivation = makeScriptDerivation {
    name = prefix;
    emacs = emacsConfig.override { inherit compile; };
    runtimeInputs = runtimeInputsFromPkgs pkgs;
    inherit text;
  };

  makeDerivationForEmacsVersion = emacsVersion: makeScriptDerivation {
    name = "${prefix}-${emacsVersion}";
    emacs = emacsConfig.override {
      emacs = emacsCIVersions.${emacsVersion};
      inherit compile;
    };
    runtimeInputs = runtimeInputsFromPkgs pkgs;
    inherit text;
  };
in
lib.extendDerivation true
  {
    matrix = lib.genAttrs emacsVersions makeDerivationForEmacsVersion;
  }
  origDerivation
