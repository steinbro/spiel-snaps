SHELL := /bin/bash
.DEFAULT_GOAL := build

SNAP_OUTPUT_DIR ?= output/snaps
PIPER_VOICES_DIR ?= speech-provider-piper/voices

SNAPS := $(shell find . -maxdepth 2 -type f -name snapcraft.yaml -printf '%h\n' | sort -u)
PIPER_VOICES := en-US es-MX ro-RO

.PHONY: clean build install connect speak test all-snaps all-piper-voices connect-orca-spiel \
	$(SNAPS:%=%-snap) \
	$(PIPER_VOICES:%=piper-voices-%) \
	$(PIPER_VOICES:%=connect-%) \
	$(PIPER_VOICES:%=speak-%)

clean:
	rm -rf "$(SNAP_OUTPUT_DIR)"
	rm -rf "$(PIPER_VOICES_DIR)"
	find . -type f -name '*.snap' -delete

$(SNAPS:%=%-snap):
	mkdir -p "$(SNAP_OUTPUT_DIR)"
	cd "$(subst -snap,,$@)" && snapcraft pack </dev/null && mv *.snap "$(abspath $(SNAP_OUTPUT_DIR))" || exit 1

all-snaps: $(SNAPS:%=%-snap)

$(PIPER_VOICES:%=piper-voices-%):
	mkdir -p "$(PIPER_VOICES_DIR)/$@"
	cd speech-provider-piper && \
		./generate_voice_snapcraft.sh $(subst piper-voices-,,$@) \
		> "voices/$@/snapcraft.yaml"
	cd "$(PIPER_VOICES_DIR)/$@" && \
		snapcraft pack && \
		mv *.snap "$(abspath $(SNAP_OUTPUT_DIR))"

all-piper-voices: $(PIPER_VOICES:%=piper-voices-%)

build: all-snaps all-piper-voices

install:
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
	@locale="$(subst connect-,,$@)"; \
	voice_snap="piper-voices-$$(printf '%s' "$$locale" | tr '[:upper:]' '[:lower:]')"; \
	set -x; \
	sudo snap connect speech-provider-piper:piper-voices "$$voice_snap":piper-voices
	# Restart the speech provider after connecting the interfaces to ensure it picks up the new connections
	sudo snap restart speech-provider-piper.speech-provider-piper

connect: $(PIPER_VOICES:%=connect-%) connect-orca-spiel

$(PIPER_VOICES:%=speak-%):
	@locale="$(subst speak-,,$@)"; \
	voice_snap="piper-voices-$$(printf '%s' "$$locale" | tr '[:upper:]' '[:lower:]')"; \
	phrase="$$(< "/snap/$$voice_snap/current/test_phrase.txt")"; \
	set -x; \
	orca-spiel.spiel -l "$$locale" "$$phrase"

speak: $(PIPER_VOICES:%=speak-%)

test:
	./tests/test_snap_interfaces.sh
