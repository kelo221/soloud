SoLoud (patched fork)
=====================

This is a fork of [jarikomppa/soloud](https://github.com/jarikomppa/soloud)
with crash, hang and memory-safety fixes that have not been merged upstream.
Upstream's last commit is from August 2024, and many bug reports and fix pull
requests are still open there.

- Based on upstream `e82fd32` ("Flush to zero (FTZ) for ARM").
- Each fix is its own commit naming the upstream issue or pull request, so you
  can cherry-pick only the fixes you need.
- The C and C++ APIs are unchanged, except that `Wav` and `WavStream` can no
  longer be copied (copies used to double-free).
- This is an altered version of SoLoud, as the zlib license requires us to
  say. SoLoud itself is the work of Jari Komppa and its contributors; see the
  original README below.

## What is fixed

### Crashes, hangs and memory corruption

| Fix | Upstream | Thanks to |
|---|---|---|
| Looping WAV, FLAC and MP3 streams corrupted the heap at every loop, because `WavStreamInstance::seek` ran the Ogg decoder's seek on the other decoders. | [#405], [PR #379] | [@ivanpaulovich] (report), [@pgrAm] (fix) |
| Looping multi-channel streams wrote every channel after the first to the wrong place after a loop wrap. | [PR #379] | [@pgrAm] |
| A looping `WavStream` reported that it had ended. | [PR #379] | [@pgrAm] |
| Playing a `WavStream` loaded with `load` crashed when its file had been deleted or locked since loading (every voice reopens the file). Such a voice now ends at once, also when it loops. | — | |
| A `WavStream` whose WAV, FLAC or MP3 data was shorter than its header claimed never ended: once the data ran out, a voice that does not loop played silence forever. It now ends where the data does. | — | |
| Crash when more voices with the "tick when inaudible" behavior were playing than the active voice limit allows. | [#279], [#205], [#327] | [@VitorioK], [@asumagic], [@stohrendorf] |
| Infinite loop in `AudioSourceInstance::seek` with a scratch buffer smaller than one frame. | [#392] | [@klein-j] |
| Crash when playing or stopping voices before `init`, or after a failed `init`; memory leak when re-initializing. | [#404], [#324], [PR #345] | [@nuclear868], [@Calorado], [@valid-ptr] |
| More than 255 active voices hit an assert (a breakpoint even in MSVC release builds) or overran the stack, although `setMaxActiveVoiceCount` accepts up to 1023. | — | |
| Heap overflow and crashes on files with more than 8 channels or huge frame counts, and on Ogg files whose length reads as 0. | [#401], [#317] | [@oneafter], [@klein-j] |
| Infinite loop in the mixer when a voice's speed (including a large Doppler shift) needs 512 or more source frames per output frame. Such a voice is now silent until its speed drops. | [#343] | [@AniCator] |
| A voice playing at (nearly) zero speed mixed in leftover audio from the previous voice. | found while checking [#343] | [@AniCator] |
| Infinite loop in the mixer when `setSamplerate` gave a voice a negative rate. Such a voice is now silent. | — | |
| Out-of-bounds access when every voice was protected (`play` returned an error code that decodes as a real voice) and for handles whose slot field is 0 or above the voice limit. `play` now returns 0 when no voice is free. | — | |
| `Wav::loadRawWave*` accepted more than 8 channels (overflowing the mixer's buffers), data shorter than one frame, and a NaN sample rate. | — | |
| Copying a `Wav` or `WavStream` double-freed its data. They are now non-copyable. | [PR #375] | [@yig] |
| `LofiFilter` kept state for only 2 channels, so on sounds with more channels it read and wrote past its instance. | — | |
| `EchoFilter` crashed (division by zero) when its delay was set or faded to 0. | — | |
| `DCRemovalFilter` read its parent filter at the first mix rather than at `play`, so a filter destroyed after `play` was used after being freed. A length too long for an `int` wrote at a negative offset. | — | |
| `BiquadResonantFilter` read the sample before its buffer when given a single sample (a global filter in a one-frame mix). | — | |
| `FreeverbFilter` on mono audio hit an assert (a breakpoint even in MSVC release builds), or without asserts processed the next block of memory as the right channel. Mono audio is now left unchanged. | — | |
| `RobotizeFilter` crashed (division by zero) when its frequency was above the sample rate, 0 or negative. | — | |
| `FlangerFilter` crashed (division by zero) when its delay was set or faded to 0. | — | |
| `Soloud::seek` on a bus hit an assert (a breakpoint even in MSVC release builds) or crashed in the SSE pan code for most seek lengths, and overran the bus's buffer for voices with more channels than the bus. | — | |
| `Soloud::seek` on a bus right after a voice was stopped and another played into its slot wrote through a null pointer. | — | |
| `Bus::getApproximateVolume` read past its array for channel 8 of an 8-channel bus. | — | |
| A `Queue` holding a looping sound hung the audio thread, holding the engine's mutex, once that sound had played to its end. A queued sound that gives no more audio is now dropped. | — | |

### Wrong behavior

| Fix | Upstream | Thanks to |
|---|---|---|
| Protected voices could still be made inactive. | [#298] | [@klein-j] |
| `play3d` into a reused voice slot inherited the previous voice's 3D flags, giving it the wrong volume. | [#361] | [@petrihakkinen] |
| On mono and stereo sources played in stereo (the SSE path), a volume or pan change overshot its target in the last 1 to 3 frames of a mix whose length is not a multiple of 4 (by up to a third for a 6-frame mix). | — | |
| Mixing 5.1 or 7.1 sources to 4 speakers added the center and LFE channels without the voice's volume, so a muted or hard-panned voice still played them. 4-channel sources on 7.1 used the side speakers' volumes for the rear pair. | — | |
| Calling `setProtectVoice` did not take effect until something else (a play, stop, pause or volume change) recomputed the active voices, so a newly protected voice could stay silent. | — | |
| `setInaudibleBehavior` had the same problem: a voice set to tick when inaudible did not get its active slot until something else recomputed the active voices. | — | |
| Seeking, and looping back to a loop point, went to the wrong place when the play speed was not 1: twice as far at speed 2. | — | |
| With a loop point above 0, every loop wrap overwrote up to 511 frames of the voice that had already been mixed in that call with other audio from the sound. | — | |
| `BiquadResonantFilter` went unstable and produced infinity and NaN, silencing the whole mix, when its frequency was at or above half the rate it filters at. Voice filters run at the voice's own rate, so a slowed-down voice could trigger it with an ordinary cutoff. The frequency is now kept below that limit. | — | |
| `WaveShaperFilter` at its minimum amount of -1 (or past the curve's pole for other negative amounts) divided by zero and produced NaN. | — | |
| Every filter's `setParams` with a validity check accepted NaN. | — | |
| `FreeverbFilter` ignored the room size, damping and width given to `setParams` until some parameter was changed on the playing instance. | — | |
| `FreeverbFilter` and `RobotizeFilter` ignored `fadeFilterParameter` and `oscillateFilterParameter`. | — | |
| `FlangerFilter` advanced its sweep once per channel per frame, so the channels of a stereo sound were swept differently and twice as fast as set. | — | |
| On Windows, `M_PI` was defined with only 12 digits (MSVC does not define it), so panning, filters, 3D audio and generators differed slightly from other platforms, and a hard-panned voice leaked about -240 dB into the other side. | — | |
| The end of a sound was cut off, with a click, whenever a mix call ended partway through its last 512-frame block: with device buffers that are not a multiple of 512 frames (WASAPI's usually are not) or with any resampling. Up to one block of the source was lost, for example 600 frames of a 1000-frame sound at speed 0.73 in 256-frame calls. | — | |
| A sound queued in a `Queue` with fewer channels than the queue played the previous sound's audio on the queue's other channels. They are now silent. | — | |
| `oscillateVolume`, `oscillatePan`, `oscillateRelativePlaySpeed`, `oscillateGlobalVolume` and `oscillateFilterParameter` from a higher value to a lower one oscillated above the higher value instead of between the two: a volume oscillation from 1 to 0 went up to 2. | — | |
| Resampled voices (a sound whose sample rate differs from the engine's, or any play speed other than 1) played slightly fast: at the end of every 512-frame source block the resampler skipped up to one step of the source. A 44.1 kHz sound on a 48 kHz engine ran about 0.09% fast, 0.1 s ahead after three minutes. | [#314] | |

### Multiple engines in one process

| Fix | Thanks to |
|---|---|
| CoreAudio (macOS): every engine shared one audio queue, so deinitializing one engine silenced all the others. | Simon Bauer |
| MiniAudio: every engine shared one device, so starting a second engine broke the first, and deinitializing any engine stopped them all. | |
| A sound kept a pointer to the last engine it played on, so stopping or destroying it after that engine was destroyed used freed memory and hung or crashed. Buses and queues used after their engine was destroyed did the same. Sounds are now stopped on every live engine and never touch a destroyed one. | |
| A sound played on several engines was stopped on only one, so destroying it left the other engines playing freed samples. | |
| Sounds first played on different engines could get the same ID, so stopping one also stopped the other. | |

### Build

- CMake 3.5 minimum, so CMake 4 can configure the project.
- New `SOLOUD_BACKEND_MINIAUDIO` option.
- New `SOLOUD_MSVC_STATIC_RUNTIME` option for a self-contained Windows DLL
  (off by default, as upstream).
- `speech/Elements.def` is no longer treated as an MSVC module-definition file.

### Not fixed yet

Known upstream problems this fork has not fixed: slow and unreliable seeking
in non-Ogg streams ([#396], [#156]), and an assert during shutdown
([#307], [#241]).

## Prebuilt libraries

GitHub Actions builds the library below for every platform on each push to
`master` and each pull request, and tests every build: the smoke test on
Windows, Linux (in Ubuntu 20.04) and macOS, and the 16 KiB alignment check for
Android, which has no device to run on. Each run keeps the libraries as
artifacts for 90 days ([Actions](https://github.com/kelo221/soloud/actions/workflows/build.yml)); pushing
a tag that starts with `v` publishes them as a
[release](https://github.com/kelo221/soloud/releases), one zip per platform plus `SHA256SUMS.txt`.

The macOS library has an ad-hoc signature only, so macOS quarantines it when
it comes from a browser download. Clear that before use:
`xattr -d com.apple.quarantine libsoloud.dylib`.

## Building

The CMake project in `contrib/` works as before. These scripts build the
shared library with the C API:

| Platform | Command | Output | Backends |
|---|---|---|---|
| Windows x64 | `build_windows.bat` (Visual Studio 2022 or newer, CMake) | `bin/soloud.dll` | WASAPI, WinMM, Null |
| Linux x86_64 | `./build_linux.sh` (Docker) | `dist/linux-x64/libsoloud.so` | MiniAudio, Null |
| macOS (arm64 + x86_64) | `./build_macos.sh` (Xcode tools, CMake) | `dist/macos/libsoloud.dylib` | CoreAudio, Null |
| Android (arm64-v8a, armeabi-v7a) | `./build_android.sh` (Docker; downloads NDK r27d) | `dist/android/<abi>/libsoloud.so` | OpenSL ES, Null |

The Linux library is built in Ubuntu 20.04, so it runs on any distribution
with glibc 2.29 or newer. The Android libraries target API level 23, link
libc++ statically and use 16 KiB page alignment, which Android 15 devices with
16 KiB pages need; `python scripts/elf_info.py <library>` shows a library's
dependencies and alignment, and `--min-align 16384` makes it fail on a
library that is not aligned that way. `build_windows.bat` uses the newest
Visual Studio unless `SOLOUD_CMAKE_GENERATOR` names one. To check a build, run
`python scripts/smoke_native_lib.py <library> --device`. It mixes 300 voices
on the null driver, and checks that a second engine keeps playing after the
first one is shut down.

## Credits

SoLoud was written by [Jari Komppa](https://github.com/jarikomppa). Thank you
to everyone who reported the bugs and wrote the fixes listed above. This fork
is maintained by [@kelo221](https://github.com/kelo221).

[#156]: https://github.com/jarikomppa/soloud/issues/156
[#205]: https://github.com/jarikomppa/soloud/issues/205
[#241]: https://github.com/jarikomppa/soloud/issues/241
[#279]: https://github.com/jarikomppa/soloud/issues/279
[#298]: https://github.com/jarikomppa/soloud/issues/298
[#307]: https://github.com/jarikomppa/soloud/issues/307
[#314]: https://github.com/jarikomppa/soloud/issues/314
[#317]: https://github.com/jarikomppa/soloud/issues/317
[#324]: https://github.com/jarikomppa/soloud/issues/324
[#327]: https://github.com/jarikomppa/soloud/issues/327
[#343]: https://github.com/jarikomppa/soloud/issues/343
[#361]: https://github.com/jarikomppa/soloud/issues/361
[#392]: https://github.com/jarikomppa/soloud/issues/392
[#396]: https://github.com/jarikomppa/soloud/issues/396
[#401]: https://github.com/jarikomppa/soloud/issues/401
[#404]: https://github.com/jarikomppa/soloud/issues/404
[#405]: https://github.com/jarikomppa/soloud/issues/405
[PR #345]: https://github.com/jarikomppa/soloud/pull/345
[PR #375]: https://github.com/jarikomppa/soloud/pull/375
[PR #379]: https://github.com/jarikomppa/soloud/pull/379
[@AniCator]: https://github.com/AniCator
[@asumagic]: https://github.com/asumagic
[@Calorado]: https://github.com/Calorado
[@ivanpaulovich]: https://github.com/ivanpaulovich
[@klein-j]: https://github.com/klein-j
[@nuclear868]: https://github.com/nuclear868
[@oneafter]: https://github.com/oneafter
[@petrihakkinen]: https://github.com/petrihakkinen
[@pgrAm]: https://github.com/pgrAm
[@stohrendorf]: https://github.com/stohrendorf
[@valid-ptr]: https://github.com/valid-ptr
[@VitorioK]: https://github.com/VitorioK
[@yig]: https://github.com/yig

---

SoLoud
======

SoLoud is an easy to use, free, portable c/c++ audio engine for games.

![ScreenShot](https://raw.github.com/jarikomppa/soloud/master/soloud.png)

Zlib/LibPng licensed. Portable. Easy.

Official site with documentation can be found at:
 http://soloud-audio.com
