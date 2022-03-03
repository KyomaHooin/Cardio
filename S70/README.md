
DESCRIPTION

GE Vivid S70 Medicus 3 integration.

![S70](https://github.com/KyomaHooin/Cardio/raw/master/S70/S70.png "screenshot")

MEDICUS SETUP

![Medicus](https://github.com/KyomaHooin/Cardio/raw/master/S70/Medicus.png "screenshot")
<pre>
Configuration > External Program > [+] > Command line:

../S70.exe %IDUZI% %RODCISN% %JMENO% %PRIJMENI% %VYSKA% %VAHA%
</pre>

FILE
<pre>
          S70.au3 - Program source code.
        Print.au3 - Printing library by "martin".
         Json.au3 - JSON library by "Ward".
   BinaryCall.au3 - JSON binary wrapper.
        LZNT1.au3 - LZNT1 de-compression library by "trancexx".
        patch.au3 - Update archived files machine code.
       userid.au3 - Get Medicus user ID.

        print.dll - Printing DLL.
          S70.ini - Program configuration file(ANSI encoding).  
          LICENSE - License & disclaimer.
        CHANGELOG - Changelog.

 logo_128x128.bmp - Printing logo bitmap. [96DPI]
vcard_123x123.bmp - vCard v3 QR code bitmap. [96DPI]
      Medicus.png - Medicus 3 external app configuration screen.
          S70.png - Program GUI screen.
          S70.ico - Program icon.
</pre>
SOURCE

https://github.com/KyomaHooin/Cardio

