;
; GE Vivid S70 - Medicus 3 integration
; CMD: S70.exe %IDUZI% %RODCISN% %JMENO% %PRIJMENI% %VYSKA% %VAHA%
;
; Copyright (c) 2020 Kyoma Hooin
;
; This program is free software: you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation, either version 3 of the License, or
; (at your option) any later version.
;
; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.
;
; You should have received a copy of the GNU General Public License
; along with this program.  If not, see <https://www.gnu.org/licenses/>.
;

#AutoIt3Wrapper_Res_Description=GE Vivid S70 Medicus 3 integration
#AutoIt3Wrapper_Res_ProductName=S70
#AutoIt3Wrapper_Res_ProductVersion=2.2
#AutoIt3Wrapper_Res_CompanyName=Kyouma Houin
#AutoIt3Wrapper_Res_LegalCopyright=GNU GPL v3
#AutoIt3Wrapper_Res_Language=1029
#AutoIt3Wrapper_Icon=S70.ico
#NoTrayIcon

; -------------------------------------------------------------------------------------------
; INCLUDE
; -------------------------------------------------------------------------------------------

#include <GUIConstantsEx.au3>
#include <GUIConstants.au3>
#include <Clipboard.au3>
#include <Excel.au3>
#include <ExcelConstants.au3>
#include <File.au3>
#include <Date.au3>
#include <Print.au3>
#include <Json.au3>
#include <GDIPlus.au3>

; -------------------------------------------------------------------------------------------
; VAR
; -------------------------------------------------------------------------------------------

global const $VERSION = '2.2'
global $AGE = 24; default stored data age in hours

global $log_file = @ScriptDir & '\' & 'S70.log'
global $config_file = @ScriptDir & '\' & 'S70.ini'

global $export_path = @ScriptDir & '\' & 'input'
global $archive_path = @ScriptDir & '\' & 'archive'
global $history_path = $archive_path & '\' & 'history'

global const $runtime = @YEAR & '/' & @MON & '/' & @MDAY & ' ' & @HOUR & ':' & @MIN & ':' & @SEC

; default result template
global const $result_template[2]=[ _
	"Srdeční oddíly nedilatované, normální systolická funkce obou komor, chlopně bez významnější valvulopatie, bez známek zvýšené tenze v plicnici.", _
	"Dobrá systolická funkce obou nedilat. komor, chlopenní aparát bez významnější valvulopatie, nejsou známky zvýšené tenze v plicnici." _
]

; Medicus user ID to name
global const $user_template='{' _
	& '"5":"Jan Škoda",' _
	& '"6":"Jiří Procházka",' _
	& '"8":"Tomáš Březák"' _
& '}'

; 5 to 4 column map template
global const $map_template='{' _
	& '"lk":[0,1,2,3,5,6,4,13,7,8,9,14,10,11,12,Null,15,16,17,18],' _
	& '"ls":[0,1,2,Null,3,4,5,6],' _
	& '"pk":[0,1,2,3,4,5,6],' _
	& '"ps":[0,1,2,3],' _
	& '"ao":[0,1,2],' _
	& '"ach":[0,1,2,7,3,4,13,14,5,6,Null,8,9,10,11,12],' _
	& '"mch":[0,1,2,3,5,6,7,Null,4,8,9,14,10,11,12,13],' _
	& '"pch":[0,1,2,3,4],' _
	& '"tch":[0,1,2],' _
	& '"p":[],' _
	& '"other":[0,1]' _
& '}'

; default note template
global const $note_template='{' _
	& '"lk":["nedilatovaná, bez hypertrofie, kinetika v normě, normální celková systolická funkce, diastolická funkce v normě", "nedilatovaná, bez hypertrofie, kinetika v normě, normální celková systolická funkce, diastolická porucha relaxace v normě"],' _
	& '"ls":["nedilatovaná", "nedilatovaná"],' _
	& '"pk":["nedilatovaná, normální systolická funkce", "nedilatovaná, normální systolická funkce"],' _
	& '"ps":["nedilatovaná", "nedilatovaná"],' _
	& '"ao":["ascendentní aorta nedilatovaná", "ascendentní aorta nedilatovaná"],' _
	& '"ach":["trojcípá, cípy jemné, bez vady", "trojcípá, fibrózní, bez vady"],' _
	& '"mch":["jemná, bez vady", "fibrózní, stopová regurgitace 1/4"],' _
	& '"pch":["jemná, normální průtok, bez vady", "jemná, normální průtok, stopová regurgitace 1/4"],' _
	& '"tch":["jemná, bez vady", "jemná, stopová regurgitace 1/4"],' _
	& '"p":["bez patologické separace", "bez patologické separace"],' _
	& '"other":["DDŽ nedilatovaná, kolabuje nad 50% s respirací", "DDŽ nedilatovaná, kolabuje nad 50% s respirací"]' _
& '}'

; data template
global const $data_template='{' _
	& '"bsa":null,' _
	& '"weight":null,' _
	& '"height":null,' _
	& '"date":null,' _
	& '"result":null,' _
	& '"group":{' _
		& '"lk":{"label":"Levá komora", "note":null, "id":null},' _
		& '"ls":{"label":"Levá síň", "note":null, "id":null},' _
		& '"pk":{"label":"Pravá komora", "note":null, "id":null},' _
		& '"ps":{"label":"Pravá síň", "note":null, "id":null},' _
		& '"ao":{"label":"Aorta", "note":null, "id":null},' _
		& '"ach":{"label":"Aortální chlopeň", "note":null, "id":null},' _
		& '"mch":{"label":"Mitrální chlopeň", "note":null, "id":null},' _
		& '"pch":{"label":"Pulmonální chlopeň", "note":null, "id":null},' _
		& '"tch":{"label":"Trikuspidální chlopeň", "note":null, "id":null},' _
		& '"p":{"label":"Perikard", "note":null, "id":null},' _
		& '"other":{"label":"Ostatní", "note":null, "id":null}' _
	& '},' _
	& '"data":{' _
		& '"lk":{' _
			& '"LVIDd":{"label":"LVd", "unit":"mm", "value":null, "id":null},' _
			& '"LVIDs"::{"label":"LVs", "unit":"mm", "value":null, "id":null},' _
			& '"IVSd":{"label":"IVS", "unit":"mm", "value":null, "id":null},' _
			& '"LVPWd":{"label":"ZS", "unit":"mm", "value":null, "id":null},' _
			& '"FS":{"label":"FS", "unit":"%", "value":null, "id":null},' _
			& '"LVd index":{"label":"LVd index", "unit":"mm/m²", "value":null, "id":null},' _
			& '"LVs index":{"label":"LVs index", "unit":"mm/m²", "value":null, "id":null},' _
			& '"LVEF % odhad":{"label":"LVEF % odhad", "unit":"%", "value":null, "id":null},' _
			& '"LVEF % Teich":{"label":"LVEF % Teich.", "unit":"%", "value":null, "id":null},' _
			& '"EF Biplane":{"label":"LVEF biplane", "unit":"%", "value":null, "id":null},' _
			& '"LVmass":{"label":"LVmass", "unit":"g", "value":null, "id":null},' _
			& '"LVmass-BSA":{"label":"LVmass-BSA", "unit":"g/m²", "value":null, "id":null},' _
			& '"LVmass-i^2,7":{"label":"LVmass-i^2.7", "unit":"g/m2.7", "value":null, "id":null},' _
			& '"RWT":{"label":"RWT", "unit":"ratio", "value":null, "id":null},' _
			& '"SV-biplane":{"label":"SV-biplane", "unit":"ml", "value":null, "id":null},' _
			& '"LVEDV MOD BP":{"label":"EDV", "unit":"ml", "value":null, "id":null},' _
			& '"EDVi":{"label":"EDVi", "unit":"ml/m²", "value":null, "id":null},' _
			& '"LVESV MOD BP":{"label":"ESV", "unit":"ml", "value":null, "id":null},' _
			& '"ESVi":{"label":"ESVi", "unit":"ml/m²", "value":null, "id":null},' _
			& '"SV MOD A4C":{"label":null, "unit":null, "value":null},' _; calculation
			& '"SV MOD A2C":{"label":null, "unit":null, "value":null}' _; calculation
		& '},' _
		& '"ls":{' _
			& '"LA Diam":{"label":"LA-plax", "unit":"mm", "value":null, "id":null},' _
			& '"LA Minor":{"label":"LA šířka", "unit":"mm", "value":null, "id":null},' _
			& '"LA Major":{"label":"LA délka", "unit":"mm", "value":null, "id":null},' _
			& '"LAV-A4C":{"label":"LAV-1D", "unit":"ml", "value":null, "id":null},' _
			& '"LAVi":{"label":"LAVi-1D", "unit":"ml/m²", "value":null, "id":null},' _
			& '"LAV-2D":{"label":"LAV-2D", "unit":"ml", "value":null, "id":null},' _
			& '"LAVi-2D":{"label":"LAVi-2D", "unit":"ml/m²", "value":null, "id":null},' _
			& '"LAEDV A-L A4C":{"label":null, "unit":null, "value":null},' _; calculation
			& '"LAEDV MOD A4C":{"label":null, "unit":null, "value":null},' _; calculation
			& '"LAEDV A-L A2C":{"label":null, "unit":null, "value":null},' _; calculation
			& '"LAEDV MOD A2C":{"label":null, "unit":null, "value":null}' _; calculation
		& '},' _
		& '"pk":{' _
			& '"RV Major":{"label":"RV-plax", "unit":"mm", "value":null, "id":null},' _
			& '"RVIDd":{"label":"RVD1", "unit":"mm", "value":null, "id":null},' _
			& '"TAPSE":{"label":"TAPSE", "unit":"mm", "value":null, "id":null},' _
			& '"S-RV":{"label":"Sm-RV", "unit":"cm/s", "value":null, "id":null},' _
			& '"FAC%":{"label":"FAC%", "unit":"%", "value":null, "id":null},' _
			& '"EDA":{"label":"EDA", "unit":"cm²", "value":null, "id":null},' _
			& '"ESA":{"label":"ESA", "unit":"cm²", "value":null, "id":null}' _
		& '},' _
		& '"ps":{' _
			& '"RA Minor":{"label":"RA šířka", "unit":"mm", "value":null, "id":null},' _
			& '"RA Major":{"label":"RA délka", "unit":"mm", "value":null, "id":null},' _
			& '"RAV":{"label":"RAV", "unit":"ml", "value":null, "id":null},' _
			& '"RAVi":{"label":"RAVi", "unit":"ml/m²", "value":null, "id":null}' _
		& '},' _
		& '"ao":{' _
			& '"Ao Diam SVals":{"label":"Bulbus", "unit":"mm", "value":null, "id":null},' _
			& '"Ao Diam":{"label":"Asc-Ao(MM)", "unit":"mm", "value":null, "id":null}' _
			& '"Asc-Ao 2D":{"label":"Asc-Ao(2D)", "unit":"mm", "value":null, "id":null}' _
		& '},' _
		& '"ach":{' _
			& '"AV Vmax":{"label":"Vmax", "unit":"m/s", "value":null, "id":null},' _
			& '"AV max/meanPG":{"label":"PG max/mean", "unit":"torr", "value":null, "id":null},' _
			& '"AV VTI":{"label":"Ao-VTI", "unit":"cm", "value":null, "id":null},' _
			& '"LVOT Diam":{"label":"LVOT", "unit":"mm", "value":null, "id":null},' _
			& '"LVOT VTI":{"label":"LVOT-VTI", "unit":"cm", "value":null, "id":null},' _
			& '"AVA":{"label":"AVA", "unit":"cm²", "value":null, "id":null},' _
			& '"AVAi":{"label":"AVAi", "unit":"cm²/m²", "value":null, "id":null},' _
			& '"SV/SVi":{"label":"SV/SVi", "unit":"ml/m²", "value":null, "id":null},' _
			& '"VTI LVOT/Ao":{"label":"VTI LVOT/Ao", "unit":"ratio", "value":null, "id":null},' _
			& '"AR RV":{"label":"AR-RV", "unit":"ml", "value":null, "id":null},' _
			& '"AR ERO":{"label":"AR-ERO", "unit":"cm²", "value":null, "id":null},' _
			& '"AR VTI":{"label":"AR-VTI", "unit":"cm", "value":null, "id":null},' _
			& '"AR Rad":{"label":"PISA radius", "unit":"mm", "value":null, "id":null},' _
			& '"AR-PHT":{"label":"AR-PHT", "unit":"ms", "value":null, "id":null},' _
			& '"AR-SLOPE":{"label":"AR-SLOPE", "unit":"cm/s²", "value":null, "id":null},' _
			& '"AV maxPG":{"label":null, "unit":null, "value":null},' _; calculation
			& '"AV meanPG":{"label":null, "unit":null, "value":null},' _; calculation
			& '"SV":{"label":null, "unit":"ml/m²", "value":null},' _; calculation
			& '"SVi":{"label":null, "unit":"ml/m²", "value":null}' _; calculation
		& '},' _
		& '"mch":{' _
			& '"MV E Vel":{"label":"E", "unit":"cm/s", "value":null, "id":null},' _
			& '"MV A Vel":{"label":"A", "unit":"cm/s", "value":null, "id":null},' _
			& '"MV E/A Ratio":{"label":"E/A", "unit":"ratio", "value":null, "id":null},' _
			& '"MV DecT":{"label":"DecT", "unit":"ms", "value":null, "id":null},' _
			& '"MV max/meanPG":{"label":"PG max/mean", "unit":"torr", "value":null, "id":null},' _
			& '"EmSept":{"label":"EmSept", "unit":"cm/s", "value":null, "id":null},' _
			& '"EmLat":{"label":"EmLat", "unit":"cm/s", "value":null, "id":null},' _
			& '"E/Em":{"label":"E/Em", "unit":"ratio", "value":null, "id":null},' _
			& '"MV PHT":{"label":"MV-PHT", "unit":"ms", "value":null, "id":null},' _
			& '"MVA-PHT":{"label":"MVA-PHT", "unit":"cm²", "value":null, "id":null},' _
			& '"MR RV":{"label":"MR-RV", "unit":"ml", "value":null, "id":null},' _
			& '"MR ERO":{"label":"MR-ERO", "unit":"cm²", "value":null, "id":null},' _
			& '"MR VTI":{"label":"MR-VTI", "unit":"cm", "value":null, "id":null},' _
			& '"MR Rad":{"label":"PISA radius", "unit":"mm", "value":null, "id":null},' _
			& '"MVAi-PHT":{"label":"MVAi-PHT", "unit":"cm²/m²", "value":null, "id":null},' _
			& '"MV maxPG":{"label":null, "unit":null, "value":null},' _; calculation
			& '"MV meanPG":{"label":null, "unit":null, "value":null}' _; calculation
		& '},' _
		& '"pch":{' _
			& '"PV Vmax":{"label":"Vmax", "unit":"m/s", "value":null, "id":null},' _
			& '"PVAcc T":{"label":"ACT", "unit":"ms", "value":null, "id":null},' _
			& '"PV max/meanPG":{"label":"PG max/mean", "unit":"torr", "value":null, "id":null},' _
			& '"PRend PG":{"label":"PGed-reg", "unit":"torr", "value":null, "id":null},' _
			& '"PR max/meanPG":{"label":"PR max/meanPG", "unit":"torr", "value":null, "id":null},' _
			& '"PV maxPG":{"label":null, "unit":null, "value":null},' _; calculation
			& '"PV meanPG":{"label":null, "unit":null, "value":null},' _; calculation
			& '"PR maxPG":{"label":null, "unit":null, "value":null},' _; calculation
			& '"PR meanPG":{"label":null, "unit":null, "value":null}' _; calculation
		& '},' _
		& '"tch":{' _
			& '"TR maxPG":{"label":"TR maxPG", "unit":"torr", "value":null, "id":null},' _
			& '"TR meanPG":{"label":"TR meanPG", "unit":"torr", "value":null, "id":null},' _
			& '"TV max/meanPG":{"label":"PG max/mean", "unit":"torr", "value":null, "id":null},' _
			& '"TV maxPG":{"label":null, "unit":null, "value":null},' _; calculation
			& '"TV meanPG":{"label":null, "unit":null, "value":null}' _; calculation
		& '},' _
		& '"p":{' _
		& '},' _
		& '"other":{' _
			& '"IVC Diam Ins":{"label":"DDŽ insp", "unit":"mm", "value":null, "id":null}' _
			& '"IVC Diam Exp":{"label":"DDŽ exp", "unit":"mm", "value":null, "id":null},' _
		& '}' _
	& '}' _
