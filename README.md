# Snaps for Spiel speech providers and voices

This repository contains configuration and tests for packaging the [Spiel](https://project-spiel.org/) text-to-speech interface as snap packages.

There are snap configurations for:
1. [speech-provider-espeak](https://github.com/project-spiel/speech-provider-espeak)
2. [speech-provider-piper](https://github.com/project-spiel/speech-provider-piper)
3. [spiel-it](https://github.com/project-spiel/spiel-it)
4. [Orca](https://gitlab.gnome.org/GNOME/orca), specifically a development build with experimental spiel support enabled.

## Usage

Build and install spiel-enabled orca, the piper speech provider, and a voice pack, and play some audio to test:
```bash
make
make install
make speak
```

By default, this will build all snaps and voices in the repository. If you just want to use Piper in US English, you can make the first command more specific:
```bash
make speech-provider-piper-snap piper-voices-en-US orca-spiel-snap
```

## Managing speech providers and voices

View installed voices and speech providers:
```bash
$ orca-spiel.spiel -V
NAME                      LANGUAGES  IDENTIFIER PROVIDER
amy                       en-US      en-US.amy-medium ai.piper.Speech.Provider

$ orca-spiel.spiel -P
NAME                           IDENTIFIER
Piper                          ai.piper.Speech.Provider
```
### Installing a packaged voice
To install a new piper voice, you will need to install the content snap, connect it to the speech provider, and restart the speech provider service.
```bash
$ sudo snap install --dangerous ./output/snaps/piper-voices-es-mx.snap
$ sudo snap connect speech-provider-piper:piper-voices piper-voices-es-mx:piper-voices
$ sudo snap restart speech-provider-piper.speech-provider-piper
```
### Packaging a new voice
Creating a snap for a new voice involves simply editing the voices.json file in the speech-provider-piper directory. The following make targets will automatically become available (using en-US as an example locale):
```bash
make piper-voices-en-US  # Build the snap
make connect-en-US       # Connect the snap to the Piper speech provider
make speak-en-US         # Speak a test phrase
```

## Testing

For end-to-end validation, `make test` will launch a fresh LXD container to install the snaps, connect the interfaces, and trigger speech.

## Architecture

The snap structure closely follows the intended architecture of Spiel services.

Each speech provider runs in its own strictly-confined snap, and exposes a D-Bus service for communication. Spiel client apps like orca can find speech providers and voices through D-Bus service discovery. Speech providers are automatically started via D-Bus service activation.

Voices are downloaded from the [rhaspy/piper-voices repo](https://huggingface.co/rhasspy/piper-voices) on Hugging Face. They are packaged per-locale as their own snaps, connected through a content interface.