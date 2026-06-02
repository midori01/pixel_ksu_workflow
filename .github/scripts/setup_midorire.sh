#!/bin/bash
set -eu

echo "[+] Setting up MidoriRE (Change Manager and VersionCode)..."

if [ -f "KernelSU/kernel/manager/apk_sign.c" ]; then
  sed -i 's/unsigned char buffer\[0x11\] = { 0 };/return true;\n\tunsigned char buffer[0x11] = { 0 };/g' KernelSU/kernel/manager/apk_sign.c
  sed -i '/^bool is_manager_apk/,/^}$/d' KernelSU/kernel/manager/apk_sign.c
  cat >> KernelSU/kernel/manager/apk_sign.c << 'EOF'
bool is_manager_apk(char *path, u8 *signature_index)
{
    char pkg[KSU_MAX_PACKAGE_NAME];
    if (get_pkg_from_apk_path(pkg, path) < 0) {
        return false;
    }
    return strcmp(pkg, "com.midori.supermanager") == 0 ||
           strcmp(pkg, "com.midori.su.manager") == 0;
}
EOF
fi

git clone --bare https://github.com/midori01/KernelSU.git /tmp/midorisu
COMMIT_COUNT=$(git -C /tmp/midorisu rev-list --count HEAD)
rm -rf /tmp/midorisu

NEW_KSU_VERSION=$((30000 + COMMIT_COUNT))
echo "[+] Dynamic KSU_VERSION (based on MidoriSU): $NEW_KSU_VERSION"

sed -i "s|^KSU_VERSION := .*|KSU_VERSION := ${NEW_KSU_VERSION}|" KernelSU/kernel/Kbuild
sed -i "s|^REPO_NAME := .*|REPO_NAME := MidoriRE|" KernelSU/kernel/Kbuild
sed -i 's|^\(\s*default "%TAG_NAME%\).*|\1-midori-build@%REPO_NAME%"|' KernelSU/kernel/Kconfig

echo "[+] MidoriRE setup complete."
