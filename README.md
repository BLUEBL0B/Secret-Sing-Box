# Secret Sing-Box

[**English version**](https://github.com/BLUEBL0B/Secret-Sing-Box/blob/main/README-ENG.md)

### Прокси с использованием протоколов Trojan и VLESS и терминированием TLS на NGINX или HAProxy
Данный скрипт предназначен для полной настройки скрытого прокси-сервера с ядром [Sing-Box](https://sing-box.sagernet.org) и маскировкой при помощи [NGINX](https://nginx.org/ru/) или [HAProxy](https://www.haproxy.org). Два варианта настройки на выбор:
- Все запросы к прокси принимает NGINX, запросы передаются на Sing-Box только при наличии в них правильного пути (транспорт WebSocket или HTTPUpgrade)
- Все запросы к прокси принимает HAProxy, запросы передаются на Sing-Box только при наличии в них правильного пароля Trojan (транспорт TCP) — метод [FPPweb3](https://github.com/FPPweb3)

Оба варианта настройки делают невозможным обнаружение Sing-Box снаружи.

> [!IMPORTANT]
> Рекомендуемая ОС: Debian 11/12 или Ubuntu 22.04/24.04. Для настройки понадобится свой домен, прикреплённый к аккаунту Cloudflare ([Как настроить?](https://github.com/BLUEBL0B/Secret-Sing-Box/blob/main/cf-settings-ru.md)). Запускайте от имени root на чистой системе. Рекомендуется обновить систему и перезагрузить сервер перед запуском скрипта.

> [!NOTE]
> С правилами маршрутизации для России.
 
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

![pic-1-ru](https://github.com/user-attachments/assets/637ce944-5a7d-4e90-aa7a-e5eec862e3c7)

В конце скрипт покажет ссылки на клиентские конфиги.

-----

Чтобы вывести дополнительные настройки, введите команду:

```
sbmanager
```

Далее следуйте инструкциям:

![pic-2-ru](https://github.com/user-attachments/assets/eedaa753-0959-4c91-a715-ca36f2dbf725)

Пункты 4 и 5 синхронизируют настройки в клиентских конфигах всех пользователей, что позволяет не редактировать конфиг каждого пользователя отдельно.

Чтобы включить DNS AdGuard на клиенте, используйте пункт 5, прописав в шаблоне конфига "tls://94.140.14.14" вместо "tls://1.1.1.1". Может снизить производительность за счёт более медленного разрешения доменов по сравнению с 1.1.1.1.

### Ключи WARP+:

Чтобы активировать ключ WARP+, введите эту команду, заменив ключ на свой:

```
warp-cli registration license CMD5m479-Y5hS6y79-U06c5mq9
```

### Настройка клиентов:
[Android и iOS](https://github.com/BLUEBL0B/Secret-Sing-Box/blob/main/Client-Guidelines/Sing-Box-Android-iOS-ru.md)

[Windows 10 и 11](https://github.com/BLUEBL0B/Secret-Sing-Box/blob/main/Client-Guidelines/Sing-Box-Windows-ru.md)

[Linux:](https://github.com/BLUEBL0B/Secret-Sing-Box/tree/main?tab=readme-ov-file#%D0%BD%D0%B0%D1%81%D1%82%D1%80%D0%BE%D0%B9%D0%BA%D0%B0-%D0%BA%D0%BB%D0%B8%D0%B5%D0%BD%D1%82%D0%BE%D0%B2) запустите команду ниже и следуйте инструкциям.
```
bash <(curl -Ls https://raw.githubusercontent.com/BLUEBL0B/Secret-Sing-Box/master/sb-pc-linux.sh)
```
