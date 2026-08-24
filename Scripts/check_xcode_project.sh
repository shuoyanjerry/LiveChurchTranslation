#!/bin/bash
set -euo pipefail

fail() {
  echo "Xcode project check failed: $*" >&2
  exit 1
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT="${1:-$REPOSITORY_ROOT/LiveChurchTranslation.xcodeproj}"
PBXPROJ="$PROJECT/project.pbxproj"
SCHEME="$PROJECT/xcshareddata/xcschemes/LiveChurchTranslation.xcscheme"
RESOLVED="$PROJECT/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"

[[ -d "$PROJECT" && -f "$PBXPROJ" ]] || fail "generated .xcodeproj is missing"
[[ -f "$SCHEME" ]] || fail "shared Archive scheme is missing"
[[ -f "$RESOLVED" ]] || fail "workspace Package.resolved is missing"
if git -C "$REPOSITORY_ROOT" ls-files \
  | rg -q '(^|/)LiveChurchTranslation[.]xcodeproj/xcuserdata/'; then
  fail "repository tracks Xcode user-specific data"
fi
plutil -lint "$PBXPROJ" >/dev/null || fail "project.pbxproj is invalid"
xmllint --noout "$SCHEME" || fail "shared scheme XML is invalid"
cmp -s "$REPOSITORY_ROOT/Package.resolved" "$RESOLVED" \
  || fail "workspace dependency lock differs from Package.resolved"

PBX_PATTERNS=(
  'productType = "com.apple.product-type.application";'
  'productName = ChurchTranslatorApp;'
  'relativePath = .;'
  'LiveChurchTranslationMain.swift'
  'Packaging/Info.plist'
  'Packaging/LiveChurchTranslation.entitlements'
  'PrivacyInfo.xcprivacy'
  'AppIcon.xcassets'
  'ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;'
  '$(SRCROOT)/Package.swift'
  'Scripts/embed_app_store_runtime.sh'
  'ditto --clone'
  'Packaging/ProductionModels.sha256'
  'Packaging/LicenseFiles.sha256'
  'ENABLE_APP_SANDBOX = YES;'
  'ENABLE_HARDENED_RUNTIME = YES;'
  'ENABLE_USER_SCRIPT_SANDBOXING = YES;'
  'EXECUTABLE_NAME = LiveChurchTranslation;'
  'ARCHS = arm64;'
)
for pattern in "${PBX_PATTERNS[@]}"; do
  rg -Fq "$pattern" "$PBXPROJ" || fail "project is missing contract: $pattern"
done
MODEL_MEMBERS=(
  qwen3-asr-0.6b-int8-2026-03-25/conv_frontend.onnx
  qwen3-asr-0.6b-int8-2026-03-25/encoder.int8.onnx
  qwen3-asr-0.6b-int8-2026-03-25/decoder.int8.onnx
  qwen3-asr-0.6b-int8-2026-03-25/tokenizer/merges.txt
  qwen3-asr-0.6b-int8-2026-03-25/tokenizer/tokenizer_config.json
  qwen3-asr-0.6b-int8-2026-03-25/tokenizer/vocab.json
  hy-mt2-1.8b-q4-k-m/Hy-MT2-1.8B-Q4_K_M.gguf
)
for member in "${MODEL_MEMBERS[@]}"; do
  rg -Fq "\$(SRCROOT)/.artifacts/release-models/$member" "$PBXPROJ" \
    || fail "model build phase is missing input: $member"
  rg -Fq "\$(TARGET_BUILD_DIR)/\$(CONTENTS_FOLDER_PATH)/Resources/Models/$member" "$PBXPROJ" \
    || fail "model build phase is missing output: $member"
done
LICENSE_MEMBERS=(
  Hy-MT2-LICENSE.txt
  ONNX-Runtime-LICENSE.txt
  Qwen3-ASR-LICENSE.txt
  Qwen3-ASR-NOTICE.txt
  libfvad-AUTHORS.txt
  libfvad-LICENSE.txt
  libfvad-PATENTS.txt
  sherpa-onnx-LICENSE.txt
)
for member in "${LICENSE_MEMBERS[@]}"; do
  rg -Fq "\$(SRCROOT)/Packaging/Licenses/$member" "$PBXPROJ" \
    || fail "license build phase is missing input: $member"
  rg -Fq "\$(TARGET_BUILD_DIR)/\$(CONTENTS_FOLDER_PATH)/Resources/Licenses/$member" \
    "$PBXPROJ" || fail "license build phase is missing output: $member"
done
RUNTIME_MEMBERS=(
  llama-server
  libllama-server-impl.dylib
  libllama-common.0.dylib
  libmtmd.0.dylib
  libllama.0.dylib
  libggml.0.dylib
  libggml-cpu.0.dylib
  libggml-blas.0.dylib
  libggml-metal.0.dylib
  libggml-rpc.0.dylib
  libggml-base.0.dylib
)
for member in "${RUNTIME_MEMBERS[@]}"; do
  rg -Fq "\$(SRCROOT)/.artifacts/llama-b10549/$member" "$PBXPROJ" \
    || fail "runtime build phase is missing input: $member"
  rg -Fq "\$(TARGET_BUILD_DIR)/\$(CONTENTS_FOLDER_PATH)/MacOS/$member" "$PBXPROJ" \
    || fail "runtime build phase is missing output: $member"
done
if rg -q 'XCRemoteSwiftPackageReference' "$PBXPROJ"; then
  fail "app project must consume only the repository-local package"
fi

SCHEME_PATTERNS=(
  'BlueprintName = "Live Church Translation"'
  'BuildableName = "Live Church Translation.app"'
  'buildConfiguration = "Debug"'
  'buildConfiguration = "Release"'
  '<ArchiveAction'
)
for pattern in "${SCHEME_PATTERNS[@]}"; do
  rg -Fq "$pattern" "$SCHEME" || fail "shared scheme is missing contract: $pattern"
done
[[ "$(xmllint --xpath 'string(/Scheme/ArchiveAction/@buildConfiguration)' "$SCHEME")" \
  == "Release" ]] || fail "Archive action must use Release"

if xcodebuild -version >/dev/null 2>&1; then
  LISTING="$(xcodebuild -project "$PROJECT" -list -json)" \
    || fail "Xcode could not load the generated project"
  [[ "$LISTING" == *'"LiveChurchTranslation"'* ]] \
    || fail "Xcode cannot discover the app target and scheme"
  echo "Full-Xcode project discovery: PASS"
else
  echo "Full-Xcode project discovery: SKIPPED (Command Line Tools only)"
fi
echo "Generated Xcode project structure: PASS"
