SHELL := /bin/bash
.DEFAULT_GOAL := build

SNAP_OUTPUT_DIR ?= output/snaps
PIPER_VOICES_DIR ?= speech-provider-piper/voices

.PHONY: clean configure build install connect speak test

SNAPS := $(shell find . -maxdepth 2 -type f -name snapcraft.yaml -printf '%h\n' | sort -u)
PIPER_VOICES := en-US es-MX ro-RO

clean:
	rm -rf "$(SNAP_OUTPUT_DIR)"
	rm -rf "$(PIPER_VOICES_DIR)"
	find . -type f -name '*.snap' -delete

.PHONY: $(SNAPS:%=%-snap)
$(SNAPS:%=%-snap):
	mkdir -p "$(SNAP_OUTPUT_DIR)"
	cd "$(subst -snap,,$@)" && snapcraft pack </dev/null && mv *.snap "$(abspath $(SNAP_OUTPUT_DIR))" || exit 1

.PHONY: all-snaps
all-snaps: $(SNAPS:%=%-snap)

.PHONY: $(PIPER_VOICES:%=piper-voices-%)
$(PIPER_VOICES:%=piper-voices-%):
	mkdir -p "$(PIPER_VOICES_DIR)/$@"
	cd speech-provider-piper && \
		./generate_voice_snapcraft.sh $(subst piper-voices-,,$@) \
		> "voices/$@/snapcraft.yaml"
	cd "$(PIPER_VOICES_DIR)/$@" && \
		snapcraft pack && \
		mv *.snap "$(abspath $(SNAP_OUTPUT_DIR))"

.PHONY: all-piper-voices
all-piper-voices: $(PIPER_VOICES:%=piper-voices-%)

build: all-snaps all-piper-voices

install:
	sudo snap install --devmode --dangerous "$(SNAP_OUTPUT_DIR)"/orca-spiel_*.snap
	# Speech providers require user-daemons feature flag in snapd
	sudo snap set system experimental.user-daemons=true
	sudo snap install --dangerous \
		"$(SNAP_OUTPUT_DIR)"/speech-provider-piper_*.snap \
		"$(SNAP_OUTPUT_DIR)"/piper-voices-*.snap

connect:
	# Connect voices to the speech provider
	sudo snap connect speech-provider-piper:piper-voices piper-voices-en-us:piper-voices
	sudo snap connect speech-provider-piper:piper-voices piper-voices-es-mx:piper-voices
	sudo snap connect speech-provider-piper:piper-voices piper-voices-ro-ro:piper-voices
	# Connect the speech provider to orca
	sudo snap connect orca-spiel:speech-provider-piper speech-provider-piper:speech-provider
	# Restart the speech provider after connecting the interfaces to ensure it picks up the new connections
	sudo snap restart speech-provider-piper.speech-provider-piper

speak: connect
	orca-spiel.spiel -l en-US "Hello, world!"
	orca-spiel.spiel -l es-MX "¡Hola, mundo!"
	orca-spiel.spiel -l ro-RO "Salut, lume!"

test:
	./tests/test_snap_interfaces.sh
