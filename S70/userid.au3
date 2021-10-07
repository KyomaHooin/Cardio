;
; Disaply medicus User ID
;

#AutoIt3Wrapper_Res_Description=Medicus 3 User ID
#AutoIt3Wrapper_Res_ProductName=S70
#AutoIt3Wrapper_Res_ProductVersion=1.0
#AutoIt3Wrapper_Res_CompanyName=Kyouma Houin
#AutoIt3Wrapper_Res_LegalCopyright=GNU GPL v3
#AutoIt3Wrapper_Res_Language=1029
#AutoIt3Wrapper_Icon=S70.ico
#NoTrayIcon

if UBound($cmdline) >= 2 then
	MsgBox(0x40, 'Medicus 3 - User ID', 'ID: ' & $cmdline[1])
endif

exit

