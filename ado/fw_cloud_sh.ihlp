#!/bin/sh
# fw_cloud.sh: Framework Cloud requests for Framework for Stata on macOS and Linux.
# Part of the framework package. It ships as an .ihlp file because net install
# keeps only Stata file types; Stata copies it to a .sh or .ps1 file to run it.
#
# Tokens never pass through Stata. This script reads them from the
# environment, the project's .env, the system keyring, or the token files that
# R, Python, and fw share, and hands them to curl in a private header file.
#
#   fw_cloud.sh http   <curl.cfg> <project|user|none> <root> <host> <outdir>
#   fw_cloud.sh poll   <curl.cfg> <host> <server> <outdir>
#   fw_cloud.sh status <host>
#   fw_cloud.sh logout <host> <server> <outdir>
#   fw_cloud.sh check  <host> <server> <outdir>
#   fw_cloud.sh keyring

umask 077
PATH="$PATH:/usr/bin:/bin:/usr/local/bin:/opt/homebrew/bin"
export PATH

cfgdir() {
  if [ -n "${FW_CONFIG_HOME:-}" ]; then printf '%s' "$FW_CONFIG_HOME"
  elif [ -n "${XDG_CONFIG_HOME:-}" ]; then printf '%s/framework' "$XDG_CONFIG_HOME"
  else printf '%s/.config/framework' "$HOME"; fi
}

rcfgdir() {
  if [ -n "${R_USER_CONFIG_DIR:-}" ]; then printf '%s/R/framework' "$R_USER_CONFIG_DIR"
  elif [ -n "${XDG_CONFIG_HOME:-}" ]; then printf '%s/R/framework' "$XDG_CONFIG_HOME"
  elif [ "$(uname -s)" = Darwin ]; then printf '%s/Library/Preferences/org.R-project.R/R/framework' "$HOME"
  else printf '%s/.config/R/framework' "$HOME"; fi
}

tokname() {
  if [ "$1" = framework.pub ]; then printf 'cloud-token'
  else printf 'cloud-token-%s' "$(printf '%s' "$1" | tr -c 'a-z0-9.-' '_')"; fi
}

firstline() { head -n 1 "$1" 2>/dev/null | tr -d '\r\n'; }

# secret-tool and a D-Bus session are not enough: the Secret Service itself
# must answer. A lookup of a missing entry prints nothing when it does, and
# an error such as "The name is not activatable" when it does not.
have_secret_service() {
  if [ -n "${fw_ss_cache:-}" ]; then [ "$fw_ss_cache" = yes ]; return; fi
  fw_ss_cache=no
  if command -v secret-tool >/dev/null 2>&1 && [ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
    if command -v timeout >/dev/null 2>&1; then
      probe=$(timeout 10 secret-tool lookup service framework-cloud:probe username probe 2>&1 >/dev/null; echo "rc=$?")
    else
      probe=$(secret-tool lookup service framework-cloud:probe username probe 2>&1 >/dev/null; echo "rc=$?")
    fi
    case "$probe" in
      rc=0|rc=1) fw_ss_cache=yes ;;
    esac
  fi
  [ "$fw_ss_cache" = yes ]
}

# go-keyring can store a value as go-keyring-base64:<base64>. Decode that form.
unwrap_keychain() {
  case $1 in
    go-keyring-base64:*) printf '%s' "${1#go-keyring-base64:}" | base64 --decode 2>/dev/null ;;
    *) printf '%s' "$1" ;;
  esac
}

# Sets TOKEN to the user token for a host and SOURCE to where it came from.
user_token() {
  host=$1
  svc="framework-cloud:$host"
  TOKEN=""; SOURCE=none
  if [ -n "${FW_CLOUD_TOKEN:-}" ]; then TOKEN=$FW_CLOUD_TOKEN; SOURCE=environment; return; fi
  if [ -n "${FW_TOKEN_FILE:-}" ]; then
    if [ -f "$FW_TOKEN_FILE" ]; then TOKEN=$(firstline "$FW_TOKEN_FILE"); SOURCE=file; fi
    return
  fi
  if [ "$(uname -s)" = Darwin ]; then
    TOKEN=$(security find-generic-password -s "$svc" -a token -w 2>/dev/null) || TOKEN=""
    if [ -z "$TOKEN" ] && [ "$host" = framework.pub ]; then
      TOKEN=$(security find-generic-password -s framework.pub -a token -w 2>/dev/null) || TOKEN=""
    fi
    TOKEN=$(unwrap_keychain "$TOKEN")
  elif have_secret_service; then
    TOKEN=$(secret-tool lookup service "$svc" username token 2>/dev/null) || TOKEN=""
  fi
  if [ -n "$TOKEN" ]; then SOURCE=keyring; return; fi
  name=$(tokname "$host")
  for f in "$(cfgdir)/$name" "$(rcfgdir)/$name"; do
    if [ -f "$f" ]; then TOKEN=$(firstline "$f"); SOURCE=file; return; fi
  done
  if [ "$host" = framework.pub ] && [ -f "$HOME/.secrets/framework/token" ]; then
    TOKEN=$(firstline "$HOME/.secrets/framework/token"); SOURCE=file
  fi
}

