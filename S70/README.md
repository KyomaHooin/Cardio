
![S70](https://github.com/KyomaHooin/Cardio/raw/master/S70/S70.png "screenshot")

DESCRIPTION

GE Vivid S70 Medicus 3 integration.

TODO
<pre>
-GUI
-dynamic print
-dynamic XLS
</pre>

MEDICUS SETUP

![Medicus](https://github.com/KyomaHooin/Cardio/raw/master/S70/Medicus.png "screenshot")
<pre>
Configuration > External Program > [+] > Command line:

../S70.exe %RODCISN% %JMENO% %PRIJMENI% %POJ%
</pre>

FILE
<pre>
    S70.au3 - Main GUI source code.
  Print.au3 - Printing library by "martin".
   Json.au3 - JSON library by "Ward".
 
  print.dll - Printing DLL.
    S70.ini - Program configuration file.
    
    LICENSE - License & disclaimer.

Medicus.png - Medicus 3 external app configuration screen.
    S70.pnp - Program GUI screen.
    S70.ico - Program icon.
</pre>
SOURCE

https://github.com/KyomaHooin/Cardio

