Moe Memos
=========

[![justforfunnoreally.dev badge](https://img.shields.io/badge/justforfunnoreally-dev-9ff)](https://justforfunnoreally.dev)

<img alt="Moe Memos" src="https://memos.moe/memos.png" width="160" height="160" />

**Moe Memos** is an app to help you capture thoughts and ideas.

*Use Moe Memos with either a self-hosted [✍️memos](https://github.com/usememos/memos) server or local on-device storage (no server required).*

**Note: Current Moe Memos version supports Memos 0.21.0 and Memos 0.27.0 to 0.31.0. Memos updates may introduce breaking API changes. If you are using a version higher than 0.31.0, it is recommended to use [Mortis](https://github.com/mudkipme/mortis) to convert the newer Memos API to the Memos 0.21.0 API and re-login in Moe Memos.**

## Installation

[![Download Moe Memos on the App Store](https://memos.moe/app-store-badge.svg)](https://apps.apple.com/app/moe-memos/id1643902185)
[![Join Moe Memos on TestFlight](https://img.shields.io/badge/TestFlight-Join%20Beta-0D96F6?logo=apple&logoColor=white)](https://testflight.apple.com/join/YVHheZ50)

Moe Memos is available on App Store for free. You can also build this app with Xcode and run on your devices. iOS 18 or higher is required.

## Features

![Screenshot](https://memos.moe/screenshot.png)

- Write memos like tweeting to yourself
- Use local on-device storage or sync with your own ✍️memos server
- Fully functional offline and automatically pushes data when back online
- Extended Markdown support
- Upload images, videos, and other file types
- Organize and find memos with tags, pinning, and search
- View your memo activity with a progress graph
- Liquid Glass, Dark Mode, and Dynamic Type support
- Available on iPhone and iPad with multitasking support
- Full privacy protection, no data collection

Moe Memos is a third-party client for [✍️memos](https://github.com/usememos/memos) and both projects aren't affiliated with each other.

## Development

Moe Memos tends to keep minimal and optimized for best native experience. It uses modern Swift and Apple platform features such as SwiftUI, async await and it keeps dependencies as few as possible.

Any contributions are greatly appreciated.

### Package organization

| Package | Responsibility |
| --- | --- |
| `Models` | Shared types, SwiftData model definitions, stable memo identifiers, and service contracts |
| `Services` | Remote Memos API clients |
| `MemoData` | Store setup, local services, sync, attachment files, export, credentials, and account sessions |
| `Account` | Account screens and their presentation state |
| `MemoKit` | Memo editor, drafts, and reusable attachment UI |
| `MemoSystem` | App Entities, Siri actions, Spotlight indexing, and onscreen entity annotations |
| `DesignSystem` / `Env` | Shared UI components / navigation state |

`Account`, `MemoKit`, and `MemoSystem` depend on `MemoData`, which depends on `Models` and `Services`. The data layer has no dependency on UI, navigation, App Intents, or Spotlight. SwiftData model types remain in `Models` so moving implementation code doesn't change the persisted schema.

After a successful save, `MemoData` publishes affected memo identities through `MemoChanges`. Hosts that need indexing register `MemoSpotlightIndex` as its observer before writing data. The main app and share extension register at their entry points; background memo intents register before performing mutations. Widgets can read data without activating indexing. Hosts can await `MemoChanges.flush()` before ending a short-lived operation.

The app registers a `MemoNavigator` dependency to handle opening memos. `MemoSystem` doesn't know about the app's routes or account screens. Intent/entity identifiers and existing widget identifiers must remain stable when reorganizing modules.

## License

The iOS version of Moe Memos is under [MPLv2](LICENSE).

While the open source license doesn't prevent anyone rename and repackage this app to distribute, it violates App Store Review Guidelines 4.1 to do so. It's welcome to build apps based off of the code in this repository and make it meaningfully different.
