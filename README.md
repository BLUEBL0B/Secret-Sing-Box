# Sing-Box-Reverse-Proxy

[**English version**](https://github.com/BLUEBL0B/Sing-Box-NGINX-WS/blob/main/README-ENG.md)

### Прокси с использованием протоколов Trojan и VLESS и терминированием TLS на NGINX или HAProxy
Данный скрипт предназначен для полной настройки скрытого прокси-сервера с маскировкой при помощи NGINX или HAProxy. Два варианта настройки на выбор:
- Все запросы к прокси принимает NGINX, а сервер работает как прокси только при наличии в запросе правильного пути (транспорт WebSocket)
- Все запросы к прокси принимает HAProxy, а сервер работает как прокси только при наличии в запросе правильного пароля Trojan (транспорт TCP)
<br/>

> [!IMPORTANT]
> Рекомендуемая ОС: Debian 12 или Ubuntu 22.04/24.04. Для настройки понадобится свой домен, прикреплённый к аккаунту Cloudflare. Запускайте от имени root на свежеустановленной системе. Рекомендуется обновить систему и перезагрузить сервер перед запуском скрипта.

> [!NOTE]
> С правилами маршрутизации для России.
 
### Включает:
1) Настройку сервера Sing-Box
2) Настройку обратного прокси на NGINX или HAProxy на 443 порту, а также сайта-заглушки на NGINX
3) Настройку безопасности, включая автоматические обновления (unattended-upgrades)
4) SSL сертификаты Cloudflare с автоматическим обновлением
5) Настройку WARP
6) Включение BBR
7) Клиентские конфиги Sing-Box с правилами маршрутизации для России
8) Автоматизированное управление конфигами пользователей
 
### Использование:

Для настройки сервера запустите эту команду:

```
bash <(curl -Ls https://raw.githubusercontent.com/BLUEBL0B/Sing-Box-NGINX-WS/master/install-server.sh)
```

Затем просто введите необходимую информацию:

![pic-1-ru](https://github.com/user-attachments/assets/d7630d62-39f1-43fc-aa93-28162bff3552)

В конце скрипт покажет ссылки на клиентские конфиги.

-----

Чтобы добавить/удалить пользователей, синхронизировать настройки в клиентских конфигах или редактировать домены в WARP, введите команду:

```
sbmanager
```

Далее следуйте инструкциям:

![pic-2-ru](https://github.com/user-attachments/assets/765e443c-356f-47dd-9877-3cf546ac468d)

Пункты 4 и 5 синхронизируют настройки в клиентских конфигах всех пользователей, что позволяет не редактировать конфиг каждого пользователя отдельно.

### Настройка клиентов:
[Android и iOS](https://github.com/BLUEBL0B/Sing-Box-NGINX-WS/blob/main/Client-Guidelines/Sing-Box-Android-iOS-ru.pdf)

[Windows 10 и 11](https://github.com/BLUEBL0B/Sing-Box-NGINX-WS/blob/main/Client-Guidelines/Sing-Box-Windows-10-11-ru.pdf)

[Linux:](https://github.com/BLUEBL0B/Sing-Box-NGINX-WS/tree/main?tab=readme-ov-file#%D0%BD%D0%B0%D1%81%D1%82%D1%80%D0%BE%D0%B9%D0%BA%D0%B0-%D0%BA%D0%BB%D0%B8%D0%B5%D0%BD%D1%82%D0%BE%D0%B2) запустите команду ниже.
```
bash <(curl -Ls https://raw.githubusercontent.com/BLUEBL0B/Sing-Box-NGINX-WS/master/sb-pc-linux.sh)
```
