#!/bin/bash
# Shared helpers for GiftCard Pro security probes
BASE="http://127.0.0.1:8200"
ORIGIN="http://127.0.0.1:3000"   # a SANCTUM_STATEFUL_DOMAIN
RA="01a0e7b4-f042-70d2-9b49-e01174ebb524"  # tenant A restaurant (bella-vista)
RB="01a0e7b4-f056-701f-9403-9ee15ebb649a"  # tenant B restaurant (goldener-hirsch)
CARD_A="01a0e7b4-f173-7348-84e3-78e97cf80545"   # tenant A active card
TOK_A="8acb41df-4304-... "
CARD_B="01a0e7b4-f68f-7363-b997-b372bac1e228"   # tenant B active card
TOKB_PUB="f294ae6b-0217-4c97-86fc-73e08e99121f" # tenant B card public token
CUST_A="01a0e7b4-f0ca-732b-87d0-bda6202535ea"   # tenant A customer
CUST_B_QUERY=""

xsrf_of() { grep XSRF-TOKEN "$1" | awk '{print $7}' | sed 's/%3D/=/g'; }

# spa_login email pass jar deviceid remember
spa_login() {
  local email="$1" pass="$2" jar="$3" dev="${4:-dev-abcdef0123456}" remember="${5:-true}"
  rm -f "$jar"
  curl -s -c "$jar" "$BASE/sanctum/csrf-cookie" -H "Origin: $ORIGIN" >/dev/null
  local xsrf; xsrf=$(xsrf_of "$jar")
  curl -s -c "$jar" -b "$jar" -X POST "$BASE/api/v1/auth/login" \
    -H "Content-Type: application/json" -H "Accept: application/json" -H "Origin: $ORIGIN" \
    -H "X-XSRF-TOKEN: $xsrf" -H "X-Device-Id: $dev" \
    -d "{\"email\":\"$email\",\"password\":\"$pass\",\"remember\":$remember}" \
    -w "\nHTTP %{http_code}"
}

# sget jar dev restaurantHeader path  -> GET with session
sget() {
  local jar="$1" dev="$2" rhdr="$3" path="$4"
  local h=(-H "Accept: application/json" -H "Origin: $ORIGIN" -H "X-Device-Id: $dev")
  [ -n "$rhdr" ] && h+=(-H "X-Restaurant-Id: $rhdr")
  curl -s -b "$jar" "${h[@]}" -w "\nHTTP %{http_code}" "$BASE$path"
}
# spost jar dev restaurantHeader path json
spost() {
  local jar="$1" dev="$2" rhdr="$3" path="$4" json="$5"
  local xsrf; xsrf=$(xsrf_of "$jar")
  local h=(-H "Accept: application/json" -H "Content-Type: application/json" -H "Origin: $ORIGIN" -H "X-Device-Id: $dev" -H "X-XSRF-TOKEN: $xsrf")
  [ -n "$rhdr" ] && h+=(-H "X-Restaurant-Id: $rhdr")
  curl -s -b "$jar" "${h[@]}" -X POST -d "$json" -w "\nHTTP %{http_code}" "$BASE$path"
}
# spatch jar dev rhdr path json
spatch() {
  local jar="$1" dev="$2" rhdr="$3" path="$4" json="$5"
  local xsrf; xsrf=$(xsrf_of "$jar")
  local h=(-H "Accept: application/json" -H "Content-Type: application/json" -H "Origin: $ORIGIN" -H "X-Device-Id: $dev" -H "X-XSRF-TOKEN: $xsrf")
  [ -n "$rhdr" ] && h+=(-H "X-Restaurant-Id: $rhdr")
  curl -s -b "$jar" "${h[@]}" -X PATCH -d "$json" -w "\nHTTP %{http_code}" "$BASE$path"
}
