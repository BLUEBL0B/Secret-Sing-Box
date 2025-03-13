# Setting Up Sing-Box Client on Windows

### 1.1) Install Sing-Box (for Windows 10 and 11)

Press Win + X and open the terminal with admin rights:

![w1](https://github.com/user-attachments/assets/614a2643-df78-478c-ad5f-66bd2cfb7405)

Then enter the command:

```
winget install sing-box
```

You can close the terminal after the installation is complete (Sing-Box can also be updated with the same command).

If you are getting an error telling that winget is absent, then follow the instructions below.

-----

### 1.2) Install Sing-Box (for Windows versions without winget)

Download Sing-Box for Windows from the official repository:

https://github.com/SagerNet/sing-box/releases/latest

Then extract sing-box.exe from the archive.

-----

### 2) Create a .cmd or .bat file with such content:

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

Change the link in the 9th line to yours.

For Windows versions without winget replace the last line like this and replace the path to sing-box.exe to your actual path:

```
C:\actual\path\to\sing-box.exe run -c C:\1-sbconfig\client.json
```

-----

### 3) Create a shortcut for this .cmd or .bat file

Then change the settings of the shortcut to run it as admin.

![w2](https://github.com/user-attachments/assets/18d9550a-0ba1-4331-b8b3-d80edd3a7362)

![w3](https://github.com/user-attachments/assets/73f76c75-f891-49a9-9b95-dd659b145725)

![w4](https://github.com/user-attachments/assets/bf8fa331-1442-4bcb-99e6-8748b5253e9a)

Then press OK.

-----

### 4) Click on the shortcut to connect to the server

Do not close the terminal window while connected to proxy.

To disconnect, click on the terminal window and then press Ctrl + C.
