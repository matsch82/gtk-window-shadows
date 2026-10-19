#!/usr/bin/env bash
# Installs (or removes) the gray window border and macOS-like drop shadow for GTK3 and GTK4
# in the current user's profile: ~/.config/gtk-3.0 and ~/.config/gtk-4.0.
#
#   ./install.sh               install or update
#   ./install.sh --uninstall   remove again
set -euo pipefail

src_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
config_dir="${XDG_CONFIG_HOME:-$HOME/.config}"
css_name="gtk-window-shadows.css"
import_line="@import '$css_name';"
stamp="$(date +%Y%m%d-%H%M%S)"

backup() {
  if [[ -f "$1" ]]; then
    local target="$1.bak-$stamp" n=1
    while [[ -e "$target" ]]; do target="$1.bak-$stamp-$((n++))"; done
    cp -p "$1" "$target"
    echo "  backup:    $target"
  fi
}

# Rewrites a file in place, so a gtk.css that is a symlink (e.g. into a dotfiles repo) stays a symlink.
rewrite() {
  local file="$1" tmp
  tmp="$(mktemp)"
  cat > "$tmp"
  cat "$tmp" > "$file"
  rm -f "$tmp"
}

install_for() {
  local dir="$config_dir/gtk-$1.0"
  local gtk_css="$dir/gtk.css"
  mkdir -p "$dir"
  install -m 644 "$src_dir/gtk-$1.0/$css_name" "$dir/$css_name"
  echo "  installed: $dir/$css_name"
  if [[ -f "$gtk_css" ]] && grep -qxF "$import_line" "$gtk_css"; then
    echo "  unchanged: $gtk_css (import already present)"
    return
  fi
  backup "$gtk_css"
  touch "$gtk_css"
  # Appended at the end: GTK applies @import in place, so these rules win over older ones in gtk.css.
  { cat "$gtk_css"; [[ -s "$gtk_css" && -n "$(tail -c1 "$gtk_css")" ]] && echo; echo "$import_line"; } | rewrite "$gtk_css"
  echo "  updated:   $gtk_css (import added)"
}

uninstall_for() {
  local dir="$config_dir/gtk-$1.0"
  local gtk_css="$dir/gtk.css"
  if [[ -f "$gtk_css" ]] && grep -qxF "$import_line" "$gtk_css"; then
    backup "$gtk_css"
    { grep -vxF "$import_line" "$gtk_css" || true; } | rewrite "$gtk_css"
    echo "  updated:   $gtk_css (import removed)"
  fi
  if [[ -f "$dir/$css_name" ]]; then
    rm -f "$dir/$css_name"
    echo "  removed:   $dir/$css_name"
  fi
}

usage() {
  echo "Usage: $0 [--uninstall]"
}

case "${1:-}" in
  "")
    for v in 3 4; do echo "GTK$v:"; install_for "$v"; done
    echo
    echo "Done. Restart GTK apps to see the change."
    echo "X11: press Alt+F2, type r, press Enter to also reload the title bars of non-GTK apps."
    echo "Wayland: log out and back in."
    ;;
  --uninstall)
    for v in 3 4; do echo "GTK$v:"; uninstall_for "$v"; done
    echo
    echo "Removed. Restart GTK apps (X11: Alt+F2, r, Enter) to get the theme's default border back."
    ;;
  -h|--help)
    usage
    ;;
  *)
    usage >&2
    exit 1
    ;;
esac
