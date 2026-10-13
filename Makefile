SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := help

SUDO ?= $(if $(filter 0,$(shell id -u)),,sudo)
VERSION ?=
FONT_DIR ?=
PROFILE := .cache/profile
export VERSION FONT_DIR

.PHONY: help iso profile check

help:
	@printf '%s\n' \
		'make iso VERSION=X.Y.Z FONT_DIR=/path/to/fonts   Build the ISO and checksum in dist/' \
		'make profile VERSION=X.Y.Z FONT_DIR=/path/to/fonts   Stage the live profile in .cache/profile/' \
		'make check           Check shell syntax and whitespace'

profile:
	@[[ "$$VERSION" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$$ ]] || \
		{ echo 'VERSION must be X.Y.Z (without the v tag prefix)' >&2; exit 1; }
	@[[ -n "$$FONT_DIR" ]] || { echo 'FONT_DIR must point to the Pond Gramercy font directory' >&2; exit 1; }
	@for style in Regular RegularItalic Book Medium; do \
		font="$$FONT_DIR/PondGramercy-$$style.otf"; \
		[[ -f "$$font" && -s "$$font" ]] || { echo "Required font is missing or empty: $$font" >&2; exit 1; }; \
	done
	rm -rf $(PROFILE)
	mkdir -p $(PROFILE)/airootfs/usr/share/pond-installer
	cp -a archiso/. $(PROFILE)
	tar -C src --exclude=__pycache__ -c backend frontend | tar -C $(PROFILE)/airootfs/usr/share/pond-installer -x
	mkdir -p $(PROFILE)/airootfs/usr/share/fonts/otf-pond-gramercy
	cp "$$FONT_DIR"/PondGramercy-*.otf $(PROFILE)/airootfs/usr/share/fonts/otf-pond-gramercy/

iso: profile
	$(SUDO) rm -rf --one-file-system .cache/work
	$(SUDO) env POND_INSTALLER_VERSION="$$VERSION" mkarchiso -v -w .cache/work -o dist $(PROFILE)
	$(SUDO) chown -R "$$(id -u):$$(id -g)" dist
	cd dist && sha256sum "pond-installer-$$VERSION-x86_64.iso" > "pond-installer-$$VERSION-x86_64.iso.sha256"

check:
	bash -n archiso/profiledef.sh
	sh -n archiso/airootfs/usr/local/bin/pond-installer
	git diff --check
