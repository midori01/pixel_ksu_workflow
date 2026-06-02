#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE=".github/config/kernel_versions.json"
TMP_DIR="/tmp/kernel-check"
rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"

REPO="${GITHUB_REPOSITORY:-midori01/gki_ksu_workflow}"

SUB_612=$(jq -r '.["6.12"].default_sub_level' "$CONFIG_FILE")
R_612=$(jq -r ".[\"6.12\"].revisions[\"$SUB_612\"].default_r" "$CONFIG_FILE")

SUB_66_TAG=$(jq -r '.["6.6"].revisions | to_entries[] | select(.value.asb_date == "2026-04") | .key' "$CONFIG_FILE")

SUB_66_LTS=$(jq -r '.["6.6"].revisions | to_entries[] | select(.value.asb_date == "lts") | .key' "$CONFIG_FILE")

SUB_61_TAG=$(jq -r '.["6.1"].revisions | to_entries[] | select(.value.asb_date == "2026-03") | .key' "$CONFIG_FILE")

SUB_61_LTS=$(jq -r '.["6.1"].revisions | to_entries[] | select(.value.asb_date == "lts") | .key' "$CONFIG_FILE")

NEEDS_COMMIT=false

echo "=== Fetching tags from AOSP common kernel ==="
git ls-remote --tags https://android.googlesource.com/kernel/common.git 2>/dev/null | \
  awk '{print $2}' | sed 's|refs/tags/||; s|\^{}||' | sort -Vu > "$TMP_DIR/all_tags.txt"

download_and_upload() {
  local release_tag="$1" kv="$2" android_ver="$3" asb_date="$4" r_suffix="$5"
  local tar_name="${android_ver}-${kv}-${asb_date}${r_suffix}.tar.gz"
  local google_url="https://android.googlesource.com/kernel/common/+archive/refs/tags/${tar_name}"
  local local_file="$TMP_DIR/${tar_name}"

  echo "  Downloading $tar_name ..."
  if curl -fsSL --connect-timeout 30 "$google_url" -o "$local_file"; then
    echo "  Uploading to release $release_tag ..."
    gh release upload "$release_tag" "$local_file" --repo "$REPO" --clobber 2>/dev/null || true
    echo "  Done: $tar_name"
  else
    echo "  Failed to download $tar_name"
  fi
}

download_lts_and_upload() {
  local release_tag="$1" kv="$2" android_ver="$3"
  local tar_name="${android_ver}-${kv}-lts.tar.gz"
  local head_url="https://android.googlesource.com/kernel/common/+archive/refs/heads/${android_ver}-${kv}-lts.tar.gz"
  local local_file="$TMP_DIR/${tar_name}"

  echo "  Downloading LTS $tar_name ..."
  if curl -fsSL --connect-timeout 30 "$head_url" -o "$local_file"; then
    echo "  Uploading to release $release_tag ..."
    gh release upload "$release_tag" "$local_file" --repo "$REPO" --clobber 2>/dev/null || true
    echo "  Done: $tar_name"
  else
    echo "  Failed to download $tar_name"
  fi
}

check_tag() {
  local kv="$1" asb_date="$2" current_sub="$3" current_r="$4"

  echo ""
  echo "=== Checking $kv tag $asb_date (current: sub=$current_sub r=$current_r) ==="

  local android_ver=$(jq -r ".[\"$kv\"].android_version" "$CONFIG_FILE")
  local prefix="${android_ver}-${kv}-${asb_date}"

  local latest_tag=$(grep "^${prefix}" "$TMP_DIR/all_tags.txt" | tail -n 1)

  if [[ -z "$latest_tag" ]]; then
    echo "  No tags found for $prefix"
    return
  fi

  echo "  Latest tag: $latest_tag"

  local new_sub=$(echo "$latest_tag" | grep -oP "(?<=${kv}\.)[0-9]+" | head -n 1)
  [[ -z "$new_sub" ]] && new_sub="$current_sub"

  local new_r=$(echo "$latest_tag" | grep -oP '_r\d+' | head -n 1)
  new_r="${new_r#_}"
  [[ -z "$new_r" ]] && new_r="none"

  if [[ "$new_r" == "$current_r" && "$new_sub" == "$current_sub" ]]; then
    echo "  Up to date."
    return
  fi

  echo "  New: sub=$new_sub r=$new_r"

  local new_default="$new_sub"
  local current_default=$(jq -r ".[\"$kv\"].default_sub_level" "$CONFIG_FILE")
  if [[ "$new_sub" -lt "$current_default" ]]; then
    new_default="$current_default"
    echo "  Tag sub_level ($new_sub) < current default ($current_default), keeping default_sub_level."
  fi

  jq --arg kv "$kv" \
     --arg sub "$new_sub" \
     --arg def "$new_default" \
     --arg asb "$asb_date" \
     --arg r "$new_r" \
     '.[$kv].default_sub_level = $def |
      .[$kv].revisions[$sub] = {"asb_date": $asb, "default_r": $r, "supported_r": [$r, "none"]}' \
     "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"

  echo "  Updated JSON. Downloading source..."
  local r_suffix=""
  [[ "$new_r" != "none" ]] && r_suffix="_$new_r"
  download_and_upload "$kv" "$kv" "$android_ver" "$asb_date" "$r_suffix"
  NEEDS_COMMIT=true
}

check_lts() {
  local kv="$1" current_sub="$2"

  echo ""
  echo "=== Checking $kv LTS (current sub=$current_sub) ==="

  local android_ver=$(jq -r ".[\"$kv\"].android_version" "$CONFIG_FILE")

  local makefile_url="https://android.googlesource.com/kernel/common/+/refs/heads/${android_ver}-${kv}-lts/Makefile?format=TEXT"
  local new_sub=$(curl -s --connect-timeout 10 "$makefile_url" | base64 -d --ignore-garbage 2>/dev/null | grep '^SUBLEVEL = ' | head -n 1 | awk '{print $3}')

  if [[ -z "$new_sub" || ! "$new_sub" =~ ^[0-9]+$ ]]; then
    echo "  Failed to fetch SUBLEVEL from Makefile"
    return
  fi

  if [[ "$new_sub" -le "$current_sub" ]]; then
    echo "  Up to date ($new_sub)."
    return
  fi

  echo "  New LTS sub_level: $new_sub (was $current_sub)"

  jq --arg kv "$kv" \
     --arg sub "$new_sub" \
     '.[$kv].default_sub_level = $sub |
      .[$kv].revisions[$sub] = {"asb_date": "lts", "default_r": "none", "supported_r": ["none"]}' \
     "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"

  echo "  Updated JSON. Downloading LTS source..."
  download_lts_and_upload "$kv" "$kv" "$android_ver"
  NEEDS_COMMIT=true
}

check_tag "6.12" "2025-06" "$SUB_612" "$R_612"
check_tag "6.6" "2026-04" "$SUB_66_TAG" "r14"
check_lts "6.6" "$SUB_66_LTS"
check_tag "6.1" "2026-03" "$SUB_61_TAG" "r14"
check_lts "6.1" "$SUB_61_LTS"

if [ "$NEEDS_COMMIT" = true ]; then
  git config user.name "github-actions"
  git config user.email "actions@github.com"
  git add "$CONFIG_FILE"
  git diff --staged --quiet || git commit -m "auto: update kernel versions and upload sources"
  git push
fi
