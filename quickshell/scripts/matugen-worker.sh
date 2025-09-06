#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 3 ]; then
    echo "Usage: $0 STATE_DIR SHELL_DIR --run" >&2
    exit 1
fi

STATE_DIR="$1"
SHELL_DIR="$2"

if [ ! -d "$STATE_DIR" ]; then
    echo "Error: STATE_DIR '$STATE_DIR' does not exist" >&2
    exit 1
fi

if [ ! -d "$SHELL_DIR" ]; then
    echo "Error: SHELL_DIR '$SHELL_DIR' does not exist" >&2
    exit 1
fi

shift 2  # Remove STATE_DIR and SHELL_DIR from arguments

if [[ "${1:-}" != "--run" ]]; then
  echo "usage: $0 STATE_DIR SHELL_DIR --run" >&2
  exit 1
fi

DESIRED_JSON="$STATE_DIR/matugen.desired.json"
BUILT_KEY="$STATE_DIR/matugen.key"
LAST_JSON="$STATE_DIR/last.json"
LOCK="$STATE_DIR/matugen-worker.lock"

exec 9>"$LOCK"
flock 9


read_desired() {
  [[ ! -f "$DESIRED_JSON" ]] && { echo "no desired state" >&2; exit 0; }
  cat "$DESIRED_JSON"
}

key_of() {
  local json="$1"
  local kind=$(echo "$json" | sed 's/.*"kind": *"\([^"]*\)".*/\1/')
  local value=$(echo "$json" | sed 's/.*"value": *"\([^"]*\)".*/\1/')
  local mode=$(echo "$json" | sed 's/.*"mode": *"\([^"]*\)".*/\1/')
  local icon=$(echo "$json" | sed 's/.*"iconTheme": *"\([^"]*\)".*/\1/')
  [[ -z "$icon" ]] && icon="System Default"
  echo "${kind}|${value}|${mode}|${icon}" | sha256sum | cut -d' ' -f1
}

