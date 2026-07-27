SHELL := /bin/bash
.DEFAULT_GOAL := snaps

.PHONY: clean piper-voices snaps test

clean:
	find . -type f -name '*.snap' -delete

piper-voice-configs:
	cd speech-provider-piper && ./generate_all_voices.sh

snaps: piper-voice-configs
	status=0; \
	while IFS= read -r dir; do \
		echo "==> snapcraft pack in $$dir"; \
		if ! (cd "$$dir" && snapcraft pack </dev/null); then \
			echo "FAILED: $$dir" >&2; \
			status=1; \
		fi; \
	done < <(find . -type f -name snapcraft.yaml -printf '%h\n' | sort -u); \
	exit $$status

test:
	./tests/test_snap_interfaces.sh