project_token() {
  root=$1
  if [ -n "${FW_PROJECT_TOKEN:-}" ]; then printf '%s' "$FW_PROJECT_TOKEN"; return; fi
  if [ -f "$root/.env" ]; then
    sed -n 's/^[[:space:]]*\(export[[:space:]][[:space:]]*\)\{0,1\}FW_PROJECT_TOKEN[[:space:]]*=[[:space:]]*//p' "$root/.env" \
      | tail -n 1 | tr -d '\r' | sed "s/^[\"']//; s/[\"']\$//"
  fi
}

# Run curl with a config file, adding the token in a private header file.
curl_with() {
  cfg=$1; tok=$2; out=$3
  if [ -n "$tok" ]; then
    printf 'header = "Authorization: Bearer %s"\n' "$tok" > "$out/auth.cfg"
    curl -K "$cfg" -K "$out/auth.cfg" > "$out/status.txt" 2> "$out/curl.err"
    rc=$?
    rm -f "$out/auth.cfg"
  else
    curl -K "$cfg" > "$out/status.txt" 2> "$out/curl.err"
    rc=$?
  fi
  return $rc
}

# Revoke a token on the server with DELETE /api/v1/token. Succeeds on 2xx,
# and on 401, which means the token was already invalid.
revoke_token() {
  tok=$1; server=$2; out=$3
  {
    printf 'url = "%s/api/v1/token"\n' "$server"
    printf 'request = "DELETE"\n'
    printf 'header = "Accept: application/json"\n'
    printf 'user-agent = "framework-stata (fw_cloud.sh)"\n'
    printf 'output = "%s/revoke.json"\n' "$out"
    printf 'write-out = "%%{http_code}"\nsilent\nshow-error\nconnect-timeout = 20\nmax-time = 30\n'
    if [ -n "${FW_CLOUD_INSECURE:-}" ]; then printf 'insecure\n'; fi
  } > "$out/revoke.cfg"
  curl_with "$out/revoke.cfg" "$tok" "$out" || return 1
  case "$(cat "$out/status.txt" 2>/dev/null)" in
    2??|401) return 0 ;;
  esac
  return 1
}

store_token() {
  host=$1; tok=$2
  svc="framework-cloud:$host"
  if [ -n "${FW_TOKEN_FILE:-}" ]; then
    mkdir -p "$(dirname "$FW_TOKEN_FILE")" && printf '%s\n' "$tok" > "$FW_TOKEN_FILE" && chmod 600 "$FW_TOKEN_FILE"
    printf 'file' ; return
  fi
  if [ "$(uname -s)" = Darwin ]; then
    if printf 'add-generic-password -U -s "%s" -a token -w "%s"\n' "$svc" "$tok" | security -i >/dev/null 2>&1; then
      printf 'keyring'; return
    fi
  elif have_secret_service; then
    if printf '%s' "$tok" | secret-tool store --label="Password for 'token' on '$svc'" \
        service "$svc" username token xdg:schema com.rstudio.keyring.password >/dev/null 2>&1; then
      printf 'keyring'; return
    fi
  fi
  d=$(cfgdir)
  mkdir -p "$d"
  f="$d/$(tokname "$host")"
  printf '%s\n' "$tok" > "$f" && chmod 600 "$f"
  printf 'file'
}

