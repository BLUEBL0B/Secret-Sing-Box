### Общие настройки
Для начала нужно добавить домен в аккаунт Cloudflare и указать NS-сервера Cloudflare у вашего регистратора доменов.

Далее выполнить следующие настройки в аккаунте Cloudflare: 
1) SSL/TLS > Overview > Configure > Full
2) SSL/TLS > Edge Certificates > Minimum TLS Version > TLS 1.2
3) SSL/TLS > Edge Certificates > TLS 1.3 > Включить

### Настройки DNS
Пример DNS записей для варианта настройки с терминированием TLS на NGINX и транспортом WebSocket или HTTPUpgrade (1 вариант):

![dns-1](https://github.com/user-attachments/assets/461f07c7-94e1-47c2-967e-5fa36b50509f)

Пример DNS записей для варианта настройки с терминированием TLS на HAProxy и выбором бэкенда по паролю Trojan (2 вариант):

![dns-2](https://github.com/user-attachments/assets/a0be45a5-2013-48b7-a3f9-565a396b33bb)

> [!IMPORTANT]
> Если уже есть А запись на этот домен, созданная для других целей, то нужно создать А запись на поддомен:
>
> A | sub | 98.76.54.32
>
> Вместо «sub» придумайте свой поддомен, и в скрипте введите его вместо домена (например, sub.example.com).
> 
> Для первого варианта настройки может потребоваться отключение ECH в аккаунте Cloudflare, либо переключение DNS записей на «DNS only».

### Получение API токена Cloudflare
Overview > Get your API token > Create Token > Edit zone DNS (Use template)

Далее нужно указать следующие настройки:

![token](https://github.com/user-attachments/assets/7eecc898-923b-4cbc-97f7-fc3d45deb395)

Остальные настройки можно оставить, как есть.

После получения токен нужно скопировать и сохранить, потому что его покажут только 1 раз.

Вместо токена можно использовать API ключ, но это менее безопасно и не рекомендуется.