& '}'

; data dicts
global $history = Json_Decode($data_template)
global $buffer = Json_Decode($data_template)
global $order = Json_Decode($data_template)
global $user = Json_Decode($user_template)
global $note = Json_Decode($note_template)
global $map = Json_Decode($map_template)

; XLS variable
global $excel, $book

; cardio bitmap logo
global const $logo_file_one = '0x424d36c000000000000036000000280000008000000080000000010018000000000000c00000c70e0000c70e00000000000000000000ffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc6c6c67979794444442323232222222020201e' _
& '1e1e212121222222282828484848909090cececee7e7e7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffd7d7d76868682b2b2b00000000000000000000000000000000000000000000' _
& '00000000000000000000000000000000000000000000003838386a6a6ad7d8d8ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffff9a979706040400000000000000000001000008060604010105020205030303010106040404' _
& '0404000000030303040404010101050505040404010101000000000000000000020000949292ffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffff929090110f0f00000002000004020206040407050505030302000000000000000000000000000000000000' _
& '0000000000000000000000000000000000010101030303010101020101070505000000000000050303615f5fffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffe0dede252323000000000000080606050202050303000000000000000000000000414040858585b1b0b0b4b3b3b8b7b7bb' _
& 'bbbbb7b8b8b4b4b4aaaaaa7f7f7f2d2d2d000000000000000000000000030101060404060404010000000000040202858383ffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffff7a78780000000000000b09090604040200000000000000002929298c8d8de5e5e5ffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffdddddd7f7f7f373737000000000000000000090707060404020000000000161414d5d4d4ffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffff434141000000020000050303030101000000000000535151e2e0e0ffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff6a68680806060000000000000503030604040000000000008d8d8dffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffff4947470000000806060604040604040000002e2c2cd4d2d2ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff787676000000000000050303060404030101000000515151ffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffff3838380000000402020402020200000000009f9d9dffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff3634340000000200000705050303030000003030' _
& '30ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& '3b3b3b000000040202080606000000121010dbd9d9ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff9a97970000000000000304040303030000' _
& '00323232ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff858585' _
& '000000020303060505000000232121dfdedeffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffdcdada0000000000000606060606' _
& '06000000575757ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffd8d8d8000000' _
& '020202040404000000010000ecebebffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0000000000000301' _
& '020302010000009e9d9cffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0f0f0f010101' _
& '000000050505000000e9e9e9ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0100000100' _
& '00070505050303000000e4e2e1ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff808080000000040404' _
& '040404000000a6a6a6ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffd7d5d40000' _
& '00020000030100000000373534ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000040404030303' _
& '000000444444ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff8987' _
& '87000000080605060403000000aeacabffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff707070000000020202020202' _
& '000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ff2b2927000000050302000000151313ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000010101030303000000' _
& '818181ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffcac8c7000000020000050302000000a3a2a1ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff9f9f9f000000060606000000000000' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffff3f3d3d000000050303000000302d2cffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff2b2b2b000000020202000000767676' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffd9d7d5000000060404030100000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffd0d0d0000000000000010101040404ffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffff2725250000000705040000008e8d8dffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff9696960000000403030000001f1f1fffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffff6c6b6a000000050303000000676666ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff2a28280000000604040000009b9999ffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffc7c6c40000000604030000001a1817716f6e92908feeecebffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff010000040202070505000000ffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffc0bfbe4542420000000604030402020705040402010000000000000000000402029b9a99ffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc2c1c10000000402020000002c2a2affffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff5351' _
& '500000000000000301000402010301010402020503020907060402020907060000000000000f0d0cd2d1d0ffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff8f8d8d0000000402020000004c4949ffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1412110000' _
& '00030100080606040202000000000000000000000000000000000000050302070503080606000000000000908f8effffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7673730000000503030000007a7979ffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0000000000000503' _
& '01090706000000000000504d4c7d7c7cb1afaebfbfbe9997966d6a69080606000000000000060403010000000000797877ffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff413e3e000000030101000000bab9b9ffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1414140000000a08070402' _
& '01000000343231eae9e8e7e5e4b8b7b6696766595756949392dad8d7fffffe8d8b8a030100000000080604050303000000ccccccffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff121010020000030101000000ffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7474740000000705040604030000' _
& '006c6a6affffff706e6e0000000000000000000000000000000000002f2d2ceeedece2e1e0050302020000040202030101181818ffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000040202060404000000ffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe6e6e60000000000000402010000005b59' _
& '58ffffff0c0a0a0000000604030705040402020b0908040200050302000000000000a6a5a4fffefd000000000000040202000000898989ffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000ffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff717171000000050505010000171514ffff' _
& 'ff161413000000070504070504060404050302050302090706070504080606000000000000dbdad99f9d9c0000000503020000001b1b1bffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc4c3c2d0cececfcdccc7c6c5ffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff161515000000040202000000adaeaca0a0' _
& '9f000000010200040201030100070504040201030100050302060403030100060403000000282625ffffff211f1f000000030303000000bdbdbdffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7e7e7e5e5c5c6765656866645b5959d3d2d1ffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff070606020000020000090a08ffffff2c2d' _
& '2b000000030502050201050302040201050302050302040201040201050302040201030100000000ffffff62605f000000030303000000999999ffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffaaaaaa000000000000000000000000000000282726ffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb1b1b10000000604030000003a3a39ffffff0000' _
& '00030402010100050302050302050302050302050302050302050302050302050301030101000000807e7ddbdad90000000202020000005b5b5bffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff3d3d3d000000070505060403060403080604000000d2d2d2ffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffa1a1a1000000050201000000424241ffffff0000' _
& '000506050303020502010503020503020503020503020503020503020503020402010604030000005e5d5cffffff0000000101010000003d3d3dffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1f1f1f000000050302040201080605030100000000cececeffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffa3a3a3000000040201000000434443ffffff0000' _
& '00020301030502050201040201040201050302050302050302040201050301040201060403000000656463ffffff0000000304040000003e3e3effffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff262626000000040100050302040201040100000000d2d2d2ffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb9b9b90000000402010000002c2e2cffffff0000' _
& '00020301030403060403060403060403040201040201030101060402040202090706010000000000b5b3b2b7b5b4000000020303000000686868ffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff252525000000040100050302050302040100000000d2d2d2ffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0b0a0a000000030000000000ffffff5b5c' _
& '5a000000040403050302050302050302040201050302050302030101070503040202080606000000ffffff484746000000030303000000a0a0a0ffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff262626000000040100050302050302040201000000d2d2d2ffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff121313040202010000000000868685e7e8' _
& 'e6000000000100040201040201050302040201050302010000080605030100070505000000716f6efffffe110f0e040201000000000000bebebeffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff252526000000040100050302050302040201000000d2d2d2ffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff999898000000080605020301000000ffff' _
& 'ff8889870000000000000301000503020604030402010806050301010503010000002e2c2affffff5755540000000705030000001d1d1dffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff262626000000040100050302050302040201000000d2d2d2ffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0d0b0b0000000404030000001e1f' _
& '1dffffff9292900000000000000100000302010605040301010000000000004b4a49ffffffa09f9f000000010000060404000000a0a0a0ffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff282726000000030100050302050302040201000000d2d2d1ffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff8b8c8c0000000404040202020000' _
& '002e2e2ffefefeededed474747000000000000000000000000161616b4b4b5ffffff9a9a9a000000000000060606000000262626ffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff282726000000030100050302050302040201000000d2d2d1ffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff2828280000000606060000' _
& '000000000000007f7f7fffffffffffffffffffffffffffffffffffffc3c3c3333333000000000000050505000000000000ebebebffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff282726000000030100050302050302040201000000d2d2d1ffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff2323230000000404' _
& '040303030000000000000000000f0f0f5252525a5a5a2b2b2b010101000000000000050505090909000000000000bcbcbcffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff2b2a29000000030100050302050302030100000000dddeddffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff3030300000' _
& '00070707060606090909000000000000000000000000000000020202010101050505030303000000040404bababaffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc5c3c212100f020000040201050302050302040201000000656463dddcdb' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7f7f' _
& '7f000000000000000000050505040404040404010101040404000000030303000000000000353535ecececffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffff8d8b8a010000000000000000030100050302050302050302050302040201000000000000' _
& '1d1b1bb6b5b4ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffff7272722e2e2e000000000000000000000000000000000000101010585858d3d3d3ffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffb5b3b212100f000000000000050302060403060403040201050302050302040201060403060403020000' _
& '0000000000003a3a39ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffdbdbdbc9c9c9a5a5a59c9c9cbebebed7d7d7ebebebffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffff6a68680000000000000604040705040200000806060705040402010503020503020402010402010705040a0808' _
& '070504080605000000020202c3c3c3ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffff100e0d000000060404030101060403020000080604040201020000010000000000000000030000050201020000030100' _
& '040100050201040303000000000000737474ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffff0000000000000503020301000503020705050402020402010000000000001111112a2a2a232323000000000000040304050505' _
& '0202020303030301010907060100000000006b6969ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffff0000000000000100000503020604030402010604040806050000000907069c9b99e6e6e6ffffffffffffcececf666666000000000000' _
& '0808080101010403010100000b09070705040000007a7776ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffff0000000000000503030806050301000200000604030100000000007b7979ffffffffffffffffffffffffffffffffffffffffffffffff1f1f1f' _
& '0000000607070403020907050200010806060806040000006b6969ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffff000000000000080605030101040201040201080605000000000000b5b4b3ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& '4848480000000705040200000806050200000907060705040000007e7c7bffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ff242221000000060404060403070504030100080605000000050302bfbdbcffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffff636464000000070503030101050302040201060404050302000000b9b6b5ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff3d3d' _
& '3d000000030100040201040201050303040201000000000000dfdddcffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffff6f6e6e000000040201040202050302040201090707060403000000e0dedeffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff5556540000' _
& '00040201050302060403060403070504000000030201d8d7d6ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffff605f5d0000000200000806040402020503020705040000000c0909ffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff9c9e9b0000000101' _
& '00060403060403060403050302000000000000c2c1c0ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffff4e4c4b000000060403060404070504030101070504000000252525ffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffd0d0cf0000000405040203' _
& '02050302050302050302030000000000c3c2c1ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffff2f2e2e000000070504030102050304040201080606000000838383ffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffff999999ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0000000000000404020505' _
& '03030201050403030201000000c3c2c1ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffff161514000000050403040302060504030202070605000000a6a6a6ffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffff272727000000c7c7c7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff2321200000000705050402010302' _
& '010606060000000000009d9d9dffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffececece5e5e5ffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffff0f1010000000010101040505040404090706000000000000cac8c6ffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffff171717000000858585ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff595a5a0000000503030907050301010604' _
& '04020202000000828282ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffeeeeee131313000000d6d6d6ffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffff020202000000050606040303070506050302000000121010ffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffff1313130000006d6d6dffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7f7f7f0000000503030b09080000000705040504' _
& '04000000686868ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffd0d0d0000000000000000000000000bbbbbbffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffcacaca000000030303040303050301090706040202000000262323ffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffff0d0d0d0000004d4d4dffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffa3a3a30000000000000401010301000b09080200000000' _
& '00414141ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffaaaaaa000000000101000101010102000000000000909090ffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffa5a5a50000000301020401010402010806050a0807000000636160ffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffff080808000000343434ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0303030000000404040604020503020402010000002926' _
& '27ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffa3a3a3000000000000030100050403040302050403000000000000777575' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff727373000000030101090706040202040202010000181615ffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffdcdcdc030303000000232323ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff06060600000004040405030208060500000012100fffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff8a8a8a000000040404060706050201050201050201040201050302070506000000' _
& '605e5effffffffffffffffffffffffffffffffffffffffffffffffffffffffffff6c6b6b0000000c0a0a0604030402020000003a3837ffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffc5c5c50000000000000f0f0fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcdcdcdffffff525252000000010000000000060404ffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffff5d5d5d000000040404000000020201050301050302050302040201060403040202050302' _
& '0000003f3e3dffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff585654000000010000000000727070ffffff969392ffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0202' _
& '024f4f4fffffffffffffffffffffffffffffffa6a6a6000000010101000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000626262ffffff818181000000141110ffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffff464646000000010101030303040404030304050201050302050302040201060403040202030101' _
& '080605000000282727ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff4b4848010000a7a5a5ffffff353332000000949191ffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff5858580000' _
& '00242424ffffffffffffffffffffffffffffff929292000000010101000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1516160000000000001b1b1bffffffd3d2d0ffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffff3d3d3d000000010102060707020203010101020303050201040201050302040201030100060403040201' _
& '0503020502010000001b1b1bffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffbbbab9000000000000000000000000d5d4d2ff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffd9d9d90000000202' _
& '02000000d6d6d6ffffffffffffffffffffffff929292000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff4f4e4e000000060404080606000000888686ffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffff2f2e2c000000050302040201040201050301050302040201070505060403040201070506060403040201060403' _
& '040201040201050302000000151312ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffd5d5d5000000000000030303000000151515fb' _
& 'fcfcffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff4d4d4d0000001313' _
& '13000000bebebeffffffffffffffffffffffff7f7f7f000000474747000000c6c6c6ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffa09e9e000000060404050303000000424040ffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffff323030000000050301060404060403040201050302050201040201050303080605060403050303050302050302050302' _
& '0503020503020200000b09080000001b1919ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff93939300000003030300000000000056' _
& '5656ffffffffffffffffffdedededcdcdcdddddde3e3e3ffffffffffffffffffffffffffffffffffffffffffffffffebebebf1f1f1ebebeb000000090909c5c5' _
& 'c50000006b6b6bffffffffffffffffffffffff5f5f5f0000009f9f9f000000787878ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000030101000000100d0dffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffff454444000000070504050303050303040201050302060403040201020000000000000000000000000000000000040201040201' _
& '0604030402010604030503030705040000001c1a18ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff4d4d4d00000007070700000000' _
& '0000040404000000000000000000000000000000000000393939c1c1c1ffffffffffffffffffffffffdcdcdc2c2c2c0101010000000000000000007e7e7effff' _
& 'ff0000001f1f1fffffffffffffffffffffffff3e3e3e000000d3d3d30000001212126868685e5e5e5a5a5a5b5b5b7a7a7affffffffffffffffffffffffffffff' _
& 'ffffffffffff6666664646462f2f2f2a2a2a2020201616160c0c0c0c0c0c090909202020333333d6d6d6ffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffff424040000000040202040202000000d6d5d5ffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffff4c4c4d000000060403060403060404060402040201060403060403030100000000ffffffffffffffffffffffff0f0d0c000000050202' _
& '060403060403050302070503030100070505000000212120ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff12121200000004040400' _
& '00000000006a6a6a6868686464647070706f6f6f6464640000000000002d2d2de9e9e9ffffff9898980000000000003a3a3a6666665d5d5d8a8a8affffffffff' _
& 'ff0000000c0c0cffffffffffffffffffffffff191919101010ffffff9090900000000000000000000b0b0b080808000000080808ffffffffffffffffffffffff' _
& 'ffffff0b0b0b0000000b0b0b3939393737373535353434343333332929291f1f1f1c1c1c333333d9d9d9ffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffc2bfbf000000040202080606000000807e7effffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffff767676000000050404030100070504080605040201060403050302060403020000000000ffffffffffffffffffffffff080605000000040302' _
& '0504020504020402010402020301010604040503020000004e4e4effffffffffffffffffffffffffffffffffffffffffffffffffffffd0d0d000000002020204' _
& '04040000007d7d7dffffffffffffffffffffffffffffffffffff505050000000000000595959000000060606dfdfdfffffffffffffffffffffffffffffffffff' _
& 'ff222222000000d4d4d4ffffffffffffffffff000000161616ffffffffffffffffffffffffffffffffffffffffffcbcbcb000000232323ffffffffffffffffff' _
& '3a3a3a0000006b6b6bffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffff1e1c1c000000050303000000131111ffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffb1b1b1000000030404030202040202030101030100080605030101050301050302020000000000ffffffffffffffffffffffff090a08000000030402' _
& '020401020401030202050201060403040201030100050606000000878787ffffffffffffffffffffffffffffffffffffffffffffffffffffff5e5e5e00000002' _
& '0202010101000000ffffffffffffffffffffffffffffffffffffffffffb5b5b5000000000000060606ffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ff6f6f6f000000a6a6a6ffffffffffffffffff000000262626ffffffffffffffffffffffffffffffffffffffffffffffffadadad000000282828ffffff343434' _
& '000000565656ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffff818080000000030101080606000000dbdadaffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffd9d9d9000000020202020303030202060303080605020000090706040202040201040201020000000000ffffffffffffffffffffffff040503000000030402' _
& '030402030402040301050302040201040201040201040404030303000000bebebeffffffffffffffffffffffffffffffffffffffffffffffffffffff02020200' _
& '0000060606000000404040ffffffffffffffffffffffffffffffffffffffffffffffff797979ffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffababab000000848484ffffffffffffffffff000000333333ffffffffffffffffffffffffffffffffffffffffffffffffffffff6b6b6b000000000000000000' _
& '6a6a6affffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffff000000030101070505000000646262fffffffffffffffffffffffffffffffffffffffffffffffffffffff9f9' _
& 'f91d1d1d000000070707040404040303060402030100080605000000000000000000000000000000000000ffffffffffffffffffffffff000000000000000000' _
& '000000000000000000040100050302060403050302030304050505000000040404e5e5e5ffffffffffffffffffffffffffffffffffffffffffffffffb4b4b400' _
& '0000010101020202000000c5c5c5ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffc1c1c1000000404040fffffffffffffafafa000000343434ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7676762a2a2ab6b6b6' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffff848484000000050303030101020000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff5d5d' _
& '5d0000000708080606060101020100000907060402010100001d1b1ab6b6b5c2c1c1bfbfbebfbebebbbab9ffffffffffffffffffffffffbfc0bebebebdbfbfbe' _
& 'bfbfbecdcdcc424140000000050302060403060402050404040404040404000000393939ffffffffffffffffffffffffffffffffffffffffffffffffffffff2b' _
& '2b2b0000000605060000003e3e3effffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffe9e9e9101010000000ffffffffffffdddddd000000444444ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffff101010000000030202000000818080ffffffffffffffffffffffffffffffffffffffffffffffffffffffc8c9c90000' _
& '000100000605040302010403030706050200000705040000001a1818ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffff5b5a59000000050302050302050302030101040303030202030201000000a1a1a1ffffffffffffffffffffffffffffffffffffffffffffffffd2' _
& 'd2d1000000010201020302000000efefeeffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffff292929000000ffffffffffffb2b2b20000006a6a6affffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffb4b4b4000000090909000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0e0e0e0000' _
& '000503010402010503010402010604030402020301000100001b1918ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffff595655000000050302040201040201050302050201050301050201010000000000ffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffff3f403e000000070806000000656664ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffff3a3a3a000000c9c9c9ffffff8e8e8e0000008c8c8cffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffff3737370000000000000000006f6f6fffffffffffffffffffffffffffffffffffffffffffffffffffffffb6b6b60000000505' _
& '05050201050302050302040201050302030100070504000000211f1effffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffff5e5c5b000000050302050302050302050302050302050302050201040302000000848484ffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffafafae000000030402000000121311ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffff7f7f7f0000007e7e7effffff6f6f6f000000aeaeaeffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffff0f0f0f000000020202000000c5c5c5ffffffffffffffffffffffffffffffffffffffffffffffffffffff3d3d3d0000000302' _
& '020502010503020503020503010402010907060402020503020b09085e5c5b605e5d5e5c5b5f5c5b555352ffffffffffffffffffffffff5553525c5a595f5d5c' _
& '5f5d5c65636222201f000000050302050302050302050302050302050302050302040201000000191919ffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffff000000010200030401000000dddedcffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffc7c7c70000005f5f5fffffff5d5d5d000000d2d2d2ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffaaaaaa000000040404000000262626ffffffffffffffffffffffffffffffffffffffffffffffffffffffdddddd0000000303030403' _
& '03050201050302050302040201050303030100040201090706020000000000000000000000000000000000ffffffffffffffffffffffff000000000000000000' _
& '000000000000000000030100050302050302050302050302050302050302050301040302000000000000cacacaffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffff676866000000050604000000555754ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffededed000000363636ffffff585858000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffff646464000000030303000000717171ffffffffffffffffffffffffffffffffffffffffffffffffffffff8b8b8b0000000404040302' _
& '02050301050302050302040201060403040201050302040201040201060403050302050302040201000000ffffffffffffffffffffffff090706000000050302' _
& '0604030503020402010402010503020503020503020503020503020503020503010403020202020000004c4c4cffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffa5a6a4000000040502000000313231ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffff090909070707ffffff4b4b4b000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffff121212000000040404000000c7c7c7ffffffffffffffffffffffffffffffffffffffffffffffffffffff3535350000000000000303' _
& '02050201050302050302050302040201050302040201050302040201060403040201040201040201000000ffffffffffffffffffffffff060403000000040201' _
& '0604030402010503020503020503020503020503020503020503020503020503020503010102020000002b2b2bffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffd0d1cf0405030001000000001c1d1bffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffff434343000000e1e1e1383838000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffff000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff2929290000000505050302' _
& '03050301050302050302050302050302050302050302050302040201060403040201040201040201000000ffffffffffffffffffffffff080504000000050302' _
& '060403040201050302050302050302050302050302050302050302050302050302030301010101010101181818ffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffff141513000000000100020301d2d2d1ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffff656565000000c0c0c02525250a0a0affffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffff000000010101010101000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1f1f1f0000000505050202' _
& '020503010503020503020503020503020503020503020503020402010604030402010402010503020000007b79797f7d7c7775748f8d8d090706010000040201' _
& '0604030402010503020503020503020503020503020503020503020503020503020402010505060000000c0c0ce3e3e3ffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffff1d1e1c000000000200000000c4c5c3ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffff8a8a8a0000006b6b6b1e1e1e272727ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffff000000000000000000020202ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff2424240000000000000403' _
& '03050201050302050302050302050302050302050302050302040201060403050302040201060403030100000000000000000000000000030100030100040201' _
& '060403040201050302050302050302050302050302050302050302050302050302040201030303000000131313e7e7e7ffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffff1d1e1c000000030402000000c2c2c1ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffd3d3d3000000202020070707434343ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffff000000000000010101000000dfdfdfffffffffffffffffffffffffffffffffffffffffffffffffffffff2d2b2a0000000402010402' _
& '01050302050302050302050302050302050302050302050302040201060403060404060403050302030101050301010000000000060404080605060403060403' _
& '060403040201050302050302050302050302050302050302050302050302050302050201050505000000242424ffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffff191616000000050202000000c6c4c3ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffff000000000000000000626262ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffff000000000000070707000000d7d7d7ffffffffffffffffffffffffffffffffffffffffffffffffffffffa19f9e0000000503020705' _
& '040402010503020503020503020503020503020503020503020402010402020705040402010604030a0807000000242221312f2f000000040202050302050302' _
& '050302040201050302050302050302050302050302050302050302050302050301040202010202000000656565ffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffd9d8d70705040200000100000a0808dcdcdbffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffff0000000000000000006c6c6cffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffff0f0f0f0000000303030000008f8f8fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0604030100000402' _
& '01050302050302050302050302050302050302050302050302040201060403040201090706050302020000000000f0efeeffffff121010000000040201050302' _
& '040201050302040201050302050302050302050302050302050302050302050201040301040404000000ffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffa9a7a6000000030100010000272524ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffff4a4a4a000000000000727272ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffff6c6c6c0000000000000000002c2c2cffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffadaaa90000000301' _
& '00040201050302050301040201050302040201050201050301050302040100080605060404040201000000bcbab9ffffffffffffe1dfde000000000000030100' _
& '040201060403040201050301050302050302050302050302050201050201050201040201000000898989ffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffff4a48470000000402010000003e3c3cffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffff9696960000000000008c8c8cffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffbababa000000020202010101000000ccccccffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7f7c7b0000' _
& '00010000040201050302050302030201060504040302040202040202040302070506000000000000a9a8a7ffffffffffffffffffffffffcdcbcb000000000000' _
& '060404040201040202040302020100030201030201030201040302050303020000000000515151ffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffff000000040201040202000000bbb9b8ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffadadad000000000000acacacffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffff202020020202040404000000343434ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff9f9d' _
& '9c030100000000020000070403020302020303020202030303020203000000000000101010c9c9c9ffffffffffffffffffffffffffffffffffffd9d7d7242223' _
& '000000030101040303030404030303030303030303050505070708000000000000858585ffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffff585554000000050303010000080605ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffdcdcdc0a0a0a000000cfcfcfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffff868686000000020202040404000000a9a9a9ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffff737171000000000000000000000000000000000000000000040404868686ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& '959393181616000000000000000000000000000000000000000000606060dfdfdfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb7' _
& 'b7b6000000080605050302000000737271ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffff121212000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffff161616000000060606000000000000ccccccffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffeeeceb9998977a7a7a767676a0a0a0ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffb2b2b27a7a7a757575959595dadadaffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffd0d0d000' _
& '0000030100050302000000040201ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffcdcdcd7d7d7dffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffc2c2c2000000010101020202000000111111d2d2d2ffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffececec01010100' _
& '0000080605040201000000b5b3b2ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffff6969690000000808080202020000000d0d0ddcdcdcffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffd7d7d705050500000002' _
& '0202040304000000706f6fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffff555555000000070707010101000000000000a8a8a8ffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffd0d0d000000000000004040407' _
& '0707000000525252ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffff5353530000000000000606060000000000004d4d4dffffffebebebffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffaaaaaa212121000000ffffff35353500000006060600' _
& '0000404040ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffff4c4c4c000000010101070707000000858585c4c4c40d0d0d484848e2e2e2ffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc6c6c62525250000000000000000009b9b9bc0c0c000000000000058' _
& '5858ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7e7e7e0000000000000d0d0dffffff3c3c3c0000000000000000003f3f3fc7c7' _
& 'c7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7d7d7d000000000000060606020202000000252525ffffff0000009c9c9cff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffd1d1d1000000717171ffffff0000000101010101010202020000000000' _
& '00d0d0d0ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff121212000000070707020202030303020202000000aaaaaaffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe6e6e6ffffff3535350000000505050303030505050303030000' _
& '00a4a4a4ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1e1e1e0000000202020505050000000000002c2c2ce4e4e4ffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff9494940000000000000000000101010101010000' _
& '00afafafffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff9d9d9d000000000000000000151515b2b2b2ffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff8080802929290000000000006161' _
& '61ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffd9d9d95f5f5fccccccffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffd7d7d7dededeffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff'

