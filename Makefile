WORKSPACE := ios/Runner.xcworkspace
SCHEME := Runner
CONFIGURATION := Debug
DERIVED_DATA := tmp/DerivedData
IOS_APP := $(DERIVED_DATA)/Build/Products/$(CONFIGURATION)-iphoneos/Runner.app
# ios target が flutter run する simulator。sim-boot でプロジェクト固有 simulator を起動して解決する (?= なので ios 以外の target では起動しない)
SIMULATOR_UDID ?= $(shell SCRIPT_QUIET=1 sim-boot | sed -n 's/^DEVICE_UDID=//p' | tail -n 1)

.PHONY: ios-device install-ios run-ios clean

# iOS アプリの実機向け Debug ビルド。Debug の bundle ID は com.bannzai.kashakeibo.dev で、kashakeibo-dev の Firebase 設定が同梱される。
# xcodebuild の前に flutter build ios --config-only で Generated.xcconfig 等を毎回生成し直す。
# 実機は code signing が必要なため、provisioning profile の自動生成とデバイス登録を CLI から行えるようにする
ios-device:
	flutter build ios --config-only --debug
	xcodebuild -workspace $(WORKSPACE) -scheme $(SCHEME) -configuration $(CONFIGURATION) -derivedDataPath $(DERIVED_DATA) -destination 'generic/platform=iOS' -allowProvisioningUpdates -allowProvisioningDeviceRegistration build

# 実機ビルドを接続中の実機にインストールする。インストール先は DEVICE 変数 (名前 / UDID) で指定でき、未指定なら devicectl の JSON から接続中デバイスを自動解決する
install-ios: ios-device
	@device="$(DEVICE)"; \
	if [ -z "$$device" ]; then \
		xcrun devicectl list devices --json-output tmp/devices.json > /dev/null; \
		device=$$(jq -r '[.result.devices[] | select(.connectionProperties.tunnelState == "connected")][0].identifier // empty' tmp/devices.json); \
	fi; \
	[ -n "$$device" ] || { echo "Error: 接続中の実機が見つかりません (DEVICE=<名前|UDID> で指定してください)" >&2; exit 1; }; \
	xcrun devicectl device install app --device "$$device" "$(IOS_APP)"

# 実機でホットリロード付きの通常開発を行う。対象は DEVICE 変数 (デバイス ID) で指定でき、未指定なら flutter devices から物理 iOS デバイスを自動解決する
run-ios:
	@device="$(DEVICE)"; \
	if [ -z "$$device" ]; then \
		device=$$(flutter devices --machine | jq -r '[.[] | select(.targetPlatform == "ios" and .emulator == false)][0].id // empty'); \
	fi; \
	[ -n "$$device" ] || { echo "Error: 接続中の実機が見つかりません (DEVICE=<デバイス ID> で指定してください)" >&2; exit 1; }; \
	flutter run --debug -d "$$device"

clean:
	rm -rf $(DERIVED_DATA)

# 引数なしの make で ios を実行する (人が手で動作確認するための入口。検査・テストは CI が行う)
.DEFAULT_GOAL := ios

.PHONY: verify
verify:
	flutter pub get
	flutter analyze --no-pub --no-fatal-infos --fatal-warnings
	dart format --set-exit-if-changed ./
	flutter test
	cd workers/image && npm ci && npm run typecheck && npm test

# プロジェクト固有の simulator (sim-boot で起動) へ flutter run する。SIMULATOR_UDID=<UDID> で対象を指定できる
.PHONY: ios
ios:
	@set -e; \
	simulator_udid="$(SIMULATOR_UDID)"; \
	[ -n "$$simulator_udid" ] || { echo "Error: sim-boot で Simulator を解決できません (sim-boot が PATH にあるか確認するか、SIMULATOR_UDID=<UDID> を指定してください)" >&2; exit 1; }; \
	flutter run --debug -d "$$simulator_udid"
