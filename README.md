# EZMac

EZMac is a suite of utility applications for macOS, designed to enhance your system management experience.

</div>

## Applications

### EZDisplay

<div align="center">
  <img src="docs/icon.png" width="256" alt="EZDisplay"/>
</div>

EZDisplay is the first tool in the suite, focused on simplifying external display management. It is a part of the EZMac family.

<div align="center">
  <img src="docs/app.png" width="400" alt="EZDisplay App View"/>
</div>

#### Features

- **Brightness Control:** Adjust the brightness of external monitors directly from your Mac, utilizing DDC/CI commands.
- **Resolution Switcher:** Quickly change display resolutions.
- **Menu Bar App:** Easily accessible controls from the macOS menu bar.

## Prerequisites

- macOS 11.0 or later.
- Xcode 13.0 or later (for building from source).

## Getting Started

To build and run the applications locally (starting with EZDisplay):

1. **Clone the repository:**
   ```bash
   git clone https://github.com/RXNova/ez-mac.git
   cd ez-mac
   ```

2. **Open the project in Xcode:**
   Double-click on `EZDisplay/EZDisplay.xcodeproj` or run:
   ```bash
   xed EZDisplay
   ```

3. **Build and Run:**
   - Select the **EZDisplay** scheme in the top toolbar to build EZDisplay.
   - Choose your Mac as the destination (My Mac).
   - Press `Cmd + R` or click the **Run** button (Play icon).

## Project Structure (EZDisplay)

- `EZDisplay/EZDisplay/App`: Application lifecycle and entry point (`EZDisplayApp.swift`).
- `EZDisplay/EZDisplay/Drivers`: Specific drivers for brightness control (DDC, Internal).
- `EZDisplay/EZDisplay/Services`: Core logic for managing displays and resolutions.
- `EZDisplay/EZDisplay/UI`: SwiftUI views for the user interface.
- `EZDisplay/EZDisplay/Models`: Data models for display configurations.
- `EZDisplay/EZDisplay/Bridging`: Objective-C bridging headers (IOKit).

## Permissions

The application may require permissions to control external displays via IOKit. Ensure you grant any prompted access rights when running the app.

---

## Developer Notes

### How DDC / External Display Brightness Works

DDC/CI (Display Data Channel / Command Interface) is a standard protocol for sending control commands to a monitor over its video cable. EZDisplay sends VCP (Virtual Control Panel) codes to read and set values like brightness, contrast, volume, and sharpness. The transport layer differs between Apple Silicon and Intel Macs.

#### Apple Silicon — `IOAVService` (CoreDisplay)

On Apple Silicon, the GPU communicates with external displays through `DCPAVServiceProxy` — an IOKit service that wraps the display pipeline. Apple exposes an I²C bridge on top of this via three private functions in `CoreDisplay.framework`:

| Symbol | Purpose |
|---|---|
| `IOAVServiceCreateWithService` | Creates an AV service handle for a `DCPAVServiceProxy` IOKit entry |
| `IOAVServiceWriteI2C` | Sends a raw DDC packet to the display |
| `IOAVServiceReadI2C` | Reads the DDC reply from the display |

These are loaded at runtime via `dlopen` + `dlsym` to avoid a hard link against the private framework. The service is matched by its `Location` property (`"External"` or `"Embedded"`) in the IORegistry.

#### Intel Macs — `IOFramebuffer` I²C

On Intel Macs, the GPU exposes `IOFramebuffer` entries in the IORegistry. Each framebuffer can have one or more I²C buses, accessed via `IOKit`'s public `IOI2CInterface` API (exposed through the bridging header):

| Symbol | Purpose |
|---|---|
| `IOFBGetI2CInterfaceCount` | How many I²C buses the framebuffer has |
| `IOFBCopyI2CInterfaceForBus` | Gets a handle to a specific bus |
| `IOI2CInterfaceOpen` / `IOI2CSendRequest` | Opens the bus and sends a DDC request |

The framebuffer is matched by `IOFramebufferUnit` number, which correlates with the `CGDisplayUnitNumber` from CoreGraphics.

#### Fallback Chain

`DDCBrightnessDriver` tries Apple Silicon path first, then falls back to Intel:

```
ddcGet / ddcSet
  └─ findAVService()        → Apple Silicon (IOAVService via DCPAVServiceProxy)
       if nil →
  └─ findFramebuffer()      → Intel (IOFramebuffer I²C)
```

---

### Internal Display Brightness

Internal (built-in) displays are controlled through `DisplayServices.framework` — a private framework that works on both Intel and Apple Silicon:

| Symbol | Purpose |
|---|---|
| `DisplayServicesGetBrightness` | Reads current brightness (0.0–1.0) |
| `DisplayServicesSetBrightness` | Sets brightness |
| `DisplayServicesCanChangeBrightness` | Whether the display supports software dimming |

Also loaded via `dlopen`/`dlsym` at runtime.

---

### Software Display Disconnect

Toggling a display on/off uses a different API depending on the macOS version:

| macOS | API | Notes |
|---|---|---|
| 26+ | `SLSConfigureDisplayEnabled` via `SkyLight.framework` | Requires a `CGDisplayConfigRef` transaction |
| 12–15 | `CoreDisplay_Display_SetUserEnabled` via `CoreDisplay.framework` | Direct call, no transaction needed |

The app prefers SkyLight and falls back to CoreDisplay. Configuration is persisted in `UserDefaults` so soft-disconnected displays survive restarts, and an auto-restore fires if all displays go dark (e.g. external monitor powered off while internal is soft-disconnected).
