# TopChrome

[Project website](https://chaosdeselva.github.io/TopChrome/)

A standalone native macOS menu-bar app that turns a dedicated Google Chrome window into a quick browser drawer. It uses your installed Chrome and its most recently active profile, including your existing sign-ins, extensions, bookmarks, and native tabs.

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

Hiding changes only the dedicated window’s visibility, keeping its tabs and page state without adding a minimized Dock tile. Showing restores that same window to the pointer’s display. Quitting TopChrome restores the window on screen. Chrome controls background-tab behavior. TopChrome never quits the whole browser or manages unrelated windows.

The drawer is a real Chrome window with a small companion toolbar. Desktop following relies on macOS: right-click **Google Chrome in the Dock → Options → Assign To → All Desktops**. This applies to **all Chrome windows**, including your regular ones. TopChrome only displays its controls when the drawer is on the current desktop; hiding keeps the drawer hidden across desktop changes. Choose **None** in Chrome's Dock menu to undo this setting.

**Known limitation:** automatic desktop following is not reliable on every macOS/Chrome combination. The window can remain on its original desktop even with All Desktops selected. TopChrome cannot independently move Chrome between Spaces. This remains an open compatibility issue; show/hide and tab management work independently of it.

Another app can cover the browser; press the shortcut to bring it back. Native full-screen Spaces are not supported. Full height means the usable desktop area, not macOS native full screen.

The window has a unique name beginning with “TopChrome” so it can be found again after a controller relaunch. Renaming that window inside Chrome detaches it; the next show action creates a new drawer. Its tabs remain in Chrome.

TopChrome accepts explicit web links through `topchrome://open?url=<encoded-http-or-https-url>`. Open the app once after building to register this handoff. It accepts only HTTP/HTTPS addresses without embedded credentials. Opening a link launches TopChrome if needed; it does not change your default browser.

## Privacy

TopChrome has no account, telemetry, server, or project integration. It stores the height, shortcut, last window bounds, hidden state, and a random window identifier in local macOS preferences. It uses Chrome’s public AppleScript interface to manage its own window. It does not copy or read Chrome profile files, cookies, passwords, history, page content, or tab URLs. Browsing itself remains subject to Chrome and website behavior.

The app requires Automation access to Google Chrome. It does not require Accessibility, Screen Recording, a browser extension, or remote debugging. Permissions can be changed in **System Settings → Privacy & Security → Automation**. It reads only process IDs and window geometry to check whether its drawer is on the active desktop. It uses public AppKit and Chrome scripting APIs; it does not modify WindowServer or change Chrome's desktop assignment automatically.

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