global const $logo_file_two = 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff'

; QR code bitmap
global const $qr_file = '0x424df2b200000000000036000000280000007b0000007b0000000100180000000000bcb20000c40e0000c40e00000000000000000000ffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffff000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000ffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffff' _
& '000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ff' _
& 'ffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffff0000' _
& '00000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff0000000000' _
& '00000000000000000000000000ffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffff000000000000000000000000' _
& '000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffff00000000' _
& '0000000000000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff0000000000000000000000000000000000' _
& '00ffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000' _
& '000000000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffff00000000000000000000000000000000' _
& '0000000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& '000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00' _
& '0000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffffff' _
& 'ffffffffffffff000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff00000000000000000000' _
& '0000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff0000' _
& '00000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000' _
& '000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff00000000000000000000000000000000000000000000' _
& '0000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000ffff' _
& 'ffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff00000000000000000000000000000000000000000000' _
& '0000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff0000000000000000000000000000' _
& '00000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffff' _
& 'ffffffffffffffffffffffff000000000000000000ffffffffffffffffff00000000000000000000000000000000000000000000000000000000000000000000' _
& '0000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffff' _
& 'ffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000' _
& '000000ffffffffffffffffff000000000000000000ffffffffffffffffff00000000000000000000000000000000000000000000000000000000000000000000' _
& '0000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff' _
& '000000000000000000ffffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffff0000000000000000' _
& '00ffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff' _
& '000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffff' _
& 'ffffffffffffff000000000000000000000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff000000' _
& '000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff0000' _
& '00000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000000000' _
& '000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffff0000000000' _
& '00000000000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffff' _
& 'ffffff000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff0000000000000000000000000000' _
& '00000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000000000000000000000000000000000' _
& '000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00000000000000' _
& '0000000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffff0000000000000000000000000000000000' _
& '00ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000' _
& '000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00' _
& '0000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff0000000000000000000000000000000000000000000000000000' _
& '00ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff000000000000000000ff' _
& 'ffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff0000000000000000000000' _
& '00000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000' _
& '000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffff' _
& 'ffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffff0000' _
& '00000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff00000000' _
& '0000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff0000000000000000000000000000000000000000000000' _
& '00000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000000000000000' _
& '000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffff00000000' _
& '0000000000ffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffff' _
& 'ffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffff000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffff' _
& 'ffff000000000000000000000000000000000000ffffffffffffffffff0000000000000000000000000000000000000000000000000000000000000000000000' _
& '00ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffff' _
& 'ffff000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffff' _
& 'ff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000' _
& '000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff000000000000000000000000000000000000ff' _
& 'ffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff0000000000000000000000000000000000000000' _
& '00000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff00000000000000000000' _
& '0000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000ffffff' _
& 'ffffffffffff000000000000000000000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff00000000' _
& '0000000000000000000000000000ffffffffffffffffffffffffffffffffffff0000000000000000000000000000000000000000000000000000000000000000' _
& '00000000000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffff000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff00000000000000000000000000000000000000000000' _
& '0000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000' _
& '000000000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff00000000000000000000000000000000' _
& '0000ffffffffffffffffffffffffffffffffffff0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000' _
& '00ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000ffffffffffff' _
& 'ffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffff000000000000000000ffffffffffffffffffffffffffffffffffff0000000000000000000000000000000000000000000000000000000000000000000000' _
& '00ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff00' _
& '0000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffff' _
& '000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ff' _
& 'ffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffff0000' _
& '00000000000000ffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffff000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff00000000000000000000000000' _
& '0000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffff' _
& 'ffffffffff000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffff' _
& 'ffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000' _
& '000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff0000000000000000' _
& '00ffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000' _
& '000000000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffff' _
& 'ff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffff' _
& '000000000000000000ffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ff' _
& 'ffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffffff' _
& 'ffffffffffffff000000ffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000' _
& '000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff0000000000000000000000' _
& '00000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffff' _
& 'ffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff00000000' _
& '0000000000000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff000000ffff' _
& 'ffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000' _
& '000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00000000' _
& '0000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff0000000000000000000000000000000000000000000000' _
& '00000000000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000' _
& '000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff00000000000000000000000000000000' _
& '0000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffff' _
& 'ffffffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff' _
& '000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000ff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& '000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff00' _
& '0000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff0000' _
& '00000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000' _
& '000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff00000000000000000000000000' _
& '0000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff0000000000000000000000000000' _
& '00000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0000000000000000000000000000' _
& '00000000ffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000' _
& '000000ffffffffffffffffff000000000000000000ffffffffffffffffff00000000000000000000000000000000000000000000000000000000000000000000' _
& '0000000000000000000000000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff0000000000000000' _
& '00ffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000' _
& '000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff00' _
& '0000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffff' _
& 'ffffffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffff' _
& '000000000000000000ffffffffffffffffff00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000' _
& '0000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffff' _
& 'ffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffffff' _
& 'ffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff0000' _
& '00000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffff' _
& 'ffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffffffff' _
& 'ffffffffff000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff0000000000' _
& '00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffff' _
& 'ffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffff00000000' _
& '0000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff0000000000' _
& '00000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff000000000000' _
& '000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00000000000000' _
& '0000000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff0000000000000000' _
& '00ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff0000000000000000000000000000000000' _
& '00000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ff' _
& 'ffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff0000' _
& '00000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000000000000000000000000000000000000000ffff' _
& 'ffffffffffffff000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff00000000' _
& '0000000000000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff0000000000000000000000000000' _
& '00000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffff000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff00000000' _
& '0000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000' _
& '000000000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff00000000000000000000000000000000' _
& '0000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000ffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff00000000000000000000000000000000' _
& '0000000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ff000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000000000000000000000' _
& 'ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffff' _
& 'ffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000ff' _
& 'ffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff0000000000000000000000' _
& '00000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffffffff' _
& 'ffffffffffff000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff00000000' _
& '0000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0000000000' _
& '00000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000' _
& '000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff00000000' _
& '0000000000ffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff0000000000' _
& '00000000ffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffff' _
& 'ffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffffff' _
& 'ffff000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000' _
& '000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffff' _
& 'ffff000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffff' _
& 'ffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000' _
& 'ffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff00000000000000000000' _
& '0000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffff000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000' _
& '000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff00000000000000000000' _
& '0000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff0000' _
& '00000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffff' _
& 'ffffffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff00000000000000000000000000000000000000000000' _
& '0000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000ffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000' _
& '000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffff' _
& 'ffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffff' _
& 'ffffffffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000' _
& '000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff00000000000000' _
& '0000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff' _
& '000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff00' _
& '0000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffff' _
& '000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff0000' _
& '00000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffff' _
& 'ffffffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff00000000000000000000000000' _
& '0000000000ffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffff' _
& 'ffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000' _
& '000000000000ffffffffffffffffff00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000' _
& '0000000000ffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff0000000000' _
& '00000000ffffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000' _
& '000000000000000000000000ffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff0000000000' _
& '00000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffff' _
& 'ffffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffff' _
& 'ffff000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffff' _
& 'ff000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000000000000000000000' _
& 'ffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff00' _
& '0000ffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffff' _
& 'ff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000' _
& '000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffff00000000000000000000' _
& '0000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff0000000000000000000000' _
& '00000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff000000' _
& '000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffff' _
& 'ffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff0000000000000000000000' _
& '00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffff' _
& 'ffffffffffff000000000000000000ffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffff' _
& 'ffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffff00000000' _
& '0000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff0000000000000000000000000000000000000000000000' _
& '00000000000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff000000000000' _
& '000000ffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff00000000000000' _
& '0000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffff' _
& 'ffff000000000000000000ffffffffffffffffffffffffffffffffffff0000000000000000000000000000000000000000000000000000000000000000000000' _
& '00000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff' _
& '000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff00000000000000000000000000000000000000' _
& '0000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0000' _
& '00000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ff' _
& 'ffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000ffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff0000000000' _
& '00000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffff' _
& 'ffffff000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff00000000' _
& '0000000000ffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000' _
& '000000000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffff' _
& 'ff000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000ffffffffffff' _
& 'ffffffffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffff' _
& 'ffffffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000' _
& '000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00' _
& '0000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffff' _
& 'ffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffff' _
& '000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000ff' _
& 'ffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000000000' _
& '000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff00000000000000000000000000000000000000000000' _
& '0000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0000000000000000000000000000' _
& '00000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffff000000000000000000000000' _
& '000000000000ffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffff' _
& 'ffffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffff' _
& 'ffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffff' _
& 'ffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff00000000000000' _
& '0000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000' _
& 'ffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffff000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff' _
& '000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffff' _
& 'ffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffff' _
& 'ffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff00000000' _
& '0000000000000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000ffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffff' _
& 'ffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffff' _
& 'ffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff00000000000000000000000000000000' _
& '0000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff0000000000000000' _
& '00ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000' _
& 'ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffff' _
& 'ffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffff0000000000000000' _
& '00ffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00' _
& '0000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff0000' _
& '00000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffff' _
& 'ffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffff00000000000000000000000000000000000000000000' _
& '0000000000ffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffff' _
& 'ffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffff' _
& 'ffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffff' _
& 'ffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff000000000000' _
& '000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffff' _
& 'ffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff0000000000' _
& '00000000000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffff' _
& 'ffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff0000000000000000' _
& '00ffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff000000000000000000000000000000000000' _
& '000000000000000000ffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff00' _
& '0000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff0000000000000000' _
& '00000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff' _
& '000000000000000000ffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ff' _
& 'ffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffff000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffff' _
& 'ffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffff' _
& 'ffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff00000000' _
& '0000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff0000000000' _
& '00000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000' _
& '000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff0000000000' _
& '00000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000' _
& '000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff00000000000000000000000000000000' _
& '0000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffff' _
& 'ff000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffff' _
& 'ff000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff' _
& '000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000000000000000000000ff' _
& 'ffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffff' _
& 'ffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffff' _
& 'ffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00' _
& '0000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff0000000000000000000000' _
& '00000000000000000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff000000000000000000000000' _
& '000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff00000000' _
& '0000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffff' _
& 'ffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffff' _
& 'ffffff000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00000000000000000000000000' _
& '0000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff0000000000000000000000000000000000000000000000' _
& '00000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff000000000000000000000000000000000000000000000000' _
& '000000000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff00000000000000000000000000000000' _
& '0000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff0000000000000000' _
& '00ffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff000000ffffffffffff' _
& 'ffffffffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff00000000000000' _
& '0000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff0000000000000000' _
& '00ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff00000000000000000000' _
& '0000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffff' _
& 'ffffffffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffff' _
& '000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffff' _
& 'ffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000' _
& '000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff0000000000' _
& '00000000000000000000000000ffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffff' _
& 'ffffffffffff000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff00000000' _
& '0000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffff' _
& 'ffffff000000000000000000000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff0000000000000000000000000000000000' _
& '00ffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffff00000000000000000000000000000000' _
& '0000000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff0000000000000000' _
& '00ffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffff000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& '000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000000000000000000000000000000000000000ff' _
& 'ffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffff' _
& 'ffffffffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000ffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000' _
& '000000000000000000000000000000ffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffff00000000' _
& '0000000000000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff0000000000' _
& '00000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000' _
& '000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffff' _
& 'ffffffff000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00000000000000000000000000000000000000000000000000' _
& '0000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff0000000000000000' _
& '00000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff000000000000000000000000000000000000' _
& '000000000000000000ffffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffff00' _
& '0000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffff0000000000000000' _
& '00000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffff00' _
& '0000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffff' _
& 'ffffffffffffff000000000000000000000000000000000000ffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffff' _
& 'ffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffff0000000000000000000000000000000000000000' _
& '00000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffff' _
& 'ffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff0000000000' _
& '00000000000000000000000000ffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000' _
& '000000000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffff000000000000000000ffffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffff' _
& 'ffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff0000000000000000000000000000000000000000000000000000' _
& '00000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff00' _
& '0000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff0000000000000000' _
& '00ffffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff00' _
& '0000000000000000ffffffffffffffffffffffffffffffffffff0000000000000000000000000000000000000000000000000000000000000000000000000000' _
& '00000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffff' _
& 'ffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff0000' _
& '00000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000' _
& '000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffff' _
& 'ffffffffffffffffffffffffffff0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000' _
& '00000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0000000000' _
& '00000000000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff000000000000000000000000000000' _
& '000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffff000000000000000000ffffffffffffffffff0000000000000000000000000000000000000000000000000000000000000000000000' _
& '00ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffff' _
& '000000000000000000ffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0000000000000000000000000000000000' _
& '00ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff' _
& '000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00' _
& '0000000000000000ffffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffff0000' _
& '00000000000000ffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffff' _
& 'ffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff0000' _
& '00000000000000000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffff' _
& 'ffffffffff000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffff' _
& 'ffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffff' _
& 'ffffff000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff00000000000000000000000000' _
& '0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffff0000000000' _
& '00000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000000000000000' _
& '000000ffffffffffffffffff00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000' _
& '0000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffff' _
& 'ffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000ffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff00000000000000000000000000000000000000000000000000' _
& '0000000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffff' _
& 'ffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff' _
& '000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff0000' _
& '00000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffff000000000000000000ffffffffffffffffff00000000000000000000000000000000000000000000000000000000000000000000000000' _
& '0000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff0000' _
& '00000000000000ffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff000000000000000000000000' _
& '000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff0000000000000000000000000000' _
& '00000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000' _
& '000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffff' _
& 'ffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffff' _
& 'ffff000000000000000000000000000000000000ffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffff' _
& 'ffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000' _
& 'ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff00000000000000000000' _
& '0000000000000000ffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffff000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff' _
& '000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff000000' _
& '000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffff' _
& 'ffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000ffff' _
& 'ffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffff' _
& 'ffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0000000000000000000000000000' _
& '00000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000' _
& '000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff00000000000000000000000000000000' _
& '0000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffff' _
& 'ffffffff000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff000000000000' _
& '000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0000000000000000000000000000000000000000000000000000' _
& '00000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff' _
& '000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000ff' _
& 'ffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffff0000000000000000' _
& '00000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff' _
& '000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000ffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000000000' _
& '000000000000ffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffff00000000' _
& '0000000000ffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000' _
& '000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffff' _
& 'ffffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff0000000000000000000000000000' _
& '00000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffff' _
& 'ffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff00000000000000' _
& '0000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffff' _
& 'ffffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00' _
& '0000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000' _
& '000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000000000000000000000ff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff0000' _
& '00000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffff' _
& 'ffffffffffffffff0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000' _
& '00000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffff' _
& 'ffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff00000000' _
& '0000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffff' _
& 'ffffffff000000000000000000ffffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000' _
& '000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffff00000000' _
& '0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffffffffff' _
& 'ffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000' _
& '000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffff' _
& 'ffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff0000000000000000' _
& '00ffffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000' _
& '000000000000000000ffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffff00000000000000000000000000000000' _
& '0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffff0000000000000000' _
& '00ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff' _
& '000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ff' _
& 'ffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff0000' _
& '00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffffff' _
& 'ffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000' _
& '000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff00000000' _
& '0000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffff' _
& 'ffffff000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffff' _
& 'ffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff00000000000000000000000000000000' _
& '0000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000ffffffffffff' _
& 'ffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffff000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff000000000000000000' _
& 'ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000000000000000000000000000000000000000ff' _
& 'ffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffff' _
& '000000000000000000ffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ff' _
& 'ffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000' _
& '000000000000ffffffffffffffffffffffffffffffffffff00000000000000000000000000000000000000000000000000000000000000000000000000000000' _
& '0000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffff' _
& 'ffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffff' _
& 'ffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff00000000' _
& '0000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff0000000000' _
& '00000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffff' _
& 'ffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffff' _
& 'ffff000000000000000000ffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffff0000000000000000' _
& '00ffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff000000000000' _
& '000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff00000000000000000000000000000000' _
& '0000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffff' _
& 'ffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff' _
& '000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ff' _
& 'ffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffff' _
& 'ffffffffffffff000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000000000000000000000' _
& '000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff00' _
& '0000000000000000000000000000000000000000000000000000ffffffffffffffffff0000000000000000000000000000000000000000000000000000000000' _
& '00000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000' _
& '000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff00000000' _
& '0000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000ffff' _
& 'ffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffff' _
& 'ffffffffffff000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff00000000000000000000000000' _
& '0000000000000000000000000000ffffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000ffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000000000000000' _
& '000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff00000000000000000000000000000000' _
& '0000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffff' _
& 'ffffffff000000000000000000ffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000' _
& '000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff00000000000000000000000000000000000000000000000000' _
& '0000ffffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000000000000000000000000000000000000000ff' _
& 'ffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffff0000000000000000' _
& '00ffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff' _
& '000000000000000000ffffffffffffffffffffffffffffffffffff00000000000000000000000000000000000000000000000000000000000000000000000000' _
& '0000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff0000' _
& '00000000000000000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffff' _
& 'ffffffffffff000000000000000000ffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffff00000000' _
& '0000000000ffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff0000' _
& '00000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffff' _
& 'ffffffffffffffffffffffffffffff00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000' _
& '0000000000ffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff0000000000000000000000000000' _
& '00000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000' _
& '000000ffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffff' _
& 'ffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff0000000000000000000000000000' _
& '00000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffff' _
& 'ffffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffff' _
& 'ffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffff' _
& 'ff000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff' _
& '000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff00' _
& '0000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000ff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffff' _
& 'ffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffff' _
& 'ffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0000' _
& '00000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffff' _
& 'ffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffff00000000' _
& '0000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffff000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff0000000000000000' _
& '00ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& '000000000000000000ffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffff00000000000000000000000000000000' _
& '0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffff0000000000000000' _
& '00000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff' _
& 'ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff00' _
& '0000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff0000' _
& '00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffffff' _
& 'ffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffff00000000000000000000000000000000000000000000000000000000' _
& '0000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000' _
& '000000000000000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffff' _
& 'ffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff0000000000000000000000000000' _
& '00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffff' _
& 'ffffff000000ffffffffffffffffffffffffffffffffffff00000000000000000000000000000000000000000000000000000000000000000000000000000000' _
& '0000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000000000000000' _
& '000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff00000000000000' _
& '0000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff0000000000000000000000000000000000000000000000000000' _
& '00000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff000000ffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffff000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000ffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000'

