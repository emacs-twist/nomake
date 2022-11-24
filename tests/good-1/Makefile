NIX := nix
NIX_OPTIONS := --override-input nomake path:$(PWD)/../..

lint: update-nomake lock
	$(NIX) run .#nomake -- playground
.PHONY: lint

lock: update-nomake
	$(NIX) run .#lock --impure
.PHONY: lock

test: update-nomake
	$(NIX) run .#test
.PHONY: test

update-nomake:
	$(NIX) flake lock --update-input nomake $(NIX_OPTIONS)
.PHONY: update-nomake
