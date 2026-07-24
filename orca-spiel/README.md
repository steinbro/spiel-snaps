Work in progress. Builds a snap containing two executables, `orca` and `spiel`. The latter works and can be tested as follows:

```bash
# Build espeak speech provider
$ cd ../speech-provider-espeak
$ snapcraft pack
Packed speech-provider-espeak_0.1_amd64.snap

# Speech providers require user-daemons feature flag in snapd
$ sudo snap set system experimental.user-daemons=true
$ sudo snap install --dangerous speech-provider-espeak_0.1_amd64.snap
speech-provider-espeak 0.1 installed

# Build and install spiel-enabled orca
$ cd ../orca-spiel
$ snapcraft pack
Packed orca-spiel_50.2-dev_amd64.snap
$ sudo snap install --devmode --dangerous orca-spiel_50.2-dev_amd64.snap
orca-spiel 50.2-dev installed

# Connect espeak speech provider to orca
$ sudo snap connect orca-spiel:speech-provider speech-provider-espeak:speech-provider

# Confirm the orca snap can see the speech provider
$ orca-spiel.spiel -P
NAME                           IDENTIFIER
eSpeak NG                      org.espeak.Speech.Provider

# Say something
$ orca-spiel.spiel "Hello world"
```