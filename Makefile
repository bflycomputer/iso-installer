SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := help

VERSION ?=
FONT_DIR ?=
PROFILE := build/archiso
export VERSION FONT_DIR

.PHONY: help iso profile check

help:
	@printf '%s\n' \
		'make iso VERSION=X.Y.Z FONT_DIR=/path/to/fonts   Build the ISO and checksum in out/' \
		'make profile VERSION=X.Y.Z FONT_DIR=/path/to/fonts   Stage the live profile in build/archiso/' \
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
	build_dir=$$(mktemp -d build/run.XXXXXX); \
		POND_INSTALLER_VERSION="$$VERSION" mkarchiso -v -r -w "$$build_dir/work" -o out $(PROFILE); \
		rmdir "$$build_dir"
	cd out && sha256sum "pond-installer-$$VERSION-x86_64.iso" > "pond-installer-$$VERSION-x86_64.iso.sha256"

check:
	bash -n archiso/profiledef.sh
	sh -n archiso/airootfs/usr/local/bin/pond-installer
	git diff --check
