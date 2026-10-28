SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := help

VERSION ?= dev
FONT_DIR ?=
PROFILE := build/archiso
export VERSION FONT_DIR

.PHONY: help iso profile check

help:
	@printf '%s\n' \
		'make iso [VERSION=X.Y.Z] [FONT_DIR=/path/to/fonts]   Build the ISO and checksum in out/' \
		'make profile [VERSION=X.Y.Z] [FONT_DIR=/path/to/fonts]   Stage the live profile in build/archiso/' \
		'make check           Check shell syntax and whitespace' \
		'VERSION defaults to dev and only labels the local build.'

profile:
	@[[ "$$VERSION" == dev || "$$VERSION" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$$ ]] || \
		{ echo 'VERSION must be dev or X.Y.Z (without the v tag prefix)' >&2; exit 1; }
	rm -rf $(PROFILE)
	mkdir -p $(PROFILE)/airootfs/usr/share/pond-installer
	cp -a archiso/. $(PROFILE)
	keyring="$$PWD/$(PROFILE)/keyring"; \
		as_root=(); (( EUID == 0 )) || as_root=(unshare --map-root-user); \
		install -d -m 0700 "$$keyring"; \
		"$${as_root[@]}" pacman-key --gpgdir "$$keyring" --init; \
		"$${as_root[@]}" pacman-key --gpgdir "$$keyring" --populate archlinux; \
		"$${as_root[@]}" pacman-key --gpgdir "$$keyring" --populate-from archiso/keyrings --populate pond; \
		sed -i "/^\[options\]/a GPGDir = $$keyring" $(PROFILE)/pacman.conf
	tar -C src --exclude=__pycache__ -c backend frontend | tar -C $(PROFILE)/airootfs/usr/share/pond-installer -x
ifneq ($(FONT_DIR),)
	@for style in Regular RegularItalic Book Medium; do \
		font="$$FONT_DIR/PondGramercy-$$style.otf"; \
		[[ -f "$$font" && -s "$$font" ]] || { echo "Required font is missing or empty: $$font" >&2; exit 1; }; \
	done
	mkdir -p $(PROFILE)/airootfs/usr/share/fonts/otf-pond-gramercy
	cp "$$FONT_DIR"/PondGramercy-*.otf $(PROFILE)/airootfs/usr/share/fonts/otf-pond-gramercy/
endif

iso: profile
	build_dir=$$(mktemp -d build/run.XXXXXX); \
		POND_INSTALLER_VERSION="$$VERSION" mkarchiso -v -r -w "$$build_dir/work" -o out $(PROFILE); \
		rmdir "$$build_dir"
	cd out && sha256sum "pond-installer-$$VERSION-x86_64.iso" > "pond-installer-$$VERSION-x86_64.iso.sha256"

check:
	bash -n archiso/profiledef.sh
	bash -n archiso/airootfs/etc/skel/.bash_profile
	sh -n archiso/airootfs/usr/local/bin/pond-installer
	git diff --check
