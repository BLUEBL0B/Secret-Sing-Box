### 1.1) Устанавливаем Sing-Box (Windows 10 и 11)

Жмём Win + X, после этого открываем командную строку с правами аминистратора:

![w1](https://github.com/user-attachments/assets/52ac24b2-101e-4a4a-b45f-740582620fb3)

Далее вводим команду:

```
winget install sing-box
```

После окончания установки командную строку можно закрыть (в дальнейшем можно обновлять Sing-Box той же командой).

Если на этом этапе возникла ошибка, предупреждающая об отсутствии winget, то следуйте инструкциям ниже.

-----

### 1.2) Устанавливаем Sing-Box (для версий Windows без winget)

Скачиваем Sing-Box для Windows из официального репозитория:

https://github.com/SagerNet/sing-box/releases/latest

Далее извлекаем sing-box.exe из архива.

-----

### 2) Создаём .cmd или .bat файл с таким содержимым:

```
@echo off
echo Started sing-box
echo.
echo Do not close this window while sing-box is running
echo.
echo Press Ctrl + C to disconnect
echo.
if not exist "C:\1-sbconfig\" mkdir C:\1-sbconfig
curl --silent -o C:\1-sbconfig\client.json https://domain.com/secret175subscr1pt10n/1-me-VLESS-CLIENT.json
sing-box run -c C:\1-sbconfig\client.json
```

Ссылку в предпоследней строчке меняем на свою.

Для версий Windows, где нет winget, заменяем последнюю строчку таким образом и меняем путь к sing-box.exe на свой:

```
C:\actual\path\to\sing-box.exe run -c C:\1-sbconfig\client.json
```

-----

### 3) Создаём ярлык для этого .cmd или .bat файла

Далее настраиваем ярлык, чтобы запускать его с правами администратора.

![w2](https://github.com/user-attachments/assets/ad3da50e-9a46-49a7-8f98-c3828edd0a1b)

![w3](https://github.com/user-attachments/assets/92e2f6ae-623e-4b28-8065-f10443888336)

![w4](https://github.com/user-attachments/assets/60185d25-6cb4-4ee0-9b98-7f639937334f)

Везде жмём OK.

-----

### 4) Для подключения к прокси просто жмём на ярлык

Не нужно закрывать появившееся окно, пока ПК подключён к прокси.

Чтобы отключиться, жмём на окно командной строки, а далее Ctrl + C.