; -------------------------------------------------------------------------------------------
; CONTROL
; -------------------------------------------------------------------------------------------

; check one instance
if UBound(ProcessList(@ScriptName)) > 2 then
	MsgBox(48, 'S70 Echo ' & $VERSION, 'Program byl již spuštěn.')
	exit
endif

; logging
$log = FileOpen($log_file, 1)
if @error then
	MsgBox(48, 'S70 Echo ' & $VERSION, 'System je připojen pouze pro čtení.')
	exit
endif

; cmdline
if UBound($cmdline) < 5 then; minimum  CNT(1) + IDUZI(1) + RC(1) + NAME(2) + H(1) + W(1)
	MsgBox(48, 'S70 Echo ' & $VERSION, 'Načtení základních údajů pacienta z Medicus selhalo.')
	exit
endif

; -------------------------------------------------------------------------------------------
; INIT
; -------------------------------------------------------------------------------------------

; logging
logger('Program spuštěn: ' & @YEAR & '/' & @MON & '/' & @MDAY & ' ' & @HOUR & ':' & @MIN & ':' & @SEC & ' [' & $cmdline[2] & ']')

; read configuration
if FileExists($config_file) then
	read_config_file($config_file)
	if @error then logger('Načtení konfiguračního souboru selhalo.')
