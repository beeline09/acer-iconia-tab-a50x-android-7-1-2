# Android 7.1.2 для Acer Iconia Tab A500/A501 (picasso, NVIDIA Tegra 2)

**Единый репозиторий: ядро + device trees + патчи платформы + инструменты сборки.**
Всё, что нужно для самостоятельной сборки прошивки Nougat 2011-го планшета —
в одном клоне. Magisk (root без NEON) — отдельный репозиторий
[magisk-picasso-noNEON](https://github.com/beeline09/magisk-picasso-noNEON).

Проверено на устройстве 13.11.2026: система загружается, Wi-Fi и Bluetooth работают,
все 233 CA-сертификата (включая современные корни ISRG/Sectigo/DigiCert G2) на месте.

## Что здесь

```
acer-iconia-tab-a50x-android-7-1-2/
├── setup.sh                  ← подготовка дерева AOSP (device+патчи+ядро) — запускать из корня AOSP
├── build-all.sh              ← полный конвейер одной командой: ядро → система → CWM-zip
├── extract-blobs.sh          ← извлечение проприетарных блобов с планшета (нужно один раз)
├── picasso.xml               ← local_manifest (опционально)
├── device/
│   ├── acer/picasso/         ← device tree picasso (BoardConfig, init.rc, Wi-Fi, cacerts×93, fstrim)
│   └── samsung/p4-common/    ← базовая платформа Tegra 2 (decatf)
├── kernel/acer/picasso/      ← ЯДРО 3.8.13.28 (Thor/digetx + бэкпорты под 7.1)
│   └── build.sh              ← сборка ядра (host-tools фикс GCC10 включён)
├── patches/                  ← ПОЛНЫЕ diff «чистый android-7.1.2_r8 → рабочее дерево»
│   ├── patches-build-core.patch        ← MALLOC_IMPL (dlmalloc!), OUT_DIR, kernel-интеграция
│   ├── patches-frameworks-base.patch   ← SystemUI/QS, projekt/OMS, power-menu, бутанимация
│   ├── patches-frameworks-native.patch ← SurfaceFlinger, nullguard, gles1_compat
│   ├── patches-system-bt.patch         ← BT BCM4329B1
│   └── patches-system-core.patch       ← fs_mgr, init.environ
└── tools/
    ├── build-kernel.sh       ← (копия kernel build.sh)
    ├── make-full-zip.py      ← CWM update-zip со всеми требованиями старого рекавери
    ├── update-binary         ← edify-интерпретатор (ОБЯЗАТЕЛЕН для этого CWM!)
    ├── META-INF/.../updater-script  ← установочный скрипт (fixperms ПЕРЕД запуском распаковывается!)
    ├── fixperms/fixperms.sh
    └── neon_check.sh         ← аудит NEON/d16+ (Tegra 2 = VFPv3-D16, БЕЗ NEON)
```

## Требования к машине

| Что | Минимум | Примечания |
|---|---|---|
| ОС | Linux x86_64 (Ubuntu 20.04+; WSL2 подходит) | **только case-sensitive FS** (ext4, не macOS!) |
| Диск | 250 ГБ свободных | AOSP ~45 ГБ + out ~50 ГБ + кеш |
| RAM | 16 ГБ (лучше 32) | jack съедает много |
| JDK | **8** (см. ниже — конкретная схема `~/jdk8-old`) | НЕ 9+; для Magisk нужен 25 — это отдельная история |
| repo | repo tool (apt install repo или curl) | |
| ccache | любой | сильно ускоряет повторные сборки |

## Подготовка окружения (один раз)

### 1. JDK 8 — конкретная схема
Рабочая сборка использует отдельный JDK 8 (у нас — `~/jdk8-old`). Подойдёт любой
`openjdk-8` (Ubuntu: `apt install openjdk-8-jdk`), затем `export JAVA_HOME=~/jdk8-old`
(или ваш путь — переменную переопределяет build-all.sh).

### 2. Качаем AOSP android-7.1.2_r8
```bash
mkdir ~/aosp && cd ~/aosp
repo init -u https://android.googlesource.com/platform/manifest -b android-7.1.2_r8 --depth=1
repo sync -j4          # НЕ -j20: Google отдаёт 429; -j4 идёт стабильно, ~45 ГБ
```
⚠️ **repo sync может соврать «successfully» при недокачанных проектах.**
После sync сверьтесь, что есть `build/kati/Makefile.ckati`, `build/soong`,
`external/v8/Android.mk`, `packages/apps/Phone`. Если чего-то нет —
`repo sync -c <project>` повторно (мы это ловили: 22 проекта пропали).

### 3. Блобы (проприетарные, в репо их нет и быть не может)
Нужен планшет с рабочей прошивкой (сток/наша — неважно) и root (SuDH/Magisk):
```bash
adb shell su -c 'dd if=/dev/block/mmcblk0p2' > /dev/null   # проверка root
./extract-blobs.sh       # складывает в vendor/acer/picasso/proprietary
```
⚠️ **Важно:** в рабочей прошивке NVIDIA/Invensense-блобы (libnv\*, libmllite\*,
omxplayer, lights) — ОБНОВЛЁННЫЕ версии. Извлекайте с устройства с рабочей
системой — тогда сборка совпадёт с эталоном байт-в-байт.

### 4. Клонируем этот репо
```bash
git clone https://github.com/beeline09/acer-iconia-tab-a50x-android-7-1-2.git
```

## Сборка

### Вариант А: всё одной командой
```bash
cd acer-iconia-tab-a50x-android-7-1-2
export JAVA_HOME=~/jdk8-old        # ваш JDK 8
./build-all.sh ~/aosp              # → picasso-71-a50x-full.zip
```
Конвейер: ядро (arm-eabi-4.8 из prebuilts) → setup дерева → make (ccache) →
cacerts-постшаг → CWM-zip. Лог: `build-all.log`.

### Вариант Б: по шагам
```bash
# 1) Ядро (ТОЛЬКО GCC 4.8 из prebuilts — 4.9 раздувает за лимит загрузчика 4 032 056 байт!)
cd kernel/acer/picasso
export PATH=~/aosp/prebuilts/gcc/linux-x86/arm/arm-eabi-4.8/bin:$PATH
./build.sh                          # → zImage-final (zImage + DTB склейка!)

# 2) Дерево AOSP
cd ~/aosp
/path/to/repo/setup.sh              # device trees + патчи (git apply --binary) + ядро-подложка

# 3) Система
export JAVA_HOME=~/jdk8-old
export PATH=$JAVA_HOME/bin:$PWD/prebuilts/python/linux-x86/2.7.5/bin:$PATH
export USE_CCACHE=1 CCACHE_DIR=~/ccache
mkdir -p out/target/product/picasso
cp device/acer/picasso/kernel out/target/product/picasso/kernel   # PREBUILT-kernel в out
source build/envsetup.sh
lunch picasso-userdebug
make -j$(nproc)

# 4) Сертификаты: conscrypt затирает PRODUCT_COPY_FILES — вернуть эталон
cp device/acer/picasso/cacerts/* out/target/product/picasso/system/etc/security/cacerts/

# 5) CWM-zip
python3 /path/to/repo/tools/make-full-zip.py ~/aosp my-rom.zip
```

## Установка

1. CWM Recovery → install zip → файл **из `/sdcard/0/Download/`**
   (в рекавери пути такие; в загруженной системе — `/sdcard/Download`)
2. Рекомендуется предварительно format /system (скрипт сам делает wipe-формат).
3. Скрипт: система → 411 симлинков → fixperms → dd boot.img в mmcblk0p2.
4. Root — отдельным zip'ом из репозитория Magisk (см. ниже).

## Известные грабли (всё пройдено на живом устройстве)

| Грабля | Симптом | Решение здесь |
|---|---|---|
| NEON на Tegra 2 | SIGILL/бутлуп | ядро/натив — только vfpv3-d16; для Magisk см. его репо |
| GCC 10+ yylloc в ядре | multiple definition при host-tools | предсобранные тулзы + touch-приём уже в kernel/build.sh |
| Ядро НЕ собирать внутри AOSP | TUN_SOCKET__ATTACH_QUEUE и пр. | PREBUILT_KERNEL: build-all подкладывает zImage-final |
| MALLOC_IMPL запрещён r8 | lunch падает | patches-build-core снимает запрет (dlmalloc) |
| webview конфликт | MODULE already defined | setup.sh удаляет external/chromium-webview (vendor/decatf свой) |
| external/iw git describe | fatal: No names found | setup.sh ставит git-тег v4.1 |
| cacerts затираются | старые корни в образе | пост-шаг cp в build-all.sh |
| CWM: zip abort | installation aborted | python-zipfile flags 0x0, БЕЗ подписи, update-binary обязателен, META первым — всё в make-full-zip.py |
| repo sync 429 | HTTP 429 | только -j4 |
| Ядро >4 032 056 байт | загрузчик не берёт | только arm-eabi-4.8; DTB клеить в хвост (build.sh) |
| Ядро из make vs zImage | разные размеры | zImage+DTB: `cat zImage tegra20-picasso.dtb > zImage-final` (build.sh делает) |

## Что работает / чего нет

Работает: UI 1280×800, тач, звук, Wi-Fi BCM4329, Bluetooth+A2DP, все сайты (233 корня),
root через Magisk-noNEON, TRIM eMMC, GL-диспетчеризация (glv-tegra схема в device tree).
Ограничения: камеры/датчики/аппаратное видео/3G-GPS — не портированы (см. 4PDA-тему picasso).

## Благодарности

- [**ThinkTwice**](https://github.com/ThinkTwice) (Thor), [**digetx**](https://github.com/digetx)
  (Dmitry Osipenko) — TegraOwners, ядро 3.8.13.28 и база
- [**decatf**](https://github.com/decatf) — p4-common 7.1.2 и device trees
- [**topjohnwu**](https://github.com/topjohnwu) — Magisk (в связке с нашим noNEON-форком)

## Связанные репозитории

- [magisk-picasso-noNEON](https://github.com/beeline09/magisk-picasso-noNEON) — root без NEON (отдельная сборка, JDK 25)

## Лицензии

Ядро GPL-2; device trees и патчи Apache-2.0 (AOSP). Блобы не входят и извлекаются
с устройства каждым владельцем.
