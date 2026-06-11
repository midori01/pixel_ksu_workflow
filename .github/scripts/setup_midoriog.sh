#!/bin/bash
set -eu

echo "[+] Setting up MidoriOG (Change Manager and VersionCode)..."

sed -i '/^ccflags-y.*KSU_KERNEL_DIR/c\ccflags-y += -I$(srctree)/$(src) -I$(srctree)/$(src)/include -I$(src) -I$(src)/include' KernelSU/kernel/Kbuild

if [ -f "KernelSU/kernel/manager/apk_sign.c" ]; then
  sed -i 's/unsigned char buffer\[0x11\] = { 0 };/return true;\n\tunsigned char buffer[0x11] = { 0 };/g' KernelSU/kernel/manager/apk_sign.c
  sed -i '/^bool is_manager_apk/,/^}$/d' KernelSU/kernel/manager/apk_sign.c
  cat >> KernelSU/kernel/manager/apk_sign.c << 'EOF'
bool is_manager_apk(char *path)
{
    char pkg[KSU_MAX_PACKAGE_NAME];
    if (get_pkg_from_apk_path(pkg, path) < 0) {
        pr_err("Failed to get package name from apk path: %s\n", path);
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

NEW_KSU_VERSION=$((30999 + COMMIT_COUNT))
echo "[+] Dynamic KSU_VERSION (based on MidoriSU): $NEW_KSU_VERSION"

sed -i "s|^\$(eval KSU_VERSION=.*|KSU_VERSION := ${NEW_KSU_VERSION}|" KernelSU/kernel/Kbuild

patch -p1 -d KernelSU < "${GITHUB_WORKSPACE}/.github/patches/20_extra_features_for_ksu.patch"

echo "[+] MidoriOG setup complete."
