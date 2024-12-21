# Secret Sing-Box

[**English version**](https://github.com/BLUEBL0B/Secret-Sing-Box/blob/main/README-ENG.md)

### Прокси с использованием протоколов Trojan и VLESS и терминированием TLS на NGINX или HAProxy
Данный скрипт предназначен для полной настройки защищённого прокси-сервера с ядром [Sing-Box](https://sing-box.sagernet.org) и маскировкой при помощи [NGINX](https://nginx.org/ru/) или [HAProxy](https://www.haproxy.org). Два варианта настройки на выбор:
- Все запросы к прокси принимает NGINX, запросы передаются на Sing-Box только при наличии в них правильного пути (транспорт WebSocket или HTTPUpgrade)

![nginx-ru](https://github.com/user-attachments/assets/1ae6d050-4325-4d47-a807-720525fe4955)

- Все запросы к прокси принимает HAProxy, запросы передаются на Sing-Box только при наличии в них правильного пароля Trojan (транспорт TCP) — метод [FPPweb3](https://github.com/FPPweb3)

![haproxy-ru](https://github.com/user-attachments/assets/91ceaa8e-4f77-4cac-8f8d-cf47db44d0f7)

Оба варианта настройки делают невозможным обнаружение Sing-Box снаружи, что повышает уровень безопасности.

> [!IMPORTANT]
> Рекомендуемая ОС: Debian 11/12 или Ubuntu 22.04/24.04. Для настройки понадобится свой домен, прикреплённый к аккаунту Cloudflare ([Как настроить?](https://github.com/BLUEBL0B/Secret-Sing-Box/blob/main/cf-settings-ru.md)). Запускайте от имени root на чистой системе. Рекомендуется обновить систему и перезагрузить сервер перед запуском скрипта.
>
> Данный проект создан в образовательных и демонстрационных целях. Пожалуйста, убедитесь в законности ваших действий перед использованием.

> [!NOTE]
> С правилами маршрутизации для России. Открытые порты на сервере: 443 и SSH.
 
### Включает:
1) Настройку сервера Sing-Box
2) Настройку обратного прокси на NGINX или HAProxy на 443 порту, а также сайта-заглушки
3) Настройку безопасности (опционально)
4) SSL сертификаты Cloudflare с автоматическим обновлением
5) Настройку WARP
6) Включение BBR
7) Клиентские конфиги Sing-Box с правилами маршрутизации для России
8) Автоматизированное управление конфигами пользователей
9) Возможность настройки цепочек из двух и более серверов
 
### Использование:

Для настройки сервера запустите эту команду:

```
bash <(curl -Ls https://raw.githubusercontent.com/BLUEBL0B/Secret-Sing-Box/master/install-server.sh)
```

Затем просто введите необходимую информацию:

![pic-1-ru](https://github.com/user-attachments/assets/6b36ee5b-512a-4fe5-b8d8-305e911ca675)

В конце скрипт покажет ссылки на клиентские конфиги.

-----

Чтобы вывести дополнительные настройки, введите команду:

```
sbmanager
```

Далее следуйте инструкциям:

![pic-2-ru](https://github.com/user-attachments/assets/4b63c6d5-0268-4d57-91a6-558da77c3f2f)

Пункты 5 и 6 синхронизируют настройки в клиентских конфигах всех пользователей, что позволяет не редактировать конфиг каждого пользователя отдельно.

### Ключи WARP+:

Чтобы активировать ключ WARP+, введите эту команду, заменив ключ на свой:

```
warp-cli registration license CMD5m479-Y5hS6y79-U06c5mq9
```

### Настройка клиентов:
[Android и iOS:](https://github.com/BLUEBL0B/Secret-Sing-Box/blob/main/Client-Guidelines/Sing-Box-Android-iOS-ru.md) на некоторых устройствах с Android, особенно старых, может не работать "stack": "system" в настройках tun-интерфейса в клиентских конфигах. В таких случаях рекомендуется заменить его на "gvisor" с помощью пункта 4 в sbmanager.

[Windows:](https://github.com/BLUEBL0B/Secret-Sing-Box/blob/main/Client-Guidelines/Sing-Box-Windows-ru.md) рекомендован данный способ, так как он обеспечивает более полные настройки маршрутизации, но можно также вставить ссылку в клиент [Hiddify](https://github.com/hiddify/hiddify-app/releases/latest).

[Linux:](https://github.com/BLUEBL0B/Secret-Sing-Box/tree/main?tab=readme-ov-file#%D0%BD%D0%B0%D1%81%D1%82%D1%80%D0%BE%D0%B9%D0%BA%D0%B0-%D0%BA%D0%BB%D0%B8%D0%B5%D0%BD%D1%82%D0%BE%D0%B2) запустите команду ниже и следуйте инструкциям. Или используйте клиент [Hiddify](https://github.com/hiddify/hiddify-app/releases/latest).
```
bash <(curl -Ls https://raw.githubusercontent.com/BLUEBL0B/Secret-Sing-Box/master/sb-pc-linux.sh)
```

### Вы можете поддержать проект, если он полезен для вас:
- USDT (BEP20): 0xe2FeA540a9F1f85C2bfA3e6949c722393B5d636A
- USDT (ERC20): 0xe2FeA540a9F1f85C2bfA3e6949c722393B5d636A
- USDT (TRC20): TFN44R1PnhyX29vBqv9Z4cB5wH7MrVyFoC
- Bitcoin (BIP84): bc1qhn2ghk3pcpsrr6l9ywfryvqfzvyx8gs2wnpz89
- Litecoin (BIP84): ltc1q7quvcq3gtlwf2yuk370vhf2syad8ee4we9huj4
- Toncoin (TON): UQCWmIBsU-EZJSH3rhghbtSOtKQBmb5y74mkjbohpDWZ6l-H

### Звёзды по времени:
[![Stargazers over time](https://starchart.cc/BLUEBL0B/Secret-Sing-Box.svg?variant=adaptive)](https://starchart.cc/BLUEBL0B/Secret-Sing-Box)