action=$1; shift
case "$action" in
  http)
    cfg=$1; kind=$2; root=$3; host=$4; out=$5
    tok=""
    if [ "$kind" = project ]; then
      tok=$(project_token "$root")
      if [ -z "$tok" ]; then echo "no-project-token" > "$out/problem.txt"; exit 3; fi
    elif [ "$kind" = user ]; then
      user_token "$host"; tok=$TOKEN
      if [ -z "$tok" ]; then echo "no-user-token" > "$out/problem.txt"; exit 3; fi
    fi
    curl_with "$cfg" "$tok" "$out"
    exit $?
    ;;
  poll)
    cfg=$1; host=$2; server=$3; out=$4
    curl -K "$cfg" > "$out/status.txt" 2> "$out/curl.err" || exit $?
    status=$(cat "$out/status.txt")
    if [ "$status" != 200 ]; then exit 0; fi
    tok=$(sed -n 's/.*"token"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$out/poll.json" | head -n 1)
    rm -f "$out/poll.json"
    if [ -z "$tok" ]; then echo "no-token-in-response" > "$out/problem.txt"; exit 4; fi
    {
      printf 'url = "%s/api/v1/me"\n' "$server"
      printf 'header = "Accept: application/json"\n'
      printf 'user-agent = "framework-stata (fw_cloud.sh)"\n'
      printf 'output = "%s/me.json"\n' "$out"
      printf 'write-out = "%%{http_code}"\nsilent\nshow-error\nmax-time = 60\n'
    } > "$out/me.cfg"
    curl_with "$out/me.cfg" "$tok" "$out" || exit $?
    if [ "$(cat "$out/status.txt")" != 200 ]; then echo "token-rejected" > "$out/problem.txt"; exit 5; fi
    store_token "$host" "$tok" > "$out/stored.txt"
    printf '200' > "$out/status.txt"
    exit 0
    ;;
  status)
    host=$1
    user_token "$host"
    if [ -n "$TOKEN" ]; then printf '%s' "$SOURCE"; else printf 'none'; fi
    exit 0
    ;;
  keyring)
    if [ "$(uname -s)" = Darwin ]; then printf 'macos'
    elif have_secret_service; then printf 'secret-service'
    else printf 'none'; fi
    exit 0
    ;;
  check)
    host=$1; server=$2; out=$3
    {
      printf 'url = "%s/api/v1/me"\n' "$server"
      printf 'header = "Accept: application/json"\n'
      printf 'user-agent = "framework-stata (fw_cloud.sh)"\n'
      printf 'output = "%s/me.json"\n' "$out"
      printf 'write-out = "%%{http_code}"\nsilent\nshow-error\nmax-time = 30\n'
    } > "$out/me.cfg"
    user_token "$host"
    if [ -z "$TOKEN" ]; then echo "no-user-token" > "$out/problem.txt"; exit 3; fi
    curl_with "$out/me.cfg" "$TOKEN" "$out"
    exit $?
    ;;
  logout)
    host=$1; server=$2; out=$3
    svc="framework-cloud:$host"
    # Revoke each stored token that logout removes, then remove it.
    # FW_CLOUD_TOKEN is not removed, so it is not revoked.
    ktok=""
    if [ "$(uname -s)" = Darwin ]; then
      ktok=$(security find-generic-password -s "$svc" -a token -w 2>/dev/null) || ktok=""
      ktok=$(unwrap_keychain "$ktok")
    elif have_secret_service; then
      ktok=$(secret-tool lookup service "$svc" username token 2>/dev/null) || ktok=""
    fi
    f="$(cfgdir)/$(tokname "$host")"
    ftok=""
    if [ -f "$f" ]; then ftok=$(firstline "$f"); fi
    etok=""
    if [ -n "${FW_TOKEN_FILE:-}" ] && [ -f "$FW_TOKEN_FILE" ]; then etok=$(firstline "$FW_TOKEN_FILE"); fi
    tried=0; failed=0; done1=""; done2=""
    for t in "$ktok" "$ftok" "$etok"; do
      if [ -z "$t" ] || [ "$t" = "$done1" ] || [ "$t" = "$done2" ]; then continue; fi
      tried=1
      revoke_token "$t" "$server" "$out" || failed=1
      if [ -z "$done1" ]; then done1=$t; else done2=$t; fi
    done
    rm -f "$out/revoke.cfg" "$out/revoke.json" "$out/status.txt"
    ktok=""; ftok=""; etok=""; t=""; done1=""; done2=""
    if [ "$tried" = 1 ]; then
      if [ "$failed" = 1 ]; then printf 'not-revoked\n'; else printf 'revoked\n'; fi
    fi
    removed=""
    if [ "$(uname -s)" = Darwin ]; then
      security delete-generic-password -s "$svc" -a token >/dev/null 2>&1 && removed="$removed keyring"
    elif have_secret_service; then
      secret-tool clear service "$svc" username token >/dev/null 2>&1 && removed="$removed keyring"
    fi
    if [ -f "$f" ]; then rm -f "$f" && removed="$removed $f"; fi
    if [ -n "${FW_TOKEN_FILE:-}" ] && [ -f "$FW_TOKEN_FILE" ]; then rm -f "$FW_TOKEN_FILE" && removed="$removed $FW_TOKEN_FILE"; fi
    r="$(rcfgdir)/$(tokname "$host")"
    if [ -f "$r" ]; then printf 'r-file %s\n' "$r"; fi
    printf 'removed%s\n' "$removed"
    exit 0
    ;;
  *)
    echo "fw_cloud.sh: unknown action $action" >&2
    exit 2
    ;;
esac