build_once() {
  local json="$1"
  local kind value mode icon
  kind=$(echo "$json" | sed 's/.*"kind": *"\([^"]*\)".*/\1/')
  value=$(echo "$json" | sed 's/.*"value": *"\([^"]*\)".*/\1/')
  mode=$(echo "$json" | sed 's/.*"mode": *"\([^"]*\)".*/\1/')
  icon=$(echo "$json" | sed 's/.*"iconTheme": *"\([^"]*\)".*/\1/')
  [[ -z "$icon" ]] && icon="System Default"

  CONFIG_DIR="${CONFIG_DIR:-$HOME/.config}"

  TMP_CFG="$(mktemp)"
  trap 'rm -f "$TMP_CFG"' RETURN

  cat "$SHELL_DIR/matugen/configs/base.toml" > "$TMP_CFG"
  echo "" >> "$TMP_CFG"
  if command -v niri >/dev/null 2>&1; then
    cat "$SHELL_DIR/matugen/configs/niri.toml" >> "$TMP_CFG"
    echo "" >> "$TMP_CFG"
  fi
  
  if command -v qt5ct >/dev/null 2>&1; then
    cat "$SHELL_DIR/matugen/configs/qt5ct.toml" >> "$TMP_CFG"
    echo "" >> "$TMP_CFG"
  fi
  
  if command -v qt6ct >/dev/null 2>&1; then
    cat "$SHELL_DIR/matugen/configs/qt6ct.toml" >> "$TMP_CFG"
    echo "" >> "$TMP_CFG"
  fi
  
  if [ "$mode" = "light" ]; then
    COLLOID_TEMPLATE="$SHELL_DIR/matugen/templates/gtk3-colloid-light.css"
  else
    COLLOID_TEMPLATE="$SHELL_DIR/matugen/templates/gtk3-colloid-dark.css"
  fi
  
  sed -i "/\[templates\.gtk3\]/,/^$/ s|input_path = './matugen/templates/gtk-colors.css'|input_path = '$COLLOID_TEMPLATE'|" "$TMP_CFG"
  sed -i "s|input_path = './matugen/templates/|input_path = '$SHELL_DIR/matugen/templates/|g" "$TMP_CFG"

  pushd "$SHELL_DIR" >/dev/null
  MAT_MODE=(-m "$mode")

  case "$kind" in
    image)
      [[ -f "$value" ]] || { echo "wallpaper not found: $value" >&2; popd >/dev/null; return 2; }
      JSON=$(matugen -c "$TMP_CFG" --json hex image "$value" "${MAT_MODE[@]}")
      matugen -c "$TMP_CFG" image "$value" "${MAT_MODE[@]}" >/dev/null
      ;;
    hex)
      [[ "$value" =~ ^#[0-9A-Fa-f]{6}$ ]] || { echo "invalid hex: $value" >&2; popd >/dev/null; return 2; }
      JSON=$(matugen -c "$TMP_CFG" --json hex color hex "$value" "${MAT_MODE[@]}")
      matugen -c "$TMP_CFG" color hex "$value" "${MAT_MODE[@]}" >/dev/null
      ;;
    *)
      echo "unknown kind: $kind" >&2; popd >/dev/null; return 2;;
  esac
  
  TMP_CONTENT_CFG="$(mktemp)"
  echo "[config]" > "$TMP_CONTENT_CFG"
  echo "" >> "$TMP_CONTENT_CFG"
  
  if command -v ghostty >/dev/null 2>&1; then
    cat "$SHELL_DIR/matugen/configs/ghostty.toml" >> "$TMP_CONTENT_CFG"
    sed -i "s|input_path = './matugen/templates/|input_path = '$SHELL_DIR/matugen/templates/|g" "$TMP_CONTENT_CFG"
    echo "" >> "$TMP_CONTENT_CFG"
  fi
  
  if command -v kitty >/dev/null 2>&1; then
    cat "$SHELL_DIR/matugen/configs/kitty.toml" >> "$TMP_CONTENT_CFG"
    sed -i "s|input_path = './matugen/templates/|input_path = '$SHELL_DIR/matugen/templates/|g" "$TMP_CONTENT_CFG"
    echo "" >> "$TMP_CONTENT_CFG"
  fi
  
  if command -v dgop >/dev/null 2>&1; then
    cat "$SHELL_DIR/matugen/configs/dgop.toml" >> "$TMP_CONTENT_CFG"
    sed -i "s|input_path = './matugen/templates/|input_path = '$SHELL_DIR/matugen/templates/|g" "$TMP_CONTENT_CFG"
    echo "" >> "$TMP_CONTENT_CFG"
  fi
  
  if [[ -s "$TMP_CONTENT_CFG" ]] && grep -q '\[templates\.' "$TMP_CONTENT_CFG"; then
    case "$kind" in
      image)
        matugen -c "$TMP_CONTENT_CFG" image "$value" "${MAT_MODE[@]}" >/dev/null
        ;;
      hex)
        matugen -c "$TMP_CONTENT_CFG" color hex "$value" "${MAT_MODE[@]}" >/dev/null
        ;;
    esac
  fi
  
  rm -f "$TMP_CONTENT_CFG"
  popd >/dev/null

  echo "$JSON" | grep -q '"primary"' || { echo "matugen JSON missing primary" >&2; return 2; }
  printf "%s" "$JSON" > "$LAST_JSON"
  
  if [ "$mode" = "light" ]; then
    SECTION=$(echo "$JSON" | sed -n 's/.*"light":{\([^}]*\)}.*/\1/p')
  else
    SECTION=$(echo "$JSON" | sed -n 's/.*"dark":{\([^}]*\)}.*/\1/p')
  fi

  PRIMARY=$(echo "$SECTION" | sed -n 's/.*"primary_container":"\(#[0-9a-fA-F]\{6\}\)".*/\1/p')
  HONOR=$(echo "$SECTION"  | sed -n 's/.*"primary":"\(#[0-9a-fA-F]\{6\}\)".*/\1/p')
  SURFACE=$(echo "$SECTION" | sed -n 's/.*"surface":"\(#[0-9a-fA-F]\{6\}\)".*/\1/p')

  if command -v ghostty >/dev/null 2>&1 && [[ -f "$CONFIG_DIR/ghostty/config-dankcolors" ]]; then
    OUT=$("$SHELL_DIR/matugen/dank16.py" "$PRIMARY" $([[ "$mode" == "light" ]] && echo --light) ${HONOR:+--honor-primary "$HONOR"} ${SURFACE:+--background "$SURFACE"} 2>/dev/null || true)
    if [[ -n "${OUT:-}" ]]; then
      TMP="$(mktemp)"
      printf "%s\n\n" "$OUT" > "$TMP"
      cat "$CONFIG_DIR/ghostty/config-dankcolors" >> "$TMP"
      mv "$TMP" "$CONFIG_DIR/ghostty/config-dankcolors"
    fi
  fi

  if command -v kitty >/dev/null 2>&1 && [[ -f "$CONFIG_DIR/kitty/dank-theme.conf" ]]; then
    OUT=$("$SHELL_DIR/matugen/dank16.py" "$PRIMARY" $([[ "$mode" == "light" ]] && echo --light) ${HONOR:+--honor-primary "$HONOR"} ${SURFACE:+--background "$SURFACE"} --kitty 2>/dev/null || true)
    if [[ -n "${OUT:-}" ]]; then
      TMP="$(mktemp)"
      printf "%s\n\n" "$OUT" > "$TMP"
      cat "$CONFIG_DIR/kitty/dank-theme.conf" >> "$TMP"
      mv "$TMP" "$CONFIG_DIR/kitty/dank-theme.conf"
    fi
  fi
  COLOR_SCHEME=$([[ "$mode" == "light" ]] && echo prefer-light || echo prefer-dark)
  if command -v dconf >/dev/null 2>&1; then
    dconf write /org/gnome/desktop/interface/color-scheme "\"$COLOR_SCHEME\"" 2>/dev/null || true
    [[ "$icon" != "System Default" && -n "$icon" ]] && dconf write /org/gnome/desktop/interface/icon-theme "\"$icon\"" 2>/dev/null || true
  elif command -v gsettings >/dev/null 2>&1; then
    gsettings set org.gnome.desktop.interface color-scheme "$COLOR_SCHEME" 2>/dev/null || true
    [[ "$icon" != "System Default" && -n "$icon" ]] && gsettings set org.gnome.desktop.interface icon-theme "$icon" 2>/dev/null || true
  fi
}

while :; do
  DESIRED="$(read_desired)"
  WANT_KEY="$(key_of "$DESIRED")"
  HAVE_KEY=""
  [[ -f "$BUILT_KEY" ]] && HAVE_KEY="$(cat "$BUILT_KEY" 2>/dev/null || true)"

  if [[ "$WANT_KEY" == "$HAVE_KEY" ]]; then
    exit 0
  fi

  if build_once "$DESIRED"; then
    echo "$WANT_KEY" > "$BUILT_KEY"
  else
    exit 2
  fi
done

exit 0