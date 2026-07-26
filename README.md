# Snaps for speech providers and voices
## espeak
### 1. Build the espeak speech provider
```bash
$ cd speech-provider-espeak
$ snapcraft pack
Packed speech-provider-espeak_0.1_amd64.snap

### Speech providers require user-daemons feature flag in snapd
$ sudo snap set system experimental.user-daemons=true
$ sudo snap install --dangerous speech-provider-espeak_0.1_amd64.snap
speech-provider-espeak 0.1 installed
```

### 2. Build spiel-enabled orca
```bash
$ cd orca-spiel
$ snapcraft pack
Packed orca-spiel_50.2-dev_amd64.snap
$ sudo snap install --devmode --dangerous orca-spiel_50.2-dev_amd64.snap
orca-spiel 50.2-dev installed
```

### 3. Connect espeak speech provider to orca
```bash
$ sudo snap connect orca-spiel:speech-provider-espeak speech-provider-espeak:speech-provider

# Confirm the orca snap can see the speech provider
$ orca-spiel.spiel -P
NAME                           IDENTIFIER
eSpeak NG                      org.espeak.Speech.Provider

# Say something
$ orca-spiel.spiel "Hello world"
```

## Piper speech provider

Because piper voices are much larger than espeak's, they are packaged as content snaps that are built and installed separately.

### 1. Build the Piper speech provider
```bash
$ cd speech-provider-piper
$ snapcraft pack
$ snapcraft install --dangerous *.snap
```
### 2. Build a language pack
```bash
$ cd speech-provider-piper/piper-voices-en-us
$ snapcraft pack
$ snapcraft install --dangerous *.snap
```
### 3. Connect orca to piper and a voice 
```bash
# Connect voice to piper, and piper to orca
$ sudo snap connect speech-provider-piper:piper-voices piper-voices-en-us:piper-voices
$ sudo snap connect orca-spiel:speech-provider-piper speech-provider-piper:speech-provider

# When loading a new language pack, you may need to restart the provider
$ snap restart --user speech-provider-piper.speech-provider-piper

# Orca should show voices from your language pack
$ orca-spiel.spiel -V
NAME                      LANGUAGES  IDENTIFIER PROVIDER
amy                       en-US      en-US.amy-medium ai.piper.Speech.Provider

# Say something
$ orca-spiel.spiel "Hello world"
```