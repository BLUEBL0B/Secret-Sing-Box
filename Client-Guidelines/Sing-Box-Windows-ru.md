
### Устанавливаем Sing-Box (Windows 10 и 11)

Жмём Win + X, после этого открываем командную строку с правами аминистратора:

![w1](https://github.com/user-attachments/assets/ebffb58e-9251-4ec5-94a7-8b5416b0ced2)

Далее вводим команду:

```
winget install sing-box
```

После окончания установки командную строку можно закрыть (в дальнейшем можно обновлять Sing-Box той же командой)

Если на этом этапе возникла ошибка, предупреждающая об отсутствии winget, то следуйте инструкциям ниже

-----

### Устанавливаем Sing-Box (для версий Windows без winget)

Скачиваем Sing-Box для Windows из официальной репозитории:

https://github.com/SagerNet/sing-box/releases

Далее извлекаем sing-box.exe из архива

-----

### Создаём .cmd или .bat файл с таким содержимым:

```
@echo off
echo Started sing-box
echo.
echo Do not close this window while sing-box is running
echo.
echo Press Ctrl + C to disconnect
echo.
if not exist "C:\1-sbconfig\" mkdir C:\1-sbconfig
curl --silent https://domain.com/secret175subscr1pt10n/1-me-VLESS-CLIENT.json -o C:\1-sbconfig\client.json
sing-box run -c C:\1-sbconfig\client.json
```

Ссылку в предпоследней строчке меняем на свою

Для версий Windows, где нет winget, заменяем последнюю строчку таким образом и меняем путь к sing-box.exe на свой:

```
C:\actual\path\to\sing-box.exe run -c C:\1-sbconfig\client.json
```

-----

### Создаём ярлык для этого .cmd или .bat файла

Далее настраиваем ярлык, чтобы запускать его с правами администратора

![w2](https://github.com/user-attachments/assets/22d79731-f46d-4d1a-868c-36b45a9e4d36)

![w3](https://github.com/user-attachments/assets/bce8b230-f0f4-4f99-9bf4-609e74290897)

![w4](https://github.com/user-attachments/assets/d35d5648-e593-4ab5-9afb-f8e8a2201f41)

Везде жмём OK

-----

### Для подключения к прокси просто жмём на ярлык

Не нужно закрывать появившееся окно, пока ПК подключён к прокси

Чтобы отключиться, жмём на окно командной строки, а далее Ctrl + C
