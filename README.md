# Snaps for Spiel speech providers and voices

This repository contains configuration and tests to use [Spiel](https://project-spiel.org/) as a text-to-speech API through snap packages.

## Usage

Build and install spiel-enabled orca, the piper speech provider, and a voice pack, and play some audio to test:
```bash
make
make install
make speak
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

To install a new piper voice, you will need to install the content snap, connect it to the speech provider, and restart the speech provider service.
```bash
$ sudo snap install --dangerous ./output/snaps/piper-voices-es-mx.snap
$ sudo snap connect speech-provider-piper:piper-voices piper-voices-es-mx:piper-voices
$ sudo snap restart speech-provider-piper.speech-provider-piper
```


## Testing

For end-to-end validation, `make test` will launch a fresh LXD container to install the snaps, connect the interfaces, and trigger speech.
