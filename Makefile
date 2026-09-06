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
# Individual voice identifiers (e.g. en_GB-alan-medium), matching the IDENTIFIER
# column shown by `orca-spiel.spiel -V` and accepted by its -v flag.
PIPER_VOICES := $(shell yq -r '. as $$root | keys_unsorted[] as $$locale | $$root[$$locale].voices[] | ($$locale | sub("-";"_")) + "-" + .' speech-provider-piper/voices.yaml)

.PHONY: clean clean-snaps build install connect speak test all-snaps connect-orca-spiel \
	enable-user-daemons \
	$(SNAPS:%=%-snap) \
	$(SNAPS:%=%-clean) \
	$(SNAP_NAMES:%=install-%)

clean: clean-snaps
	rm -rf "$(SNAP_OUTPUT_DIR)"
	find . -type f -name '*.snap' -delete

# Runs snapcraft clean in each directory containing a snapcraft.yaml file.
$(SNAPS:%=%-clean):
	cd "$(subst -clean,,$@)" && snapcraft clean

clean-snaps: $(SNAPS:%=%-clean)

# speech-provider-piper's snapcraft.yaml is generated: it bundles one voice
# component per voice listed in voices.yaml, appended to the static template.
speech-provider-piper/snapcraft.yaml: speech-provider-piper/snapcraft.yaml.in speech-provider-piper/voices.yaml speech-provider-piper/generate_snapcraft.sh
	cd speech-provider-piper && ./generate_snapcraft.sh > snapcraft.yaml

speech-provider-piper-snap: speech-provider-piper/snapcraft.yaml

# Building a snap just involves calling snapcraft pack in the directory
# containing the snapcraft.yaml file and moving the resulting .snap file to
# the output directory.
$(SNAPS:%=%-snap):
	mkdir -p "$(SNAP_OUTPUT_DIR)"
	cd "$(subst -snap,,$@)" && snapcraft pack </dev/null && shopt -s nullglob && mv *.snap *.comp "$(abspath $(SNAP_OUTPUT_DIR))" || exit 1

all-snaps: $(SNAPS:%=%-snap)

# By default, build all snaps. Piper voice packs are built as components
# alongside speech-provider-piper, so no separate step is needed for them.
build: all-snaps

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
# ensuring the user-daemons feature flag is enabled first. Also installs any
# components (e.g. piper voice packs) built alongside the snap, if present.
$(SPEECH_PROVIDER_NAMES:%=install-%): install-speech-provider-%:
	@shopt -s nullglob; \
	files=("$(SNAP_OUTPUT_DIR)"/speech-provider-$*_*.snap); \
	components=("$(SNAP_OUTPUT_DIR)"/speech-provider-$*+*.comp); \
	$(MAKE) enable-user-daemons; \
	set -x; \
	sudo snap install --dangerous "$${files[@]}"; \
	if [ "$${#components[@]}" -gt 0 ]; then \
		sudo snap install --dangerous "$${components[@]}"; \
	fi

# Install any other top-level snap that doesn't need special handling.
$(OTHER_SNAP_NAMES:%=install-%):
	@name="$(subst install-,,$@)"; \
	shopt -s nullglob; \
	files=("$(SNAP_OUTPUT_DIR)"/$${name}_*.snap); \
	set -x; \
	sudo snap install --dangerous "$${files[@]}"

install: $(SNAP_NAMES:%=install-%)

connect-speech-provider-espeak:
	# Connect the speech provider to orca
	sudo snap connect orca-spiel:speech-provider-espeak speech-provider-espeak:speech-provider

connect-speech-provider-piper:
	# Connect the speech provider to orca
	sudo snap connect orca-spiel:speech-provider-piper speech-provider-piper:speech-provider

connect: $(SPEECH_PROVIDER_NAMES:%=connect-%)

# Speak each locale's test phrase with every voice defined for that locale in voices.yaml.
speak-speech-provider-piper: $(PIPER_VOICES:%=speak-speech-provider-piper-voice-%)

# Speak a locale's test phrase with one specific voice (e.g. en_GB-alan-medium).
$(PIPER_VOICES:%=speak-speech-provider-piper-voice-%):
	@voice="$(subst speak-speech-provider-piper-voice-,,$@)"; \
	locale="$${voice%%-*}"; \
	locale="$${locale/_/-}"; \
	phrase="$$(yq -r --arg locale "$$locale" '.[$$locale].test_phrase' speech-provider-piper/voices.yaml)"; \
	set -x; \
	orca-spiel.spiel -v "$${voice}" "$$phrase";

speak-speech-provider-espeak:
	# Speak a test phrase with the espeak speech provider
	orca-spiel.spiel -p org.espeak.Speech.Provider "Hello, world!"

speak: $(SPEECH_PROVIDER_NAMES:%=speak-%)

# Run the test script to verify that the snaps and their interfaces are working correctly.
test:
	./tests/test_snap_interfaces.sh
