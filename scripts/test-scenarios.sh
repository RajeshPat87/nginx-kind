#!/usr/bin/env bash
# Exercise every ingress use case and assert the expected behaviour.
# Uses curl --resolve so no /etc/hosts edits are required.
set -uo pipefail

IP="${INGRESS_IP:-127.0.0.1}"
PG_NS="${PG_NS:-data}"
PG_USER="${PG_USER:-appuser}"
PG_PASSWORD="${PG_PASSWORD:-apppass123}"
PG_DB="${PG_DB:-appdb}"

PASS=0
FAIL=0
ok()  { printf "  \033[32mPASS\033[0m %s\n" "$1"; PASS=$((PASS+1)); }
bad() { printf "  \033[31mFAIL\033[0m %s\n" "$1"; FAIL=$((FAIL+1)); }

# curl helpers ---------------------------------------------------------------
geth()  { curl -s --resolve "$1:80:$IP"  "http://$1$2"; }              # body
codeh() { curl -s -o /dev/null -w "%{http_code}" --resolve "$1:80:$IP"  "http://$1$2" "${@:3}"; }
codes() { curl -sk -o /dev/null -w "%{http_code}" --resolve "$1:443:$IP" "https://$1$2"; }

echo "== 1. Path-based routing (app.example.com) =="
geth app.example.com /app1 | grep -q "Name: app1" && ok "/app1 -> app1" || bad "/app1 -> app1"
geth app.example.com /app2 | grep -q "Name: app2" && ok "/app2 -> app2" || bad "/app2 -> app2"

echo "== 2. Host-based routing =="
for hsvc in shop api blog; do
  geth "${hsvc}.example.com" / | grep -q "Name: ${hsvc}" && ok "${hsvc}.example.com -> ${hsvc}" || bad "${hsvc}.example.com -> ${hsvc}"
done

echo "== 3. TLS termination (secure.example.com) =="
[ "$(codes secure.example.com /)" = "200" ] && ok "https 200" || bad "https 200"
rc="$(codeh secure.example.com /)"
{ [ "$rc" = "308" ] || [ "$rc" = "301" ]; } && ok "http -> https redirect ($rc)" || bad "http -> https redirect (got $rc)"

echo "== 4. URL rewrite (rewrite.example.com/svc/... -> /...) =="
geth rewrite.example.com /svc/hello | grep -q "GET /hello " && ok "/svc/hello rewritten to /hello" || bad "/svc/hello rewritten to /hello"

echo "== 5. Rate limiting (ratelimit.example.com) =="
codes_out="$(seq 1 40 | xargs -P10 -I{} curl -s -o /dev/null -w '%{http_code}\n' --resolve ratelimit.example.com:80:$IP http://ratelimit.example.com/)"
echo "$codes_out" | grep -q "503" && ok "burst traffic gets throttled (503 seen)" || bad "expected some 503s under burst"

echo "== 6. Basic auth (auth.example.com) =="
[ "$(codeh auth.example.com /)" = "401" ] && ok "401 without credentials" || bad "401 without credentials"
[ "$(codeh auth.example.com / -u admin:secret123)" = "200" ] && ok "200 with credentials" || bad "200 with credentials"

echo "== 7. Canary / weighted split (canary.example.com) =="
stable=0; canary=0
for _ in $(seq 1 40); do
  if geth canary.example.com / | grep -q "Name: canary-canary"; then canary=$((canary+1)); else stable=$((stable+1)); fi
done
{ [ "$canary" -gt 0 ] && [ "$stable" -gt 0 ]; } && ok "traffic split (stable=$stable canary=$canary)" || bad "traffic split (stable=$stable canary=$canary)"

echo "== 8. DB-backed app through ingress (db.example.com -> Adminer -> Postgres) =="
[ "$(codeh db.example.com /)" = "200" ] && ok "adminer reachable via ingress" || bad "adminer reachable via ingress"
rows="$(kubectl -n "$PG_NS" exec statefulset/postgres -- env PGPASSWORD="$PG_PASSWORD" psql -U "$PG_USER" -d "$PG_DB" -t -c 'SELECT count(*) FROM visitors;' 2>/dev/null | tr -d '[:space:]')"
{ [ -n "$rows" ] && [ "$rows" -ge 1 ]; } && ok "postgres reachable & seeded ($rows rows)" || bad "postgres reachable & seeded"

echo "== 9. Default backend (unknown host -> 404) =="
[ "$(codeh nope.example.com /)" = "404" ] && ok "unmatched host returns 404" || bad "unmatched host returns 404"

echo
echo "-----------------------------------------"
printf "  Results: \033[32m%d passed\033[0m, \033[31m%d failed\033[0m\n" "$PASS" "$FAIL"
echo "-----------------------------------------"
[ "$FAIL" -eq 0 ]
