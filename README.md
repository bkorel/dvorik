# Дворик

Офлайн Android-игра на Godot 4.3. Без рекламы, платежей, аналитики и аккаунта.

## Открыть в редакторе

Нужен Godot 4.3+. Открыть `project.godot`, F5.

## Собрать APK

CI на каждый пуш в `main` и вручную (Actions → Android APK → Run workflow).
Артефакт: `dvorik-debug-apk`. Debug-подпись, без релизного ключа.

Локально: Godot → Project → Export → Android → Export Project (Debug).

## Поставить на телефон (сайдлоад)

1. Скачать `dvorik-debug.apk` из артефакта Actions.
2. На телефоне разрешить установку из этого источника.
3. Открыть файл и установить.

Play и RuStore не нужны. Релизная подпись — позже.
