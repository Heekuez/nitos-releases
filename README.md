<div align="center">

# 🪐 NITOS

[![Telegram](https://img.shields.io/badge/Telegram-Сообщество-2AABEE?logo=telegram&logoColor=white)](https://t.me/nitos_space)


[![Сайт](https://img.shields.io/badge/nitos.space-сайт-E8823C)](https://nitos.space)
[![Telegram](https://img.shields.io/badge/Telegram-бот-26A5E4?logo=telegram&logoColor=white)](https://t.me/nitos_vpn_bot)
[![Версия](https://img.shields.io/github/v/release/Heekuez/nitos-releases?color=4FD18B&label=версия)](https://github.com/Heekuez/nitos-releases/releases/latest)
[![Загрузки](https://img.shields.io/github/downloads/Heekuez/nitos-releases/total?color=E8823C&label=загрузок)](https://github.com/Heekuez/nitos-releases/releases)

<p>
  <img src="assets/scr-mobile.png" width="224" alt="Телефон">
  <img src="assets/scr-desktop.png" width="500" alt="Компьютер">
</p>

</div>

## Скачать

<!-- DL -->
| Платформа | Скачать |
|---|---|
| Android / Android TV | **[NITOS-2.9.4.apk](https://github.com/Heekuez/nitos-releases/releases/download/v2.9.4/NITOS-2.9.4.apk)** |
| Windows | **[на странице релиза](https://github.com/Heekuez/nitos-releases/releases/latest)** |
| Ubuntu / Debian / Mint | **[на странице релиза](https://github.com/Heekuez/nitos-releases/releases/latest)** |
| Другой Linux | **[на странице релиза](https://github.com/Heekuez/nitos-releases/releases/latest)** |
<!-- /DL -->

## Роутер (бета)

VPN один раз на роутере — работает у всех устройств дома сразу.

| Роутер | Поддержка | Как |
|---|---|---|
| **Keenetic** | ✅ | без перепрошивки, через Entware → [гайд](router/GUIDE.md#keenetic) |
| **GL.iNet** | ✅ | работает из коробки → [гайд](router/GUIDE.md#glinet) |
| **Xiaomi, TP-Link, ASUS…** | ⚙️ | после прошивки OpenWRT → [гайд](router/GUIDE.md#openwrt) |
| **Huawei, Tenda, от провайдера** | ❌ | прошивка закрыта |

Установка — одна команда по SSH ([подробный гайд](router/GUIDE.md)):

```sh
curl -fsSL https://raw.githubusercontent.com/Heekuez/nitos-releases/main/router/install.sh | sh -s -- "ССЫЛКА"
```

`ССЫЛКА` — ваша подписка или vless-конфиг. Удаление: тот же скрипт с `--uninstall`.
