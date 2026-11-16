#!/usr/bin/env bash
# shared/ icindeki sozlesme dosyalarini Android asset klasorune kopyalar.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
src="$here/../../../shared"
dst="$here/../assets/shared"
mkdir -p "$dst/l10n"
cp "$src/design-tokens.json" "$dst/design-tokens.json"
cp "$src/constants.json" "$dst/constants.json"
cp "$src/l10n/tr.json" "$dst/l10n/tr.json"
