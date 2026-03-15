# EZMac

EZMac is a macOS application designed to simplify the management of external display settings, such as brightness (via DDC/CI) and resolution.

## Features

- **Brightness Control:** Adjust the brightness of external monitors directly from your Mac, utilizing DDC/CI commands.
- **Resolution Switcher:** Quickly change display resolutions.
- **Menu Bar App:** Easily accessible controls from the macOS menu bar.

## Prerequisites

- macOS 11.0 or later.
- Xcode 13.0 or later (for building from source).

## Getting Started

To build and run the application locally:

1. **Clone the repository:**
   ```bash
   git clone https://github.com/RXNova/ez-mac.git
   cd ez-mac
   ```

2. **Open the project in Xcode:**
   Double-click on `EZMac.xcodeproj` or run:
   ```bash
   xed .
   ```

3. **Build and Run:**
   - Select the **EZMac** scheme in the top toolbar.
   - Choose your Mac as the destination (My Mac).
   - Press `Cmd + R` or click the **Run** button (Play icon).

## Project Structure

- `EZMac/App`: Application lifecycle and entry point (`EZMacApp.swift`).
- `EZMac/Drivers`: Specific drivers for brightness control (DDC, Internal).
- `EZMac/Services`: Core logic for managing displays and resolutions.
- `EZMac/UI`: SwiftUI views for the user interface.
- `EZMac/Models`: Data models for display configurations.
- `EZMac/Bridging`: Objective-C bridging headers (IOKit).

## Permissions

The application may require permissions to control external displays via IOKit. Ensure you grant any prompted access rights when running the app.
