#!/bin/sh
# Headless tests for the dev log (docs/specs/devlog.md, Verification).
# Run inside the Hugo container:
#   docker compose run --rm --entrypoint sh hugo scripts/test-site.sh
set -u

cd "$(dirname "$0")/.."
WORK=$(mktemp -d)
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "PASS $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL $1"; [ $# -gt 1 ] && echo "     $2"; }

# Build fixture content: base, plus an overlay directory.
fixture() { # name overlay
  rm -rf "$WORK/$1"
  mkdir -p "$WORK/$1"
  cp -R tests/fixtures/base/. "$WORK/$1/"
  [ -n "${2:-}" ] && cp -R "$2/." "$WORK/$1/"
  echo "$WORK/$1"
}

# Visible HTML only: drop <head> so metadata (published_time) doesn't count.
body_of() { sed -e '/<head>/,/<\/head>/d' "$1"; }

# --- T1: the real site builds without warnings ------------------------------
if out=$(hugo --gc --minify --destination "$WORK/real" 2>&1); then
  # The vendored theme still uses a few deprecated fields; only other warnings count.
  if echo "$out" | grep "WARN" | grep -qv "deprecated"; then fail T1 "warnings: $(echo "$out" | grep WARN | grep -v deprecated | head -3)"
  else pass "T1 real site builds"; fi
else
  fail T1 "$(echo "$out" | tail -5)"
fi
grep -rl "ai-writing-tropes\|AI Writing Tropes" "$WORK/real" >/dev/null 2>&1 \
  && fail T7 "tropes file reached public/ in the real build" \
  || pass "T7 docs/ never published (real build)"

# --- Good fixture build -----------------------------------------------------
GOOD=$(fixture good tests/fixtures/good)
OUT="$WORK/out-good"
if ! out=$(hugo --contentDir "$GOOD" --destination "$OUT" 2>&1); then
  fail "good fixture build" "$(echo "$out" | tail -8)"
  echo "RESULT pass=$PASS fail=$FAIL found=$((PASS + FAIL))"
  exit 1
fi
pass "good fixture builds"

# --- T2: each bad fixture fails with its own message ------------------------
for dir in tests/fixtures/bad/*/; do
  name=$(basename "$dir")
  expect=$(cat "$dir/expect.txt")
  src=$(fixture "bad-$name" "$dir/content")
  if out=$(hugo --contentDir "$src" --destination "$WORK/out-bad-$name" 2>&1); then
    fail "T2 $name" "build passed but should have failed"
  elif echo "$out" | grep -qF "$expect"; then
    pass "T2 $name"
  else
    fail "T2 $name" "expected '$expect', got: $(echo "$out" | grep -i error | head -2)"
  fi
done

# --- T3: no originals published ---------------------------------------------
# Processed copies carry Hugo's "_hu" suffix; anything else is an original.
originals() { find "$OUT/posts" "$OUT/projects" -type f \( -name '*.jpg' -o -name '*.jpeg' -o -name '*.png' \) ! -name '*_hu*'; }
orig=$(originals | wc -l)
[ "$orig" -eq 0 ] && pass "T3 no original images published" || fail T3 "$orig originals found: $(originals | head -3)"

# --- T4: responsive WebP for a raster image ---------------------------------
A="$OUT/posts/alpha/index.html"
webps=$(find "$OUT/posts/alpha" -name '*.webp' | wc -l)
img=$(grep -o '<img[^>]*A test photo with GPS data[^>]*>' "$A" | head -1)
ok=1
for w in 480w 960w 1600w; do echo "$img" | grep -q "$w" || ok=0; done
for attr in 'srcset=' 'width=' 'height=' 'loading="lazy"'; do echo "$img" | grep -q "$attr" || ok=0; done
grep -q '<figure class="devlog-figure">' "$A" || ok=0
grep -q '<figcaption>Photo caption</figcaption>' "$A" || ok=0
[ "$ok" -eq 1 ] && [ "$webps" -ge 3 ] && pass "T4 WebP srcset, figure and caption ($webps webp files)" || fail T4 "img: $img"
grep -q 'diagram[^"]*\.svg' "$A" && pass "T4 SVG passed through" || fail "T4 svg" "no svg reference"
grep -o '<p>Inline <img[^>]*>' "$A" | grep -q 'tiny icon' && pass "T4 inline image stays inline" || fail "T4 inline"

# --- T5: processed images carry no EXIF -------------------------------------
leak=0
for f in $(find "$OUT" \( -name '*.webp' -o -name '*.jpg' \)); do
  if grep -q 'DevlogTestCam' "$f" || grep -q 'Exif' "$f"; then leak=$((leak + 1)); echo "     exif: ${f#$OUT}"; fi
done
[ "$leak" -eq 0 ] && pass "T5 no EXIF in published images" || fail T5 "$leak images carry EXIF"
grep -q 'og:image" content="[^"]*_hu[^"]*\.jpg' "$OUT/posts/beta/index.html" && pass "T5 og:image is a processed copy" || fail "T5 og:image" "$(grep -o 'og:image[^>]*' "$OUT/posts/beta/index.html")"

# --- T6: no visible dates ----------------------------------------------------
dated=0
for f in $(find "$OUT" -name '*.html'); do
  if body_of "$f" | grep -q -e '<time' -e '2024-03-05' -e 'Mar 5, 2024' -e '5 Mar 2024' -e 'March 5, 2024'; then
    dated=$((dated + 1)); echo "     dated: ${f#$OUT}"
  fi
done
[ "$dated" -eq 0 ] && pass "T6 no dates on any page" || fail T6 "$dated pages show a date"

# --- T7: docs/ never published (fixture build) ------------------------------
[ -z "$(find "$OUT" -iname '*tropes*')" ] && pass "T7 docs/ never published (fixtures)" || fail T7

# --- T8: ordering ------------------------------------------------------------
P="$OUT/projects/index.html"
order=$(grep -o 'devlog-card-title"><a href="/projects/[a-z]*/' "$P" | sed 's#.*/projects/##; s#/##' | tr '\n' ' ')
[ "$order" = "demo shelf old " ] && pass "T8 projects in status order" || fail T8 "got: $order"
D="$OUT/projects/demo/index.html"
arts=$(grep -o 'post-item-title"><a href="/posts/[a-z]*/' "$D" | sed 's#.*/posts/##; s#/##' | tr '\n' ' ')
[ "$arts" = "beta alpha " ] && pass "T8 project articles by weight" || fail "T8 weight" "got: $arts"
grep -q '2 of 2' "$A" && grep -q '← Beta Article' "$A" && pass "T8 spec sheet position and prev link" || fail "T8 spec sheet"
grep -q 'example.com/demo' "$A" && pass "T8 source falls back to project repo" || fail "T8 repo"
grep -q 'devlog-status--active' "$A" && pass "T8 status pill on article" || fail "T8 status"

# --- T9: skills page ---------------------------------------------------------
S="$OUT/skills/index.html"
for d in "Cloud &amp; infra" "Game dev" "Software" "Making"; do
  grep -q "$d" "$S" || { fail "T9 domain $d"; continue; }
done
rows=$(grep -c '<tr data-skills=' "$S")
[ "$rows" -eq 4 ] && pass "T9 index lists every article ($rows)" || fail "T9 rows" "got $rows"
grep -q 'data-skills="terraform aws" data-domains="infra"' "$S" && pass "T9 row skills and domains" || fail "T9 row data"
missing=0
for s in terraform aws unreal-cpp multiplayer testing 3d-printing openscad python scraping; do
  [ -f "$OUT/skills/$s/index.html" ] || { missing=$((missing + 1)); echo "     missing /skills/$s/"; }
done
[ "$missing" -eq 0 ] && pass "T9 every used skill has a page" || fail "T9 term pages"
grep -q '<h1 class="header-title">Unreal C&#43;&#43;</h1>' "$OUT/skills/unreal-cpp/index.html" && pass "T9 skill page uses display name" || fail "T9 skill name"

# --- Home --------------------------------------------------------------------
H="$OUT/index.html"
grep -q 'Alpha Article' "$H" && ! grep -q 'Beta Article' "$H" && pass "home shows only featured articles" || fail "home featured"
grep -q 'Demo Project' "$H" && ! grep -q 'Shelf Project' "$H" && pass "home shows only active projects" || fail "home active"

rm -rf "$WORK"
echo "RESULT pass=$PASS fail=$FAIL found=$((PASS + FAIL))"
[ "$FAIL" -eq 0 ]
