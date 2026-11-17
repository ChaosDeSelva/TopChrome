# TopChrome

[Project website](https://chaosdeselva.github.io/TopChrome/)

A standalone native macOS menu-bar app that turns a dedicated Google Chrome window into a quick browser drawer. It uses your installed Chrome and its most recently active profile, including your existing sign-ins, extensions, bookmarks, and native tabs.

## Install

[Download TopChrome 0.1.0 for Apple silicon](https://github.com/ChaosDeSelva/TopChrome/releases/download/v0.1.0/TopChrome-0.1.0-arm64.dmg). Open the disk image and drag TopChrome into Applications. Requires macOS 14 or later and Google Chrome.

## Use

Open TopChrome and click **Open Chrome Drawer**. Allow its macOS Automation request to control Google Chrome. If you have several Chrome profiles, activate a window in the profile you want before creating the drawer.

- Click the menu-bar icon or press **Control + Option + B** to show or hide the drawer.
- The drawer starts at **50% of usable screen height** and spans the display’s available width. The percentage button offers presets; drag the bottom edge to save any height between 30% and 95%. Chrome’s minimum window size still applies.
- The top-right expand button switches between full available height and your saved height. The hide button is immediately to its right.
- Click the shortcut hint, press **Command + comma** while TopChrome is active, or choose **Show / Hide Shortcut…** from the menu to remap the global shortcut. A conflict keeps your previous shortcut.
- Use Chrome’s native tabs and address bar. The toolbar’s **+** button adds a tab; Chrome’s usual keyboard shortcuts still work.
- In the updated TabShelf app, choose **Settings → Open links in → TopChrome** and save preferences. Saved sites and New Tab then open in this drawer, showing it if hidden and keeping existing tabs. TabShelf's Chrome option continues to use normal Chrome windows.
- Right-click the menu-bar icon for all controls.
- **Quit TopChrome (Keep Tabs)** leaves the drawer’s Chrome window available as a normal browser window. **Close Drawer Window & Quit…** closes only that window, after confirmation.

Hiding changes only the dedicated window’s visibility, keeping its tabs and page state without adding a minimized Dock tile. Showing restores that same window to the pointer’s display. Quitting TopChrome restores the window on screen. Chrome controls background-tab behavior. TopChrome never quits the whole browser. Tabs outside its drawer are untouched; optional desktop following moves all Chrome windows.

The drawer is a real Chrome window with a small companion toolbar. To follow normal desktop Spaces, choose **Desktop Following Setup… → Enable for All Chrome Windows**. This is opt-in because it brings **all Chrome windows**, including regular ones, to the active desktop while the drawer is shown. It preserves their tabs and live page state. Hiding the drawer suspends following; turn the option off in the same menu to stop moving Chrome.

Following uses the private macOS `SLSProcessAssignToSpace` interface. It moves Chrome before activation and checks that the drawer actually arrived, with a bounded wait for asynchronous window-server updates. A failed move leaves the tabs open and avoids activating Chrome on the wrong desktop. Missing interfaces, full-screen Spaces, and future macOS compatibility changes can prevent following. This approach does not require changing SIP, injecting code, or changing Chrome's persistent Dock assignment.

Another app can cover the browser; press the shortcut to bring it back. Native full-screen Spaces are not supported. Full height means the usable desktop area, not macOS native full screen.

The window has a unique name beginning with “TopChrome” so it can be found again after a controller relaunch. Renaming that window inside Chrome detaches it; the next show action creates a new drawer. Its tabs remain in Chrome.

TopChrome accepts explicit web links through `topchrome://open?url=<encoded-http-or-https-url>`. Open the app once after building to register this handoff. It accepts only HTTP/HTTPS addresses without embedded credentials. Opening a link launches TopChrome if needed; it does not change your default browser.

## Privacy

TopChrome has no account, telemetry, server, or project integration. It stores the height, shortcut, following preference, last window bounds, hidden state, and a random window identifier in local macOS preferences. It uses Chrome’s public AppleScript interface to manage its drawer. With desktop following enabled, it also moves Chrome's other windows. It does not copy or read Chrome profile files, cookies, passwords, history, page content, or tab URLs. Browsing itself remains subject to Chrome and website behavior.

The app requires Automation access to Google Chrome. It does not require Accessibility, Screen Recording, a browser extension, or remote debugging. Permissions can be changed in **System Settings → Privacy & Security → Automation**. Its desktop bridge reads process IDs, window geometry, and Space membership without reading window titles or images. Movement is restricted to the running Google Chrome process and requires a matching drawer window. Desktop API research is credited in [Third-party notices](Resources/ThirdPartyNotices.txt).

## Build locally

Requires macOS 14 or later, Google Chrome, and Swift 6 or later. There are no package dependencies or network downloads during the build.

```sh
zsh scripts/build.sh
open build/TopChrome.app
```

The local bundle is ad-hoc signed. For distribution, sign and notarize it on your signing Mac, retaining `Resources/TopChrome.entitlements` and the Automation usage description. Do not enable App Sandbox for this build. No release is published by the build script.

## Check

```sh
swift run --disable-sandbox TopChromeChecks
swift build --disable-sandbox
.build/debug/TopChrome --self-test
```

Core checks cover sizing, display coordinate conversion, invalid preferences, escaped window identifiers, and command scope. App checks cover preference persistence, shortcut conflicts, and compilation of all Chrome commands without executing them. Live review should also exercise show/hide, tab preservation, resizing, shortcut recording, external window closure, relaunch, and leaving unrelated Chrome windows alone.

## Source layout

- `Sources/TopChrome`: menu bar, window controls, preferences, shortcut recorder, and serialized Chrome commands.
- `Sources/TopChromeCore`: geometry and AppleScript generation.
- `Resources`: app metadata, icon, and Automation entitlement.
- `scripts`: local app packaging.

TopChrome is an independent project and is not affiliated with Google. A project license has not yet been selected.
