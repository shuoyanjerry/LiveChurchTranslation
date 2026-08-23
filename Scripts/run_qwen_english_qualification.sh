#!/bin/bash

set -euo pipefail

if [[ -z "${QWEN_MODEL_DIR:-}" ]]; then
    echo "QWEN_MODEL_DIR must point to the verified Qwen3-ASR model." >&2
    exit 64
fi

workspace_root="$(cd "$(dirname "$0")/.." && pwd)"
output_dir="${1:-$workspace_root/.artifacts/qwen-english-qualification}"
mkdir -p "$output_dir"
staging_dir="$(mktemp -d "$output_dir/.generation.XXXXXX")"
trap 'rm -rf "$staging_dir"' EXIT

ids=(
    grace-through-faith
    justification-and-sanctification
    holy-spirit-comfort
    church-body
    resurrection-hope
    trinity-confession
    prayer-and-wisdom
    shepherding-care
    gospel-reconciliation
    forgiveness-and-repentance
    melchizedek-priesthood
    eschatology-hope
    prayer-praise-contrast
    pray-praise-inflections
    grace-prayer-repetition
    pastoral-prayer
    gracious-prayer
    corporate-praise
)
voices=(
    Samantha Daniel Karen Moira Tessa Rishi Fred Samantha Daniel Karen Moira Rishi
    Tessa Fred Rishi Daniel Moira Karen
)
locales=(
    en_US en_GB en_AU en_IE en_ZA en_IN en_US en_US en_GB en_AU en_IE en_IN
    en_ZA en_US en_IN en_GB en_IE en_AU
)
rates=(185 175 180 170 185 175 190 165 180 190 170 180 175 195 170 185 180 190)
references=(
    "Salvation is by grace through faith, not by works."
    "Justification is God's judicial act, while sanctification is his continuing work."
    "The Holy Spirit comforts believers and leads the church in truth."
    "The church is the body of Christ, called to worship and serve together."
    "The resurrection of Jesus gives Christians a living hope beyond death."
    "Christians confess one God in three persons: Father, Son, and Holy Spirit."
    "Prayer asks God for wisdom while trusting his gracious care."
    "Faithful shepherds protect the congregation and teach with humility."
    "The gospel announces reconciliation with God through Jesus Christ."
    "Repentance turns from sin, and forgiveness restores fellowship."
    "The priesthood of Melchizedek points beyond ordinary human ancestry."
    "Christian eschatology looks toward resurrection, judgment, and renewed creation."
    "Prayer and praise are related, but the words describe different acts of worship."
    "She prays for grace, and afterward she praises God with the congregation."
    "Grace encourages prayer, and prayer responds to grace with gratitude."
    "The pastor asks the church to pray before the choir begins its praise."
    "A gracious answer to prayer can strengthen a weary believer's faith."
    "Public praise should not replace quiet prayer or careful listening."
)

clip_count="${#ids[@]}"
if [[ "${#voices[@]}" -ne "$clip_count" || "${#locales[@]}" -ne "$clip_count" \
    || "${#rates[@]}" -ne "$clip_count" || "${#references[@]}" -ne "$clip_count" ]]; then
    echo "English qualification fixture arrays are inconsistent." >&2
    exit 65
fi

available_voices="$(/usr/bin/say -v '?')"
for voice in "${voices[@]}"; do
    if ! grep -Fq "$voice" <<< "$available_voices"; then
        echo "Required macOS voice is unavailable: $voice" >&2
        exit 69
    fi
done

manifest_plist="$staging_dir/manifest.plist"
/usr/bin/plutil -create xml1 "$manifest_plist"
/usr/bin/plutil -insert schemaVersion -integer 1 "$manifest_plist"
/usr/bin/plutil -insert generatorRevision -string qwen-english-say-v1 "$manifest_plist"
/usr/bin/plutil -insert sourceKind -string macos-say-synthetic "$manifest_plist"
/usr/bin/plutil -insert generatedAt -string "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" "$manifest_plist"
/usr/bin/plutil -insert hostOS -string "$(/usr/bin/sw_vers -productVersion)" "$manifest_plist"
/usr/bin/plutil -insert clips -array "$manifest_plist"

for index in "${!ids[@]}"; do
    id="${ids[$index]}"
    voice="${voices[$index]}"
    locale="${locales[$index]}"
    rate="${rates[$index]}"
    reference="${references[$index]}"
    aiff="$staging_dir/$id.aiff"
    wav="$staging_dir/$id.wav"
    /usr/bin/say -v "$voice" -r "$rate" -o "$aiff" -- "$reference"
    /usr/bin/afconvert -f WAVE -d LEI16@16000 -c 1 "$aiff" "$wav"
    audio_sha="$(/usr/bin/shasum -a 256 "$wav" | /usr/bin/awk '{print $1}')"

    /usr/bin/plutil -insert clips -dictionary -append "$manifest_plist"
    /usr/bin/plutil -insert "clips.$index.id" -string "$id" "$manifest_plist"
    /usr/bin/plutil -insert "clips.$index.file" -string "$id.wav" "$manifest_plist"
    /usr/bin/plutil -insert "clips.$index.reference" -string "$reference" "$manifest_plist"
    /usr/bin/plutil -insert "clips.$index.voice" -string "$voice" "$manifest_plist"
    /usr/bin/plutil -insert "clips.$index.locale" -string "$locale" "$manifest_plist"
    /usr/bin/plutil -insert "clips.$index.speakingRate" -integer "$rate" "$manifest_plist"
    /usr/bin/plutil -insert "clips.$index.audioSHA256" -string "$audio_sha" "$manifest_plist"
done

/usr/bin/plutil -convert json -r "$manifest_plist"
for id in "${ids[@]}"; do
    mv -f "$staging_dir/$id.wav" "$output_dir/$id.wav"
done
mv -f "$manifest_plist" "$output_dir/manifest.json"

QWEN_ENGLISH_CORPUS_MANIFEST="$output_dir/manifest.json" \
QWEN_ENGLISH_ASR_REPORT="$output_dir/qualification-report.json" \
swift test --package-path "$workspace_root" --filter Qwen3EnglishQualificationTests
