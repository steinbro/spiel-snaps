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
# Confirm content snap(s) are connected
$ snap connections speech-provider-piper
Interface              Plug                                  Slot                                             Notes
audio-playback         speech-provider-piper:audio-playback  :audio-playback                                  -
content[piper-voices]  speech-provider-piper:piper-voices    speech-provider-piper-voices-en-us:piper-voices  manual
content[piper-voices]  speech-provider-piper:piper-voices    speech-provider-piper-voices-pt-br:piper-voices  manual
...

# When loading a new language pack, you may need to restart the provider
$ snap restart --user speech-provider-piper.speech-provider-piper
$ orca-spiel.spiel -V
NAME                      LANGUAGES  IDENTIFIER PROVIDER
amy                       en-US      en-US.amy-medium ai.piper.Speech.Provider
faber                     pt-BR      pt-BR.faber-medium ai.piper.Speech.Provider
```