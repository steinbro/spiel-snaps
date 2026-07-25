```bash
# Build a language pack
$ cd ../speech-provider-piper-voices-en-us
$ snapcraft pack
$ snapcraft install --dangerous *.snap

# Build the TTS engine
$ cd ../speech-provider-piper
$ snapcraft pack
$ snapcraft install --dangerous *.snap

# Connect the language pack to the TTS engine
$ sudo snap connect speech-provider-piper:piper-voices speech-provider-piper-voices-en-us:piper-voices
```