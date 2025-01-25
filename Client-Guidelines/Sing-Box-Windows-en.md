### Install Sing-Box (for Windows 10 and 11)

Press Win + X and open the terminal with admin rights:

![w1](https://github.com/user-attachments/assets/ebffb58e-9251-4ec5-94a7-8b5416b0ced2)

Then enter the command:

```
winget install sing-box
```

You can close the terminal after the installation is complete (Sing-Box can also be updated with the same command)

If you are getting an error telling that winget is absent, then follow the instructions below

-----

### Install Sing-Box (for Windows versions without winget)

Download Sing-Box for Windows from the official repository:

https://github.com/SagerNet/sing-box/releases

Then extract sing-box.exe from the archive

-----

### Create a .cmd or .bat file with such content:

```
@echo off
echo Started sing-box
echo.
echo Do not close this window while sing-box is running
echo.
echo Press Ctrl + C to disconnect
echo.
if not exist "C:\1-sbconfig\" mkdir C:\1-sbconfig
curl --silent https://domain.com/secret175subscr1pt10n/1-me-VLESS-CLIENT.json -o C:\1-sbconfig\VLESS-CLIENT.json
sing-box run -c C:\1-sbconfig\VLESS-CLIENT.json
```

Change the link in the 9th line to yours

For Windows versions without winget replace the last line like this and replace the path to sing-box.exe to your actual path:

```
C:\actual\path\to\sing-box.exe run -c C:\1-sbconfig\VLESS-CLIENT.json
```

-----

### Create a shortcut for this .cmd or .bat file

Then change the settings of the shortcut to run it as admin:

![w2](https://github.com/user-attachments/assets/22d79731-f46d-4d1a-868c-36b45a9e4d36)

![w3](https://github.com/user-attachments/assets/91a6f89f-a2b3-4029-bbfa-2e21a0c047da)

![w4](https://github.com/user-attachments/assets/d35d5648-e593-4ab5-9afb-f8e8a2201f41)

Then press OK

-----

### Click on the shortcut to connect to the server

Do not close the terminal window while connected to proxy

To disconnect, click on the terminal window and then press Ctrl + C
