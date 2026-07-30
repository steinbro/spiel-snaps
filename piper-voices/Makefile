SHELL := /bin/bash
.DEFAULT_GOAL := build

# Path (relative to this Makefile, or absolute) to drop built .snap files into.
# When invoked from the top-level Makefile, this is passed in as an absolute path.
SNAP_OUTPUT_DIR ?= ../output/snaps

# Set of piper voices to build is governed by keys in the voices.yaml file.
PIPER_VOICES := $(shell yq -r 'keys_unsorted[]' voices.yaml)

.PHONY: clean build install connect speak all-piper-voices \
	$(PIPER_VOICES:%=piper-voices-%) \
	$(PIPER_VOICES:%=install-piper-voices-%) \
	$(PIPER_VOICES:%=connect-%) \
	$(PIPER_VOICES:%=speak-%) \
	$(PIPER_VOICES:%=validate-piper-voice-%)

clean:
	rm -rf piper-voices-*/

# Piper voice snaps have dynamically generated snapcraft.yaml files that follow
# a simple template. After that, the snap is built in the same way as other snaps.
$(PIPER_VOICES:%=piper-voices-%):
	mkdir -p "$(SNAP_OUTPUT_DIR)"
	mkdir -p "$@"
	./generate_voice_snapcraft.sh "$(subst piper-voices-,,$@)" > "$@/snapcraft.yaml"
	cd "$@" && \
		snapcraft pack && \
		mv *.snap "$(abspath $(SNAP_OUTPUT_DIR))"

all-piper-voices: $(PIPER_VOICES:%=piper-voices-%)

build: all-piper-voices

# Install a single piper voice snap, e.g. `make install-piper-voices-en-US`.
$(PIPER_VOICES:%=install-piper-voices-%):
	@locale="$(subst install-piper-voices-,,$@)"; \
	voice_snap="piper-voices-$$(printf '%s' "$$locale" | tr '[:upper:]' '[:lower:]')"; \
	shopt -s nullglob; \
	files=("$(SNAP_OUTPUT_DIR)/$${voice_snap}"_*.snap); \
	set -x; \
	sudo snap install --dangerous "$${files[@]}"

install: $(PIPER_VOICES:%=install-piper-voices-%)

$(PIPER_VOICES:%=connect-%):
	# Make the piper-voices snap available to the speech provider
	@locale="$(subst connect-,,$@)"; \
	voice_snap="piper-voices-$$(printf '%s' "$$locale" | tr '[:upper:]' '[:lower:]')"; \
	set -x; \
	sudo snap connect speech-provider-piper:piper-voices "$$voice_snap":piper-voices
	# Restart the speech provider after connecting the interfaces to ensure it picks up the new connections
	sudo snap restart speech-provider-piper.speech-provider-piper

connect: $(PIPER_VOICES:%=connect-%)

# Use the orca-spiel binary to speak a test phrase with every voice included in
# the specified locale's pack, e.g. `make speak-en-US` speaks with en-US.amy-medium,
# en-US.lessac-medium, en-US.ryan-medium, etc.
$(PIPER_VOICES:%=speak-%):
	@locale="$(subst speak-,,$@)"; \
	voice_snap="piper-voices-$$(printf '%s' "$$locale" | tr '[:upper:]' '[:lower:]')"; \
	phrase="$$(< "/snap/$$voice_snap/current/test_phrase.txt")"; \
	mapfile -t voice_ids < <(yq -r --arg locale "$$locale" '.[$$locale].voices[]' voices.yaml); \
	set -x; \
	for voice_id in "$${voice_ids[@]}"; do \
		orca-spiel.spiel -v "$$locale.$$voice_id" "$$phrase"; \
	done

# Speak using all piper voices in the voices.yaml file.
speak: $(PIPER_VOICES:%=speak-%)

# Validate a single piper voice end-to-end: install the voice snap, connect it
# to the speech provider, and speak a test phrase.
# e.g. `make validate-piper-voice-en-US`
$(PIPER_VOICES:%=validate-piper-voice-%): validate-piper-voice-%:
	$(MAKE) install-piper-voices-$*
	$(MAKE) connect-$*
	$(MAKE) speak-$*
