# Convenience wrappers. Requires macOS + Xcode. XcodeGen is optional (only for
# `make generate`): install with `brew install xcodegen`.

SCHEME = VoiceAlarm
PROJECT = VoiceAlarm.xcodeproj
DESTINATION ?= platform=iOS Simulator,name=iPhone 16

.PHONY: help generate test build clean open

help:
	@echo "Targets:"
	@echo "  make generate  - regenerate $(PROJECT) from project.yml (needs xcodegen)"
	@echo "  make build     - build the app for the simulator"
	@echo "  make test      - run unit + UI tests on the simulator"
	@echo "  make open      - open the project in Xcode"
	@echo "  make clean     - remove build artifacts"
	@echo ""
	@echo "Override the simulator with: make test DESTINATION='platform=iOS Simulator,name=iPhone 15'"

generate:
	xcodegen generate

build:
	xcodebuild build -project $(PROJECT) -scheme $(SCHEME) -destination "$(DESTINATION)" CODE_SIGNING_ALLOWED=NO

test:
	xcodebuild test -project $(PROJECT) -scheme $(SCHEME) -destination "$(DESTINATION)" CODE_SIGNING_ALLOWED=NO

open:
	open $(PROJECT)

clean:
	xcodebuild clean -project $(PROJECT) -scheme $(SCHEME) || true
	rm -rf build DerivedData *.xcresult
