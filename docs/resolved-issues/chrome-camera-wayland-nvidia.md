# Chrome Camera Broken on Wayland + NVIDIA

## Issue

Camera feed not rendering in Chrome (Google Meet, etc.) on a Wayland session with an NVIDIA GPU.

## Environment

- OS: CachyOS (Arch-based), kernel 6.19.x
- GPUs: NVIDIA RTX 4060 Ti (discrete, `renderD128`) + AMD Raphael iGPU (`renderD129`)
- Session: Wayland (niri)
- Chrome: Ozone/Wayland backend

## Symptoms

- Camera LED turns on — Chrome accesses the device successfully.
- No video stream displayed in Google Meet or other WebRTC apps.
- Camera works fine in Firefox under the same Wayland session.
- Chrome console spams these errors in a loop:

```
OzoneImageBacking::ProduceSkiaGanesh failed to create GL representation
SharedImageManager::ProduceSkia: Trying to produce a Skia representation from an incompatible backing: OzoneImageBacking
eglCreateImage failed with 0x00003009
Unable to initialize binding from pixmap
```

## Root Cause

Chrome's Ozone/Wayland backend receives camera frames from PipeWire as DMA-BUF pixmaps. It then tries to import these as EGL images on the NVIDIA GPU for rendering via the Skia Ganesh pipeline. NVIDIA's EGL implementation fails to create images from these pixmaps (`eglCreateImage` returns `0x00003009`), so every frame is silently dropped.

Firefox handles the PipeWire DMA-BUF → GPU path differently and is unaffected.

## What Did NOT Fix It

| Attempted Fix | Result |
|---|---|
| `--disable-video-capture-use-gpu-memory-buffer` | No effect — frames still routed through EGL |
| `--use-angle=vulkan --enable-features=Vulkan` | Chrome window goes completely black |
| `--video-capture-device-render-node=/dev/dri/renderD129` | No effect — same EGL errors |
| `--render-node-override=/dev/dri/renderD129` (AMD iGPU) | Camera works, but causes screen tearing |

## Solution

Force Chrome to use the X11/XWayland backend instead of native Ozone/Wayland:

```
--ozone-platform=x11
```

### Permanent Fix

Add to `~/.config/chrome-flags.conf`:

```
--ozone-platform=x11
```

## Trade-offs

Running under XWayland means Chrome is not using native Wayland. Minor differences:
- Fractional scaling may be slightly blurrier (rendered at integer scale, then scaled by compositor).
- Some Wayland-native features (e.g., per-monitor scaling, input protocols) are handled by XWayland instead.

Functionally no issues observed.

## Notes

- This is an upstream issue in Chrome's Ozone backend + NVIDIA proprietary driver EGL.
- May be resolved in future Chrome or NVIDIA driver updates — periodically test by removing the flag.
