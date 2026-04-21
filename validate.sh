#!/usr/bin/env bash
# DevSecOps Workshop — Validación de Entorno
set -euo pipefail

PASS=0
FAIL=0

check() {
  local name="$1" cmd="$2" version_flag="${3:---version}"
  if command -v "$cmd" &>/dev/null; then
    ver=$($cmd $version_flag 2>&1 | head -1 | grep -oE '[0-9]+\.[0-9]+[.0-9]*' | head -1)
    printf "[✓] %-14s — %s\n" "$name" "${ver:-installed}"
    ((++PASS))
  else
    printf "[✗] %-14s — NO ENCONTRADO\n" "$name"
    ((++FAIL))
  fi
}

echo ""
echo "═══════════════════════════════════════════════"
echo "  DevSecOps Workshop — Validación de Entorno"
echo "═══════════════════════════════════════════════"
echo ""

check "Git"         git
check "Docker"      docker "--version"
check "Python"      python3
check "pip"         pip3
check "GitHub CLI"  gh

echo ""
echo "═══════════════════════════════════════════════"
if [ "$FAIL" -eq 0 ]; then
  echo "  ${PASS}/${PASS} dependencias OK — Entorno listo"
else
  echo "  ${PASS}/$((PASS+FAIL)) OK, ${FAIL} faltantes"
  echo "  Instala las dependencias faltantes antes de continuar"
fi
echo "═══════════════════════════════════════════════"
echo ""

exit "$FAIL"
