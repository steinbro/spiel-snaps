SHELL := /bin/bash
.DEFAULT_GOAL := build

SNAP_OUTPUT_DIR ?= output/snaps

# Set of snaps to build comprises all directories containing a snapcraft.yaml file
SNAPS := $(shell find . -maxdepth 2 -type f -name snapcraft.yaml -printf '%h\n' | sort -u)
# Plain names (without the leading "./") of the snaps above, for use in target names.
SNAP_NAMES := $(notdir $(SNAPS))
# Snaps that require --devmode for now.
DEVMODE_SNAP_NAMES := orca-spiel spiel-it
# Speech provider snaps require the user-daemons feature flag in snapd.
SPEECH_PROVIDER_NAMES := $(filter speech-provider-%,$(SNAP_NAMES))
OTHER_SNAP_NAMES := $(filter-out $(DEVMODE_SNAP_NAMES) $(SPEECH_PROVIDER_NAMES),$(SNAP_NAMES))

# Piper voice packs live in their own directory with their own Makefile;
# forward the relevant targets there, passing down an absolute output dir.
PIPER_VOICES_MAKE := $(MAKE) -C piper-voices SNAP_OUTPUT_DIR="$(abspath $(SNAP_OUTPUT_DIR))"

.PHONY: clean build install connect speak test all-snaps all-piper-voices connect-orca-spiel \
	enable-user-daemons \
	$(SNAPS:%=%-snap) \
	$(SNAP_NAMES:%=install-%)

clean:
	rm -rf "$(SNAP_OUTPUT_DIR)"
	find . -type f -name '*.snap' -delete
	$(PIPER_VOICES_MAKE) clean

# Building a snap just involves calling snapcraft pack in the directory
# containing the snapcraft.yaml file and moving the resulting .snap file to
# the output directory.
$(SNAPS:%=%-snap):
	mkdir -p "$(SNAP_OUTPUT_DIR)"
	cd "$(subst -snap,,$@)" && snapcraft pack </dev/null && mv *.snap "$(abspath $(SNAP_OUTPUT_DIR))" || exit 1

all-snaps: $(SNAPS:%=%-snap)

all-piper-voices:
	$(PIPER_VOICES_MAKE) all-piper-voices

# By default, build all snaps and piper voices.
build: all-snaps all-piper-voices

# orca-spiel and spiel-it snaps require --devmode for now.
$(DEVMODE_SNAP_NAMES:%=install-%):
	@name="$(subst install-,,$@)"; \
	shopt -s nullglob; \
	files=("$(SNAP_OUTPUT_DIR)"/$${name}_*.snap); \
	set -x; \
	sudo snap install --devmode --dangerous "$${files[@]}"

# Speech providers require the user-daemons feature flag in snapd.
enable-user-daemons:
	sudo snap set system experimental.user-daemons=true

# Install any speech-provider-* snap (e.g. speech-provider-piper, speech-provider-espeak),
# ensuring the user-daemons feature flag is enabled first.
$(SPEECH_PROVIDER_NAMES:%=install-%): install-speech-provider-%:
	@shopt -s nullglob; \
	files=("$(SNAP_OUTPUT_DIR)"/speech-provider-$*_*.snap); \
	$(MAKE) enable-user-daemons; \
	set -x; \
	sudo snap install --dangerous "$${files[@]}"

# Install any other top-level snap that doesn't need special handling.
$(OTHER_SNAP_NAMES:%=install-%):
	@name="$(subst install-,,$@)"; \
	shopt -s nullglob; \
	files=("$(SNAP_OUTPUT_DIR)"/$${name}_*.snap); \
	set -x; \
	sudo snap install --dangerous "$${files[@]}"

# Piper voice packs (build/install/connect/speak/validate) are handled by
# piper-voices/Makefile; forward the relevant per-locale and aggregate targets.
# Note: explicit targets below (e.g. connect-orca-spiel) take precedence over
# these pattern rules for the same name.
piper-voices-%:
	$(PIPER_VOICES_MAKE) $@

install-piper-voices-%:
	$(PIPER_VOICES_MAKE) $@

connect-%:
	$(PIPER_VOICES_MAKE) $@

speak-%:
	$(PIPER_VOICES_MAKE) $@

validate-piper-voice-%:
	$(PIPER_VOICES_MAKE) $@

install: $(SNAP_NAMES:%=install-%)
	$(PIPER_VOICES_MAKE) install

connect-orca-spiel:
	# Connect the speech provider to orca
	sudo snap connect orca-spiel:speech-provider-piper speech-provider-piper:speech-provider

connect:
	$(PIPER_VOICES_MAKE) connect
	$(MAKE) connect-orca-spiel

# Speak using all piper voices in the voices.yaml file.
speak:
	$(PIPER_VOICES_MAKE) speak

# Run the test script to verify that the snaps and their interfaces are working correctly.
test:
	./tests/test_snap_interfaces.sh
