# Minimal setup + deferred applications

- Fix OpenOS startup: remove shell.getRunningProgram(); accept explicit distribution root.
- Bootstrap now downloads setup metadata only, then opens setup choices.
- Minimal default installs only system tools; optional apps install later via ZOS Software.
- Add shared ZOSDownload with checksums, .part files and reuse of existing downloads.
- Reuse the latest existing /home/ZOS-download[-N] directory, including -3 from the screenshot.
- Save manifest/source configuration to installed /ZOS/ for the later application catalog.

# GitHub MCP: полная публикация ресурсов

- Восстановлены пропущенные текстовые файлы и скрытые каталоги.
- Для бинарных ресурсов добавлены точные Base64-копии .b64; новый bootstrap
  декодирует их перед установкой. Формат установленных ресурсов не меняется.
- Добавлен tools/restore_assets.py для офлайн-сборки из GitHub ZIP/clone.
- Manifest указывает реальные remotePath бинарных ресурсов.

# Hotfix: повторное создание каталогов в OpenOS

- Исправлен отказ `file or directory with that name already exists`: загрузчик,
  установщик и менеджер ZPK сначала проверяют наличие и тип каталога.
- Адрес загрузки по умолчанию: https://raw.githubusercontent.com/Nenormalniypon/ZOS/main/.
- При повторном запуске загрузчик выбирает новую папку с числовым суффиксом,
  не удаляя прежнюю загрузку.
- Тестовая модель mkdir теперь возвращает ошибку при существующем каталоге.
  Добавлены тесты сетевого bootstrap на повторные каталоги, пробелы и повторный запуск.
- Обновлены Installer/Manifest.lua и SHA256SUMS после изменения ZOSPackages.lua.

# 0.1.0 alpha

## Добавлено
- Libraries/ZOSShell.lua: XP/Xfce-inspired оболочка поверх MineOS GUI/System.
- Libraries/ZOSPackages.lua и Applications/ZOS Packages.app: локальные пакеты ZPK1.
- EFI/ZOS.lua: 2837-байтная прошивка, F2, F8, выбор OS.lua/init.lua.
- init.lua: вход для стандартной EFI OpenComputers.
- Themes/ZOS Luna.thm, Wallpapers/ZOS Hills.wlp и ZOS Teal.wlp.
- Отдельный офлайн-установщик OpenOS, manifest, резервирование/откат EEPROM.
- Pastebin-ready bootstrap (без опубликованного ID/хостинга).
- Пример Hello.zpk, packer, воспроизводимые тесты и контрольные суммы.

## Точечно изменено в унаследованном коде
- OS.lua: чёрный загрузочный экран с движущимися блоками, подключение оболочки,
  event timeout 0.05 вместо busy polling.
- Libraries/System.lua: лёгкие настройки по умолчанию, статичный фон с интервалом 1 s,
  обработка отключённых обоев, сброс признака static, безопасная загрузка без автозадач/сети.
- Settings.app/Modules/1_Wallpaper/Main.lua: выбор обоев повторно включает их,
  если установка была выполнена в режиме «без обоев».
- Исправлены ошибки исходных локализаций, найденные Lua-парсером:
  VK Spanish: синтаксически недопустимые ключи с диакритикой и переведённые API-ключи;
  RayWalk French: незакрытая строка;
  Control Dutch: некорректное экранирование.

## Не изменено / не включено
- Все исходные файлы библиотек сохранены: 28 из 29 побайтно не изменены.
- Исходный нестандартный LICENSE сохранён дословно.
- Старые Installer/pastebin.txt и MineOS EFI не используются в новой установке.
- Нет ISO, эмуляции Linux/Xfce, доказанных ускорений или гарантии всей экосистемы MineOS.
- Нет реального тестирования в Minecraft и опубликованного Pastebin.
