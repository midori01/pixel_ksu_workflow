#!/bin/bash
set -eu

echo "[+] Setting up MidoriXX (Change Manager, VersionCode, and add HookType)..."

if [ -f "KernelSU/kernel/setup.sh" ]; then
  sed -i 's|https://github.com/backslashxx/KernelSU|https://github.com/MidoriKSU/KernelSU|g' KernelSU/kernel/setup.sh
fi

if [ -f "KernelSU/kernel/manager/apk_sign.c" ]; then
  sed -i 's/unsigned char buffer\[0x11\] = { 0 };/return true;\n\tunsigned char buffer[0x11] = { 0 };/g' KernelSU/kernel/manager/apk_sign.c
  sed -i '/bool is_manager_apk(char \*path)/,$d' KernelSU/kernel/manager/apk_sign.c
  echo -e "bool is_manager_apk(char *path)\n{\n\tchar pkg[KSU_MAX_PACKAGE_NAME];\n\tif (get_pkg_from_apk_path(pkg, path) < 0) {\n\t\treturn false;\n\t}\n\treturn strcmp(pkg, \"com.midori.supermanager\") == 0 ||\n\t       strcmp(pkg, \"com.midori.su.manager\") == 0;\n}" >> KernelSU/kernel/manager/apk_sign.c
fi

git clone --bare https://github.com/midori01/KernelSU.git /tmp/midorisu
COMMIT_COUNT=$(git -C /tmp/midorisu rev-list --count HEAD)
rm -rf /tmp/midorisu

NEW_KSU_VERSION=$((30999 + COMMIT_COUNT))
echo "[+] Dynamic KSU_VERSION (based on MidoriSU): $NEW_KSU_VERSION"

if [ -f "KernelSU/kernel/Makefile" ]; then
  sed -i "s/-DKSU_VERSION=[0-9]*/-DKSU_VERSION=$NEW_KSU_VERSION/g" KernelSU/kernel/Makefile
fi

patch -p1 -d KernelSU < "${GITHUB_WORKSPACE}/.github/patches/21_extra_features_for_ksu.patch"

echo "[+] MidoriXX setup complete."
