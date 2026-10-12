"""Smoke-test a built SoLoud shared library through its C API.

Usage: python scripts/smoke_native_lib.py <path to soloud.dll/.so/.dylib> [--device]

Always: null-driver offline mix with 300 simultaneous voices (above the old
255 cap), checking the output is finite and not silent.
--device: two engines on the default device backend; deinit the first and
check the second keeps advancing (per-engine backend state). Output is muted.
"""
import ctypes
import math
import sys
import time

AUTO, NULLDRIVER, CLIP_ROUNDOFF = 0, 16, 1
SFXR_EXPLOSION = 2


def load(path):
    lib = ctypes.CDLL(path)
    p, u, i = ctypes.c_void_p, ctypes.c_uint, ctypes.c_int
    sigs = {
        "Soloud_create": (p, []), "Soloud_destroy": (None, [p]),
        "Soloud_initEx": (i, [p, u, u, u, u, u]), "Soloud_deinit": (None, [p]),
        "Soloud_getBackendString": (ctypes.c_char_p, [p]),
        "Soloud_play": (u, [p, p]), "Soloud_mix": (None, [p, ctypes.POINTER(ctypes.c_float), u]),
        "Soloud_getStreamTime": (ctypes.c_double, [p, u]),
        "Soloud_getActiveVoiceCount": (u, [p]), "Soloud_getVoiceCount": (u, [p]),
        "Soloud_setMaxActiveVoiceCount": (i, [p, u]),
        "Soloud_setGlobalVolume": (None, [p, ctypes.c_float]),
        "Sfxr_create": (p, []), "Sfxr_destroy": (None, [p]),
        "Sfxr_loadPreset": (i, [p, i, i]), "Sfxr_setLooping": (None, [p, i]),
    }
    for name, (res, args) in sigs.items():
        fn = getattr(lib, name)
        fn.restype, fn.argtypes = res, args
    return lib


def make_sound(lib):
    sfx = lib.Sfxr_create()
    assert lib.Sfxr_loadPreset(sfx, SFXR_EXPLOSION, 42) == 0
    lib.Sfxr_setLooping(sfx, 1)
    return sfx


def null_mix(lib):
    so = lib.Soloud_create()
    assert lib.Soloud_initEx(so, CLIP_ROUNDOFF, NULLDRIVER, 44100, 512, 2) == 0
    assert lib.Soloud_setMaxActiveVoiceCount(so, 300) == 0
    sfx = make_sound(lib)
    for _ in range(300):
        lib.Soloud_play(so, sfx)
    buf = (ctypes.c_float * (512 * 2))()
    peak = 0.0
    for _ in range(20):
        lib.Soloud_mix(so, buf, 512)
        assert all(math.isfinite(x) for x in buf), "non-finite sample"
        peak = max(peak, max(abs(x) for x in buf))
    active, voices = lib.Soloud_getActiveVoiceCount(so), lib.Soloud_getVoiceCount(so)
    assert voices == 300 and active == 300, (voices, active)
    assert peak > 0.01, peak
    # Sources must die before their engine: ~AudioSource calls back into it.
    lib.Sfxr_destroy(sfx)
    lib.Soloud_deinit(so)
    lib.Soloud_destroy(so)
    print(f"null driver: 300 voices active, peak {peak:.3f}, output finite")


def two_engines(lib):
    sfx = make_sound(lib)
    engines, handles = [], []
    for _ in range(2):
        so = lib.Soloud_create()
        rc = lib.Soloud_initEx(so, CLIP_ROUNDOFF, AUTO, 0, 0, 2)
        assert rc == 0, f"device init failed ({rc})"
        lib.Soloud_setGlobalVolume(so, 0.0)
        engines.append(so)
        handles.append(lib.Soloud_play(so, sfx))
    backend = lib.Soloud_getBackendString(engines[0]).decode()
    time.sleep(0.5)
    before = lib.Soloud_getStreamTime(engines[1], handles[1])
    lib.Soloud_deinit(engines[0])
    time.sleep(0.5)
    after = lib.Soloud_getStreamTime(engines[1], handles[1])
    lib.Sfxr_destroy(sfx)
    lib.Soloud_deinit(engines[1])
    for so in engines:
        lib.Soloud_destroy(so)
    assert before > 0.2, f"second engine never started ({before:.3f}s)"
    assert after - before > 0.3, f"second engine stopped with the first ({before:.3f}s -> {after:.3f}s)"
    print(f"device ({backend}): engine 2 kept playing after engine 1 deinit "
          f"({before:.2f}s -> {after:.2f}s)")


if __name__ == "__main__":
    library = load(sys.argv[1])
    null_mix(library)
    if "--device" in sys.argv[2:]:
        two_engines(library)
    print("OK")
