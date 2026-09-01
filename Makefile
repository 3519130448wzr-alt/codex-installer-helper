.PHONY: test build app dmg security-check verify windows-test windows-security-check windows-build clean

test:
	swift run CodexInstallerCoreTests

build:
	swift build -c release --product CodexInstallerHelper

app:
	bash scripts/build-app.sh

dmg:
	bash scripts/create-dmg.sh

security-check:
	bash scripts/security-check.sh

verify: test security-check app

windows-test:
	pwsh -NoProfile -File windows/scripts/test.ps1

windows-security-check:
	pwsh -NoProfile -File windows/scripts/security-check.ps1

windows-build:
	pwsh -NoProfile -File windows/scripts/build.ps1 -Runtime win-x64 -Version "$(VERSION)"
	pwsh -NoProfile -File windows/scripts/build.ps1 -Runtime win-arm64 -Version "$(VERSION)"

clean:
	swift package clean
	rm -rf build
