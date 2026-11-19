#!/bin/zsh
# Prepara un DMG firmato Developer ID e notarizzato per GitHub Releases.
# Procedura, prerequisiti e limiti in docs/rilascio.md.
#
#   scripts/release.sh 0.2.0              # firma, notarizza, applica il ticket
#   scripts/release.sh 0.2.0 --unsigned   # solo pacchetto con firma ad hoc (prove)
#
# Variabili:
#   SOCIALFRAME_SIGN_IDENTITY   identità di firma (default: l'unica
#                               "Developer ID Application" nel portachiavi)
#   SOCIALFRAME_NOTARY_PROFILE  profilo di `xcrun notarytool store-credentials`
#                               (default: socialframe-notary)
set -eu
cd "${0:A:h:h}"

usage() { print -u2 "Uso: scripts/release.sh <versione, es. 0.2.0> [--unsigned]"; exit 64; }
fail() { print -u2 "Errore: $*"; exit 1; }

[[ $# -ge 1 ]] || usage
VERSION="$1"
[[ "$VERSION" =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]] || fail "versione non valida: $VERSION (atteso X.Y.Z)"
UNSIGNED=0
if [[ $# -ge 2 ]]; then
    [[ "$2" == --unsigned ]] || usage
    UNSIGNED=1
fi

APP="$PWD/.build/SocialFrame.app"
OUT="$PWD/.build/release"
DMG="$OUT/SocialFrame-$VERSION.dmg"
PROFILE="${SOCIALFRAME_NOTARY_PROFILE:-socialframe-notary}"

if [[ -n "$(git status --porcelain)" ]]; then
    print -u2 "Attenzione: modifiche non committate; il pacchetto non corrisponde a un commit."
fi

if (( ! UNSIGNED )); then
    IDENTITY="${SOCIALFRAME_SIGN_IDENTITY:-}"
    if [[ -z "$IDENTITY" ]]; then
        identities=("${(@f)$(security find-identity -v -p codesigning | sed -n 's/.*"\(Developer ID Application: .*\)"/\1/p')}")
        identities=(${identities:#})
        (( ${#identities} == 1 )) || fail "serve una sola identità \"Developer ID Application\" nel portachiavi (trovate: ${#identities}). Impostare SOCIALFRAME_SIGN_IDENTITY o crearla come in docs/rilascio.md."
        IDENTITY="${identities[1]}"
    fi
    xcrun notarytool history --keychain-profile "$PROFILE" >/dev/null 2>&1 ||
        fail "profilo notarytool \"$PROFILE\" assente o non valido: vedere docs/rilascio.md."
fi

# 1. Build universale (arm64 + x86_64) con le risorse dell'app soltanto.
SOCIALFRAME_UNIVERSAL=1 ./scripts/build-app.sh >/dev/null
[[ "$(lipo -archs "$APP/Contents/MacOS/SocialFrame")" == *arm64* && "$(lipo -archs "$APP/Contents/MacOS/SocialFrame")" == *x86_64* ]] ||
    fail "il binario non è universale"

# 2. Versione nel bundle: X.Y.Z visibile, build = numero di commit.
PLIST="$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $(git rev-list --count HEAD)" "$PLIST"

# 3. Firma: Developer ID con hardened runtime e timestamp (richiesti dalla
#    notarizzazione), oppure ad hoc per le prove.
if (( UNSIGNED )); then
    codesign --force --sign - "$APP"
else
    codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP"
fi
codesign --verify --deep --strict "$APP"

# 4. DMG con l'app e il collegamento ad Applicazioni.
mkdir -p "$OUT"
STAGE="$(mktemp -d "${TMPDIR:-/tmp}/socialframe-dmg.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT
ditto "$APP" "$STAGE/SocialFrame.app"
ln -s /Applications "$STAGE/Applications"
rm -f "$DMG"
hdiutil create -volname "SocialFrame $VERSION" -srcfolder "$STAGE" -fs HFS+ -format UDZO -ov "$DMG" >/dev/null

if (( UNSIGNED )); then
    print "DMG di prova (firma ad hoc, non notarizzato): $DMG"
    print "Gatekeeper lo bloccherà sugli altri Mac: non pubblicarlo come release."
    exit 0
fi

# 5. Firma del DMG, notarizzazione e ticket applicato (funziona anche offline).
codesign --force --timestamp --sign "$IDENTITY" "$DMG"
xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"
spctl --assess --type open --context context:primary-signature --verbose "$DMG"

print "\nPronto: $DMG"
print "SHA-256: $(shasum -a 256 "$DMG" | cut -d' ' -f1)"
print "\nPubblicazione (dopo il merge su main e il tag):"
print "  git tag v$VERSION && git push origin v$VERSION"
print "  gh release create v$VERSION \"$DMG\" --title \"SocialFrame $VERSION\" --generate-notes"
