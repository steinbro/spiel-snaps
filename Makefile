SHELL := /bin/bash
.DEFAULT_GOAL := build

SNAP_OUTPUT_DIR ?= output/snaps
PIPER_VOICES_DIR ?= speech-provider-piper/voices

# Set of snaps to build comprises all directories containing a snapcraft.yaml file
SNAPS := $(shell find . -maxdepth 2 -type f -name snapcraft.yaml -printf '%h\n' | sort -u)
# Set of piper voices to build is governed by keys in the voices.yaml file
PIPER_VOICES := $(shell yq -r 'keys_unsorted[]' speech-provider-piper/voices.yaml)

.PHONY: clean build install connect speak test all-snaps all-piper-voices connect-orca-spiel \
	$(SNAPS:%=%-snap) \
	$(PIPER_VOICES:%=piper-voices-%) \
	$(PIPER_VOICES:%=connect-%) \
	$(PIPER_VOICES:%=speak-%)

clean:
	rm -rf "$(SNAP_OUTPUT_DIR)"
	rm -rf "$(PIPER_VOICES_DIR)"
	find . -type f -name '*.snap' -delete

# Building a snap just involves calling snapcraft pack in the directory
# containing the snapcraft.yaml file and moving the resulting .snap file to
# the output directory.
$(SNAPS:%=%-snap):
	mkdir -p "$(SNAP_OUTPUT_DIR)"
	cd "$(subst -snap,,$@)" && snapcraft pack </dev/null && mv *.snap "$(abspath $(SNAP_OUTPUT_DIR))" || exit 1

all-snaps: $(SNAPS:%=%-snap)

# Piper voice snaps have dynamically generated snapcraft.yaml files that follow
# a simple template. After that, the snap is built in the same way as other snaps.
$(PIPER_VOICES:%=piper-voices-%):
	mkdir -p "$(PIPER_VOICES_DIR)/$@"
	cd speech-provider-piper && \
		./generate_voice_snapcraft.sh $(subst piper-voices-,,$@) \
		> "voices/$@/snapcraft.yaml"
	cd "$(PIPER_VOICES_DIR)/$@" && \
		snapcraft pack && \
		mv *.snap "$(abspath $(SNAP_OUTPUT_DIR))"

all-piper-voices: $(PIPER_VOICES:%=piper-voices-%)

# By default, build all snaps and piper voices.
build: all-snaps all-piper-voices

install:
	# orca-spiel snap requires --devmode for now
	sudo snap install --devmode --dangerous "$(SNAP_OUTPUT_DIR)"/orca-spiel_*.snap
	# Speech providers require user-daemons feature flag in snapd
	sudo snap set system experimental.user-daemons=true
	sudo snap install --dangerous \
		"$(SNAP_OUTPUT_DIR)"/speech-provider-piper_*.snap \
		"$(SNAP_OUTPUT_DIR)"/piper-voices-*.snap

connect-orca-spiel:
	# Connect the speech provider to orca
	sudo snap connect orca-spiel:speech-provider-piper speech-provider-piper:speech-provider

$(PIPER_VOICES:%=connect-%):
	# Make the piper-voices snap available to the speech provider
	@locale="$(subst connect-,,$@)"; \
	voice_snap="piper-voices-$$(printf '%s' "$$locale" | tr '[:upper:]' '[:lower:]')"; \
	set -x; \
	sudo snap connect speech-provider-piper:piper-voices "$$voice_snap":piper-voices
	# Restart the speech provider after connecting the interfaces to ensure it picks up the new connections
	sudo snap restart speech-provider-piper.speech-provider-piper

connect: $(PIPER_VOICES:%=connect-%) connect-orca-spiel

# Use the orca-spiel binary to speak a test phrase using the specified voice.
$(PIPER_VOICES:%=speak-%):
	@locale="$(subst speak-,,$@)"; \
	voice_snap="piper-voices-$$(printf '%s' "$$locale" | tr '[:upper:]' '[:lower:]')"; \
	phrase="$$(< "/snap/$$voice_snap/current/test_phrase.txt")"; \
	set -x; \
	orca-spiel.spiel -l "$$locale" "$$phrase"

# Speak using all piper voices in the voices.json file.
speak: $(PIPER_VOICES:%=speak-%)

# Run the test script to verify that the snaps and their interfaces are working correctly.
test:
	./tests/test_snap_interfaces.sh
