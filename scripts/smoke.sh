#!/usr/bin/env bash
# Smoke test : verifie rapidement que l'application demarree repond correctement.
# Usage : smoke.sh <BASE_URL> [FICHIER_RESULTAT]
# Code retour : 0 = tous les cas PASSED, 1 = au moins un cas FAILED
# Pour la demo d'un build en echec : SMOKE_FORCE_FAIL=1 ./smoke.sh ...

BASE_URL="${1:-http://localhost:3000}"
OUT="${2:-/dev/stdout}"
FAILED=0
: > "$OUT"

check() { # nom, commande de test (evaluee),
  local name="$1"; shift
  if "$@" >/dev/null 2>&1; then
    echo "[PASSED] $name" | tee -a "$OUT"
  else
    echo "[FAILED] $name" | tee -a "$OUT"
    FAILED=1
  fi
}

http_code() { curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$@"; }

expect_code() { # code attendu, args curl
  local expected="$1"; shift
  [ "$(http_code "$@")" = "$expected" ]
}

# Attente du demarrage (max 30 s)
for i in $(seq 1 30); do
  [ "$(http_code "$BASE_URL/health")" = "200" ] && break
  sleep 1
done

echo "== Smoke test sur $BASE_URL ($(date -u +%FT%TZ)) ==" | tee -a "$OUT"

check "GET /health -> 200"            expect_code 200 "$BASE_URL/health"
check "GET /version -> 200"           expect_code 200 "$BASE_URL/version"
check "GET /health contient UP"       bash -c "curl -s --max-time 5 '$BASE_URL/health' | grep -q '\"UP\"'"
check "POST /todos valide -> 201"     expect_code 201 -X POST -H 'Content-Type: application/json' -d '{"title":"smoke"}' "$BASE_URL/todos"
check "POST /todos invalide -> 400"   expect_code 400 -X POST -H 'Content-Type: application/json' -d '{}' "$BASE_URL/todos"
check "GET /todos -> 200"             expect_code 200 "$BASE_URL/todos"

if [ "${SMOKE_FORCE_FAIL:-0}" = "1" ]; then
  check "Cas force en echec (demo) GET /inexistant -> 200" expect_code 200 "$BASE_URL/inexistant"
fi

if [ "$FAILED" -eq 0 ]; then
  echo "RESULT: PASSED" | tee -a "$OUT"
else
  echo "RESULT: FAILED" | tee -a "$OUT"
fi
exit "$FAILED"