Else
	$c = FileOpen($config_file, 2 + 256); UTF8 / NOBOM overwrite
	FileWrite($c, 'export=' & @CRLF & 'archive=' & @CRLF & 'history=')
	FileClose($c)
endif

; update history path
$history_path = $archive_path & '\' & 'history'

; create archive / history directory
DirCreate($archive_path)
DirCreate($history_path & '\' & $cmdline[2])

; archive file full path
global $archive_file = $archive_path & '\' & $cmdline[2] & '.dat'

; export  file full path
global $export_file = get_export_file($export_path, $cmdline[2])
if @error or not $export_file then logger('Export: Soubor exportu nebyl nalezen. ' & $cmdline[2])

; update data buffer from export
if FileExists($export_file) then
	$parse = export_parse($export_file)
	if @error then
		FileMove($export_file, $export_file & '.err', 1); overwrite
		logger('Export: Nepodařilo se načíst export. ' & $cmdline[2])
	else
		FileMove($export_file, $export_file & '.old', 1); overwrite
		logger('Export: Soubor načten.')
	endif
endif

; update history buffer from archive
if FileExists($archive_file) then
	$history = Json_Decode(FileRead($archive_file))
	if @error then logger('Historie: Nepodařilo se načíst historii. ' & $cmdline[2] & '.dat')
endif

; update note from history
for $group in Json_ObjGet($history, '.group')
	Json_Put($buffer, '.group.' & $group & '.note', Json_ObjGet($history, '.group.' & $group & '.note'), True)
next

; update height & weight if not export
if UBound($cmdline) = 7  Then
		if Json_ObjGet($buffer, '.height') = Null then Json_Put($buffer, '.height', Number($cmdline[5]), True)
		if Json_ObjGet($buffer, '.weight') = Null then Json_Put($buffer, '.weight', Number($cmdline[6]), True)
endif

; update result from history or template
Json_Put($buffer, '.result', Json_ObjGet($history, '.result'), True)
if Json_ObjGet($buffer, '.result') = Null then
	if fifty($cmdline[2]) then
		Json_Put($buffer, '.result', $result_template[1], True)
	else
		Json_Put($buffer, '.result', $result_template[0], True)
	endif
endif

; update note on default
for $group in Json_ObjGet($history, '.group')
	if Json_ObjGet($buffer, '.group.' & $group & '.note') = Null then
		if fifty($cmdline[2]) then
			Json_Put($buffer, '.group.' & $group & '.note', Json_Get($note, '.' & $group & '[1]'), True)
		else
			Json_Put($buffer, '.group.' & $group & '.note', Json_Get($note, '.' & $group & '[0]'), True)
		endif
	endif
next

; calculate values
calculate()

; -------------------------------------------------------------------------------------------
; GUI
; -------------------------------------------------------------------------------------------

$gui_index = 0
$gui_top_offset = 15; offset from basic
$gui_left_offset = 0
$gui_group_top_offset = 20
$gui_group_index = 0

$gui = GUICreate('S70 Echo ' & $VERSION & ' - ' &$cmdline[3] & ' ' & $cmdline[4] & ' - ' & StringLeft($cmdline[2], 6) & '/' & StringTrimLeft($cmdline[2], 6), 890, 1010, @DesktopWidth - 895, 0)
;$gui = GUICreate('S70 Echo ' & $VERSION & ' - ' & $cmdline[3] & ' ' & $cmdline[4] & ' - ' & StringLeft($cmdline[2], 6) & '/' & StringTrimLeft($cmdline[2], 6), 890, 1010, 120, 0)

; header
$label_height = GUICtrlCreateLabel('Výška', 0, 5, 85, 17, 0x0002); right
$input_height = GUICtrlCreateEdit(Json_ObjGet($buffer, '.height'), 89, 2, 36, 19, 1); ES_CENTER
$input_height_unit = GUICtrlCreateLabel('cm', 130, 4, 45, 21)

$label_wegiht = GUICtrlCreateLabel('Váha', 175, 5, 85, 17, 0x0002); right
$input_weight = GUICtrlCreateEdit(Json_ObjGet($buffer, '.weight'), 175 + 89, 2, 36, 19, 1); ES_CENTER
$input_weight_unit = GUICtrlCreateLabel('kg', 175 + 130, 4, 45, 21)

$label_bsa = GUICtrlCreateLabel('BSA', 175 + 175, 5, 85, 17, 0x0002); right
$input_bsa = GUICtrlCreateEdit(Json_ObjGet($buffer, '.bsa'), 175 + 175 + 89, 2, 36, 19, BitOr(0x0001, 0x0800)); read-only
$input_bsa_unit = GUICtrlCreateLabel('m²', 175 + 175 + 130, 4, 45, 21)

$button_del_note = GUICtrlCreateButton('Vymazat poznámky', 602, 2, 110, 21)
$button_del_result = GUICtrlCreateButton('Vymazat závěr', 715, 2, 90, 21)
$button_recount = GUICtrlCreateButton('Přepočítat', 808, 2, 75, 21)

; groups
for $group in Json_ObjGet($order, '.group')
	for $member in Json_ObjGet($order, '.data.' & $group)
		; data
		if IsString(Json_Get($buffer, '.data.' & $group & '."' & $member & '".label')) then
			; update index / offset
			if Mod($gui_index, 5) = 0 then; = both start or end offset!
				$gui_top_offset+=21; member spacing
				$gui_left_offset=0; reset
			Else
				$gui_left_offset+=175; column offset
			endif
			; label
			GUICtrlCreateLabel(Json_Get($buffer, '.data.' & $group & '."' & $member & '".label'), $gui_left_offset, $gui_top_offset + 3, 85, 21, 0x0002); align right
			if $member == 'AV max/meanPG' or $member == 'SV/SVi' Then; the broken one
				; input
				Json_Put($buffer,'.data.' & $group & '."' & $member & '".id', GUICtrlCreateEdit(Json_Get($buffer, '.data.' & $group & '."' & $member & '".value'), 89 + $gui_left_offset, $gui_top_offset, 43, 19, 0x0001), True); centered
				; unit
				GUICtrlCreateLabel(Json_Get($buffer, '.data.' & $group & '."' & $member & '".unit'), 130 + $gui_left_offset + 5, $gui_top_offset + 3, 40, 21)
			else
				; input
				Json_Put($buffer,'.data.' & $group & '."' & $member & '".id', GUICtrlCreateEdit(Json_Get($buffer, '.data.' & $group & '."' & $member & '".value'), 89 + $gui_left_offset, $gui_top_offset, 36, 19, 0x0001), True); centered
				; unit
				GUICtrlCreateLabel(Json_Get($buffer, '.data.' & $group & '."' & $member & '".unit'), 130 + $gui_left_offset, $gui_top_offset + 3, 45, 21)
			endif
			; update index
			$gui_index+=1
			; extra step down hole
			if $member == 'S-RV' then $gui_index+=1
		endif
	next
	; note
	GUICtrlCreateLabel('Poznámka:', 0, 21 + $gui_top_offset + 3, 85, 21, 0x0002)
	Json_Put($buffer, '.group.' & $group & '.id', GUICtrlCreateEdit(Json_Get($buffer, '.group.' & $group & '.note'), 89, 21 + $gui_top_offset, 786, 21, 128), True); $ES_AUTOHSCROLL

	$gui_top_offset+=18; group spacing

	; group
	GUICtrlCreateGroup(Json_ObjGet($buffer, '.group.' & $group & '.label'), 5, $gui_group_top_offset, 880, 21 + 21 * (gui_get_group_index($gui_index, 5)+ 1))
	GUICtrlSetFont(-1, 8, 800, 0, 'MS Sans Serif')
	$gui_group_top_offset += 21 + 21 * (gui_get_group_index($gui_index, 5) + 1)

	; update index / offset
	$gui_top_offset+=24; group spacing
	$gui_left_offset=0; reset
	$gui_index=0; reset
next

; dekurz
$label_dekurz = GUICtrlCreateLabel('Závěr:', 0, $gui_group_top_offset + 8, 85, 21,0x0002); align right
$edit_dekurz = GUICtrlCreateEdit(Json_ObjGet($buffer, '.result'), 89, $gui_group_top_offset + 8, 793, 90, BitOR(64, 4096, 0x00200000)); $ES_AUTOVSCROLL, $ES_WANTRETURN, $WS_VSCROLL

; date
$label_datetime = GUICtrlCreateLabel($runtime, 8, $gui_group_top_offset + 108, 105, 17)

; error
$label_error = GUICtrlCreateLabel('', 120, $gui_group_top_offset + 108, 40, 17)

; button
$button_history = GUICtrlCreateButton('Historie', 574, $gui_group_top_offset + 104, 75, 21)
$button_tisk = GUICtrlCreateButton('Tisk', 652, $gui_group_top_offset + 104, 75, 21)
$button_dekurz = GUICtrlCreateButton('Dekurz', 730, $gui_group_top_offset + 104, 75, 21)
$button_konec = GUICtrlCreateButton('Konec', 808, $gui_group_top_offset + 104, 75, 21)

; GUI tune
GUICtrlSetColor($label_error, 0xff0000)
GUICtrlSetState($button_konec, $GUI_FOCUS)

; message handler response
;$dummy = GUICtrlCreateDummy()

; message handler
;GUIRegisterMsg($WM_COMMAND, 'input_handler')

; GUI display
GUISetState(@SW_SHOW)

; dekurz initialize
$dekurz_init = dekurz_init()
if @error then logger($dekurz_init)

; -------------------------------------------------------------------------------------------
; MAIN
; -------------------------------------------------------------------------------------------

While 1
	$msg = GUIGetMsg()
	; dynamic handler
	;if $msg = $dummy Then
	;	; check value
	;	if StringRegExp(GUICtrlRead(GUICtrlRead($dummy)), '^[.,/0-9]+$|^$') then
	;		GUICtrlSetBkColor(GUICtrlRead($dummy), 0xffffff)
	;	else
	;		GUICtrlSetBkColor(GUICtrlRead($dummy), 0xffcccb)
	;	endif
	;	; dynamic dat update + get_name_from_id()
	;	; ....
	;endif
	; generate dekurz clipboard
	if $msg = $button_dekurz then
		gui_enable(False)
		GUICtrlSetData($label_error, '')
		$dekurz = dekurz()
		if @error then
			logger($dekurz)
			MsgBox(48, 'S70 Echo ' & $VERSION, 'Generování dekurzu selhalo.')
			; trying re-initialize
			$dekurz_init = dekurz_init()
			if @error then logger($dekurz_init)
		endif
		sleep(200)
		gui_enable(True)
		GUICtrlSetData($label_error, 'Hotovo.')
	endif
	; print data
	if $msg = $button_tisk Then
		gui_enable(False)
		$print = print()
		if @error then
			logger($print)
			MsgBox(48, 'S70 Echo ' & $VERSION, 'Tisk selhal.')
		endif
		gui_enable(True)
	endif
	if $msg = $button_del_note Then
		for $group in Json_ObjGet($history, '.group')
			GUICtrlSetData(Json_Get($buffer, '.group.' & $group & '.id'), '')
		next
	endif
	if $msg = $button_del_result Then
		GUICtrlSetData($edit_dekurz, '')
	endif
	; re-calculate
	if $msg = $button_recount Then
		gui_enable(False)
		; update height / weight
		if GuiCtrlRead($input_height) then
			Json_Put($buffer, '.height', Number(StringReplace(GuiCtrlRead($input_height), ',', '.')), True)
		else
			Json_Put($buffer, '.height', Null)
		endif
		if GuiCtrlRead($input_weight) then
			Json_Put($buffer, '.weight', Number(StringReplace(GuiCtrlRead($input_weight), ',', '.')), True)
		else
			Json_Put($buffer, '.weight', Null)
		endif
		; update data buffer
		for $group in Json_ObjGet($history, '.group')
			for $member in Json_ObjGet($history, '.data.' & $group)
				if not GuiCtrlRead(Json_Get($buffer, '.data.'  & $group & '."' & $member & '".id')) then
					Json_Put($buffer, '.data.'  & $group & '."' & $member & '".value', Null, True)
				else
					; detect double value
					$double = StringSplit(StringReplace(GuiCtrlRead(Json_Get($buffer, '.data.'  & $group & '."' & $member & '".id')), ',', '.'), '/', 2); no count
					if @error then
						Json_Put($buffer, '.data.'  & $group & '."' & $member & '".value', Number($double[0]), True)
					else
						Json_Put($buffer, '.data.'  & $group & '."' & $member & '".value', $double[0] & '/' & $double[1], True)
					endif
				endif
			next
		next
		; re-calculate
		calculate(False)
		; re-fill BSA
		GUICtrlSetData($input_bsa, Json_ObjGet($buffer, '.bsa'))
		; re-fill data
		for $group in Json_ObjGet($history, '.group')
			for $member in Json_ObjGet($history, '.data.' & $group)
				GUICtrlSetData(Json_Get($buffer, '.data.' & $group & '."' & $member & '".id'), Json_Get($buffer,'.data.' & $group & '."' & $member & '".value'))
			next
		next
		gui_enable(True)
	endif
	; load history data
	if $msg = $button_history Then
		if FileExists($archive_file) then
			if _DateDiff('h', Json_Get($history,'.date'), $runtime) < $AGE then
				if msgbox(4, 'S70 Echo ' & $VERSION, 'Načíst poslední naměřené hodnoty?') = 6 then
					; update basic
					GUICtrlSetData($input_height, Json_ObjGet($history, '.height'))
					GUICtrlSetData($input_weight, Json_ObjGet($history, '.weight'))
					GUICtrlSetData($input_bsa, Json_ObjGet($history, '.bsa'))
					for $group in Json_ObjGet($buffer, '.group')
						; update data
						for $member in Json_ObjGet($buffer, '.data.' & $group)
							GUICtrlSetData(Json_Get($buffer,'.data.' & $group & '."' & $member & '".id'), Json_Get($history,'.data.' & $group & '."' & $member & '".value'))
						next
					next
				endif
			else
				msgbox(48, 'S70 Echo ' & $VERSION, 'Nelze načís historii. Příliš stará data.')
			endif
		else
			MsgBox(48, 'S70 Echo ' & $VERSION, 'Historie není dostupná.')
		endif
	endif
	; write & exit
	if $msg = $GUI_EVENT_CLOSE or $msg = $button_konec then
		; close dekurz
		_Excel_BookClose($book)
		_Excel_Close($excel)
		; update result
		Json_Put($buffer, '.result', GuiCtrlRead($edit_dekurz), True)
		; update height / weight
		Json_Put($buffer, '.height', Number(StringReplace(GuiCtrlRead($input_height), ',', '.')), True)
		Json_Put($buffer, '.weight', Number(StringReplace(GuiCtrlRead($input_weight), ',', '.')), True)
		; update data buffer
		for $group in Json_ObjGet($history, '.group')
			; update note
			Json_Put($buffer, '.group.' & $group & '.note', GuiCtrlRead(Json_Get($buffer, '.group.' & $group & '.id')), True)
			; update data
			for $member in Json_ObjGet($history, '.data.' & $group)
				if not GuiCtrlRead(Json_Get($buffer, '.data.'  & $group & '."' & $member & '".id')) then
					Json_Put($buffer, '.data.'  & $group & '."' & $member & '".value', Null, True)
				else
					$double = StringSplit(StringReplace(GuiCtrlRead(Json_Get($buffer, '.data.'  & $group & '."' & $member & '".id')), ',', '.'), '/', 2); no count
					if @error then
						Json_Put($buffer, '.data.'  & $group & '."' & $member & '".value', Number($double[0]), True)
					else
						Json_Put($buffer, '.data.'  & $group & '."' & $member & '".value', $double[0] & '/' & $double[1], True)
					endif
				endif
			next
		next
		; update timestamp
		Json_Put($buffer, '.date', $runtime, True)
		; write data buffer to archive
		$out = FileOpen($archive_file, 2 + 256); UTF8 / NOBOM overwrite
		FileWrite($out, Json_Encode($buffer))
		if @error then logger('Program: Zápis historie selhal. ' & $cmdline[2] & '.dat')
		FileClose($out)
		; update history
		FileCopy($archive_file, $history_path & '\' & $cmdline[2] & '\' & $cmdline[2] & '_'  & @YEAR & @MDAY & @MON & @HOUR & @MIN & @SEC & '.dat')
		if @error then logger('Program: Zápis archivu selhal. ' & $cmdline[2])
		; exit
		exitloop
	endif
wend

;exit
logger('Program ukončen: ' & @YEAR & '/' & @MON & '/' & @MDAY & ' ' & @HOUR & ':' & @MIN & ':' & @SEC)
logger('----')
FileClose($log)

exit

; -------------------------------------------------------------------------------------------
; FUNCTION
; -------------------------------------------------------------------------------------------

; logging
func logger($text)
	FileWriteLine($log_file, $text)
endfunc

; get name from id
;func get_name_from_id($id)
;	if $id = $input_height then return 'height'
;	if $id = $input_weight then return 'weight'
;	for $group in Json_ObjGet($history, '.group')
;		for $member in Json_ObjGet($history, '.data.' & $group)
;			if $id = Json_Get($buffer, '.data.'  & $group & '."' & $member & '".id') then return $member
;		next
;	next
;endfunc

; message handler
;func input_handler($window, $message, $param, $control)
;	local $id = BitAND($param, 0x0000ffff); loword
;	local $code = BitShift($param, 16); hiword
;	if $code = $EN_CHANGE then
;		if $id = $input_height then return GUICtrlSendToDummy($dummy, $id)
;		if $id = $input_weight then return GUICtrlSendToDummy($dummy, $id)
;		for $group in Json_ObjGet($history, '.group')
;			for $member in Json_ObjGet($history, '.data.' & $group)
;				if $id = Json_Get($buffer, '.data.'  & $group & '."' & $member & '".id') then return GUICtrlSendToDummy($dummy, $id)
;			next
;		next
;	endif
;EndFunc

; determine age over fifty from UIN
func fifty($rc)
	local $rc_year = Int(StringLeft($rc, 2))
	local $year = Int(StringRight(@YEAR, 2))
	local $fifty = Int(StringRight(@YEAR - 50, 2))
	if $year < 50 then
		if $rc_year > $fifty or $rc_year <= $year then Return False
	ElseIf $year >= 50 then
		if $rc_year > $fifty and $rc_year <= $year then Return False
	endif
	Return True
endfunc

; GUI buttons visibility
func gui_enable($visible)
	if $visible = True then $state = $GUI_ENABLE
	If $visible = False then $state = $GUI_DISABLE
	GUICtrlSetState($button_recount, $state)
	GUICtrlSetState($button_history, $state)
	GUICtrlSetState($button_tisk, $state)
	GUICtrlSetState($button_dekurz, $state)
	GUICtrlSetState($button_konec, $state)
EndFunc

; read configuration file
func read_config_file($file)
	local $cfg
	_FileReadToArray($file, $cfg, 0, "=")
	if @error then return SetError(1)
	for $i = 0 to UBound($cfg) - 1
		if $cfg[$i][0] == 'export' then $export_path = StringRegExpReplace($cfg[$i][1], '\\$', ''); strip trailing backslash
		if $cfg[$i][0] == 'archive' then $archive_path = StringRegExpReplace($cfg[$i][1], '\\$', ''); strip trailing backslash
		if $cfg[$i][0] == 'history' then $AGE = $cfg[$i][1]
	next
endfunc

; find export file
func get_export_file($export_path, $rc)
	local $list = _FileListToArray($export_path, '*.txt', 1); files only
	if @error then Return SetError(1)
	for $i = 1 to ubound($list) - 1
		if StringRegExp($list[$i], '^' & $rc & '_.*') then return $export_path & '\' & $list[$i]
	next
	return ''
endfunc

; parse S70 export file
func export_parse($export)
	local $raw
	_FileReadToArray($export, $raw, 0); no count
	if @error then return SetError(1, 0, 'Export: Nelze načíst souboru exportu. ' & $export)
	; parse basic
	for $i = 0 to UBound($raw) - 1
		if StringRegExp($raw[$i], '^BSA\h.*') then Json_Put($buffer, '.bsa', Number(StringRegExpReplace($raw[$i], '^BSA\h(.*) .*', '$1')), True)
		if StringRegExp($raw[$i], '^Height\h.*') then Json_Put($buffer, '.height', Number(StringRegExpReplace($raw[$i], '^Height\h(.*) .*', '$1')), True)
		if StringRegExp($raw[$i], '^Weight\h.*') then Json_Put($buffer, '.weight', Number(StringRegExpReplace($raw[$i], '^Weight\h(.*) .*', '$1')), True)
	next
	; parse data
	for $group in Json_ObjGet($history, '.group')
		for $member in Json_ObjGet($history, '.data.' & $group)
			for $j = 0 to UBound($raw) - 1
				if StringRegExp($raw[$j], '^' & $member & '\t.*') then
					StringReplace($raw[$j], @TAB, ''); test tabs
					if @extended = 2 Then
						Json_Put($buffer, '.data.' & $group & '."' & $member & '".value', Round(Number(StringRegExpReplace($raw[$j], '^.*\t(.*)\t.*', '$1')), 1), True)
					elseif @extended = 1 then
						Json_Put($buffer, '.data.' & $group & '."' & $member & '".value', Round(Number(StringRegExpReplace($raw[$j], '.*\t(.*)$', '$1')), 1), True)
					endif
					ExitLoop; skip full traversal
				endif
			next
		next
	next
endfunc

; calculate aditional variables
func calculate($is_export = True)
	if not $is_export then
		; BSA
		if IsNumber(Json_Get($buffer, '.weight')) and IsNumber(Json_Get($buffer, '.height')) then
			Json_Put($buffer, '.bsa', Round((Json_Get($buffer, '.weight')^0.425)*(Json_Get($buffer, '.height')^0.725)*71.84*(10^-4), 2), True)
		EndIf
	endif
	;LVd index
	if IsNumber(Json_Get($buffer, '.data.lk.LVIDd.value')) and IsNumber(Json_Get($buffer, '.bsa')) then
		Json_Put($buffer, '.data.lk."LVd index".value', Json_Get($buffer, '.data.lk.LVIDd.value')/Json_Get($buffer, '.bsa'), True)
	endif
	;LVs index
	if IsNumber(Json_Get($buffer, '.data.lk.LVIDs.value')) and IsNumber(Json_Get($buffer, '.bsa')) then
		Json_Put($buffer, '.data.lk."LVs index".value', Json_Get($buffer, '.data.lk.LVIDs.value')/Json_Get($buffer, '.bsa'), True)
	endif
	; LVEF % Teich.
	if IsNumber(Json_Get($buffer, '.data.lk.LVIDd.value')) and IsNumber(Json_Get($buffer, '.data.lk.LVIDs.value')) then
		Json_Put($buffer, '.data.lk."LVEF % Teich".value', (7/(2.4+Json_Get($buffer, '.data.lk.LVIDd.value')/10)*(Json_Get($buffer, '.data.lk.LVIDd.value')/10)^3-7/(2.4+Json_Get($buffer, '.data.lk.LVIDs.value')/10)*(Json_Get($buffer, '.data.lk.LVIDs.value')/10)^3)/(7/(2.4+Json_Get($buffer, '.data.lk.LVIDd.value')/10)*(Json_Get($buffer, '.data.lk.LVIDd.value')/10)^3)*100, True)
	endif
	; LVmass
	if IsNumber(Json_Get($buffer, '.data.lk.LVIDd.value')) and IsNumber(Json_Get($buffer, '.data.lk.IVSd.value')) and IsNumber(Json_Get($buffer, '.data.lk.LVPWd.value')) then
		Json_Put($buffer, '.data.lk.LVmass.value', 1.04*(Json_get($buffer, '.data.lk.LVIDd.value')/10 + Json_Get($buffer, '.data.lk.IVSd.value')/10 + Json_Get($buffer, '.data.lk.LVPWd.value')/10)^3-(Json_Get($buffer, '.data.lk.LVIDd.value')/10)^3-13.6, True)
	endif
	; LVmass-i^2,7
	if IsNumber(Json_Get($buffer, '.height')) and IsNumber(Json_Get($buffer, '.data.lk.LVmass.value')) then
		Json_Put($buffer, '.data.lk."LVmass-i^2,7".value', Json_Get($buffer, '.data.lk.LVmass.value')/(Json_Get($buffer, '.height')/100)^2.7, True)
	endif
	; LVmass-BSA
	if IsNumber(Json_Get($buffer, '.bsa')) and IsNumber(Json_Get($buffer, '.data.lk.LVmass.value')) then
		Json_Put($buffer, '.data.lk.LVmass-BSA.value', Json_Get($buffer, '.data.lk.LVmass.value')/Json_Get($buffer, '.bsa'), True)
	endif
	; RWT
	if IsNumber(Json_Get($buffer, '.data.lk.LVIDd.value')) and IsNumber(Json_Get($buffer, '.data.lk.LVPWd.value')) then
		Json_Put($buffer, '.data.lk.RWT.value', 2*Json_Get($buffer, '.data.lk.LVPWd.value')/Json_Get($buffer, '.data.lk.LVIDd.value'), True)
	endif
	; FS
	if IsNumber(Json_Get($buffer, '.data.lk.LVIDd.value')) and IsNumber(Json_Get($buffer, '.data.lk.LVIDs.value')) then
		Json_Put($buffer, '.data.lk.FS.value', (Json_Get($buffer, '.data.lk.LVIDd.value')-Json_Get($buffer, '.data.lk.LVIDs.value'))/Json_Get($buffer, '.data.lk.LVIDd.value')*100, True)
	endif
	; SV-biplane
	if IsNumber(Json_Get($buffer, '.data.lk."SV MOD A2C".value')) and IsNumber(Json_Get($buffer, '.data.lk."SV MOD A4C".value')) then
		Json_Put($buffer, '.data.lk.SV-biplane.value', (Json_Get($buffer, '.data.lk."SV MOD A4C".value') + Json_Get($buffer, '.data.lk."SV MOD A2C".value'))/2, True)
	endif
	;EDVi
	if IsNumber(Json_Get($buffer, '.data.lk."LVEDV MOD BP".value')) and IsNumber(Json_Get($buffer, '.bsa')) then
		Json_Put($buffer, '.data.lk.EDVi.value', Json_Get($buffer, '.data.lk."LVEDV MOD BP".value')/Json_Get($buffer, '.bsa'), True)
	endif
	;ESVi
	if IsNumber(Json_Get($buffer, '.data.lk."LVESV MOD BP".value')) and IsNumber(Json_Get($buffer, '.bsa')) then
		Json_Put($buffer, '.data.lk.ESVi.value', Json_Get($buffer, '.data.lk."LVESV MOD BP".value')/Json_Get($buffer, '.bsa'), True)
	endif
	; LAV-A4C (LAV-1D)
	if IsNumber(Json_Get($buffer, '.data.ls."LAEDV A-L A4C".value')) and IsNumber(Json_Get($buffer, '.data.ls."LAEDV MOD A4C".value')) then
		Json_Put($buffer, '.data.ls.LAV-A4C.value', (Json_Get($buffer, '.data.ls."LAEDV A-L A4C".value') + Json_Get($buffer, '.data.ls."LAEDV MOD A4C".value'))/2, True)
	endif
	; LAVi (LAVi-1D)
	if IsNumber(Json_Get($buffer, '.data.ls.LAV-A4C.value')) and IsNumber(Json_Get($buffer, '.bsa')) then
		Json_Put($buffer, '.data.ls.LAVi.value', Json_Get($buffer, '.data.ls.LAV-A4C.value')/Json_Get($buffer, '.bsa'), True)
	endif
	; LAV-2D
	if IsNumber(Json_Get($buffer,'.data.ls.LAV-A4C.value')) and IsNumber(Json_Get($buffer, '.data.ls."LAEDV A-L A2C".value')) and IsNumber(Json_Get($buffer, '.data.ls."LAEDV MOD A2C".value')) then
		Json_Put($buffer, '.data.ls.LAV-2D.value', (Json_Get($buffer, '.data.ls.LAV-A4C.value')+(Json_Get($buffer, '.data.ls."LAEDV A-L A2C".value') + Json_Get($buffer, '.data.ls."LAEDV MOD A2C".value'))/2)/2, True)
	endif
	; LAVi-2D
	if IsNumber(Json_Get($buffer,'.data.ls.LAV-2D.value')) and IsNumber(Json_Get($buffer, '.bsa')) then
		Json_Put($buffer, '.data.ls.LAVi-2D.value', Json_Get($buffer, '.data.ls.LAV-2D.value')/Json_Get($buffer, '.bsa'), True)
	endif
	; FAC%
	if IsNumber(Json_Get($buffer,'.data.pk.EDA.value')) and IsNumber(Json_Get($buffer, '.data.pk.ESA.value')) then
		Json_Put($buffer, '.data.pk."FAC%".value', (Json_Get($buffer, '.data.pk.EDA.value')-Json_Get($buffer, '.data.pk.ESA.value'))/Json_Get($buffer, '.data.pk.EDA.value')*100, True)
	endif
	; RAVi
	if IsNumber(Json_Get($buffer,'.data.ps.RAV.value')) and IsNumber(Json_Get($buffer, '.bsa')) then
		Json_Put($buffer, '.data.ps.RAVi.value', Json_Get($buffer, '.data.ps.RAV.value')/Json_Get($buffer, '.bsa'), True)
	endif
	if $is_export then
		;MR Rad
		if IsNumber(Json_Get($buffer,'.data.mch."MR Rad".value')) then
			Json_Put($buffer, '.data.mch."MR Rad".value', Json_Get($buffer, '.data.mch."MR Rad".value')*100, True)
		endif
		;AR Rad
		if IsNumber(Json_Get($buffer,'.data.ach."AR Rad".value')) then
			Json_Put($buffer, '.data.ach."AR Rad".value', Json_Get($buffer, '.data.ach."AR Rad".value')*100, True)
		endif
		;PV Vmax
		if IsNumber(Json_Get($buffer,'.data.pch."PV Vmax".value')) then
			Json_Put($buffer, '.data.pch."PV Vmax".value', Json_Get($buffer, '.data.pch."PV Vmax".value')/100, True)
		endif
	endif
	; PV max/meanPG
	if IsNumber(Json_Get($buffer,'.data.pch."PV maxPG".value')) or IsNumber(Json_Get($buffer, '.data.pch."PV meanPG".value')) then
		Json_Put($buffer, '.data.pch."PV max/meanPG".value', Json_Get($buffer, '.data.pch."PV maxPG".value') & '/' & Json_Get($buffer, '.data.pch."PV meanPG".value'), True)
	endif
	; PR max/meanPG
	if IsNumber(Json_Get($buffer,'.data.pch."PR maxPG".value')) or IsNumber(Json_Get($buffer, '.data.pch."PR meanPG".value')) then
		Json_Put($buffer, '.data.pch."PR max/meanPG".value', Json_Get($buffer, '.data.pch."PR maxPG".value') & '/' & Json_Get($buffer, '.data.pch."PR meanPG".value'), True)
	endif
	;MV E/A Ratio
	if IsNumber(Json_Get($buffer,'.data.mch."MV E Vel".value')) and IsNumber(Json_Get($buffer, '.data.mch."MV A Vel".value')) then
		Json_Put($buffer, '.data.mch."MV E/A Ratio".value', Json_Get($buffer, '.data.mch."MV E Vel".value')/Json_Get($buffer, '.data.mch."MV A Vel".value'), True)
	endif
	; MV max/meanPG
	if IsNumber(Json_Get($buffer,'.data.mch."MV maxPG".value')) or IsNumber(Json_Get($buffer, '.data.mch."MV meanPG".value')) then
		Json_Put($buffer, '.data.mch."MV max/meanPG".value', Json_Get($buffer, '.data.mch."MV maxPG".value') & '/' & Json_Get($buffer, '.data.mch."MV meanPG".value'), True)
	endif
	; MVA-PHT
	if IsNumber(Json_Get($buffer,'.data.mch."MV PHT".value')) then
		Json_Put($buffer, '.data.mch."MVA-PHT".value', 220/Json_Get($buffer, '.data.mch."MV PHT".value'), True)
	endif
	; MVAi-PHT
	if IsNumber(Json_Get($buffer,'.data.mch."MVA-PHT".value')) and IsNumber(Json_Get($buffer,'.bsa')) then
		Json_Put($buffer, '.data.mch."MVAi-PHT".value', Json_Get($buffer, '.data.mch."MVA-PHT".value')/Json_Get($buffer, '.bsa'), True)
	endif
	;E/Em
	if IsNumber(Json_Get($buffer, '.data.mch."MV E Vel".value')) and IsNumber(Json_Get($buffer,'.data.mch.EmSept.value')) and IsNumber(Json_Get($buffer,'.data.mch.EmLat.value')) then
		Json_Put($buffer, '.data.mch."E/Em".value', 2 * Json_Get($buffer, '.data.mch."MV E Vel".value')/(Json_Get($buffer, '.data.mch.EmSept.value') + Json_Get($buffer, '.data.mch.EmLat.value')), True)
	endif
	; TV max/meanPG
	if IsNumber(Json_Get($buffer,'.data.tch."TV maxPG".value')) or IsNumber(Json_Get($buffer, '.data.tch."TV meanPG".value')) then
		Json_Put($buffer, '.data.tch."TV max/meanPG".value', Json_Get($buffer, '.data.tch."TV maxPG".value') & '/' & Json_Get($buffer, '.data.tch."TV meanPG".value'), True)
	endif
	; AV max/meanPG
	if IsNumber(Json_Get($buffer,'.data.ach."AV maxPG".value')) or IsNumber(Json_Get($buffer, '.data.ach."AV meanPG".value')) then
		Json_Put($buffer, '.data.ach."AV max/meanPG".value', Json_Get($buffer, '.data.ach."AV maxPG".value') & '/' & Json_Get($buffer, '.data.ach."AV meanPG".value'), True)
	endif
	; SV
	if IsNumber(Json_Get($buffer,'.data.ach."LVOT Diam".value')) and IsNumber(Json_Get($buffer, '.data.ach."LVOT VTI".value')) then
		Json_Put($buffer, '.data.ach.SV.value', Json_Get($buffer,'.data.ach."LVOT VTI".value')*Json_Get($buffer,'.data.ach."LVOT Diam".value')^2*3.14159265/4/100, True)
	endif
	; SVi
	if IsNumber(Json_Get($buffer,'.data.ach.SV.value')) and IsNumber(Json_Get($buffer, '.bsa')) then
		Json_Put($buffer, '.data.ach.SVi.value', Json_Get($buffer,'.data.ach.SV.value')/Json_Get($buffer,'.bsa'), True)
	endif
	; SV/SVi
	if IsNumber(Json_Get($buffer,'.data.ach.SV.value')) or IsNumber(Json_Get($buffer, '.data.ach.SVi.value')) then
		Json_Put($buffer, '.data.ach."SV/SVi".value', Json_Get($buffer,'.data.ach.SV.value') & '/' & Json_Get($buffer,'.data.ach.SVi.value'), True)
	endif
	; AVA
	if IsNumber(Json_Get($buffer,'.data.ach."LVOT Diam".value')) and IsNumber(Json_Get($buffer, '.data.ach."LVOT VTI".value')) and IsNumber(Json_Get($buffer, '.data.ach."AV VTI".value')) then
		Json_Put($buffer, '.data.ach.AVA.value', Json_Get($buffer,'.data.ach."LVOT VTI".value')*Json_Get($buffer,'.data.ach."LVOT Diam".value')^2*3.14159265/4/Json_Get($buffer,'.data.ach."AV VTI".value')/100, True)
	endif
	; AVAi
	if IsNumber(Json_Get($buffer,'.data.ach.AVA.value')) and IsNumber(Json_Get($buffer, '.bsa')) then
		Json_Put($buffer, '.data.ach.AVAi.value', Json_Get($buffer,'.data.ach.AVA.value')/Json_Get($buffer,'.bsa'), True)
	endif
	; VTI LVOT/Ao
	if IsNumber(Json_Get($buffer, '.data.ach."LVOT VTI".value')) and IsNumber(Json_Get($buffer, '.data.ach."AV VTI".value')) then
		Json_Put($buffer, '.data.ach."VTI LVOT/Ao".value', Json_Get($buffer,'.data.ach."LVOT VTI".value')/Json_Get($buffer,'.data.ach."AV VTI".value'), True)
	endif
	; round it!
	for $group in Json_ObjGet($history, '.group')
		for $member in Json_ObjGet($history, '.data.' & $group)
			if Json_Get($buffer, '.data.' & $group & '."' & $member & '".value') <> Null then
				switch $member
					; round 2 decimal
					case 'RWT', 'AVA', 'AVAi', 'VTI LVOT/Ao', 'AR ERO', 'MVA-PHT', 'MR ERO', 'MVAi-PHT', 'AR ERO'
						Json_Put($buffer, '.data.' & $group & '."' & $member & '".value', StringFormat("%.2f", Json_Get($buffer, '.data.' & $group & '."' & $member & '".value')), True)
					; round 1 decimal
					case 'AV Vmax', 'MV E/A Ratio', 'PV Vmax'
						Json_Put($buffer, '.data.' & $group & '."' & $member & '".value', StringFormat("%.1f", Json_Get($buffer, '.data.' & $group & '."' & $member & '".value')), True)
					; round 0 default
					case else
						; test double value
						$double = StringSplit(Json_Get($buffer, '.data.' & $group & '."' & $member & '".value'), '/', 2); no count
						if @error then
							Json_Put($buffer, '.data.' & $group & '."' & $member & '".value', Round($double[0], 0), True)
						else
							if $double[0] then $double[0] = Round($double[0], 0)
							if $double[1] then $double[1] = Round($double[1], 0)
							Json_Put($buffer, '.data.' & $group & '."' & $member & '".value', $double[0] & '/' & $double[1], True)
						endif
				EndSwitch
			endif
		next
	next
EndFunc

; gui get group index
func gui_get_group_index($i, $mod)
	if mod($i, $mod) = 0 then
		return int($i/5)
	Else
		return int($i/5 + 1)
	endif
EndFunc

; initialize XLS template
func dekurz_init()
	; excel
;	$excel = _Excel_Open()
	$excel = _Excel_Open(False, False, False, False, True)
	if @error then return SetError(1, 0, 'Dekurz: Nelze spustit aplikaci Excel.')
	$book = _Excel_BookNew($excel)
	if @error then return SetError(1, 0, 'Dekurz: Nelze vytvořit Excel book.')
	; logging
	logger('Dekurz: Inicializace.')
	; columns width [ group. label | member.label | member.value | member.unit | ... ]
	$book.Activesheet.Range('A1').ColumnWidth = 14.5; group A-E
	for $i = 0 to 3; four columns starts B[66]
		$book.Activesheet.Range(Chr(66 + $i) & '1').ColumnWidth = 17.5
	Next
	; header
	$book.Activesheet.Range('A1').RowHeight = 20
endFunc

func not_empty_group($group)
	if StringLen(GUICtrlRead(Json_Get($buffer, '.group.' & $group & '.id'))) > 0 then return True
	for $member in Json_ObjGet($history, '.data.' & $group)
		if GUICtrlRead(Json_Get($buffer, '.data.' & $group & '."' & $member & '".id')) then return True
	next
	return False
endFunc

; update XLS data & write clipboard
func dekurz()
	; check init
	if $dekurz_init <> 0 then return SetError(1, 0, 'Dekurz: Inicializace aplikace Excel selhala.')
	;clear the clip
	_ClipBoard_Open(0)
	_ClipBoard_Empty()
	if @error then
		logger('Dekurz: Vyprázdnění schránky selhalo.')
	else
		logger('Dekurz: Vyprázdnění schránky.')
	endif
	_ClipBoard_Close()

	; clean-up
	_Excel_RangeDelete($book.Activesheet, 'A1:E49')
	; default font
	$book.Activesheet.Range('A2:E40').Font.Size = 8
	; columns height
	$book.Activesheet.Range('A2:E40').RowHeight = 10
	; number format
	$book.Activesheet.Range('A1:E40').NumberFormat = "@"; string
	; header
	$book.Activesheet.Range('A1').Font.Size = 11
	$book.Activesheet.Range('A1').Font.Bold = True
	_Excel_RangeWrite($book, $book.Activesheet, 'Echokardiografie(TTE) ' &  @MDAY & '.' & @MON & '.' & @YEAR & ':', 'A1')
	; data init
	$row_index = 2
	$column_index = 65; 65 A, 66 B, 67 C, 68 D, 69 E
	; top line
	With $book.Activesheet.Range('A' & $row_index & ':E' & $row_index).Borders(8); $xlEdgeTop
		.LineStyle = 1
		.Weight = 2
	EndWith
	; generate data
	for $group in Json_ObjGet($order, '.group')
		if not_empty_group($group) then
			; group label
			$book.Activesheet.Range('A' & $row_index).Font.Bold = True
			$book.Activesheet.Range('A' & $row_index).Font.Size = 9
			_Excel_RangeWrite($book, $book.Activesheet, Json_ObjGet($buffer, '.group.' & $group & '.label'), 'A' & $row_index)
			$step=False
			$members = Json_ObjGet($order, '.data.' & $group).Keys()
			for $i in Json_ObjGet($map, '.' & $group)
				; line break
				if $column_index = 69 Then
					if $step then $row_index+=1
					$step=False
					$column_index = 65
				endif
				; write value
				if $i <> Null then; not hole
					if GUICtrlRead(Json_Get($buffer, '.data.' & $group & '."' & $members[$i] & '".id')) then; has value
						_Excel_RangeWrite($book, $book.Activesheet, Json_Get($buffer, '.data.' & $group & '."' & $members[$i] & '".label') & ': ' & StringReplace(GUICtrlRead(Json_Get($buffer, '.data.' & $group & '."' & $members[$i] & '".id')), ',', '.') & ' ' & Json_Get($buffer, '.data.' & $group & '."' & $members[$i] & '".unit'), Chr($column_index + 1) & $row_index)
						$step=True
					endif
				endif
				; update index
				$column_index+=1
			next
			; update offset
			if $step then $row_index+=1
			; note
			if StringLen(GUICtrlRead(Json_Get($buffer,'.group.' & $group & '.id'))) > 0 then
				$book.Activesheet.Range('B' & $row_index & ':E' & $row_index).MergeCells = True
				$book.Activesheet.Range('B' & $row_index).Font.Bold = True
				$book.Activesheet.Range('A' & $row_index).RowHeight = 13
				_Excel_RangeWrite($book, $book.Activesheet, GUICtrlRead(Json_Get($buffer,'.group.' & $group & '.id')), 'B' & $row_index)
			endif
			; group line
			With $book.Activesheet.Range('A' & $row_index & ':E' & $row_index).Borders(9); $xlEdgeBottom
				.LineStyle = 1
				.Weight = 2
			EndWith
			; update index
			$row_index+=1
			$column_index = 65
		endif
	next
	; result
	$book.Activesheet.Range('A' & $row_index).Font.Size = 9
	$book.Activesheet.Range('A' & $row_index).Font.Bold = True
	_Excel_RangeWrite($book, $book.Activesheet, 'Závěr:', 'A' & $row_index)
	$row_index+=1
	$book.Activesheet.Range('A' & $row_index & ':E' & $row_index).MergeCells = True
	$book.Activesheet.Range('A' & $row_index).Font.Size = 9
	$book.Activesheet.Range('A' & $row_index).Font.Bold = True
	_Excel_RangeWrite($book, $book.Activesheet, StringReplace(GUICtrlRead($edit_dekurz), @CRLF, @LF), 'A' & $row_index)
	$row_index+=1
	; footer
	$book.Activesheet.Range('A' & $row_index & ':E' & $row_index).Font.Size = 9
	_Excel_RangeWrite($book, $book.Activesheet, 'Dne: ' & @MDAY & '.' & @MON & '.' & @YEAR, 'A' & $row_index)
	_Excel_RangeWrite($book, $book.Activesheet, 'MUDr. ' & Json_ObjGet($user, '.' & $cmdline[1]), 'D' & $row_index)
	; clip
	_Excel_RangeCopyPaste($book.ActiveSheet, 'A1:E' & $row_index + 1); data + one empty line..
	if @error then
		logger('Dekurz: Kopírování do schránky selhalo.')
		return SetError(1, 0, 'Dekurz: Nelze kopírovat data.')
	else
		logger('Dekurz: Kopírování do schránky.')
	endif
EndFunc

func print(); 2100 x 2970
	local $printer, $printer_error
	; GDI+ init
	_GDIPlus_Startup()
	$logo = _GDIPlus_BitmapCreateFromMemory(Binary($logo_file_one & $logo_file_two))
	$logo_handle = _GDIPlus_BitmapCreateHBITMAPFromBitmap($logo)
	$qr = _GDIPlus_BitmapCreateFromMemory(Binary($qr_file))
	$qr_handle = _GDIPlus_BitmapCreateHBITMAPFromBitmap($qr)
	;priner init
	$printer = _PrintDllStart($printer_error)
	if @error then return SetError(1, 0, 'Tisk: ' & $printer_error)
	; select printer
	;_PrintSetPrinter($printer)
	; log printer name
	$printer_name = _PrintGetPrinter($printer)
	if @error Then
		logger('Tisk: Nepodařilo se získat název tiskárny.')
	else
		logger('Tisk: Tiskárna ' & $printer_name)
	endif
	; printer create page
	_PrintStartPrint($printer)
	if @error then
		logger('Tisk: Inicializace selhala.')
	else
		logger('Tisk: Inicializace.')
	endif
	$max_height = _PrintGetPageHeight($printer) - _PrintGetYOffset($printer)
	$max_width = _PrintGetPageWidth($printer) - _PrintGetXOffset($printer)
	$line_offset = 5
	$top_offset = 0

	;logo
	_PrintImageFromDC($printer, $logo_handle, 0, 0, 128, 128, 50, 45, 338, 338); 128 x 128 inch 96 DPI => 338 mm
	; QR code
	_PrintImageFromDC($printer, $qr_handle, 0, 0, 123, 123, $max_width - 325 - 50, 50, 325, 325); 123 x 123 inch 96 DPI => 325 mm
	; address
	_PrintSetFont($printer,'Arial',12, Default, 'bold')
	$text_height = _PrintGetTextHeight($printer, 'Arial')
	$top_offset += 125
	_PrintText($printer, 'Echokardiografické vyšetření (TTE)', ($max_width - _PrintGetTextWidth($printer, 'Echokardiografické vyšetření (TTE)'))/2, $top_offset)
	$top_offset+=$text_height + $line_offset
	_PrintSetFont($printer,'Arial',11, Default, Default)
	$text_height = _PrintGetTextHeight($printer, 'Arial')
	_PrintText($printer, 'Kardiologie Praha 17 - Řepy s.r.o.', ($max_width - _PrintGetTextWidth($printer, 'Kardiologie Praha 17 - Řepy s.r.o.'))/2, $top_offset)
	$top_offset+=$text_height + $line_offset
	_PrintText($printer, 'Poliklinika - Žufanova 1113/3', ($max_width - _PrintGetTextWidth($printer, 'Poliklinika - Žufanova 1113/3'))/2, $top_offset)
	$top_offset+=$text_height + $line_offset
	_PrintText($printer, 'Tel: +420/235318915', ($max_width - _PrintGetTextWidth($printer, 'Tel: +420/235318915'))/2, $top_offset)
	$top_offset+=$text_height + $line_offset
	; separator
	_PrintSetLineWid($printer, 2)
	_PrintLine($printer, 50, $top_offset + 75, $max_width - 50, $top_offset + 75)
	$top_offset+=75
	; patient
	_PrintSetFont($printer, 'Arial',10, Default, Default)
	$text_height = _PrintGetTextHeight($printer, 'Arial')
	$top_offset += 25
	_PrintText($printer, 'Jméno: ' & $cmdline[3]& ' ' & $cmdline[4], 50, $top_offset)
	_PrintText($printer, 'Výška: ' & StringReplace(GUICtrlRead($input_height), ',', '.') & ' cm', 550, $top_offset)
	_PrintText($printer, 'BSA: ' & GUICtrlRead($input_bsa) & ' m²', 1050, $top_offset)
	_PrintText($printer, 'Datum: ' & @MDAY & '.' & @MON & '.' & @YEAR, 1550, $top_offset)
	$top_offset+=$text_height + $line_offset
	_PrintText($printer, 'Rodné číslo: ' & StringLeft($cmdline[2], 6) & '/' & StringTrimLeft($cmdline[2], 6), 50, $top_offset)
	_PrintText($printer, 'Váha: ' & StringReplace(GUICtrlRead($input_weight), ',', '.') & ' kg', 550, $top_offset)
	; separator
	_PrintSetLineWid($printer, 2)
	_PrintLine($printer, 50, $top_offset + 70, $max_width - 50, $top_offset + 70)
	$top_offset+=70
	; data
	_PrintSetFont($printer, 'Arial',10, Default, Default)
	$text_height = _PrintGetTextHeight($printer, 'Arial')
	$top_offset+=15
	$group_index = $top_offset
	for $group in Json_ObjGet($order, '.group')
		if not_empty_group($group) then
			;check new page
			if $top_offset + 200 >= $max_height Then
				_PrintNewPage($printer)
				$top_offset = 50
				$group_index = $top_offset
			endif
			; line index
			$line_index = 1
			; group line
			if $group_index <> $top_offset then; skip first one
				_PrintSetLineCol($printer, 0xd3d3d3)
				_PrintSetLineWid($printer, 2)
				_PrintLine($printer, 50, $top_offset, $max_width - 50, $top_offset)
			endif
			; group label
			_PrintSetFont($printer, 'Arial', 9, Default, 'bold')
			_PrintText($printer, Json_ObjGet($buffer,'.group.' & $group & '.label'), 50, $top_offset)
			$top_offset += $text_height + $line_offset; step down
			; group data
			_PrintSetFont($printer, 'Arial', 8, Default, Default)
			$step=False
			$members = Json_ObjGet($order, '.data.' & $group).Keys()
			for $i in Json_ObjGet($map, '.' & $group)
				; line break
				if $line_index = 5 Then
					if $step then $top_offset += $text_height + $line_offset
					$step=False
					$line_index = 1
				endif
				; write value
				if $i <> Null then; not hole
					if GUICtrlRead(Json_Get($buffer, '.data.' & $group & '."' & $members[$i] & '".id')) then; has value
						_PrintText($printer, Json_Get($buffer,'.data.' & $group & '."' & $members[$i] & '".label') & ': ' & StringReplace(String(GuiCtrlRead(Json_Get($buffer,'.data.' & $group & '."' & $members[$i] & '".id'))), ',', '.') & ' ' & Json_Get($buffer,'.data.' & $group & '."' & $members[$i] & '".unit'), 400*$line_index, $top_offset)
						$step=True
					endif
				endif
				; update index
				$line_index+=1
			next
			; update offset
			if $step then $top_offset += $text_height + $line_offset
			; note
			_PrintSetFont($printer, 'Arial', 8, Default, 'bold')
			$text_height = _PrintGetTextHeight($printer, 'Arial')
			$line_len = 395
			if StringLen(GUICtrlRead(Json_Get($buffer,'.group.' & $group & '.id'))) > 0 then
				for $word in StringSplit(GUICtrlRead(Json_Get($buffer,'.group.' & $group & '.id')), ' ', 2); no count
					if _PrintGetTextWidth($printer, ' ' & $word) + $line_len > $max_width - 80 Then
						$line_len=395
						$top_offset+=$text_height + $line_offset
					EndIf
					_PrintText($printer, ' ' & $word, $line_len, $top_offset)
					$line_len+=_PrintGetTextWidth($printer, ' ' & $word)
				next
				; update offset
				$top_offset += $text_height + $line_offset
			endif
		endif
	next
	; separator
	_PrintSetLineCol($printer, 0x000000); black
	_PrintSetLineWid($printer, 2)
	_PrintLine($printer, 50, $top_offset + 15, $max_width - 50, $top_offset + 15)
	$top_offset += 35
	; result label
	_PrintSetFont($printer, 'Arial', 9, Default, 'bold')
	_PrintText($printer, 'Závěr:', 50, $top_offset)
	$top_offset += $text_height + $line_offset + 5
	; result
	_PrintSetFont($printer, 'Arial', 9, Default, Default)
	$text_height = _PrintGetTextHeight($printer, 'Arial')
	$line_len = 50
	for $phrase in StringSplit(GUICtrlRead($edit_dekurz), @LF, 2); no count
		for $word in StringSplit($phrase, ' ', 2); no count
			if _PrintGetTextWidth($printer, ' ' & $word) + $line_len > $max_width - 80 Then
				; check new page
				if $top_offset + 200 >= $max_height Then
					_PrintNewPage($printer)
					$top_offset = 50
				endif
				; line break
				$line_len=50
				$top_offset+=$text_height + $line_offset
			EndIf
			_PrintText($printer, ' ' & $word, $line_len, $top_offset)
			$line_len+=_PrintGetTextWidth($printer, ' ' & $word)
		next
		; phrase break
		$top_offset+=$text_height + $line_offset
		$line_len=50
	next
	; footer
	$top_offset+=$text_height + $line_offset
	; date
	_PrintText($printer, 'Dne: ' & @MDAY & '.' & @MON & '.' & @YEAR, 50, $top_offset)
	; singnature
	_PrintText($printer, 'MUDr. ' & Json_ObjGet($user, '.' & $cmdline[1]) , 1250, $top_offset)
	; print
	_PrintEndPrint($printer)
	if @error Then
		logger('Tisk: Tisk selhal.')
	else
		logger('Tisk: Tisk.')
	endif
	; print de-init
	_printDllClose($printer)
	; GDI+ de-init
	 _WinAPI_DeleteObject($logo_handle)
	 _WinAPI_DeleteObject($qr_handle)
	_GDIPlus_ImageDispose($logo)
	_GDIPlus_ImageDispose($qr)
	_GDIPlus_Shutdown()
EndFunc
