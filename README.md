# RTV 365 for Apple TV

Unofficial tvOS client for RTV Slovenija's 365 archive and live channels, built with SwiftUI and AVKit.
It talks to the same public "ava" API the 365.rtvslo.si web player uses.

## Features
- Risanke: children's programmes (RTV category "Otroške") with the newest episodes first, then every kids' show
- Live TV (TV SLO 1/2/3, Koper, Maribor, MMC TV) and live radio, with "now playing"
- Newest broadcasts, day by day
- Alphabetical show archive with per-show episode lists
- Search across shows and recordings
- Native tvOS player: scrubbing, subtitles, audio tracks, Picture in Picture

## Requirements
- Xcode 16 or newer (the project uses folder-synchronized groups)
- An Apple ID signed in to Xcode (free is enough; apps expire after 7 days, paid account gives 1 year)
- Apple TV and Mac on the same network

## Install on your Apple TV
1. Open `RTVSlovenija.xcodeproj` in Xcode.
2. The target is set to sign with your Personal Team automatically. If Xcode complains the bundle identifier is taken, change it under Signing & Capabilities.
3. On the Apple TV: Settings → Remotes and Devices → Remote App and Devices.
4. In Xcode: Window → Devices and Simulators → the Apple TV appears → Pair, type the code shown on the TV.
5. Pick the Apple TV as the run destination and press Run.

## Development tips
- Debug builds accept `-autoplayKids` as a launch argument, which opens the newest children's episode immediately:
  `xcrun simctl launch booted si.nejcvidrih.RTVSlovenija -autoplayKids`
- The player logs `RTVPLAYER ready/failed` lines, and `RTVClient.logShowClassification()` (DEBUG only) dumps
  the API's show categories if RTV ever renumbers them. Children's programmes are `showTypeId` 31.

## Notes
- Some content is geo-restricted to Slovenia and some sports/foreign shows are DRM-protected; those will show a "no stream" message.
- The API is unofficial and can change. All endpoint handling lives in `RTVSlovenija/API/RTVClient.swift`
  and the JSON field lookups in `RTVSlovenija/API/Models.swift`.
