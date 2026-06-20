# MacBrowser (`apps/macos`)

Native macOS browser app (Swift + SwiftUI + WebKit), Arc-style. The reusable engine lives in the
[`BrowserCore`](../../packages/BrowserCore) Swift package; this target only hosts the UI.

- **Minimum OS:** macOS 14 (Sonoma)
- **Bundle id:** `com.iosbrowser.macos`
- **Project generation:** [XcodeGen](https://github.com/yonyz/XcodeGen) (`project.yml`)

## Prerequisites

```sh
brew install xcodegen   # if not already installed
```

This machine has full **Xcode** in `/Applications/Xcode.app`, but `xcode-select` may point at the
Command Line Tools. The build commands below prefix `DEVELOPER_DIR=...` so no global change is needed.
To switch globally instead (optional, one-time):

```sh
sudo xcode-select -s /Applications/Xcode.app
```

## Generate / regenerate the Xcode project

`MacBrowser.xcodeproj` is generated from `project.yml`. Regenerate it whenever sources or settings
change:

```sh
cd apps/macos
xcodegen generate
```

## Open in Xcode

```sh
cd apps/macos
open MacBrowser.xcodeproj
```

Select the **MacBrowser** scheme and press ⌘R.

## Build from the CLI

```sh
cd apps/macos
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -scheme MacBrowser -destination 'platform=macOS' build
```

(Drop the `DEVELOPER_DIR=...` prefix if you ran `sudo xcode-select -s /Applications/Xcode.app`.)

## Run the built app

Find and launch the freshly built `.app` from the build output:

```sh
APP=$(DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -scheme MacBrowser -destination 'platform=macOS' \
  -showBuildSettings 2>/dev/null | awk -F' = ' '/ BUILT_PRODUCTS_DIR /{d=$2} / FULL_PRODUCT_NAME /{n=$2} END{print d"/"n}')
open "$APP"
```

Or just run it from Xcode with ⌘R.
