# Building & running

## Requirements
- macOS with **Xcode 16+** (the project uses Xcode-16 file-system synchronized
  groups and targets iOS 17+).
- Optional: [XcodeGen](https://github.com/yonsei/XcodeGen) (`brew install
  xcodegen`) to regenerate the project from `project.yml`.

## Open & run
```bash
open VoiceAlarm.xcodeproj
```
Pick the **VoiceAlarm** scheme and a simulator, then **⌘R**.

## Run on a physical iPhone
Alarms, microphone, and notification sounds are best verified on a real device.

1. Select the **VoiceAlarm** target → **Signing & Capabilities**.
2. Set **Team** to your Apple ID / developer team. (The project ships with
   `CODE_SIGNING_ALLOWED=NO` so it builds for the simulator and in CI without a
   team; you only need a team for device installs.)
3. Choose your iPhone as the run destination and **⌘R**.
4. On first launch, allow **Notifications** (so alarms can sound) and grant
   **Microphone** access when you record.

## Command line
```bash
make build     # build for simulator
make test      # run all tests
make generate  # regenerate the .xcodeproj from project.yml (needs xcodegen)
```

Override the simulator:
```bash
make test DESTINATION='platform=iOS Simulator,name=iPhone 15'
```

## Bundle identifier
The default is `com.voicealarm.app`. Change it in `project.yml` (then
`xcodegen generate`) or directly in the target's build settings.

## Regenerating the project
The committed `VoiceAlarm.xcodeproj` is the source you open day-to-day. If it ever
gets into a bad state, `project.yml` is the canonical definition:
```bash
rm -rf VoiceAlarm.xcodeproj
xcodegen generate
```
CI verifies that this regeneration always produces a buildable, test-passing
project.
