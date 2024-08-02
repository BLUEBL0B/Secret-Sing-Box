# Sing-Box-NGINX-WebSocket

[**English version**](https://github.com/BLUEBL0B/Sing-Box-NGINX-WS/blob/main/README-ENG.md)

### Прокси с использованием протоколов Trojan и VLESS (WebSocket) и терминированием TLS на NGINX
Скрипт для полной настройки скрытого прокси-сервера с маскировкой при помощи NGINX.

> [!IMPORTANT]
> Рекомендуемая ОС: Debian 12. Запускайте от имени root на свежеустановленной системе. Рекомендуется обновить систему и перезагрузить сервер перед запуском скрипта.

> [!NOTE]
> С правилами маршрутизации для России.
 
### Включает:
1) Настройку сервера Sing-Box (Протоколы Trojan и VLESS)
2) Настройку обратного прокси и веб-сайта на NGINX
3) Базовую настройку безопасности, включая автоматические обновления (unattended-upgrades)
4) Настройку WARP
5) SSL сертификаты Cloudflare с автоматическим обновлением
6) Включение BBR
7) Клиентские конфиги Sing-Box с правилами маршрутизации для России
 
### Использование:

Запустите эту команду:

```
bash <(curl -Ls https://raw.githubusercontent.com/BLUEBL0B/Sing-Box-NGINX-WS/master/sb-nginx-server.sh)
```
Затем просто введите необходимую информацию:

![image](https://github.com/user-attachments/assets/7e46a4a0-2168-4b63-95f2-fc481e2ddf60)

В конце скрипт покажет ссылки на клиентские конфиги.

### Инструкции по настройке клиентов:
[Android и iOS](https://github.com/BLUEBL0B/Sing-Box-NGINX-WS/blob/main/Client-Guidelines/Sing-Box-Android-iOS-ru.pdf)

[Windows 10 и 11](https://github.com/BLUEBL0B/Sing-Box-NGINX-WS/blob/main/Client-Guidelines/Sing-Box-Windows-10-11-ru.pdf)
