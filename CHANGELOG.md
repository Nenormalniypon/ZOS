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
