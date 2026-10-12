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
| Crash when more voices with the "tick when inaudible" behavior were playing than the active voice limit allows. | [#279], [#205], [#327] | [@VitorioK], [@asumagic], [@stohrendorf] |
| Infinite loop in `AudioSourceInstance::seek` with a scratch buffer smaller than one frame. | [#392] | [@klein-j] |
| Crash when playing or stopping voices before `init`, or after a failed `init`; memory leak when re-initializing. | [#404], [#324], [PR #345] | [@nuclear868], [@Calorado], [@valid-ptr] |
| More than 255 active voices hit an assert (a breakpoint even in MSVC release builds) or overran the stack, although `setMaxActiveVoiceCount` accepts up to 1023. | — | |
| Heap overflow and crashes on files with more than 8 channels or huge frame counts, and on Ogg files whose length reads as 0. | [#401], [#317] | [@oneafter], [@klein-j] |
| A voice playing at (nearly) zero speed mixed in leftover audio from the previous voice. | found while checking [#343] | [@AniCator] |
| Copying a `Wav` or `WavStream` double-freed its data. They are now non-copyable. | [PR #375] | [@yig] |

### Wrong behavior

| Fix | Upstream | Thanks to |
|---|---|---|
| Protected voices could still be made inactive. | [#298] | [@klein-j] |
| `play3d` into a reused voice slot inherited the previous voice's 3D flags, giving it the wrong volume. | [#361] | [@petrihakkinen] |

### Multiple engines in one process

| Fix | Thanks to |
|---|---|
| CoreAudio (macOS): every engine shared one audio queue, so deinitializing one engine silenced all the others. | Simon Bauer |
| MiniAudio: every engine shared one device, so starting a second engine broke the first, and deinitializing any engine stopped them all. | |

### Build

- CMake 3.5 minimum, so CMake 4 can configure the project.
- New `SOLOUD_BACKEND_MINIAUDIO` option.
- New `SOLOUD_MSVC_STATIC_RUNTIME` option for a self-contained Windows DLL
  (off by default, as upstream).
- `speech/Elements.def` is no longer treated as an MSVC module-definition file.

### Not fixed yet

Known upstream problems this fork has not fixed: playback position drift when
the source and output sample rates differ ([#314]), slow and unreliable seeking
in non-Ogg streams ([#396], [#156]), and an assert during shutdown
([#307], [#241]). The infinite loop reported in [#343] could not be reproduced.

## Building

The CMake project in `contrib/` works as before. These scripts build the
shared library with the C API:

| Platform | Command | Output | Backends |
|---|---|---|---|
| Windows x64 | `build_windows.bat` (Visual Studio 2022, CMake) | `bin/soloud.dll` | WASAPI, WinMM, Null |
| Linux x86_64 | `./build_linux.sh` (Docker) | `dist/linux-x64/libsoloud.so` | MiniAudio, Null |
| macOS (arm64 + x86_64) | `./build_macos.sh` (Xcode tools, CMake) | `dist/macos/libsoloud.dylib` | CoreAudio, Null |

The Linux library is built in Ubuntu 20.04, so it runs on any distribution
with glibc 2.29 or newer. To check a build, run
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
