# Android 7.1.2 для Acer Iconia Tab A500/A501 (picasso, NVIDIA Tegra 2)

**Единый репозиторий: ядро + device trees + патчи платформы + vendor + инструменты.**
Всё, что нужно для самостоятельной сборки прошивки Nougat для планшета 2011 года —
в одном клоне. Magisk (root без NEON) — отдельный репозиторий
[magisk-picasso-noNEON](https://github.com/beeline09/magisk-picasso-noNEON).

**Проверено на устройстве 13.11.2026**: чистый цикл «клон → build-all → zip → прошивка» —
загрузка, Wi-Fi, Bluetooth, все сайты (233 CA-сертификата).

## Что здесь

```
acer-iconia-tab-a50x-android-7-1-2/
├── setup.sh                  ← подготовка дерева AOSP — запускать из корня AOSP
├── build-all.sh              ← полный конвейер: ядро → система → CWM-zip
├── extract-blobs.sh          ← извлечение проприетарных блобов с планшета (1 раз)
├── picasso.xml               ← local_manifest (опционально)
├── device/
│   ├── acer/picasso/         ← device tree (BoardConfig, init.rc, Wi-Fi, 93 сертификата)
│   └── samsung/p4-common/    ← платформа Tegra 2 (decatf)
├── kernel/acer/picasso/      ← ЯДРО 3.8.13.28 (Thor/digetx + бэкпорты для 7.1)
│   └── build.sh              ← host-tools GCC10+ фикс включён, DTB-склейка
├── hardware/
│   ├── broadcom/             ← драйверы Wi-Fi/BT bcmdhd (исходники)
│   └── libhardware_legacy/   ← Wi-Fi HAL (wifi_set_mode)
├── vendor/decatf/            ← открытые компоненты: webview 54МБ, Launcher3, busybox, addon.d
├── patches/                  ← ПОЛНЫЕ diff «чистый android-7.1.2_r8 → рабочее дерево»
│   ├── patches-bionic.patch     ← paths.h (_PATH_BSHELL2), libc
│   ├── patches-build.patch      ← MALLOC_IMPL, kernel.mk, kati/soong гэпы
│   ├── patches-frameworks.patch ← SystemUI/QS, projekt/OMS, GL, bootanimation, wifi_setMode
│   ├── patches-libcore.patch
│   ├── patches-packages.patch   ← 11 apps + DeskClock gen/BuildConfig
│   └── patches-system.patch     ← BT BCM4329B1, fs_mgr, sepolicy ics_blob_file
├── aosp-gaps/                ← проекты, которые repo sync «молча пропускает»
│   ├── build/kati, build/soong, build/blueprint
│   ├── external/v8 (WebView JS-движок, 246МБ), external/lld
│   └── frameworks/opt/emoji, inputconnectioncommon, packages/apps/Phone, system/nvram...
└── tools/
    ├── build-kernel.sh       ← сборка ядра (GCC 4.8 из prebuilts)
    ├── make-full-zip.py      ← CWM update-zip (все требования старого рекавери)
    ├── update-binary         ← edify-интерпретатор (ОБЯЗАТЕЛЕН для этого CWM)
    ├── META-INF/updater-script ← установочный скрипт (fixperms ДО запуска!)
    ├── fixperms/fixperms.sh
    └── neon_check.sh         ← аудит NEON/d16 (Tegra 2 = VFPv3-D16, БЕЗ NEON)
```

## Требования к машине

| Что | Минимум | Примечания |
|---|---|---|
| ОС | Linux x86_64 (Ubuntu 20.04+; WSL2 подходит) | case-sensitive FS |
| Диск | 250 ГБ | AOSP ~45 ГБ + out ~50 ГБ + ccache |
| RAM | 16 ГБ | jack съедает много |
| JDK | **8** | НЕ 9+; `~/jdk8-old` или apt install openjdk-8-jdk |

## Подготовка окружения (один раз)

### 1. JDK 8
```bash
sudo apt install openjdk-8-jdk
# или отдельный каталог ~/jdk8-old — build-all.sh подхватит
```

### 2. AOSP android-7.1.2_r8
```bash
mkdir ~/aosp && cd ~/aosp
repo init -u https://android.googlesource.com/platform/manifest -b android-7.1.2_r8 --depth=1
repo sync -j4          # НЕ -j20: Google отдаёт HTTP 429
```

### 3. Блобы (проприетарные, НЕ в репо)
Нужен планшет с рабочей прошивкой + root:
```bash
./extract-blobs.sh       # → vendor/acer/picasso/proprietary/
```

### 4. Клон этого репо
```bash
git clone https://github.com/beeline09/acer-iconia-tab-a50x-android-7-1-2.git
```

## Сборка

### Всё одной командой
```bash
cd acer-iconia-tab-a50x-android-7-1-2
./build-all.sh ~/aosp    # → picasso-71-a50x-full.zip (~40-60 мин с ccache)
```

### По шагам
```bash
# 1) Ядро (GCC 4.8 из prebuilts — 4.9 раздувает за лимит 4 032 056 байт!)
cd kernel/acer/picasso
export PATH=~/aosp/prebuilts/gcc/linux-x86/arm/arm-eabi-4.8/bin:$PATH
./build.sh                          # → zImage-final (zImage + DTB склейка)

# 2) Подготовка дерева
cd ~/aosp
/path/to/repo/setup.sh              # device + patches + hardware + vendor + gaps

# 3) Система
export JAVA_HOME=~/jdk8-old
export PATH=$JAVA_HOME/bin:$PWD/prebuilts/python/linux-x86/2.7.5/bin:$PATH
export USE_CCACHE=1 CCACHE_DIR=~/ccache
source build/envsetup.sh
lunch picasso-userdebug
mkdir -p out/target/product/picasso
cp device/acer/picasso/kernel out/target/product/picasso/kernel
make -j$(nproc)

# 4) Сертификаты (conscrypt затирает PRODUCT_COPY_FILES)
cp device/acer/picasso/cacerts/* out/target/product/picasso/system/etc/security/cacerts/

# 5) CWM-zip
python3 /path/to/repo/tools/make-full-zip.py ~/aosp my-rom.zip
```

## Установка

1. CWM Recovery → install → файл из **`/sdcard/0/Download/`**
2. Скрипт: format /system (wipe) → система (1867 файлов) → симлинки → fixperms → dd boot
3. Root: отдельным zip'ом [magisk-picasso-noNEON](https://github.com/beeline09/magisk-picasso-noNEON)

## Подводные камни (ВСЕ пройдены на живом устройстве)

| Проблема | Решение здесь |
|---|---|
| NEON на Tegra 2 → SIGILL | только vfpv3-d16; для Magisk см. его репо |
| GCC 10+ yylloc | предсобранные host-tools в kernel/scripts/ |
| Ядро не собирать внутри AOSP | PREBUILT_KERNEL: build-all.sh подкладывает zImage-final |
| repo sync «successfully» без 22 проектов | aosp-gaps/ — раскладываются setup.sh |
| v8/*.mk скрыты .gitignore | force-add в aosp-gaps |
| DeskClock BuildConfig | gen/BuildConfig.java в patches-packages |
| CWM abort: zip-флаги | python-zipfile, flags 0x0, БЕЗ подписи, update-binary первый |
| CWM abort: нет update-binary | tools/update-binary (edify ELF) в zip |
| vendor/decatf потерян | в репо как каталог (webview, Launcher3, busybox) |
| cacerts затёрты conscrypt | пост-шаг cp в build-all.sh |
| Wi-Fi HAL wifi_set_mode | hardware/libhardware_legacy в репо |
| внешние .gitignore прячут файлы от git apply | setup.sh чистит каталоги патчей с -x |

## Что работает

UI 1280×800, тач, звук, Wi-Fi BCM4329, Bluetooth+A2DP, все сайты (233 корня),
root через Magisk-noNEON, TRIM eMMC, GL-диспетчеризация.

## Благодарности

- [**ThinkTwice**](https://github.com/ThinkTwice) (Thor), [**digetx**](https://github.com/digetx) — TegraOwners, ядро 3.8.13.28
- [**decatf**](https://github.com/decatf) — p4-common 7.1.2, device trees, vendor компоненты
- [**topjohnwu**](https://github.com/topjohnwu) — Magisk

## Лицензии

Ядро GPL-2; device trees, патчи, vendor — Apache-2.0 (AOSP). Блобы извлекаются
с устройства каждым владельцем.
