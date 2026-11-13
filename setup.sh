#!/bin/bash
# Подготовка дерева AOSP android-7.1.2_r8 для picasso (A500/A501)
# Запускать ИЗ КОРНЯ ДЕРЕВА AOSP:  /path/to/repo/setup.sh
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
AOSP_ROOT="$(pwd)"

echo "=== picasso setup: AOSP=$AOSP_ROOT, repo=$SCRIPT_DIR ==="

[ -d "$AOSP_ROOT/build/core" ] || { echo "FATAL: запустите из корня AOSP"; exit 1; }

# 1. Ядро кладём в дерево (собирается ОТДЕЛЬНО tools/build-kernel.sh; в AOSP — prebuilt)
if [ ! -f "$SCRIPT_DIR/kernel/acer/picasso/build.sh" ]; then
  echo "FATAL: нет kernel/acer/picasso в репо"; exit 1
fi
mkdir -p kernel/acer
[ -d kernel/acer/picasso ] || cp -a "$SCRIPT_DIR/kernel/acer/picasso" kernel/acer/

# 2. Ядро: либо готовый zImage-final, либо собрать
if [ -f "$SCRIPT_DIR/kernel/acer/picasso/zImage-final" ]; then
  cp "$SCRIPT_DIR/kernel/acer/picasso/zImage-final" "$SCRIPT_DIR/device/acer/picasso/kernel"
elif [ -f kernel/acer/picasso/zImage-final ]; then
  cp kernel/acer/picasso/zImage-final "$SCRIPT_DIR/device/acer/picasso/kernel"
  echo "  kernel: zImage-final скопирован из дерева сборки"
else
  echo "  WARN: zImage-final не найден — соберите ядро: tools/build-kernel.sh (нужен arm-eabi-4.8)"
fi

# 3. Device trees
mkdir -p device/acer device/samsung vendor/acer
rm -rf device/acer/picasso device/samsung/p4-common
cp -a "$SCRIPT_DIR/device/acer/picasso" device/acer/
cp -a "$SCRIPT_DIR/device/samsung/p4-common" device/samsung/

# 4. Патчи платформы (полные git-binary; повторный запуск безопасен)
shopt -s nullglob
for patchfile in "$SCRIPT_DIR"/patches/*.patch; do
  base=$(basename "$patchfile" .patch)
  echo "--- patch: $base"
  if (cd "$AOSP_ROOT" && git apply --binary --check "$patchfile" 2>/dev/null); then
    (cd "$AOSP_ROOT" && git apply --binary "$patchfile")
  elif (cd "$AOSP_ROOT" && git apply --binary --reverse --check "$patchfile" 2>/dev/null); then
    echo "    уже применён — пропуск"
  else
    echo "FATAL: $base не применился (дерево AOSP должно быть чистым android-7.1.2_r8)"
    exit 1
  fi
done

# 5. Chromium-webview конфликтует с vendor/decatf webview — удаляем (как в рабочей сборке)
[ -d external/chromium-webview ] && rm -rf external/chromium-webview && echo "  chromium-webview: удалён (используется vendor/decatf webview)"

# 6. build/kati: тег для external/iw (version.sh зовёт git describe)
if [ -d .git ]; then
  git tag -a -f v4.1 -m v4.1 >/dev/null 2>&1 || true
fi

# 7. Vendor блобы
if [ ! -d vendor/acer/picasso/proprietary ]; then
  echo "  ВНИМАНИЕ: vendor/acer/picasso отсутствует — извлеките блобы:"
  echo "    adb pull /system/... через $SCRIPT_DIR/extract-blobs.sh (нужен планшет с рабочей прошивкой)"
fi

# 8. Проверка
ok=1
[ -f device/acer/picasso/AndroidProducts.mk ] && echo "AndroidProducts.mk OK" || { echo "AndroidProducts.mk MISSING"; ok=0; }
[ -f device/samsung/p4-common/p4-common.mk ] && echo "p4-common.mk OK" || { echo "p4-common.mk MISSING"; ok=0; }
[ -f device/acer/picasso/BoardConfig.mk ] && grep -q TARGET_PREBUILT_KERNEL device/acer/picasso/BoardConfig.mk && echo "BoardConfig+PREBUILT OK" || { echo "BoardConfig BAD"; ok=0; }
[ $ok = 1 ] && echo "=== SETUP OK ===" || exit 1
