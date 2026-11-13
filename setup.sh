#!/bin/bash
# Подготовка дерева AOSP android-7.1.2_r8 для picasso (A500/A501)
# Запускать ИЗ КОРНЯ ДЕРЕВА AOSP:  /path/to/repo/setup.sh
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
AOSP_ROOT="$(pwd)"

echo "=== picasso setup: AOSP=$AOSP_ROOT, repo=$SCRIPT_DIR ==="
[ -d "$AOSP_ROOT/build/core" ] || { echo "FATAL: запустите из корня AOSP"; exit 1; }

# 1. Ядро: prebuilt-файл (собирается ОТДЕЛЬНО; внутри-AOSP сборка не поддерживается)
rm -rf kernel/acer/picasso
if [ -f "$SCRIPT_DIR/kernel/acer/picasso/zImage-final" ]; then
  cp "$SCRIPT_DIR/kernel/acer/picasso/zImage-final" "$SCRIPT_DIR/device/acer/picasso/kernel"
  echo "  kernel: zImage-final подложен"
else
  echo "  WARN: zImage-final не найден — соберите: ./build-all.sh (или kernel build.sh)"
fi


# 2. hardware/broadcom (драйверы Wi-Fi/BT bcmdhd — исходники, не патч)
mkdir -p hardware
rm -rf hardware/broadcom
cp -a "$SCRIPT_DIR/hardware/broadcom" hardware/

# 3. Device trees
mkdir -p device/acer device/samsung vendor/acer
rm -rf device/acer/picasso device/samsung/p4-common
cp -a "$SCRIPT_DIR/device/acer/picasso" device/acer/
cp -a "$SCRIPT_DIR/device/samsung/p4-common" device/samsung/

# 4. Патчи платформы: полные git-binary (pristine r8 -> рабочее дерево).
#    Чистим корневые каталоги каждого патча с -x: внутренние .gitignore
#    (например system/bt: "third_party") прячут файлы от git apply.
shopt -s nullglob
for patchfile in "$SCRIPT_DIR"/patches/*.patch; do
  base=$(basename "$patchfile" .patch | sed 's/^patches-//')
  echo "--- patch: $base"
  git clean -qfdx -- "$base" 2>/dev/null || true
  if (cd "$AOSP_ROOT" && git apply --binary --check "$patchfile" 2>/dev/null); then
    (cd "$AOSP_ROOT" && git apply --binary "$patchfile")
  elif (cd "$AOSP_ROOT" && git apply --binary --reverse --check "$patchfile" 2>/dev/null); then
    echo "    уже применён — пропуск"
  else
    echo "FATAL: $base не применился (нужно чистое дерево android-7.1.2_r8)"
    exit 1
  fi
done

# 4. webview: конфликтует с vendor-версией — убрать
[ -d external/chromium-webview ] && rm -rf external/chromium-webview && echo "  chromium-webview: удалён"

# 1b. Дыры repo-sync (repo врёт об успехе): раскладываем из aosp-gaps/
GAPS_LIST="build/blueprint build/kati build/soong external/lld external/v8 frameworks/opt/emoji frameworks/opt/inputconnectioncommon packages/apps/Phone system/nvram tools/swt tools/tradefederation"
for g in $GAPS_LIST; do
  if [ -d "$SCRIPT_DIR/aosp-gaps/$g" ]; then
    mkdir -p "$(dirname "$g")"
    rm -rf "$g"
    cp -a "$SCRIPT_DIR/aosp-gaps/$g" "$(dirname "$g")/"
  fi
done
echo "  aosp-gaps: разложены"

# 5. Тег для external/iw (git describe в version.sh)
if [ -d .git ]; then git tag -a -f v4.1 -m v4.1 >/dev/null 2>&1 || true; fi

# 6. Блобы
if [ ! -d vendor/acer/picasso/proprietary ]; then
  echo "  ВНИМАНИЕ: нет vendor/acer/picasso — извлеките блобы extract-blobs.sh"
fi

# 7. Проверка
ok=1
[ -f device/acer/picasso/AndroidProducts.mk ] && echo "AndroidProducts.mk OK" || ok=0
[ -f device/samsung/p4-common/p4-common.mk ] && echo "p4-common.mk OK" || ok=0
grep -q TARGET_PREBUILT_KERNEL device/acer/picasso/BoardConfig.mk && echo "PREBUILT_KERNEL OK" || ok=0
[ -f hardware/broadcom/wlan ] || [ -d hardware/broadcom/wlan ] && echo "broadcom OK" || ok=0
[ $ok = 1 ] && echo "=== SETUP OK ===" || { echo "SETUP_FAILED"; exit 1; }
