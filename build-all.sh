#!/bin/bash
# ПОЛНЫЙ конвейер: ядро -> AOSP система -> CWM update-zip
# Запуск: ./build-all.sh <корень-AOSP> [выходной-zip]
# Зависимости: см. README (jdk8-old-схема, prebuilts python2.7, arm-eabi-4.8 в AOSP, ccache)
set -o pipefail
exec > >(tee build-all.log) 2>&1
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
AOSP="${1:?Укажите корень AOSP, например: ./build-all.sh ~/aosp}"
OUTZIP="${2:-$SCRIPT_DIR/picasso-71-a50x-full.zip}"

echo "=== [$(date '+%F %T')] BUILD-ALL: AOSP=$AOSP ==="

# ---------- ЭТАП 1: ядро ----------
echo "--- [1/4] Ядро (arm-eabi-4.8 из prebuilts, host-tools фикс включены)"
export PATH="$AOSP/prebuilts/gcc/linux-x86/arm/arm-eabi-4.8/bin:$PATH"
export KBUILD_BUILD_USER=beeline09 KBUILD_BUILD_HOST=picasso
export SOURCE_DATE_EPOCH=1794506790
(
  cd "$SCRIPT_DIR/kernel/acer/picasso" || exit 1
  ./build.sh || { echo FATAL_KERNEL; exit 1; }
)
cp "$SCRIPT_DIR/kernel/acer/picasso/zImage-final" "$SCRIPT_DIR/device/acer/picasso/kernel"
ls -la "$SCRIPT_DIR/device/acer/picasso/kernel"

# ---------- ЭТАП 2: setup ----------
echo "--- [2/4] Setup дерева AOSP"
(cd "$AOSP" && bash "$SCRIPT_DIR/setup.sh") || { echo FATAL_SETUP; exit 1; }

# ---------- ЭТАП 3: система ----------
echo "--- [3/4] AOSP make (jdk8 + ccache)"
export JAVA_HOME="${JAVA_HOME:-$HOME/jdk8-old}"
export PATH="$JAVA_HOME/bin:$AOSP/prebuilts/python/linux-x86/2.7.5/bin:$PATH"
export USE_CCACHE=1 CCACHE_DIR="${CCACHE_DIR:-$HOME/ccache}"
(
  cd "$AOSP" || exit 1
  mkdir -p out/target/product/picasso
  cp -f device/acer/picasso/kernel out/target/product/picasso/kernel 2>/dev/null || true
  rm -rf ~/.jack-server ~/.jack-settings
  source build/envsetup.sh || exit 1
  lunch picasso-userdebug || exit 1
  make -j"$(nproc)" || exit 1
) || { echo FATAL_MAKE; exit 1; }
[ -f "$AOSP/out/target/product/picasso/system.img" ] || { echo FATAL_NO_SYSTEMIMG; exit 1; }

# cacerts: conscrypt затирает PRODUCT_COPY_FILES — восстанавливаем эталонный набор
cp -f "$SCRIPT_DIR/device/acer/picasso/cacerts/"* \
      "$AOSP/out/target/product/picasso/system/etc/security/cacerts/" 2>/dev/null || true
echo "  cacerts: $(ls "$AOSP/out/target/product/picasso/system/etc/security/cacerts" | wc -l) файлов"

# ---------- ЭТАП 4: CWM zip ----------
echo "--- [4/4] CWM update-zip (python-zipfile, flags 0x0, update-binary)"
python3 "$SCRIPT_DIR/tools/make-full-zip.py" "$AOSP" "$SCRIPT_DIR/kernel/acer/picasso/zImage-final" "$OUTZIP" \
  || { echo FATAL_ZIP; exit 1; }

echo "=== [$(date '+%F %T')] BUILD-ALL COMPLETE: $OUTZIP ==="
