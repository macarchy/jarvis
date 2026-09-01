# Third-party components

Jarvis's own code is MIT ([LICENSE](LICENSE)). It is about 500 KB of bash,
Python and QML, and that is all this repository distributes.

Everything below is fetched at install time by [`bootstrap.sh`](bootstrap.sh)
from its own upstream, into `piper/`, `models/` and `wake/venv/` — all three
are in `.gitignore`. **This repository never redistributes any of it.** That
distinction matters: some of these are copyleft, and downloading a component
to run it locally is not the same as shipping it inside your own release.

If you plan to package or redistribute Jarvis *together with* these pieces,
read their licenses first. The summary below is a map, not legal advice.

## The voice

| Component | Version | License | Source |
|---|---|---|---|
| Piper | 1.2.0 | MIT | [rhasspy/piper](https://github.com/rhasspy/piper) |
| piper-phonemize | bundled | MIT | [rhasspy/piper-phonemize](https://github.com/rhasspy/piper-phonemize) |
| **espeak-ng** | 1.52 | **GPL-3.0** | [espeak-ng/espeak-ng](https://github.com/espeak-ng/espeak-ng) |
| ONNX Runtime | 1.14.1 | MIT | [microsoft/onnxruntime](https://github.com/microsoft/onnxruntime) |

The Piper release tarball bundles espeak-ng and its data as shared libraries.
Piper itself is MIT; the bundle you download is not uniformly MIT.

## The voice models

Fetched from [rhasspy/piper-voices](https://huggingface.co/rhasspy/piper-voices).
Each voice carries its own license, inherited from the dataset it was trained
on, and they are **not** the same:

| Voice | Role | License | Dataset |
|---|---|---|---|
| `fr_FR-tom-medium` | **French, default** | **AGPL-3.0** | [French-tts-model-piper](https://git.bksp.space/Tjiho/French-tts-model-piper) |
| `en_GB-alan-medium` | English, default | see source | [mimic3-voices / apope](https://github.com/MycroftAI/mimic3-voices/blob/master/voices/en_UK/apope_low) |
| `fr_FR-siwis-medium` | French, alternate | **CC-BY 4.0** | [SIWIS, Univ. of Edinburgh](https://datashare.is.ed.ac.uk/handle/10283/2353) |
| `fr_FR-upmc-medium` | French, alternate | CC-BY-SA 4.0 | [upmc-pierre-data](https://github.com/marytts/upmc-pierre-data) |

> **Worth knowing.** The default French voice is AGPL-3.0 — the strongest
> copyleft of anything Jarvis touches. It is downloaded and run locally, never
> redistributed here, and Jarvis is not a network service. But if you intend to
> ship a bundle, or to run something like this as a hosted service, this is the
> line to read carefully.
>
> `fr_FR-siwis-medium` (CC-BY 4.0) is already fetched by
> `./bootstrap.sh --all-voices` and is a drop-in replacement: change `VOICE_FR`
> near the top of [`bin/jarvis`](bin/jarvis). It is a different voice, not a
> worse one.

Only the two defaults are downloaded unless you pass `--all-voices`.

## The ear

| Component | License | Source |
|---|---|---|
| voxtype 1.0.1 | MIT | [voxtype.io](https://voxtype.io) — you install this yourself |
| Whisper `ggml-small` | MIT | [whisper.cpp](https://huggingface.co/ggerganov/whisper.cpp), from [OpenAI Whisper](https://github.com/openai/whisper) |

## « Hey Jarvis »

Installed into `wake/venv/`, and entirely optional (`--skip-wake`).

| Component | Version | License |
|---|---|---|
| openWakeWord | 0.4.0 | Apache-2.0 |
| ONNX Runtime | 1.29.0 | MIT |
| NumPy | 2.5.2 | BSD-3-Clause |
| scikit-learn | 1.9.0 | BSD-3-Clause |
| joblib | 1.5.3 | BSD-3-Clause |

openWakeWord downloads its own pre-trained models on first setup, including
the `hey_jarvis` one. The accent verifier in `wake/verifier-hey-jarvis.joblib`
is not in this repository — it is trained from your own voice by
`wake/train-verifier`, and it is yours.

## The brain

[Claude Code](https://claude.com/claude-code) is proprietary and requires an
Anthropic account. Jarvis invokes it as `claude -p`; it is not vendored, not
wrapped, and not redistributed. See [docs/privacy.md](docs/privacy.md) for what
is sent to it.

## The desktop

[Omarchy](https://omarchy.org), [Hyprland](https://hyprland.org) and
[Quickshell](https://quickshell.org) are dependencies of the *hands* and the
*body* layers only. Jarvis calls their CLIs; it does not include them, and the
voice loop runs without any of them.
