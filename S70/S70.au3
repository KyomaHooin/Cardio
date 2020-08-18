;
; GE Vivid S70 - Medicus 3 integration
; CMD: S70.exe %RODCISN% %CELEJMENO% %VYSKA% %VAHA%
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
#AutoIt3Wrapper_Res_ProductVersion=1.8
#AutoIt3Wrapper_Res_CompanyName=Kyouma Houin
#AutoIt3Wrapper_Res_LegalCopyright=GNU GPL v3
#AutoIt3Wrapper_Res_Language=1029
#AutoIt3Wrapper_Icon=S70.ico
#NoTrayIcon

; -------------------------------------------------------------------------------------------
; INCLUDE
; -------------------------------------------------------------------------------------------

#include <GUIConstantsEx.au3>
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

$VERSION = '1.8'
$AGE = 24; default stored data age in hours

global $log_file = @ScriptDir & '\' & 'S70.log'
global $config_file = @ScriptDir & '\' & 'S70.ini'
global $result_file = @ScriptDir & '\' & 'zaver.txt'

global $export_path = @ScriptDir & '\' & 'input'
global $archive_path = @ScriptDir & '\' & 'archiv'
global $history_path = $archive_path & '\' & 'history'

global $runtime = @YEAR & '/' & @MON & '/' & @MDAY & ' ' & @HOUR & ':' & @MIN & ':' & @SEC

;data template
global $json_template='{' _
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
			& '"LA Diam":{"label":"Plax", "unit":"mm", "value":null, "id":null},' _
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
			& '"RV Major":{"label":"RVplax", "unit":"mm", "value":null, "id":null},' _
			& '"RVIDd":{"label":"RVD1", "unit":"mm", "value":null, "id":null},' _
			& '"TAPSE":{"label":"TAPSE", "unit":"mm", "value":null, "id":null},' _
			& '"S-RV":{"label":"S-RV", "unit":"cm/s", "value":null, "id":null},' _
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
			& '"Ao Diam":{"label":"Asc-Ao", "unit":"mm", "value":null, "id":null}' _
		& '},' _
		& '"ach":{' _
			& '"AV Vmax":{"label":"Vmax", "unit":"m/s", "value":null, "id":null},' _
			& '"AV max/meanPG":{"label":"PG max/mean", "unit":"torr", "value":null, "id":null},' _
			& '"AV VTI":{"label":"Ao-VTI", "unit":"cm", "value":null, "id":null},' _
			& '"LVOT Diam":{"label":"LVOT", "unit":"mm", "value":null, "id":null},' _
			& '"LVOT VTI":{"label":"LVOT-VTI", "unit":"cm", "value":null, "id":null},' _
			& '"AVA":{"label":"AVA", "unit":"cm", "value":null, "id":null},' _
			& '"AVAi":{"label":"AVAi", "unit":"cm²", "value":null, "id":null},' _
			& '"SV/SVi":{"label":"SV/SVi", "unit":"ml/m²", "value":null, "id":null},' _
			& '"VTI LVOT/Ao":{"label":"VTI LVOT/Ao", "unit":"ratio", "value":null, "id":null},' _
			& '"AR RV":{"label":"AR-RV", "unit":"ml", "value":null, "id":null},' _
			& '"AR ERO":{"label":"AR-ERO", "unit":"cm²", "value":null, "id":null},' _
			& '"AR VTI":{"label":"AR-VTI", "unit":"cm", "value":null, "id":null},' _
			& '"AR Rad":{"label":"PISA radius", "unit":"mm", "value":null, "id":null},' _
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
			& '"TR maxPG":{"label":"PGmax-reg", "unit":"torr", "value":null, "id":null},' _
			& '"TR meanPG":{"label":"PGmean-reg", "unit":"torr", "value":null, "id":null},' _
			& '"TV max/meanPG":{"label":"PG max/mean", "unit":"torr", "value":null, "id":null},' _
			& '"TV maxPG":{"label":null, "unit":null, "value":null},' _; calculation
			& '"TV meanPG":{"label":null, "unit":null, "value":null}' _; calculation
		& '},' _
		& '"p":{' _
		& '},' _
		& '"other":{' _
			& '"IVC diam Ins":{"label":"DDŽ insp", "unit":"mm", "value":null, "id":null}' _
			& '"IVC Diam Exp":{"label":"DDŽ exp", "unit":"mm", "value":null, "id":null},' _
		& '}' _
	& '}' _
& '}'

;data
global $history = Json_Decode($json_template)
global $buffer = Json_Decode($json_template)
global $order = Json_Decode($json_template)

;XLS variable
global $excel, $book

global $logo_file_one = '0x424d36c000000000000036000000280000008000000080000000010018000000000000c00000c40e0000c40e00000000000000000000ffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffdfdfdfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfc' _
& 'fcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfefefeffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffefefefcfcfcffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcfcfcffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffdfdfdfffffffffffff6f6f6c8c8c8aaaaaaa6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6' _
& 'a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6b0b0b0d8d8d8fffffffffffffefefefefefeffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffcfcfcfffffff1f1f17c7c7c1f1f1f00000000000000000000000000000000000000000000000000000000000000000000000000000000' _
& '0000000000000000000000000000000000000000000000000000050505373737a6a6a6fffffffffffffdfdfdffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffcfcfcffffffd0d0d024242400000000000000000002020202020202020202020202020202020202020202020202020202020202020202020202' _
& '0202020202020202020202020202020202020202020202020202000000000000000000575757f9f9f9fffffffefefeffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffdfdfdffffffd7d7d710101000000006060602020201010102020202020202020202020202020202020202020202020202020202020202020202020202' _
& '02020202020202020202020202020202020202020202020202020101010303030505050000004b4b4bfffffffffffffefefeffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffff38383800000006060600000001010103030300000000000000000000000000000000000000000000000000000000000000000000000000' _
& '0000000000000000000000000000000000000000000000000000030303000000010101060606000000858585fffffffffffffffffffffffffffffffefefefcfc' _
& 'fcffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fcfcfcffffffa6a6a60000000404040000000101010000000000000909090f0f0f0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e' _
& '0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0f0f0f020202000000020202000000020202000000131313dededef6f6f6f1f1f1f2f2f2f8f8f8ffffffffff' _
& 'fffffffffdfdfdffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fefefeffffff5252520000000404040101010101010000007d7d7de8e8e8f2f2f2f1f1f1f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2' _
& 'f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f1f1f1f3f3f3d4d4d44646460000000303030000000101010000000909090f0f0f0e0e0e0f0f0f222222525252a6a6' _
& 'a6fffffffffffffcfcfcffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffff7f7f7222222000000020202040404000000626262ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffffff3f3f31d1d1d0000000202020000000101010000000000000000000000000000000000000000' _
& '00383838d7d7d7fffffffcfcfcffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffefefe' _
& 'fffffff2f2f20f0f0f000000020202030303000000a5a5a5fffffffafafaffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffefefefbfbfbffffff5353530000000404040000000101010101010202020202020202020202020404040404' _
& '04000000101010cfcfcffffffffdfdfdffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffcfcfcfbfbfbfdfdfdfefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefdfdfd' _
& 'fffffff0f0f00e0e0e000000020202020202000000a6a6a6fffffffcfcfcffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffefefeffffff5454540000000404040101010000000101010202020202020303030404040101010000' _
& '00060606000000232323f1f1f1fffffffefefeffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffefefefcfc' _
& 'fcffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffbfbfb0f0f0f000000020202020202000000a6a6a6fffffffcfcfcffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffefefeffffff5353530000000404040000000101010000000000000000000000000000000101010101' _
& '010000000606060000007c7c7cfffffffcfcfcffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcfcfcffffffffff' _
& 'fff3f3f3b3b3b37e7e7e6161615757575a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a' _
& '5b5b5b555555050505000000010101020202000000a6a6a6fffffffcfcfcffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffefefeffffff545454000000040404030303000000363636abababa5a5a5a5a5a56161610000000000' _
& '000101010202020000001f1f1ff6f6f6ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcfcfcfffffff4f4f48080' _
& '801c1c1c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000' _
& '000000000000000000010101010101020202000000a6a6a6fffffffcfcfcffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffefefeffffff545454000000040404040404000000595959ffffffffffffffffffffffff7d7d7d0000' _
& '00030303010101000000000000c8c8c8fffffffdfdfdffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcfcfcffffffc8c8c82525250000' _
& '00000000020202050505040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404' _
& '040404040404010101000000010101030303000000a3a3a3fffffffcfcfcffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffefefeffffff545454000000040404040404000000535353fffffffbfbfbfafafaffffffe9e9e90a0a' _
& '0a000000020202020202000000aaaaaafffffffcfcfcffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcfcfcffffffb9b9b90404040000000505' _
& '05020202010101020202030303040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404' _
& '040404040404010101000000010101030303000000a3a3a3fffffffcfcfcffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffefefeffffff545454000000040404040404000000535353fffffffbfbfbfafafaffffffe9e9e90a0a' _
& '0a000000020202020202000000aaaaaafffffffcfcfcffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffdfdfdffffffd5d5d50909090000000505050000' _
& '00010101030303000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000' _
& '000000000000000000010101010101020202000000a6a6a6fffffffcfcfcffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffefefeffffff545454000000040404040404000000595959ffffffffffffffffffffffff7d7d7d0000' _
& '00030303010101000000000000c8c8c8fffffffdfdfdffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff3b3b3b0000000505050000000202' _
& '020000000000001414144949495757575a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a' _
& '5b5b5b555555050505000000010101020202000000a6a6a6fffffffcfcfcffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffefefeffffff545454000000040404030303000000363636abababa5a5a5a5a5a56262620000000000' _
& '000101010202020000001f1f1ff6f6f6ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcfcfcffffffa8a8a80000000404040000000202020000' _
& '000000007e7e7eedededffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffbfbfb0f0f0f000000020202020202000000a6a6a6fffffffcfcfcffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffefefeffffff5353530000000404040000000101010000000000000000000000000000000101010101' _
& '010000000606060000007c7c7cfffffffcfcfcffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffefefeffffff4747470000000404040101010101010000' _
& '00a1a1a1fffffffffffffefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefdfdfd' _
& 'fffffff0f0f00e0e0e000000020202020202000000a6a6a6fffffffcfcfcffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffefefeffffff5454540000000404040101010000000101010202020202020303030404040101010000' _
& '00060606000000232323f1f1f1fffffffefefeffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffefefeffffffe7e7e70e0e0e0000000101010404040000005f5f' _
& '5ffffffffbfbfbfefefefffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffefefe' _
& 'fffffff2f2f20f0f0f000000020202030303000000a5a5a5fffffffafafaffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffefefefbfbfbffffff5353530000000404040000000101010101010202020202020202020202020404040404' _
& '04000000101010cfcfcffffffffdfdfdffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffdfdfdffffffbfbfbf000000010101020202010101000000c1c1' _
& 'c1fffffffcfcfcffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffff7f7f7222222000000020202040404000000626262ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffffff3f3f31d1d1d0000000202020000000101010000000000000000000000000000000000000000' _
& '00383838d7d7d7fffffffcfcfcffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcfcfcffffffa6a6a60000000202020202020000000d0d0debeb' _
& 'ebfffffffefefeffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fefefeffffff5151510000000404040101010101010000007e7e7ee9e9e9f2f2f2f1f1f1f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2' _
& 'f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f1f1f1f3f3f3d5d5d54646460000000303030000000101010000000909090f0f0f0e0e0e0f0f0f222222525252a6a6' _
& 'a6fffffffffffffcfcfcffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcfcfcffffffa3a3a30000000303030202020000000e0e0ef2f2' _
& 'f2ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fcfcfcffffffa6a6a60000000404040000000101010000000000000909090f0f0f0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e' _
& '0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0f0f0f020202000000020202000000020202000000131313dededef6f6f6f1f1f1f2f2f2f7f7f7ffffffffff' _
& 'fffffffffdfdfdffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcfcfcffffffa7a7a70000000202020202020000000e0e0ef2f2' _
& 'f2ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffff38383800000006060600000001010103030300000000000000000000000000000000000000000000000000000000000000000000000000' _
& '0000000000000000000000000000000000000000000000000000030303000000010101060606000000858585fffffffffffffffffffffffffffffffefefefcfc' _
& 'fcffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcfcfcffffffa6a6a60000000202020202020000000e0e0ef2f2' _
& 'f2ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffdfdfdffffffd7d7d710101000000006060602020201010102020202020202020202020202020202020202020202020202020202020202020202020202' _
& '02020202020202020202020202020202020202020202020202020101010303030505050000004a4a4afffffffffffffefefeffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcfcfcffffffa6a6a60000000202020202020000000e0e0ef2f2' _
& 'f2ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffcfcfcffffffcfcfcf23232300000000000000000002020202020202020202020202020202020202020202020202020202020202020202020202' _
& '0202020202020202020202020202020202020202020202020202000000000000000000565656f9f9f9fffffffefefeffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcfcfcffffffa6a6a60000000202020202020000000e0e0ef2f2' _
& 'f2ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffcfcfcfffffff2f2f27c7c7c1e1e1e00000000000000000000000000000000000000000000000000000000000000000000000000000000' _
& '0000000000000000000000000000000000000000000000000000050505363636a6a6a6fffffffffffffdfdfdffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcfcfcffffffa6a6a60000000202020202020000000e0e0ef2f2' _
& 'f2ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffdfdfdfffffffffffff6f6f6c7c7c7aaaaaaa6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6' _
& 'a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6b0b0b0d7d7d7fffffffffffffefefefefefeffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcfcfcffffffa6a6a60000000202020202020000000e0e0ef2f2' _
& 'f2ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffefefefcfcfcffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcfcfcffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcfcfcffffffa6a6a60000000202020202020000000e0e0ef2f2' _
& 'f2ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffdfdfdfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfc' _
& 'fcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfefefeffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcfcfcffffffa6a6a60000000202020202020000000e0e0ef2f2' _
& 'f2ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffefefefcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfc' _
& 'fcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfc' _
& 'fcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfefefeffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcfcfcffffffa6a6a60000000202020202020000000e0e0ef2f2' _
& 'f2ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffefefefcfcfcffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffffcfcfcfefefeffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcfcfcffffffa6a6a60000000202020202020000000e0e0ef2f2' _
& 'f2ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffcfcfcfffffffffffffefefedadadab5b5b5a2a2a2a5a5a5a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6' _
& 'a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6' _
& 'a6a6a6a6a6a6a6a6a6a6a5a5a5a2a2a2b5b5b5dadadafefefefffffffffffffcfcfcffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcfcfcffffffa6a6a60000000202020202020000000e0e0ef2f2' _
& 'f2ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffdfdfdffffffebebeb8585852f2f2f06060600000000000000000000000000000000000000000000000000000000000000' _
& '00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000' _
& '000000000000000000000000000000000000000606062f2f2f858585ebebebfffffffdfdfdffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcfcfcffffffa6a6a60000000202020202020000000e0e0ef2f2' _
& 'f2ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffefefeffffffffffffa3a3a317171700000000000000000001010103030302020202020202020202020202020202020202020202020202' _
& '02020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202' _
& '02020202020202020202020202030303010101000000000000000000171717a3a3a3fffffffffffffefefeffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcfcfcffffffa6a6a60000000202020202020000000e0e0ef2f2' _
& 'f2ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffff77777700000000000005050503030301010102020202020202020202020202020202020202020202020202020202020202' _
& '02020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202' _
& '02020202020202020202020202020202020202010101030303050505000000000000777777ffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcfcfcffffffa6a6a60000000202020202020000000e0e0ef2f2' _
& 'f2ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffdfdfdffffff80808000000003030303030300000002020204040400000000000000000000000000000000000000000000000000000000000000' _
& '00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000' _
& '00000000000000000000000000000000000000040404020202000000030303030303000000808080fffffffdfdfdffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcfcfcffffffa6a6a60000000202020202020000000e0e0ef2f2' _
& 'f2ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffdfdfdffffffbbbbbb0000000101010202020000000303030000000000000404040e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e' _
& '0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e' _
& '0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e040404000000000000030303000000020202010101000000bbbbbbfffffffdfdfdffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcfcfcffffffa6a6a60000000202020202020000000e0e0ef2f2' _
& 'f2ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffff323232000000040404000000030303000000111111858585d4d4d4f0f0f0f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2' _
& 'f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2' _
& 'f2f2f2f2f2f2f2f2f2f2f2f2f2f0f0f0d4d4d4868686111111000000030303000000040404000000333333ffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcfcfcffffffa6a6a60000000202020202020000000e0e0ef2f2' _
& 'f2ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fcfcfcffffffb3b3b3000000030303010101030303000000232323dbdbdbffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffdbdbdb232323000000030303010101030303000000b3b3b3fffffffcfcfcffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcfcfcffffffa6a6a60000000202020202020000000e0e0ef2f2' _
& 'f2ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fdfdfdffffff656565000000040404010101000000030303cbcbcbfffffff9f9f9fdfdfdffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffdfdfdf9f9f9ffffffcbcbcb030303000000010101040404000000656565fffffffdfdfdffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcfcfcffffffa6a6a60000000202020202020000000e0e0ef2f2' _
& 'f2ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffdfdfd333333000000030303040404000000595959fffffffbfbfbffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffbfbfbffffff595959000000040404030303000000333333fdfdfdffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcfcfcffffffa6a6a60000000202020202020000000e0e0ef2f2' _
& 'f2ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffff4f4f4151515000000020202040404000000969696fffffffbfbfbffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffbfbfbffffff969696000000040404020202000000161616f4f4f4ffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcfcfcffffffa6a6a60000000202020202020000000e0e0ef2f2' _
& 'f2ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffff2f2f20e0e0e000000020202030303000000a2a2a2fffffffcfcfcffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffcfcfcffffffa2a2a20000000303030202020000000e0e0ef2f2f2ffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcfcfcffffffa6a6a60000000202020202020000000e0e0ef2f2' _
& 'f2ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffff2f2f20e0e0e000000020202020202000000a6a6a6fffffffcfcfcffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffcfcfcffffffa6a6a60000000202020202020000000e0e0ef2f2f2ffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcfcfcffffffa6a6a60000000202020202020000000e0e0ef2f2' _
& 'f2ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffff2f2f20e0e0e000000020202020202000000a6a6a6fffffffcfcfcffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffcfcfcffffffa6a6a60000000202020202020000000e0e0ef2f2f2ffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcfcfcffffffa6a6a60000000202020202020000000e0e0ef2f2' _
& 'f2ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffff2f2f20e0e0e000000020202020202000000a6a6a6fffffffcfcfcffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffcfcfcffffffa6a6a60000000202020202020000000e0e0ef2f2f2ffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcfcfcffffffa6a6a60000000202020202020000000e0e0ef2f2' _
& 'f2ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffff2f2f20e0e0e000000020202020202000000a6a6a6fffffffcfcfcffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffcfcfcffffffa6a6a60000000202020202020000000e0e0ef2f2f2ffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcfcfcffffffa6a6a60000000202020202020000000e0e0ef2f2' _
& 'f2ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffff2f2f20e0e0e000000020202020202000000a6a6a6fffffffcfcfcffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffcfcfcffffffa6a6a60000000202020202020000000e0e0ef2f2f2ffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcfcfcffffffa6a6a60000000202020202020000000e0e0ef2f2' _
& 'f2ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffff2f2f20e0e0e000000020202020202000000a6a6a6fffffffcfcfcffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffcfcfcffffffa6a6a60000000202020202020000000e0e0ef2f2f2ffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcfcfcffffffa6a6a60000000202020202020000000e0e0ef2f2' _
& 'f2ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffff2f2f20e0e0e000000020202020202000000a6a6a6fffffffcfcfcffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffcfcfcffffffa6a6a60000000202020202020000000e0e0ef2f2f2ffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcfcfcffffffa6a6a60000000202020202020000000e0e0ef2f2' _
& 'f2ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffff2f2f20e0e0e000000020202020202000000a6a6a6fffffffcfcfcffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffcfcfcffffffa6a6a60000000202020202020000000e0e0ef2f2f2ffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcfcfcffffffa6a6a60000000202020202020000000e0e0ef2f2' _
& 'f2ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffff2f2f20e0e0e000000020202020202000000a6a6a6fffffffcfcfcffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffcfcfcffffffa6a6a60000000202020202020000000e0e0ef2f2f2ffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcfcfcffffffa6a6a60000000202020202020000000e0e0ef2f2' _
& 'f2ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffff2f2f20e0e0e000000020202020202000000a6a6a6fffffffcfcfcffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffcfcfcffffffa6a6a60000000202020202020000000e0e0ef2f2f2ffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffefefefcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcf9f9f9ffffffa4a4a40000000202020202020000000e0e0eefef' _
& 'effffffffbfbfbfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfbfbfb' _
& 'ffffffefefef0e0e0e000000020202020202000000a4a4a4fffffff9f9f9fcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfd' _
& 'fdfdfefefeffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffcfcfcffffffa6a6a60000000202020202020000000e0e0ef2f2f2ffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffefefefefefeffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb0b0b00000000303030202020000000f0f0fffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffff0f0f0f000000020202030303000000b0b0b0ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffdfdfdffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffcfcfcffffffa6a6a60000000202020202020000000e0e0ef2f2f2ffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffd' _
& 'fdfdffffffffffffd8d8d8adadada6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a4a4a4b0b0b06c6c6c0000000202020101010000000909099d9d' _
& '9da8a8a8a5a5a5a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a5a5a5' _
& 'a8a8a89d9d9d0909090000000101010202020000006c6c6cb0b0b0a4a4a4a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6b7' _
& 'b7b7ecececfffffffffffffefefeffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffcfcfcffffffa6a6a60000000202020202020000000e0e0ef2f2f2ffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffdfdfdff' _
& 'ffffe4e4e45151510505050000000000000000000000000000000000000000000000000000000000000000000000000101010000000000000101010000000000' _
& '00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000' _
& '00000000000000000001010100000000000001010100000000000000000000000000000000000000000000000000000000000000000000000000000000000000' _
& '0000131313818181fffffffffffffefefeffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffcfcfcffffffa6a6a60000000202020202020000000e0e0ef2f2f2ffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffefefeffffffe3' _
& 'e3e32020200000000000000202020202020202020202020202020202020202020202020202020202020303030202020000000101010101010000000101010202' _
& '02020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202' _
& '02020202020201010100000001010101010100000002020203030302020202020202020202020202020202020202020202020202020202020202020202020202' _
& '02020000000000005f5f5fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffcfcfcffffffa6a6a60000000202020202020000000e0e0ef2f2f2ffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffefefeffffff51' _
& '51510000000707070101010101010202020202020202020202020202020202020202020202020202020202020202020101010101010101010101010101010202' _
& '02020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202' _
& '02020202020201010101010101010101010101010102020202020202020202020202020202020202020202020202020202020202020202020202020201010101' _
& '0101020202050505000000a2a2a2fffffffcfcfcffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffcfcfcffffffa6a6a60000000202020202020000000e0e0ef2f2f2ffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffefefeffffffd8d8d805' _
& '05050000000101010101010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000' _
& '00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000' _
& '00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001' _
& '01010000000404040000003f3f3fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffcfcfcffffffa6a6a60000000202020202020000000e0e0ef2f2f2ffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcfcfcffffffacacac00' _
& '00000202020101010000000101010d0d0d0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e' _
& '0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e' _
& '0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0f0f0f09090900' _
& '0000010101020202000000151515f4f4f4ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffcfcfcffffffa6a6a60000000202020202020000000e0e0ef2f2f2ffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcfcfcffffffa6a6a600' _
& '00000202020202020000000d0d0de5e5e5f6f6f6f1f1f1f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2' _
& 'f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2' _
& 'f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2efefefffffff9e9e9e00' _
& '00000202020202020000000e0e0ef2f2f2fffffffffffffffffffffffffffffffffffffffffffffffffdfdfdfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfc' _
& 'fcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcf9f9f9ffffffa4a4a40000000202020202020000000e0e0eefefeffffffffbfbfbfcfcfcfcfcfcfcfcfc' _
& 'fcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfefefefffffffffffffffffffffffffffffffffffffcfcfcffffffa6a6a600' _
& '00000202020202020000000e0e0ef6f6f6ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffaaaaaa00' _
& '00000202020202020000000e0e0ef2f2f2fffffffffffffffffffffffffffffffffffffdfdfdffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffb0b0b00000000303030202020000000f0f0fffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffefefefefefefffffffffffffffffffffffffcfcfcffffffa6a6a600' _
& '00000202020202020000000e0e0ef1f1f1fffffffefefeffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffbfbfbffffffa6a6a600' _
& '00000202020202020000000e0e0ef2f2f2fffffffffffffffffffffffffffffffdfdfdfffffffdfdfdc6c6c6a7a7a7a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6' _
& 'a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a4a4a4b0b0b06c6c6c0000000202020101010000000909099d9d9da8a8a8a5a5a5a6a6a6a6a6a6a6a6a6' _
& 'a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6adadadd9d9d9fffffffffffffdfdfdfffffffffffffffffffcfcfcffffffa6a6a600' _
& '00000202020202020000000e0e0ef2f2f2ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcfcfcffffffa7a7a700' _
& '00000202020202020000000e0e0ef2f2f2fffffffffffffffffffffffffdfdfdffffffb7b7b72b2b2b0000000000000000000000000000000000000000000000' _
& '00000000000000000000000000000000000000000000000000000000000000010101000000000000010101000000000000000000000000000000000000000000' _
& '000000000000000000000000000000000000000000000000000000000000000000050505515151e3e3e3fffffffdfdfdfffffffffffffcfcfcffffffa6a6a600' _
& '00000202020202020000000e0e0ef2f2f2ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcfcfcffffffa7a7a700' _
& '00000202020202020000000e0e0ef2f2f2fffffffffffffffffffdfdfdffffffa8a8a80000000000000101010202020202020202020202020202020202020202' _
& '02020202020202020202020202020202020202020202020202030303020202000000010101010101000000010101020202020202020202020202020202020202' _
& '020202020202020202020202020202020202020202020202020202020202020202000000000000202020e4e4e4fffffffefefefffffffcfcfcffffffa6a6a600' _
& '00000202020202020000000e0e0ef2f2f2ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcfcfcffffffa7a7a700' _
& '00000202020202020000000e0e0ef2f2f2fffffffffffffefefeffffffe5e5e51010100000000505050101010101010202020202020202020202020202020202' _
& '02020202020202020202020202020202020202020202020202020202020202010101010101010101010101010101020202020202020202020202020202020202' _
& '020202020202020202020202020202020202020202020202020202020202010101010101070707000000515151fffffffefefefffffffcfcfcffffffa6a6a600' _
& '00000202020202020000000e0e0ef2f2f2ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffffffffffefefefdfdfdfffffffffffffffffffcfcfcffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcfcfcffffffa7a7a700' _
& '00000202020202020000000e0e0ef2f2f2fffffffffffffbfbfbffffff8c8c8c0000000505050000000101010000000000000000000000000000000000000000' _
& '00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000' _
& '000000000000000000000000000000000000000000000000000000000000000000010101010101000000050505d9d9d9fffffffefefefcfcfcffffffa6a6a600' _
& '00000202020202020000000e0e0ef2f2f2ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffffdfdfdfffffffffffff7f7f7f2f2f2fefefefffffffffffffefefeffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcfcfcffffffa7a7a700' _
& '00000202020202020000000e0e0ef2f2f2fffffffefefefdfdfdffffff6161610000000404040101010000000505050f0f0f0e0e0e0e0e0e0e0e0e0e0e0e0e0e' _
& '0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e' _
& '0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0d0d0d010101000000010101020202000000adadadfffffffcfcfcfcfcfcffffffa6a6a600' _
& '00000202020202020000000e0e0ef2f2f2ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffcfcfcffffffe3e3e36565652020201010102f2f2f8c8c8cfffffffffffffdfdfdffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcfcfcffffffa7a7a700' _
& '00000202020202020000000e0e0ef2f2f2fffffffefefefefefeffffff5a5a5a000000040404040404000000555555fbfbfbf0f0f0f2f2f2f2f2f2f2f2f2f2f2' _
& 'f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2' _
& 'f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f1f1f1f5f5f5e5e5e50e0e0e000000020202020202000000a6a6a6fffffffcfcfcfcfcfcffffffa6a6a600' _
& '00000202020202020000000e0e0ef2f2f2ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffbfbfbffffffd1d1d11818180000000000000000000000000000004d4d4dfdfdfdfffffffdfdfdffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcfcfcffffffa7a7a700' _
& '00000202020202020000000e0e0ef2f2f2fffffffefefefefefeffffff5a5a5a0000000404040404040000005b5b5bffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffffffff6f6f6101010000000020202020202000000a6a6a6fffffffcfcfcfcfcfcffffffa6a6a600' _
& '00000202020202020000000e0e0ef2f2f2ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffbfbfbffffffd1d1d1131313000000060606020202010101030303060606000000494949fdfdfdfffffffdfdfdffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcfcfcffffffa7a7a700' _
& '00000202020202020000000e0e0ef2f2f2fffffffefefefefefeffffff5a5a5a0000000404040404040000005a5a5afffffffdfdfdfefefeffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffefefefefefefffffffffffffffffffffffffffffffffffffffffffffffffffffffefefefefefeffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffefefefffffff1f1f10f0f0f000000020202020202000000a6a6a6fffffffcfcfcfcfcfcffffffa6a6a600' _
& '00000202020202020000000e0e0ef2f2f2ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffbfbfbffffffd1d1d1131313000000040404000000010101020202000000010101050505000000484848fdfdfdfffffffdfdfd' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcfcfcffffffa7a7a700' _
& '00000202020202020000000e0e0ef2f2f2fffffffefefefefefeffffff5a5a5a0000000404040404040000005a5a5afffffffefefeffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffdfdfdfcfcfcfcfcfcfdfdfdfffffffffffffffffffffffffffffffffffffffffffcfcfcfdfdfdfcfcfcfefefeffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffffffff2f2f20f0f0f000000020202020202000000a6a6a6fffffffcfcfcfcfcfcffffffa6a6a600' _
& '00000202020202020000000e0e0ef2f2f2ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffbfbfbffffffd1d1d1131313000000040404000000020202000000000000030303000000000000050505000000494949fdfdfdffffff' _
& 'fdfdfdfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcfcfcffffffa7a7a700' _
& '00000202020202020000000e0e0ef2f2f2fffffffefefefefefeffffff5a5a5a0000000404040404040000005a5a5afffffffefefeffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffdfdfdfffffffffffffffffffffffffdfdfdfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffefefe' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffffffff2f2f20f0f0f000000020202020202000000a6a6a6fffffffcfcfcfcfcfcffffffa6a6a600' _
& '00000202020202020000000e0e0ef2f2f2ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffbfbfbffffffd1d1d1131313000000040404000000020202000000030303282828000000030303000000000000050505000000494949fdfdfd' _
& 'fffffffdfdfdfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcfcfcffffffa7a7a700' _
& '00000202020202020000000e0e0ef2f2f2fffffffefefefefefeffffff5a5a5a0000000404040404040000005a5a5afffffffefefeffffffffffffffffffffff' _
& 'fffffffffffffffffffffdfdfdffffffc8c8c8636363666666cbcbcbfffffffdfdfdffffffffffffffffffffffffffffff9f9f9f5959597b7b7bedededffffff' _
& 'fefefefffffffffffffffffffffffffffffffffffffffffffffffff2f2f20f0f0f000000020202020202000000a6a6a6fffffffcfcfcfcfcfcffffffa6a6a600' _
& '00000202020202020000000e0e0ef2f2f2ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffbfbfbffffffd1d1d11313130000000404040000000202020101010000008e8e8efefefe464646000000050505000000000000050505000000494949' _
& 'fdfdfdfffffffdfdfdfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcfcfcffffffa7a7a700' _
& '00000202020202020000000e0e0ef2f2f2fffffffefefefefefeffffff5a5a5a0000000404040404040000005a5a5afffffffefefeffffffffffffffffffffff' _
& 'fffffffffffffffdfdfdffffffc8c8c8040404000000000000050505c8c8c8fffffffdfdfdfffffffdfdfdffffff868686000000000000000000393939fafafa' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffffffff2f2f20f0f0f000000020202020202000000a6a6a6fffffffcfcfcfcfcfcffffffa6a6a600' _
& '00000202020202020000000e0e0ef2f2f2ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffbfbfbffffffd1d1d11313130000000404040000000202020101010000008c8c8cfffffffffffffcfcfc464646000000050505000000000000050505000000' _
& '494949fdfdfdfffffffdfdfdfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcfcfcffffffa7a7a700' _
& '00000202020202020000000e0e0ef2f2f2fffffffefefefefefeffffff5a5a5a0000000404040404040000005a5a5afffffffefefeffffffffffffffffffffff' _
& 'fffffffffffffffdfdfdffffff636363000000090909090909000000636363fffffffcfcfcfefefefffffff7f7f7191919000000070707050505000000b2b2b2' _
& 'fffffffcfcfcfffffffffffffffffffffffffffffffffffffffffff2f2f20f0f0f000000020202020202000000a6a6a6fffffffcfcfcfcfcfcffffffa6a6a600' _
& '00000202020202020000000e0e0ef2f2f2fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffbfb' _
& 'fbffffffd1d1d11313130000000404040000000202020101010000008c8c8cfffffffefefefcfcfcfffffffcfcfc464646000000050505000000000000050505' _
& '000000494949fdfdfdfffffffdfdfdfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcfcfcffffffa7a7a700' _
& '00000202020202020000000e0e0ef2f2f2fffffffefefefefefeffffff5a5a5a0000000404040404040000005a5a5afffffffefefeffffffffffffffffffffff' _
& 'fffffffffffffffcfcfcffffff656565000000090909090909000000656565fffffffcfcfcfefefefffffff6f6f6171717000000070707050505000000b4b4b4' _
& 'fffffffcfcfcfffffffffffffffffffffffffffffffffffffffffff2f2f20f0f0f000000020202020202000000a6a6a6fffffffcfcfcfcfcfcffffffa6a6a600' _
& '00000202020202020000000e0e0ef2f2f2fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffbfbfbffff' _
& 'ffd1d1d11313130000000404040000000202020101010000008c8c8cfffffffdfdfdfffffffffffffdfdfdfffffffcfcfc464646000000050505000000000000' _
& '050505000000494949fdfdfdfffffffdfdfdfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcfcfcffffffa7a7a700' _
& '00000202020202020000000e0e0ef2f2f2fffffffefefefefefeffffff5a5a5a0000000404040404040000005a5a5afffffffefefeffffffffffffffffffffff' _
& 'fffffffffffffffdfdfdffffffc8c8c8030303000000000000040404c9c9c9fffffffdfdfdfffffffdfdfdffffff828282000000000000000000393939fafafa' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffffffff2f2f20f0f0f000000020202020202000000a6a6a6fffffffcfcfcfcfcfcffffffa6a6a600' _
& '00000202020202020000000e0e0ef2f2f2fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffbfbfbffffffd1d1' _
& 'd11313130000000404040000000202020101010000008b8b8bfffffffdfdfdfffffffffffffffffffffffffdfdfdfffffffcfcfc464646000000050505000000' _
& '010101050505000000494949fdfdfdfffffffdfdfdfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcfcfcffffffa7a7a700' _
& '00000202020202020000000e0e0ef2f2f2fffffffefefefefefeffffff5a5a5a0000000404040404040000005a5a5afffffffefefeffffffffffffffffffffff' _
& 'fffffffffffffffffffffefefeffffffc7c7c7636363646464cacacafffffffdfdfdffffffffffffffffffffffffffffffa1a1a15a5a5a7d7d7dedededffffff' _
& 'fefefefffffffffffffffffffffffffffffffffffffffffffffffff2f2f20f0f0f000000020202020202000000a6a6a6fffffffcfcfcfcfcfcffffffa6a6a600' _
& '00000202020202020000000e0e0ef2f2f2fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffbfbfbffffffd1d1d11313' _
& '130000000404040000000202020000000000008a8a8afffffffbfbfbfffffffffffffffffffffffffffffffffffffcfcfcfffffffafafa454545000000030303' _
& '010101000000050505000000494949fefefefffffffdfdfdfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcfcfcffffffa7a7a700' _
& '00000202020202020000000e0e0ef2f2f2fffffffefefefefefeffffff5a5a5a0000000404040404040000005a5a5afffffffefefeffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffefefefffffffffffffffffffffffffefefefffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffefefe' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffffffff2f2f20f0f0f000000020202020202000000a6a6a6fffffffcfcfcfcfcfcffffffa6a6a600' _
& '00000202020202020000000e0e0ef2f2f2fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffbfbfbffffffd1d1d11313130000' _
& '00040404000000010101010101000000959595fffffffffffffffffffdfdfdfffffffffffffffffffffffffefefeffffffffffffffffffffffff515151000000' _
& '020202010101010101050505000000494949fefefefffffffdfdfdfffffffffffffffffffffffffffffffffffffffffffffffffffffffcfcfcffffffa7a7a700' _
& '00000202020202020000000e0e0ef2f2f2fffffffefefefefefeffffff5a5a5a0000000404040404040000005a5a5afffffffefefeffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffdfdfdfdfdfdfcfcfcfdfdfdfffffffffffffffffffffffffffffffffffffffffffcfcfcfdfdfdfcfcfcfefefeffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffffffff2f2f20f0f0f000000020202020202000000a6a6a6fffffffcfcfcfcfcfcffffffa6a6a600' _
& '00000202020202020000000e0e0ef2f2f2fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffbfbfbffffffd2d2d21313130000000404' _
& '040000000101010101010000001515156262625757575f5f5fc4c4c4fffffffcfcfcfffffffffffffefefeffffffffffff999999545454606060515151010101' _
& '000000010101000000010101050505000000494949fefefefffffffdfdfdfffffffffffffffffffffffffffffffffffffffffffffffffcfcfcffffffa7a7a700' _
& '00000202020202020000000e0e0ef2f2f2fffffffefefefefefeffffff5a5a5a0000000404040404040000005a5a5afffffffefefeffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffefefefefefefffffffffffffffffffffffffffffffffffffffffffffffffffffffefefefefefeffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffffffff2f2f20f0f0f000000020202020202000000a6a6a6fffffffcfcfcfcfcfcffffffa6a6a600' _
& '00000202020202020000000e0e0ef2f2f2fffffffffffffffffffffffffffffffffffffffffffffffffffffffbfbfbffffffd2d2d21313130000000404040000' _
& '00010101010101000000010101000000000000000000000000000000afafaffffffffcfcfcfefefeffffffffffff696969000000000000000000000000010101' _
& '010101000000010101000000010101050505000000494949fefefefffffffdfdfdfffffffffffffffffffffffffffffffffffffffffffcfcfcffffffa7a7a700' _
& '00000202020202020000000e0e0ef2f2f2fffffffefefefefefeffffff5a5a5a0000000404040404040000005a5a5afffffffefefeffffffffffffffffffffff' _
& 'fffffffffdfdfdfdfdfdffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffcfcfcfefefefffffffffffffffffffffffffffffffffffff2f2f20f0f0f000000020202020202000000a6a6a6fffffffcfcfcfcfcfcffffffa6a6a600' _
& '00000202020202020000000e0e0ef2f2f2fffffffffffffffffffffffffffffffffffffffffffffffffbfbfbffffffd2d2d21313130000000404040000000101' _
& '01010101000000010101000000010101040404040404060606000000000000b0b0b0fffffffefefeffffff696969000000040404050505040404030303010101' _
& '000000010101000000010101000000010101050505000000494949fefefefffffffdfdfdfffffffffffffffffffffffffffffffffffffcfcfcffffffa7a7a700' _
& '00000202020202020000000e0e0ef2f2f2fffffffefefefefefeffffff5a5a5a0000000404040404040000005a5a5afffffffefefeffffffffffffffffffffff' _
& 'fffdfdfdfffffffffffff6f6f6f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2' _
& 'fcfcfcfffffffffffffdfdfdfffffffffffffffffffffffffffffff2f2f20f0f0f000000020202020202000000a6a6a6fffffffcfcfcfcfcfcffffffa6a6a600' _
& '00000202020202020000000e0e0ef2f2f2fffffffffffffffffffffffffffffffffffffffffffbfbfbffffffd2d2d21414140000000404040000000101010404' _
& '04040404040404040404040404040404040404010101000000030303000000000000b0b0b0ffffff676767000000030303010101000000020202040404040404' _
& '040404040404040404040404030303000000010101050505000000494949fefefefffffffdfdfdfffffffffffffffffffffffffffffffcfcfcffffffa7a7a700' _
& '00000202020202020000000e0e0ef2f2f2fffffffefefefefefeffffff5a5a5a0000000404040404040000005a5a5afffffffefefefffffffffffffffffffdfd' _
& 'fdffffffcccccc5959591e1e1e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e101010' _
& '2c2c2c7a7a7aefefeffffffffdfdfdfffffffffffffffffffffffff2f2f20f0f0f000000020202020202000000a6a6a6fffffffcfcfcfcfcfcffffffa6a6a600' _
& '00000202020202020000000e0e0ef2f2f2fffffffffffffffffffffffffffffffffffffcfcfcffffffd2d2d21414140000000404040000000101010101010000' _
& '000000000000000000000000000000000000000000000202020000000303030000000e0e0e4b4b4b000000020202010101000000030303000000000000000000' _
& '000000000000000000000000000000030303000000010101050505000000494949fdfdfdfffffffdfdfdfffffffffffffffffffffffffcfcfcffffffa7a7a700' _
& '00000202020202020000000e0e0ef2f2f2fffffffefefefefefeffffff5a5a5a0000000404040404040000005a5a5afffffffefefefffffffffffffdfdfdffff' _
& 'ffa3a3a3000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000' _
& '000000000000252525ddddddfffffffdfdfdfffffffffffffffffff2f2f20f0f0f000000020202020202000000a6a6a6fffffffcfcfcfcfcfcffffffa6a6a600' _
& '00000202020202020000000e0e0ef2f2f2fffffffffffffffffffffffffffffffcfcfcffffffd5d5d51414140000000404040000000202020000000000004e4e' _
& '4e5d5d5d5959595a5a5a5a5a5a5b5b5b5858580707070000000303030000000202020000000000000303030101010000000404040000002424245f5f5f595959' _
& '5a5a5a5a5a5a5959596060603232320000000404040000000101010505050000004b4b4bfffffffffffffefefefffffffffffffffffffcfcfcffffffa7a7a700' _
& '00000202020202020000000e0e0ef2f2f2fffffffefefefefefeffffff5a5a5a0000000404040404040000005a5a5afffffffefefefffffffdfdfdffffffcccc' _
& 'cc000000000000060606020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202' _
& '030303070707000000353535fdfdfdfffffffffffffffffffffffff2f2f20f0f0f000000020202020202000000a6a6a6fffffffcfcfcfcfcfcffffffa6a6a600' _
& '00000202020202020000000e0e0ef2f2f2fffffffffffffffffffffffffefefeffffffececec2121210000000505050000000202020101010000008a8a8affff' _
& 'ffffffffffffffffffffffffffffffffffffffafafaf0000000000000303030000000101010303030101010000000505050000002a2a2ae6e6e6ffffffffffff' _
& 'fffffffffffffffffffffffff9f9f9464646000000050505000000010101050505000000656565fffffffdfdfdfffffffffffffffffffcfcfcffffffa7a7a700' _
& '00000202020202020000000e0e0ef2f2f2fffffffefefefefefeffffff5a5a5a0000000404040404040000005a5a5afffffffefefefffffffdfdfdffffff5858' _
& '58000000060606000000000000020202030303020202020202020202020202020202020202020202020202020202020202020202020202020202020202010101' _
& '000000010101050505000000a8a8a8fffffffcfcfcfffffffffffff2f2f20f0f0f000000020202020202000000a6a6a6fffffffcfcfcfcfcfcffffffa6a6a600' _
& '00000202020202020000000e0e0ef2f2f2fffffffffffffffffffffffffdfdfdffffff5858580000000606060000000202020101010000008a8a8afffffffefe' _
& 'fefdfdfdfefefefefefefefefefdfdfdfcfcfcffffffb1b1b10000000000000303030000000101010000000505050000002a2a2ae9e9e9fffffffbfbfbfefefe' _
& 'fefefefefefefefefefcfcfcfffffffbfbfb454545000000050505000000010101030303000000a8a8a8fffffffcfcfcfffffffffffffcfcfcffffffa6a6a600' _
& '00000202020202020000000e0e0ef2f2f2fffffffefefefefefeffffff5a5a5a0000000404040404040000005a5a5afffffffefefefefefefffffff6f6f61e1e' _
& '1e000000020202000000010101000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000' _
& '0101010000000505050000006a6a6afffffffcfcfcfefefefffffff2f2f20f0f0f000000020202020202000000a6a6a6fffffffcfcfcfcfcfcffffffa6a6a600' _
& '00000202020202020000000e0e0ef2f2f2fffffffffffffffffffcfcfcffffffbababa0000000303030101010101010101010000008a8a8afffffffdfdfdfefe' _
& 'fefffffffffffffffffffffffffffffffffffffbfbfbffffffb1b1b10000000000000404040101010606060000002a2a2ae9e9e9fffffffcfcfcffffffffffff' _
& 'fffffffffffffffffffffffffcfcfcfffffffcfcfc454545000000040404000000030303000000242424f6f6f6fffffffffffffffffffcfcfcffffffa7a7a700' _
& '00000202020202020000000e0e0ef2f2f2fffffffefefefefefeffffff5a5a5a0000000404040404040000005a5a5afffffffefefefefefefffffff2f2f20e0e' _
& '0e0000000202020202020000006c6c6cb0b0b0a4a4a4a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a5a5a5acacac3b3b3b' _
& '0000000303030404040000005a5a5afffffffefefefefefefffffff2f2f20f0f0f000000020202020202000000a6a6a6fffffffcfcfcfcfcfcffffffa6a6a600' _
& '00000202020202020000000e0e0ef2f2f2fffffffffffffffffffefefeffffff4c4c4c0000000404040101010303030000007f7f7ffffffffdfdfdffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffbfbfbffffffb1b1b1000000000000000000000000292929e9e9e9fffffffcfcfcffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffdfdfdfffffffbfbfb3838380000000303030000000404040000009d9d9dfffffffcfcfcfffffffcfcfcffffffa6a6a600' _
& '00000202020202020000000e0e0ef2f2f2fffffffefefefefefeffffff5a5a5a0000000404040404040000005a5a5afffffffefefefefefefffffff2f2f20e0e' _
& '0e000000020202030303000000b0b0b0ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff616161' _
& '0000000404040404040000005a5a5afffffffefefefefefefffffff2f2f20f0f0f000000020202020202000000a6a6a6fffffffcfcfcfcfcfcffffffa6a6a600' _
& '00000202020202020000000e0e0ef2f2f2fffffffffffffefefeffffffdedede090909000000010101030303000000444444fffffffffffffefefeffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffffcfcfcffffffb4b4b42626260b0b0b4a4a4ae6e6e6fffffffcfcfcffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffcfcfcffffffdbdbdb0b0b0b000000020202040404000000474747fffffffffffffffffffcfcfcffffffa6a6a600' _
& '00000202020202020000000e0e0ef2f2f2fffffffefefefefefeffffff5a5a5a0000000404040404040000005a5a5afffffffefefefefefefffffff2f2f20e0e' _
& '0e000000020202020202000000a4a4a4fffffff9f9f9fcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfafafaffffff5a5a5a' _
& '0000000404040404040000005a5a5afffffffefefefefefefffffff2f2f20f0f0f000000020202020202000000a6a6a6fffffffcfcfcfcfcfcffffffa6a6a600' _
& '00000202020202020000000e0e0ef2f2f2fffffffffffffcfcfcffffffa2a2a2000000030303010101010101000000bfbfbffffffffcfcfcffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffffffffffdfdfdfffffffcfcfcf0f0f0fffffffffffffdfdfdffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffbfbfbffffff6e6e6e000000040404010101000000101010ebebebfffffffefefefcfcfcffffffa6a6a600' _
& '00000202020202020000000e0e0ef2f2f2fffffffefefefefefeffffff5a5a5a0000000404040404040000005a5a5afffffffefefefefefefffffff2f2f20e0e' _
& '0e000000020202020202000000a6a6a6fffffffcfcfcfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffefefeffffff5b5b5b' _
& '0000000404040404040000005a5a5afffffffefefefefefefffffff2f2f20f0f0f000000020202020202000000a6a6a6fffffffcfcfcfcfcfcffffffa6a6a600' _
& '00000202020202020000000e0e0ef2f2f2fffffffefefefbfbfbffffff787878000000050505020202000000252525fafafaffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffdfdfdfffffffffffffffffffefefeffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffdfdfdffffffbdbdbd000000010101020202000000000000c5c5c5fffffffdfdfdfcfcfcffffffa6a6a600' _
& '00000202020202020000000e0e0ef2f2f2fffffffefefefefefeffffff5a5a5a0000000404040404040000005a5a5afffffffefefefefefefffffff2f2f20e0e' _
& '0e000000020202020202000000a6a6a6fffffffcfcfcfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffefefeffffff5b5b5b' _
& '0000000404040404040000005a5a5afffffffefefefefefefffffff2f2f20f0f0f000000020202020202000000a6a6a6fffffffcfcfcfcfcfcffffffa6a6a600' _
& '00000202020202020000000e0e0ef2f2f2fffffffefefefdfdfdffffff6161610000000404040404040000004f4f4fffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcfcfcfbfbfbfcfcfcfbfbfbfdfdfdffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffefefeffffffe6e6e60b0b0b000000020202020202000000adadadfffffffcfcfcfcfcfcffffffa6a6a600' _
& '00000202020202020000000e0e0ef2f2f2fffffffefefefefefeffffff5a5a5a0000000404040404040000005a5a5afffffffefefefefefefffffff2f2f20e0e' _
& '0e000000020202020202000000a6a6a6fffffffcfcfcfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffefefeffffff5b5b5b' _
& '0000000404040404040000005a5a5afffffffefefefefefefffffff2f2f20f0f0f000000020202020202000000a6a6a6fffffffcfcfcfcfcfcffffffa6a6a600' _
& '00000202020202020000000e0e0ef2f2f2fffffffefefefefefeffffff5b5b5b000000040404040404000000585858fffffffefefeffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffffefefefffffffffffffffffffffffffffffffffffffdfdfdffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffefefefffffff0f0f00e0e0e000000020202020202000000a7a7a7fffffffcfcfcfcfcfcffffffa6a6a600' _
& '00000202020202020000000e0e0ef2f2f2fffffffefefefefefeffffff5a5a5a0000000404040404040000005a5a5afffffffefefefefefefffffff2f2f20e0e' _
& '0e000000020202020202000000a6a6a6fffffffcfcfcfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffefefeffffff5b5b5b' _
& '0000000404040404040000005a5a5afffffffefefefefefefffffff2f2f20f0f0f000000020202020202000000a6a6a6fffffffcfcfcfcfcfcffffffa6a6a600' _
& '00000202020202020000000e0e0ef2f2f2fffffffefefefdfdfdffffff676767000000050505030303000000424242ffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffdfdfdffffffffffffb3b3b36e6e6e6060607e7e7ed4d4d4fffffffefefeffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffefefeffffffdbdbdb080808000000020202010101000000b3b3b3fffffffcfcfcfcfcfcffffffa6a6a600' _
& '00000202020202020000000e0e0ef2f2f2fffffffefefefefefeffffff5a5a5a0000000404040404040000005a5a5afffffffefefefefefefffffff2f2f20e0e' _
& '0e000000020202020202000000a6a6a6fffffffcfcfcfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffefefeffffff5b5b5b' _
& '0000000404040404040000005a5a5afffffffefefefefefefffffff2f2f20f0f0f000000020202020202000000a6a6a6fffffffcfcfcfcfcfcffffffa6a6a600' _
& '00000202020202020000000e0e0ef2f2f2fffffffffffffbfbfbffffff858585000000050505020202000000131313ecececfffffffefefeffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffdfdfdfffffff9f9f9525252000000000000000000000000020202919191fffffffefefeffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffcfcfcffffffa6a6a6000000030303010101000000030303d2d2d2fffffffdfdfdfcfcfcffffffa6a6a600' _
& '00000202020202020000000e0e0ef2f2f2fffffffefefefefefeffffff5a5a5a0000000404040404040000005a5a5afffffffefefefefefefffffff2f2f20e0e' _
& '0e000000020202020202000000a6a6a6fffffffcfcfcfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffefefeffffff5b5b5b' _
& '0000000404040404040000005a5a5afffffffefefefefefefffffff2f2f20f0f0f000000020202020202000000a6a6a6fffffffcfcfcfcfcfcffffffa6a6a600' _
& '00000202020202020000000e0e0ef2f2f2fffffffffffffdfdfdffffffb7b7b7000000020202010101030303000000979797fffffffafafaffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffcfcfcfffffffbfbfb4444440000000404040505050404040505050000000000008a8a8afffffffdfdfdfefefeffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffdfdfdffffff4949490000000404040202020000001f1f1ff6f6f6fffffffffffffcfcfcffffffa6a6a600' _
& '00000202020202020000000e0e0ef2f2f2fffffffefefefefefeffffff5a5a5a0000000404040404040000005a5a5afffffffefefefefefefffffff2f2f20e0e' _
& '0e000000020202020202000000a6a6a6fffffffcfcfcfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffefefeffffff5b5b5b' _
& '0000000404040404040000005a5a5afffffffefefefefefefffffff2f2f20f0f0f000000020202020202000000a6a6a6fffffffcfcfcfcfcfcffffffa6a6a600' _
& '00000202020202020000000e0e0ef2f2f2fffffffffffffffffffffffff2f2f21b1b1b000000020202020202000000191919e8e8e8fffffffafafaffffffffff' _
& 'fffffffffffffffffffffffffffbfbfbfffffffbfbfb434343000000050505010101010101010101000000020202010101000000898989fffffffdfdfdfdfdfd' _
& 'fffffffffffffffffffffffffffffffefefefafafaffffffa6a6a6000000020202010101040404000000626262fffffffdfdfdfffffffcfcfcffffffa6a6a600' _
& '00000202020202020000000e0e0ef2f2f2fffffffefefefefefeffffff5a5a5a0000000404040404040000005a5a5afffffffefefefefefefffffff2f2f20e0e' _
& '0e000000020202020202000000a6a6a6fffffffcfcfcfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffefefeffffff5a5a5a' _
& '0000000404040404040000005a5a5afffffffefefefefefefffffff2f2f20e0e0e000000020202020202000000a6a6a6fffffffcfcfcfcfcfcffffffa6a6a600' _
& '00000202020202020000000e0e0ef2f2f2fffffffffffffffffffcfcfcffffff727272000000050505000000040404000000393939f3f3f3fffffffefefefbfb' _
& 'fbfcfcfcfcfcfcfbfbfbfefefefffffff6f6f6424242000000050505000000010101020202010101020202000000020202010101000000858585ffffffffffff' _
& 'fcfcfcfbfbfbfcfcfcfbfbfbfcfcfcffffffffffffbfbfbf090909000000020202010101020202000000c0c0c0fffffffdfdfdfffffffcfcfcffffffa6a6a600' _
& '00000202020202020000000e0e0ef2f2f2fffffffefefefefefeffffff5a5a5a0000000404040404040000005a5a5afffffffefefefefefefffffff2f2f20e0e' _
& '0e000000020202020202000000a6a6a6fffffffcfcfcfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffefefeffffff5a5a5a' _
& '0000000404040404040000005a5a5afffffffefefefefefefffffff2f2f20f0f0f000000020202020202000000a6a6a6fffffffcfcfcfcfcfcffffffa6a6a600' _
& '00000202020202020000000e0e0ef2f2f2fffffffffffffffffffefefeffffffe1e1e10e0e0e000000020202000000040404000000282828bebebeffffffffff' _
& 'ffffffffffffffffffffffffffc0c0c02b2b2b0000000404040000000000000202020000000000000000000303030000000202020101010000005e5e5ee3e3e3' _
& 'fffffffffffffffffffffffffffffff7f7f78d8d8d0505050000000303030000000505050000004b4b4bfffffffefefefffffffffffffcfcfcffffffa6a6a600' _
& '00000202020202020000000e0e0ef2f2f2fffffffefefefefefeffffff5a5a5a0000000404040404040000005a5a5afffffffefefefefefefffffff2f2f20e0e' _
& '0e000000020202020202000000a6a6a6fffffffcfcfcfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffefefeffffff5a5a5a' _
& '0000000404040404040000005a5a5afffffffefefefefefefffffff2f2f20f0f0f000000020202020202000000a6a6a6fffffffcfcfcfcfcfcffffffa6a6a600' _
& '00000202020202020000000e0e0ef2f2f2fffffffffffffffffffffffffcfcfcffffff9393930000000404040101010000000404040000000000003e3e3e8282' _
& '82a1a1a1a1a1a1838383404040000000000000040404000000010101050505000000535353c7c7c71616160000000404040000000101010202020000000e0e0e' _
& '5a5a5a919191a4a4a49a9a9a7070702323230000000000000303030000000303030000000a0a0ad9d9d9fffffffdfdfdfffffffffffffcfcfcffffffa6a6a600' _
& '00000202020202020000000e0e0ef2f2f2fffffffefefefefefeffffff5a5a5a0000000404040404040000005a5a5afffffffefefefefefefffffff2f2f20e0e' _
& '0e000000020202020202000000a6a6a6fffffffcfcfcfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffdfdfdffffff5a5a5a' _
& '0000000404040404040000005a5a5afffffffefefefefefefffffff2f2f20e0e0e000000020202020202000000a6a6a6fffffffcfcfcfcfcfcffffffa6a6a600' _
& '00000202020202020000000e0e0ef2f2f2fffffffffffffffffffffffffffffffefefeffffff5f5f5f0000000505050202020000000303030101010000000000' _
& '000000000000000000000000000101010303030000000101010505050000004b4b4bfbfbfbffffffd0d0d0141414000000050505000000010101040404000000' _
& '000000000000000000000000000000000000030303020202000000040404000000000000aaaaaafffffffcfcfcfffffffffffffffffffcfcfcffffffa6a6a600' _
& '00000202020202020000000e0e0ef2f2f2fffffffefefefefefeffffff5a5a5a0000000404040404040000005a5a5afffffffefefefefefefffffff2f2f20e0e' _
& '0e000000020202020202000000a5a5a5fffffffafafafefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefdfdfdfcfcfcffffff595959' _
& '0000000404040404040000005a5a5afffffffefefefefefefffffff2f2f20e0e0e000000020202020202000000a6a6a6fffffffcfcfcfcfcfcffffffa6a6a600' _
& '00000202020202020000000e0e0ef2f2f2fffffffffffffffffffffffffffffffefefeffffffffffff5757570000000101010404040101010101010303030505' _
& '05030303030303050505030303010101010101040404010101000000505050fefefefffffff9f9f9ffffffd3d3d31a1a1a000000050505030303010101010101' _
& '0404040404040202020404040505050202020101010202020505050000000000009d9d9dfffffffcfcfcfffffffffffffffffffffffffcfcfcffffffa6a6a600' _
& '00000202020202020000000e0e0ef2f2f2fffffffefefefefefeffffff5a5a5a0000000404040404040000005a5a5afffffffefefefefefefffffff2f2f20e0e' _
& '0e000000020202020202000000acacacffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff5d5d5d' _
& '0000000404040404040000005a5a5afffffffefefefefefefffffff2f2f20e0e0e000000020202020202000000a6a6a6fffffffcfcfcfcfcfcffffffa6a6a600' _
& '00000202020202020000000e0e0ef2f2f2fffffffffffffffffffffffffffffffffffffefefeffffffffffff7c7c7c0000000000000101010505050303030202' _
& '02020202020202020202030303050505010101000000000000777777fffffffffffffdfdfdfffffffbfbfbffffffe3e3e3404040000000000000030303050505' _
& '030303020202020202020202020202040404040404000000000000191919b7b7b7fffffffdfdfdfffffffffffffffffffffffffffffffcfcfcffffffa6a6a600' _
& '00000202020202020000000e0e0ef2f2f2fffffffefefefefefeffffff5a5a5a0000000404040404040000005a5a5afffffffefefefefefefffffff2f2f21010' _
& '100000000202020101010000003b3b3b5f5f5f5959595a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5959595d5d5d202020' _
& '0000000202020404040000005c5c5cfffffffdfdfdfefefefffffff2f2f20e0e0e000000020202020202000000a6a6a6fffffffcfcfcfcfcfcffffffa6a6a600' _
& '00000202020202020000000e0e0ef2f2f2fffffffffffffffffffffffffffffffffffffffffffefefeffffffffffffc7c7c74747470000000000000000000000' _
& '00000000000000000000000000000000000000454545c4c4c4fffffffffffffefefefffffffffffffffffffcfcfcffffffffffff989898242424000000000000' _
& '0000000000000000000000000000000000000000000f0f0f6f6f6febebebfffffffcfcfcfffffffffffffffffffffffffffffffffffffcfcfcffffffa6a6a600' _
& '00000202020202020000000e0e0ef2f2f2fffffffefefefefefeffffff5a5a5a0000000404040404040000005a5a5afffffffefefefffffffffffffbfbfb2c2c' _
& '2c000000030303000000010101000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000' _
& '010101000000050505000000787878fffffffcfcfcfefefefffffff2f2f20e0e0e000000020202020202000000a6a6a6fffffffcfcfcfcfcfcffffffa6a6a600' _
& '00000202020202020000000e0e0ef2f2f2fffffffffffffffffffffffffffffffffffffffffffffffffffffffcfcfcffffffffffffcbcbcb7e7e7e4747472323' _
& '231111111111112323234646467d7d7dcacacafffffffffffffdfdfdfffffffffffffffffffffffffffffffffffffdfdfdfffffffffffff8f8f8aeaeae686868' _
& '3838381b1b1b0f0f0f1515152d2d2d575757969696e5e5e5fffffffffffffcfcfcfffffffffffffffffffffffffffffffffffffffffffcfcfcffffffa6a6a600' _
& '00000202020202020000000e0e0ef2f2f2fffffffefefefefefeffffff5a5a5a0000000404040404040000005a5a5afffffffefefefffffffcfcfcffffff7a7a' _
& '7a000000070707010101000000030303040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404020202' _
& '000000020202020202000000c7c7c7fffffffdfdfdfffffffffffff2f2f20e0e0e000000020202020202000000a6a6a6fffffffcfcfcfcfcfcffffffa6a6a600' _
& '00000202020202020000000e0e0ef2f2f2fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffdfdfdfefefefffffffffffffffffff8f8' _
& 'f8f3f3f3f3f3f3f8f8f8fffffffffffffffffffefefefdfdfdfffffffffffffffffffffffffffffffffffffffffffffffffffffffcfcfcffffffffffffffffff' _
& 'fefefef6f6f6f2f2f2f4f4f4fbfbfbfffffffffffffffffffcfcfcfefefefffffffffffffffffffffffffffffffffffffffffffffffffcfcfcffffffa6a6a600' _
& '00000202020202020000000e0e0ef2f2f2fffffffefefefefefeffffff5a5a5a0000000404040404040000005a5a5afffffffefefefffffffefefeffffffefef' _
& 'ef252525000000050505050505040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404' _
& '0505050202020000006a6a6afffffffdfdfdfffffffffffffffffff2f2f20e0e0e000000020202020202000000a6a6a6fffffffcfcfcfcfcfcffffffa6a6a600' _
& '00000202020202020000000e0e0ef2f2f2fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffdfdfdfcfcfcffffffffff' _
& 'fffffffffffffffffffffffffffcfcfcfdfdfdfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcfcfcfcfcfc' _
& 'fffffffffffffffffffffffffffffffefefefcfcfcfefefefffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcfcfcffffffa6a6a600' _
& '00000202020202020000000e0e0ef2f2f2fffffffefefefefefeffffff5a5a5a0000000404040404040000005a5a5afffffffefefefffffffffffffdfdfdffff' _
& 'ffdddddd353535000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000' _
& '0000000000006a6a6afffffffffffffffffffffffffffffffffffff2f2f20e0e0e000000020202020202000000a6a6a6fffffffcfcfcfcfcfcffffffa6a6a600' _
& '00000202020202020000000e0e0ef2f2f2ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcfcfcffffffa6a6a600' _
& '00000202020202020000000e0e0ef2f2f2fffffffefefefefefeffffff5a5a5a0000000404040404040000005a5a5afffffffefefefffffffffffffffffffdfd' _
& 'fdfffffffdfdfda8a8a86969695a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5c5c5c' _
& '777777c6c6c6fffffffffffffefefefffffffffffffffffffffffff2f2f20e0e0e000000020202020202000000a6a6a6fffffffcfcfcfcfcfcffffffa6a6a600' _
& '00000202020202020000000e0e0ef2f2f2ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcfcfcffffffa6a6a600' _
& '00000202020202020000000e0e0ef2f2f2fffffffefefefefefeffffff5a5a5a0000000404040404040000005a5a5afffffffefefeffffffffffffffffffffff' _
& 'fffdfdfdffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffdfdfdfffffffffffffffffffffffffffffffffffff2f2f20e0e0e000000020202020202000000a6a6a6fffffffcfcfcfcfcfcffffffa6a6a600' _
& '00000202020202020000000e0e0ef2f2f2ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcfcfcffffffa6a6a600' _
& '00000202020202020000000e0e0ef2f2f2fffffffefefefefefeffffff5a5a5a0000000404040404040000005a5a5afffffffefefeffffffffffffffffffffff' _
& 'fffffffffffffffcfcfcfcfcfcfefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefdfdfd' _
& 'fcfcfcfdfdfdfffffffffffffffffffffffffffffffffffffffffff2f2f20e0e0e000000020202020202000000a6a6a6fffffffcfcfcfcfcfcffffffa6a6a600' _
& '00000202020202020000000e0e0ef1f1f1fffffffefefeffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffbfbfbffffffa5a5a500' _
& '00000202020202020000000e0e0ef2f2f2fffffffefefefefefeffffff5a5a5a0000000404040404040000005a5a5afffffffdfdfdfefefeffffffffffffffff' _
& 'fffffffffffffffffffffefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefe' _
& 'fefefefffffffffffffffffffffffffffffffffffffefefefffffff1f1f10e0e0e000000020202020202000000a6a6a6fffffffcfcfcfcfcfcffffffa6a6a600' _
& '00000202020202020000000e0e0ef6f6f6ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffa8a8a800' _
& '00000202020202020000000e0e0ef2f2f2fffffffefefefefefeffffff5a5a5a0000000404040404040000005b5b5bffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffffffff6f6f60e0e0e000000020202020202000000a6a6a6fffffffcfcfcfcfcfcffffffa6a6a600' _
& '00000202020202020000000d0d0de5e5e5f6f6f6f1f1f1f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2' _
& 'f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2' _
& 'f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2efefefffffff9d9d9d00' _
& '00000202020202020000000e0e0ef2f2f2fffffffefefefefefeffffff5a5a5a000000040404040404000000555555fbfbfbf0f0f0f2f2f2f2f2f2f2f2f2f2f2' _
& 'f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2' _
& 'f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f1f1f1f6f6f6e5e5e50d0d0d000000020202020202000000a6a6a6fffffffcfcfcfcfcfcffffffacacac00' _
& '00000202020101010000000101010d0d0d0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e' _
& '0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e' _
& '0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0f0f0f09090900' _
& '0000010101020202000000151515f4f4f4fffffffefefefdfdfdffffff6161610000000404040101010000000505050f0f0f0e0e0e0e0e0e0e0e0e0e0e0e0e0e' _
& '0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e' _
& '0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0d0d0d010101000000010101020202000000adadadfffffffcfcfcfefefeffffffd8d8d805' _
& '05050000000101010101010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000' _
& '00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000' _
& '00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001' _
& '01010000000404040000003f3f3ffffffffffffffffffffbfbfbffffff8c8c8c0000000505050000000101010000000000000000000000000000000000000000' _
& '00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000' _
& '000000000000000000000000000000000000000000000000000000000000000000010101010101000000050505d8d8d8fffffffefefefffffffefefeffffff51' _
& '51510000000707070101010101010202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202' _
& '02020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202' _
& '02020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020201010101' _
& '0101020202050505000000a1a1a1fffffffcfcfcfffffffefefeffffffe5e5e51010100000000505050101010101010202020202020202020202020202020202' _
& '02020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202' _
& '020202020202020202020202020202020202020202020202020202020202010101010101070707000000515151fffffffefefefffffffffffffefefeffffffe3' _
& 'e3e32020200000000000000202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202' _
& '02020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202' _
& '02020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202' _
& '02020000000000005e5e5efffffffffffffffffffffffffffffffdfdfdffffffa7a7a70000000000000101010202020202020202020202020202020202020202' _
& '02020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202' _
& '0202020202020202020202020202020202020202020202020202020202020202020000000000001f1f1fe3e3e3fffffffefefefffffffffffffffffffdfdfdff' _
& 'ffffe3e3e35151510505050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000' _
& '00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000' _
& '00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000'

global $logo_file_two = '0000131313818181fffffffffffffefefefffffffffffffffffffffffffdfdfdffffffb7b7b72b2b2b0000000000000000000000000000000000000000000000' _
& '00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000' _
& '000000000000000000000000000000000000000000000000000000000000000000050505515151e3e3e3fffffffdfdfdfffffffffffffffffffffffffffffffd' _
& 'fdfdffffffffffffd8d8d8acacaca6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6' _
& 'a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6' _
& 'a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6b6' _
& 'b6b6ecececfffffffffffffefefefffffffffffffffffffffffffffffffffffffdfdfdfffffffdfdfdc5c5c5a7a7a7a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6' _
& 'a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6' _
& 'a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6acacacd8d8d8fffffffffffffdfdfdffffffffffffffffffffffffffffffffffffff' _
& 'fffffefefefefefeffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffdfdfdfffffffffffffffffffffffffffffffffffffffffffffffffffffffdfdfdffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffefefefefefeffffffffffffffffffffffffffffffffffffffffffff' _
& 'fffffffffffffffffefefefcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfc' _
& 'fcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfc' _
& 'fcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfd' _
& 'fdfdfefefefffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffdfdfdfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfc' _
& 'fcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfc' _
& 'fcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfefefeffffffffffffffffffffffffffffffffffff'

global $qr_file = '0x424df2b200000000000036000000280000007b0000007b0000000100180000000000bcb20000c40e0000c40e00000000000000000000ffffffffffffffffffff' _
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
& 'ffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffff' _
& 'ffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000' _
& '000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff0000000000' _
& '00000000000000000000000000ffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffff000000000000000000000000' _
& '000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffff00000000' _
& '0000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff0000000000' _
& '00000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000' _
& '000000000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff0000000000000000000000000000000000' _
& '00ffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000' _
& '000000000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffff00000000000000000000000000000000' _
& '0000000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000' _
& '000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffffff' _
& 'ffffffffffffff000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff00000000000000000000000000000000000000000000000000000000' _
& '0000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffff00000000' _
& '0000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000ffff' _
& 'ffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffff000000000000000000ffffffffffffffffff00000000000000000000000000000000000000000000000000000000000000000000000000000000' _
& '0000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffff000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffff' _
& 'ffff000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffff' _
& 'ffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000' _
& '000000ffffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffff' _
& 'ffffffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ff000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000' _
& '000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff00000000000000000000' _
& '0000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffff0000000000000000' _
& '00ffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff00000000000000000000000000000000000000' _
& '0000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffff' _
& 'ffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000' _
& '000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff0000' _
& '00000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffff000000000000000000000000000000000000ffffffffffffffffff00000000000000000000000000000000000000000000000000000000000000' _
& '0000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff0000000000' _
& '00000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffff' _
& 'ffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff0000000000000000000000000000' _
& '00000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000' _
& '000000000000000000000000ffffffffffffffffff00000000000000000000000000000000000000000000000000000000000000000000000000000000000000' _
& '0000000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff000000000000000000' _
& 'ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00' _
& '0000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff0000000000000000000000000000000000000000000000000000' _
& '00ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000' _
& '000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff000000000000000000000000000000000000ff' _
& 'ffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff0000000000000000000000' _
& '00000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffff' _
& 'ffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffff' _
& 'ffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffff0000' _
& '00000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffff' _
& 'ffffffffffff000000000000000000000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff00000000' _
& '0000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffff' _
& 'ffffffff000000000000000000ffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000' _
& '000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffff00000000' _
& '0000000000ffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000' _
& '000000000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffff' _
& 'ffffffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff0000000000000000' _
& '00ffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffff' _
& 'ffff000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff0000000000000000' _
& '00000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000' _
& '000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ff' _
& 'ffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff0000000000000000000000000000000000000000' _
& '00000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffff' _
& 'ffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff00000000000000000000' _
& '0000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff0000000000000000000000000000000000000000' _
& '00000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff00000000' _
& '0000000000ffffffffffffffffff000000000000000000ffffffffffffffffff0000000000000000000000000000000000000000000000000000000000000000' _
& '00000000000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffff' _
& 'ffffff000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff00000000000000000000000000000000000000000000' _
& '0000000000ffffffffffffffffff000000000000000000ffffffffffffffffff0000000000000000000000000000000000000000000000000000000000000000' _
& '00000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffff' _
& 'ffff000000000000000000ffffffffffffffffff0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000' _
& '00ffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff000000ffffffffffff' _
& 'ffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffff000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000' _
& 'ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ff' _
& 'ffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff0000000000000000000000000000000000000000' _
& '00000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffff' _
& '000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ff' _
& 'ffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0000' _
& '00000000000000ffffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000' _
& '000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff00000000' _
& '0000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff0000000000000000000000000000000000000000000000000000000000000000' _
& '00000000000000000000000000ffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff00000000' _
& '0000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffff' _
& 'ffffffff000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffff' _
& 'ffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffff0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000' _
& '00ffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000' _
& '000000000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff00000000000000' _
& '0000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff0000000000000000000000000000000000000000000000000000' _
& '00000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000' _
& '000000000000000000ffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ff' _
& 'ffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffff000000ffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000' _
& '000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff00000000000000000000000000000000000000' _
& '0000000000000000ffffffffffffffffffffffffffffffffffff0000000000000000000000000000000000000000000000000000000000000000000000000000' _
& '00000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffff' _
& 'ffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff00000000' _
& '0000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000ffff' _
& 'ffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000' _
& '000000000000000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffff' _
& 'ffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffffffffff' _
& 'ffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff000000000000' _
& '000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff00000000000000000000000000000000' _
& '0000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff00000000000000' _
& '0000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffff' _
& 'ff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff' _
& '000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffff' _
& 'ffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& '000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff00000000000000000000000000000000000000' _
& '0000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffff' _
& 'ffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff00000000' _
& '0000000000ffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffff' _
& 'ffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffff' _
& 'ffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff0000000000' _
& '00000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffff' _
& 'ffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffff' _
& 'ffffffff000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffff0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000' _
& '00ffffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000' _
& '000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff00' _
& '0000ffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffff0000000000000000' _
& '00000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffff0000' _
& '00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffff' _
& 'ffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffff0000000000000000000000000000000000000000' _
& '00000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000' _
& '000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00000000' _
& '0000000000000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffff0000000000000000000000000000' _
& '00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffff' _
& 'ffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffff00000000000000' _
& '0000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000' _
& '000000000000000000ffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffff000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff0000000000000000' _
& '00000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& '000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffff' _
& 'ffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffff' _
& 'ffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffff' _
& 'ffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00000000000000000000' _
& '0000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffff' _
& 'ffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000' _
& '000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff00000000' _
& '0000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff0000000000' _
& '00000000ffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffff' _
& 'ffffff000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffff' _
& 'ffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffff0000000000000000000000000000' _
& '00000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffff' _
& 'ff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000ffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffffff' _
& 'ffff000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffff' _
& 'ff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff00' _
& '0000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff00000000000000000000' _
& '0000000000000000000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffff' _
& 'ffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff00000000000000000000000000' _
& '0000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff0000000000000000000000000000' _
& '00000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffff' _
& 'ffffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffff00000000000000' _
& '0000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff0000000000000000' _
& '00ffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffff' _
& 'ffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000' _
& '000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffff' _
& 'ffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffff' _
& 'ffffffffffffff000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff0000' _
& '00000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000000000000000000000000000' _
& '000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff00000000' _
& '0000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000ffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff000000' _
& '000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff00000000' _
& '0000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff0000000000' _
& '00000000000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000' _
& '000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff00000000000000000000000000000000' _
& '0000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000000000000000' _
& '000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff00000000000000000000000000000000' _
& '0000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff0000000000000000000000000000000000' _
& '00000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000000000000000000000' _
& '000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff00' _
& '0000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000000000000000000000000000000000000000' _
& '000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000ff' _
& 'ffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff0000000000000000000000000000000000000000000000000000000000' _
& '00000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffff' _
& 'ffffffffffff000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff00000000000000000000000000' _
& '0000000000ffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffff0000000000000000000000000000000000000000' _
& '00000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff000000' _
& '000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffff' _
& 'ffffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff0000000000000000000000000000000000000000000000' _
& '00000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000000000000000000000000000000000' _
& '000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000000000000000' _
& '000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff00000000000000' _
& '0000000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffff' _
& 'ffffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00' _
& '0000ffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff000000000000000000000000000000000000ff' _
& 'ffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff0000' _
& '00000000000000ffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffff' _
& 'ffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffff0000' _
& '00000000000000ffffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffffff' _
& 'ffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffff00000000' _
& '0000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff0000000000000000000000000000' _
& '00000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000' _
& '000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffff00000000' _
& '0000000000000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffff' _
& 'ffffffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000' _
& '000000000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffff00000000000000000000000000000000' _
& '0000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff0000000000000000000000000000000000000000000000000000' _
& '00ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffff00000000000000000000000000000000' _
& '0000000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff0000000000000000' _
& '00000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000000000000000000000' _
& '000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000000000000000000000000000000000000000ff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffff0000' _
& '00000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ff' _
& 'ffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff0000' _
& '00000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000' _
& '000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffff000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffff' _
& 'ffffff000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffff' _
& 'ffffffffff000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffff' _
& 'ffffffffffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00000000000000' _
& '0000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff0000000000000000' _
& '00ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000ffffffffffff' _
& 'ffffffffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff00000000000000' _
& '0000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffff' _
& 'ff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ff' _
& 'ffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffff00000000000000000000' _
& '0000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff0000' _
& '00000000000000ffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000000000' _
& '000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffff' _
& 'ffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff0000000000' _
& '00000000000000000000000000ffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffff' _
& 'ffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffff' _
& 'ffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffff' _
& 'ffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffff' _
& 'ffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff0000000000000000000000000000000000' _
& '00ffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000' _
& '000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffffff' _
& 'ffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff0000000000000000' _
& '00000000000000000000000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff' _
& '000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ff' _
& 'ffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffffff' _
& 'ffffffffffffff000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff' _
& '000000000000000000000000000000000000ffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffff00' _
& '0000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff0000000000000000000000000000000000000000' _
& '00000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffff' _
& 'ffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000ffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff000000000000000000000000' _
& '000000000000ffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffff' _
& 'ffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff0000000000000000000000000000000000000000000000000000000000000000' _
& '00000000000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff000000000000' _
& '000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffff' _
& 'ffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffff' _
& 'ffff000000000000000000ffffffffffffffffff0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000' _
& '00ffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff' _
& '000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ff' _
& 'ffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000' _
& '000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff00' _
& '0000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffff' _
& 'ffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff000000' _
& '000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0000' _
& '00000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000000000' _
& '000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff00000000000000000000000000' _
& '0000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffff' _
& 'ffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffff' _
& 'ffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000' _
& '000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff00000000000000000000000000000000000000000000000000' _
& '0000000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff0000000000000000' _
& '00ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000' _
& '000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00' _
& '0000ffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffff0000000000000000' _
& '00ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff' _
& 'ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff00000000000000000000' _
& '0000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff0000' _
& '00000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffff' _
& 'ffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000' _
& '000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff00000000000000000000000000000000000000000000' _
& '0000000000ffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff0000000000000000000000000000' _
& '00000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffff00000000' _
& '0000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffff' _
& 'ffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffff' _
& 'ffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff0000000000000000000000000000000000000000000000000000' _
& '00000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& '000000000000000000ffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffff' _
& 'ffffffffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffff0000000000000000' _
& '00ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff' _
& '000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ff' _
& 'ffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0000' _
& '00000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff00' _
& '0000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff00000000' _
& '0000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0000000000000000000000000000' _
& '00000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffff000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff00000000000000000000000000' _
& '0000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0000000000000000000000000000000000000000000000000000' _
& '00ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000ffffffffffff' _
& 'ffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000' _
& 'ffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff00000000000000000000' _
& '0000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff0000' _
& '00000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffff' _
& '000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff0000' _
& '00000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffff' _
& 'ffffffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff00000000000000000000000000000000000000000000' _
& '0000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffff000000000000000000000000' _
& '000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff0000000000000000000000000000' _
& '00000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000000000' _
& '000000000000000000000000ffffffffffffffffffffffffffffffffffff00000000000000000000000000000000000000000000000000000000000000000000' _
& '0000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffff000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffff000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff0000000000000000000000000000000000' _
& '00000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000' _
& 'ffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffff00000000000000000000000000000000000000' _
& '0000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffff000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000' _
& 'ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff00000000000000000000' _
& '0000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000ffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff000000' _
& '000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffff' _
& 'ffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000ffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff000000' _
& '000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff000000000000000000000000000000' _
& '000000000000000000000000ffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffff00000000000000' _
& '0000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffff' _
& 'ffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffff' _
& 'ff000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000000000000000000000000000000000000000' _
& '000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffff' _
& 'ffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffff0000000000000000' _
& '00ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000' _
& '000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00' _
& '0000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff0000000000000000000000' _
& '00000000000000000000000000000000ffffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000000000' _
& '000000000000ffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff00000000' _
& '0000000000ffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffff' _
& 'ffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff0000000000000000000000000000000000000000000000' _
& '00000000ffffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffff' _
& 'ffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffff' _
& 'ffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0000000000000000000000000000' _
& '00000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000' _
& '000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffff' _
& 'ffffffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff0000000000000000000000000000000000' _
& '00ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000000000000000000000' _
& '000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff00' _
& '0000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffff' _
& 'ff000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff' _
& '000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff00' _
& '0000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000000000000000000000000000000000000000000000' _
& '000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff0000000000000000000000' _
& '00000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffff' _
& 'ffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffff' _
& 'ffffffffff000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffff000000000000000000ffffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffff' _
& 'ffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffff00000000' _
& '0000000000000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffff00000000000000000000000000000000' _
& '0000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff0000000000000000' _
& '00000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000000000000000000000' _
& '000000000000000000ffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffff00000000000000000000000000000000' _
& '0000ffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ff000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& '000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000000000000000000000000000000000000000ff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff0000000000000000000000000000000000000000' _
& '00000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffff' _
& 'ffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffff' _
& 'ffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffff' _
& 'ffffffffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000' _
& '000000000000000000000000000000ffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff0000000000000000000000000000000000000000000000000000000000000000' _
& '00000000000000000000000000ffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffff' _
& 'ffffff000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff00000000000000000000000000' _
& '0000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff0000000000000000000000000000000000000000000000' _
& '00000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00000000000000000000000000000000000000000000000000' _
& '0000000000000000000000000000000000000000000000000000000000ffffffffffffffffff0000000000000000000000000000000000000000000000000000' _
& '00000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000ffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffff' _
& 'ffff000000000000000000000000000000000000ffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffff00000000000000000000000000000000000000000000000000000000000000000000000000' _
& '0000000000000000000000000000000000ffffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000ffff' _
& 'ffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff00000000000000000000' _
& '0000000000000000ffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffff00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000' _
& '0000000000ffffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffff0000000000' _
& '00000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffff000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffff' _
& 'ffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff0000000000' _
& '00000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffff' _
& 'ffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffff' _
& 'ffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000' _
& '000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffff' _
& 'ffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffff' _
& 'ff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000' _
& 'ffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ff' _
& 'ffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffff000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff' _
& '000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ff' _
& 'ffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffff' _
& 'ffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffff' _
& 'ffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff00000000' _
& '0000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000ffff' _
& 'ffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000000000' _
& '000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00000000000000000000000000' _
& '0000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff0000000000' _
& '00000000000000000000000000ffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff00000000000000' _
& '0000000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffff' _
& 'ffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000' _
& '000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffff' _
& 'ffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff0000000000000000000000000000000000' _
& '00ffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff00000000000000000000000000000000000000' _
& '0000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffff0000000000000000' _
& '00000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff000000000000000000ff' _
& 'ffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff0000' _
& '00000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff00000000000000000000000000000000000000000000000000000000000000' _
& '0000000000ffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000' _
& '000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff00000000' _
& '0000000000000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffff' _
& 'ffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffff' _
& 'ffffffffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff00000000000000000000000000000000' _
& '0000ffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffff0000000000000000' _
& '00ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00' _
& '0000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff' _
& '000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffff' _
& 'ffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffff' _
& 'ffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
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
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffff' _
& 'ffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffff' _
& 'ffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffff' _
& 'ffffff000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff0000000000' _
& '00000000000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffff' _
& 'ffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff00000000000000' _
& '0000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000ffffffffffff' _
& 'ffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff0000000000000000000000000000000000' _
& '00000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000' _
& 'ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffff' _
& '000000000000000000ffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffff' _
& 'ffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff000000' _
& '000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff00000000000000000000000000000000000000000000' _
& '0000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffff' _
& 'ffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffff' _
& 'ffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff0000000000' _
& '00000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffff' _
& 'ffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffff' _
& 'ffff000000000000000000ffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffff0000000000000000' _
& '00ffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff000000000000' _
& '000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000' _
& 'ffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ff' _
& 'ffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffff' _
& 'ffffffffffffff000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000000000000000000000' _
& '000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff00' _
& '0000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff0000000000000000000000' _
& '00000000000000000000000000000000ffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000' _
& '000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff00000000' _
& '0000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000ffff' _
& 'ffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffff' _
& 'ffffffffffff000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffff' _
& 'ffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff0000000000000000000000000000000000000000000000' _
& '00000000ffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000000000000000' _
& '000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff00000000000000000000000000000000' _
& '0000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffff' _
& 'ffffffff000000000000000000ffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000' _
& '000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff00000000000000' _
& '0000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffff' _
& 'ff000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff' _
& '000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000000000000000000000000000000000000000ff' _
& 'ffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffff0000000000000000' _
& '00ffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff' _
& '000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff00000000000000000000' _
& '0000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffff' _
& 'ffffffffffffff000000000000000000000000000000000000ffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffff' _
& 'ffffffffffff000000000000000000ffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffff00000000' _
& '0000000000ffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff0000' _
& '00000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffff' _
& 'ffffffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffff' _
& 'ffffffffff000000000000000000000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff0000000000' _
& '00000000000000000000000000ffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000' _
& '000000ffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffff' _
& 'ffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff0000000000000000000000000000' _
& '00000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000' _
& '000000000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff00000000000000' _
& '0000000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff0000000000000000000000000000000000' _
& '00ffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff' _
& '000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff00' _
& '0000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff00000000000000000000000000000000000000000000000000000000' _
& '0000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffff' _
& 'ffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0000' _
& '00000000000000ffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffff000000000000000000ffffffffffffffffff00000000000000000000000000000000000000000000000000000000000000000000000000000000' _
& '0000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& 'ffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffff00000000' _
& '0000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffff' _
& 'ffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000' _
& '000000ffffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffff' _
& 'ffffffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff0000000000000000' _
& '00ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' _
& '000000000000000000ffffffffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffff00000000000000000000000000000000' _
& '0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffff0000000000000000' _
& '00000000000000000000000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff000000000000000000' _
& 'ffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff00' _
& '0000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffff0000' _
& '00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffffff' _
& 'ffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffffffffff00000000000000000000000000000000000000000000000000000000' _
& '0000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffff0000000000000000000000000000000000000000' _
& '00000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000' _
& '000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffff' _
& 'ffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffffffffffff0000000000000000000000000000' _
& '00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffff' _
& 'ffffff000000ffffffffffffffffffffffffffffffffffff00000000000000000000000000000000000000000000000000000000000000000000000000000000' _
& '0000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000000000000000000000000000000000000000ffffffffff' _
& 'ffffffff000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000ffffffffffff' _
& 'ffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffffffff000000000000000000ffffffffffffffffffffffffffffffff' _
& 'ffff000000000000000000000000000000000000000000000000000000ffffffffffffffffff0000000000000000000000000000000000000000000000000000' _
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
if UBound($cmdline) < 3 then; minimum RC + NAME
	MsgBox(48, 'S70 Echo ' & $VERSION, 'Načtení údajů pacienta z Medicus selhalo.')
	exit
endif

; -------------------------------------------------------------------------------------------
; INIT
; -------------------------------------------------------------------------------------------

; logging
logger('Program start: ' & @YEAR & '/' & @MON & '/' & @MDAY & ' ' & @HOUR & ':' & @MIN & ':' & @SEC)

; read configuration
if FileExists($config_file) then
	read_config_file($config_file)
	if @error then logger('Načtení konfiguračního souboru selhalo.')
Else
	$c = FileOpen($config_file, 2 + 256); UTF8 / NOBOM overwrite
	FileWrite($c, 'export=' & @CRLF & 'archiv=' & @CRLF & 'result=' & @CRLF & 'history=')
	FileClose($c)
endif

; update history path
$history_path = $archive_path & '\' & 'history'

; create archive / history directory
DirCreate($archive_path)
DirCreate($history_path & '\' & $cmdline[1])

; archive file full path
global $archive_file = $archive_path & '\' & $cmdline[1] & '.dat'

; export  file full path
global $export_file = get_export_file($export_path, $cmdline[1])
if @error or not $export_file then logger('Soubor exportu nebyl nalezen: ' & $cmdline[1])

; update data buffer from export
if FileExists($export_file) then
	$parse = export_parse($export_file)
	if @error then
		FileMove($export_file, $export_file & '.err', 1); overwrite
		logger('Nepodařilo se načíst export: ' & $cmdline[1])
	else
		FileMove($export_file, $export_file & '.old', 1); overwrite
	endif
endif

; update history buffer from archive
if FileExists($archive_file) then
	$history = Json_Decode(FileRead($archive_file))
	if @error then logger('Nepodařilo se načíst historii: ' & $cmdline[1] & '.dat')
endif

; update note from history
for $group in Json_Get($history, '.group')
	Json_Put($buffer, '.group.' & $group & '.note', Json_Get($history, '.group.' & $group & '.note'), True)
next

; update height & weight if not export
if UBound($cmdline) = 6  Then
		if Json_Get($buffer, '.height') = Null then Json_Put($buffer, '.height', Number($cmdline[4]), True)
		if Json_Get($buffer, '.weight') = Null then Json_Put($buffer, '.weight', Number($cmdline[5]), True)
endif

; update result from history or template
Json_Put($buffer, '.result', Json_Get($history, '.result'), True)
if Json_Get($buffer, '.result') = Null then
	$result_text = FileRead($result_file)
	if @error then
		logger('Načtení výchozího závěru selhalo.')
	else
		Json_Put($buffer, '.result', $result_text, True)
	endif
endif

; calculate values
calculate(True)

; -------------------------------------------------------------------------------------------
; GUI
; -------------------------------------------------------------------------------------------

$gui_index = 0
$gui_top_offset = 15; offset from basic
$gui_left_offset = 0
$gui_group_top_offset = 20
$gui_group_index = 0

;$gui = GUICreate('S70 Echo ' & $VERSION & ' [' & $cmdline[2] & ' ' & $cmdline[3] & ' : ' & $cmdline[1] & ']', 890, 1010, @DesktopWidth - 895, 0)
$gui = GUICreate('S70 Echo ' & $VERSION & ' [' & $cmdline[2] & ' ' & $cmdline[3] & ' : ' & $cmdline[1] & ']', 890, 1010, 120, 0)

; header

$label_height = GUICtrlCreateLabel('Výška', 0, 5, 85, 17, 0x0002); right
$input_height = GUICtrlCreateInput(Json_Get($buffer, '.height'), 90, 2, 34, 19, 1)
$input_height_unit = GUICtrlCreateLabel('cm', 130, 4, 45, 21)

$label_wegiht = GUICtrlCreateLabel('Váha', 185, 5, 85, 17, 0x0002); right
$input_weight = GUICtrlCreateInput(Json_Get($buffer, '.weight'), 185 + 90, 2, 34, 19, 1)
$input_weight_unit = GUICtrlCreateLabel('kg', 185 + 130, 4, 45, 21)

$label_bsa = GUICtrlCreateLabel('BSA', 185 + 185, 5, 85, 17, 0x0002); right
$input_bsa = GUICtrlCreateInput(Json_Get($buffer, '.bsa'), 185 + 185 + 90, 2, 34, 19, BitOr(0x0001, 0x0800)); read-only
$input_bsa_unit = GUICtrlCreateLabel('m²', 185 + 185 + 130, 4, 45, 21)

$button_recount = GUICtrlCreateButton('Přepočítat', 808, 2, 75, 21)

; groups
for $group in Json_Get($order, '.group')
	for $member in Json_Get($order, '.data.' & $group)
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
			; input
			Json_Put($buffer,'.data.' & $group & '."' & $member & '".id', GUICtrlCreateInput(Json_Get($buffer, '.data.' & $group & '."' & $member & '".value'), 90 + $gui_left_offset, $gui_top_offset, 34, 19, 1), True)
			; unit
			GUICtrlCreateLabel(Json_Get($buffer, '.data.' & $group & '."' & $member & '".unit'), 130 + $gui_left_offset, $gui_top_offset + 3, 45, 21)
			; update index
			$gui_index+=1
		endif
	next
	; note
	GUICtrlCreateLabel('Poznámka:', 0, 21 + $gui_top_offset + 3, 85, 21, 0x0002)
	Json_Put($buffer, '.group.' & $group & '.id', GUICtrlCreateInput(Json_Get($buffer, '.group.' & $group & '.note'), 90, 21 + $gui_top_offset, 785, 21), True)

	$gui_top_offset+=18; group spacing

	; group
	GUICtrlCreateGroup(Json_Get($buffer, '.group.' & $group & '.label'), 5, $gui_group_top_offset, 880, 21 + 21 * (gui_get_group_index($gui_index, 5)+ 1))
	GUICtrlSetFont(-1, 8, 800, 0, 'MS Sans Serif')
	$gui_group_top_offset += 21 + 21 * (gui_get_group_index($gui_index, 5) + 1)

	; update index / offset
	$gui_top_offset+=24; group spacing
	$gui_left_offset=0; reset
	$gui_index=0; reset
next

; dekurz
$label_dekurz = GUICtrlCreateLabel('Závěr:', 0, $gui_group_top_offset + 8, 85, 21,0x0002); align right
$edit_dekurz = GUICtrlCreateEdit(Json_Get($buffer, '.result'), 90, $gui_group_top_offset + 8, 792, 90, BitOR(64, 4096, 0x00200000)); $ES_AUTOVSCROLL, $ES_WANTRETURN, $WS_VSCROLL

; date
$label_datetime = GUICtrlCreateLabel($runtime, 8, $gui_group_top_offset + 108, 150, 17)

; button
$button_history = GUICtrlCreateButton('Historie', 574, $gui_group_top_offset + 104, 75, 21)
$button_tisk = GUICtrlCreateButton('Tisk', 652, $gui_group_top_offset + 104, 75, 21)
$button_dekurz = GUICtrlCreateButton('Dekurz', 730, $gui_group_top_offset + 104, 75, 21)
$button_konec = GUICtrlCreateButton('Konec', 808, $gui_group_top_offset + 104, 75, 21)

; GUI tune
GUICtrlSetBkColor($input_height, 0xC0DCC0)
GUICtrlSetBkColor($input_weight, 0xC0DCC0)
GUICtrlSetState($button_konec, $GUI_FOCUS)

; GUI display
GUISetState(@SW_SHOW)

; dekurz initialize
$dekurz_init = dekurz_init()
if @error then logger($dekurz_init)

; -------------------------------------------------------------------------------------------
; MAIN
; -------------------------------------------------------------------------------------------

; main loop
While 1
	$msg = GUIGetMsg()
	; generate dekurz clipboard
	if $msg = $button_dekurz then
		gui_enable(False)
		$dekurz = dekurz()
		if @error then
			logger($dekurz)
			MsgBox(48, 'S70 Echo ' & $VERSION, 'Generování dekurzu selhalo.')
		endif
		gui_enable(True)
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
	; re-calculate
	if $msg = $button_recount Then
		; update height / weight
		Json_Put($buffer, '.height', Number(StringReplace(GuiCtrlRead($input_height), ',', '.')), True)
		Json_Put($buffer, '.weight', Number(StringReplace(GuiCtrlRead($input_weight), ',', '.')), True)
		; update data buffer
		for $group in Json_Get($history, '.group')
			for $member in Json_Get($history, '.data.' & $group)
				if not GuiCtrlRead(Json_Get($buffer, '.data.'  & $group & '."' & $member & '".id')) then
					Json_Put($buffer, '.data.'  & $group & '."' & $member & '".value', Null, True)
				else
					Json_Put($buffer, '.data.'  & $group & '."' & $member & '".value', Number(StringReplace(GuiCtrlRead(Json_Get($buffer, '.data.'  & $group & '."' & $member & '".id')), ',', '.')), True)
				endif
			next
		next
		; re-calculate
		calculate(False)
		; re-fill BSA
		GUICtrlSetData($input_bsa, Json_Get($buffer, '.bsa'))
		; re-fill data
		for $group in Json_Get($history, '.group')
			for $member in Json_Get($history, '.data.' & $group)
				GUICtrlSetData(Json_Get($buffer, '.data.' & $group & '."' & $member & '".id'), Json_Get($buffer,'.data.' & $group & '."' & $member & '".value'))
			next
		next
	endif
	; load history
	if $msg = $button_history Then
		if FileExists($archive_file) then
			if _DateDiff('h', Json_Get($history,'.date'), $runtime) < $AGE then
				if msgbox(4, 'S70 Echo ' & $VERSION, 'Načíst poslední naměřené hodnoty?') = 6 then
					; update basic
					GUICtrlSetData($input_height, Json_Get($history, '.height'))
					GUICtrlSetData($input_weight, Json_Get($history, '.weight'))
					GUICtrlSetData($input_bsa, Json_Get($history, '.bsa'))
					for $group in Json_Get($buffer, '.group')
						; update note
						GUICtrlSetData(Json_Get($buffer, '.group.' & $group & '.id'), Json_Get($history, '.group.' & $group & '.note'))
						; update data
						for $member in Json_Get($buffer, '.data.' & $group)
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
		for $group in Json_Get($history, '.group')
			; update note
			Json_Put($buffer, '.group.' & $group & '.note', GuiCtrlRead(Json_Get($buffer, '.group.' & $group & '.id')), True)
			; update data
			for $member in Json_Get($history, '.data.' & $group)
				if not GuiCtrlRead(Json_Get($buffer, '.data.'  & $group & '."' & $member & '".id')) then
					Json_Put($buffer, '.data.'  & $group & '."' & $member & '".value', Null, True)
				else
					Json_Put($buffer, '.data.'  & $group & '."' & $member & '".value', Number(StringReplace(GuiCtrlRead(Json_Get($buffer, '.data.'  & $group & '."' & $member & '".id')), ',', '.')), True)
				endif
			next
		next
		; update timestamp
		Json_Put($buffer, '.date', $runtime, True)
		; write data buffer to archive
		$out = FileOpen($archive_file, 2 + 256); UTF8 / NOBOM overwrite
		FileWrite($out, Json_Encode($buffer))
		if @error then logger('Zápis archivu selhal: ' & $cmdline[1] & '.dat')
		FileClose($out)
		; update history
		FileCopy($archive_file, $history_path & '\' & $cmdline[1] & '\' & $cmdline[1] & '_'  & @YEAR & @MDAY & @MON & @HOUR & @MIN & @SEC & '.dat')
		if @error then logger('Zápis historie selhal: ' & $cmdline[1])
		; exit
		exitloop
	endif
wend

;exit
logger('Program exit: ' & @YEAR & '/' & @MON & '/' & @MDAY & ' ' & @HOUR & ':' & @MIN & ':' & @SEC)
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

func gui_enable($visible)
	if $visible = True then $state = $GUI_ENABLE
	If $visible = False then $state = $GUI_DISABLE
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
		if $cfg[$i][0] == 'archiv' then $archive_path = StringRegExpReplace($cfg[$i][1], '\\$', ''); strip trailing backslash
		if $cfg[$i][0] == 'result' then $result_file = $cfg[$i][1]
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
	if @error then return SetError(1, 0, 'Nelze načíst souboru exportu.')
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
				endif
			next
		next
	next
endfunc

; calculate aditional variables
func calculate($is_export)
	if not $is_export then
		; BSA
		if IsNumber(Json_Get($buffer, '.weight')) and IsNumber(Json_Get($buffer, '.height')) then
			Json_Put($buffer, '.bsa', Round((Json_Get($buffer, '.weight')^0.425)*(Json_Get($buffer, '.height')^0.725)*71.84*(10^-4), 2), True)
		EndIf
	endif
	;LVd index
	if IsNumber(Json_Get($buffer, '.data.lk.LVIDd.value')) and IsNumber(Json_Get($buffer, '.bsa')) then
		Json_Put($buffer, '.data.lk."LVd index".value', Round(Json_Get($buffer, '.data.lk.LVIDd.value')/Json_Get($buffer, '.bsa'), 1), True)
	endif
	;LVs index
	if IsNumber(Json_Get($buffer, '.data.lk.LVIDs.value')) and IsNumber(Json_Get($buffer, '.bsa')) then
		Json_Put($buffer, '.data.lk."LVs index".value', Round(Json_Get($buffer, '.data.lk.LVIDs.value')/Json_Get($buffer, '.bsa'), 1), True)
	endif
	; LVEF % Teich.
	if IsNumber(Json_Get($buffer, '.data.lk.LVIDd.value')) and IsNumber(Json_Get($buffer, '.data.lk.LVIDs.value')) then
		Json_Put($buffer, '.data.lk."LVEF % Teich".value', Round((7/(2.4+Json_Get($buffer, '.data.lk.LVIDd.value')/10)*(Json_Get($buffer, '.data.lk.LVIDd.value')/10)^3-7/(2.4+Json_Get($buffer, '.data.lk.LVIDs.value')/10)*(Json_Get($buffer, '.data.lk.LVIDs.value')/10)^3)/(7/(2.4+Json_Get($buffer, '.data.lk.LVIDd.value')/10)*(Json_Get($buffer, '.data.lk.LVIDd.value')/10)^3)*100, 1), True)
	endif
	; LVmass
	if IsNumber(Json_Get($buffer, '.data.lk.LVIDd.value')) and IsNumber(Json_Get($buffer, '.data.lk.IVSd.value')) and IsNumber(Json_Get($buffer, '.data.lk.LVPWd.value')) then
		Json_Put($buffer, '.data.lk.LVmass.value', Round(1.04*(Json_get($buffer, '.data.lk.LVIDd.value')/10 + Json_Get($buffer, '.data.lk.IVSd.value')/10 + Json_Get($buffer, '.data.lk.LVPWd.value')/10)^3-(Json_Get($buffer, '.data.lk.LVIDd.value')/10)^3-13.6, 1), True)
	endif
	; LVmass-i^2,7
	if IsNumber(Json_Get($buffer, '.height')) and IsNumber(Json_Get($buffer, '.data.lk.LVmass.value')) then
		Json_Put($buffer, '.data.lk."LVmass-i^2,7".value', Round(Json_Get($buffer, '.data.lk.LVmass.value')/(Json_Get($buffer, '.height')/100)^2.7, 1), True)
	endif
	; LVmass-BSA
	if IsNumber(Json_Get($buffer, '.bsa')) and IsNumber(Json_Get($buffer, '.data.lk.LVmass.value')) then
		Json_Put($buffer, '.data.lk.LVmass-BSA.value', Round(Json_Get($buffer, '.data.lk.LVmass.value')/Json_Get($buffer, '.bsa'), 1), True)
	endif
	; RWT
	if IsNumber(Json_Get($buffer, '.data.lk.LVIDd.value')) and IsNumber(Json_Get($buffer, '.data.lk.LVPWd.value')) then
		Json_Put($buffer, '.data.lk.RWT.value', Round(2*Json_Get($buffer, '.data.lk.LVPWd.value')/Json_Get($buffer, '.data.lk.LVIDd.value'), 1), True)
	endif
	; FS
	if IsNumber(Json_Get($buffer, '.data.lk.LVIDd.value')) and IsNumber(Json_Get($buffer, '.data.lk.LVIDs.value')) then
		Json_Put($buffer, '.data.lk.FS.value', Round((Json_Get($buffer, '.data.lk.LVIDd.value')-Json_Get($buffer, '.data.lk.LVIDs.value'))/Json_Get($buffer, '.data.lk.LVIDd.value')*100, 1), True)
	endif
	; SV-biplane
	if IsNumber(Json_Get($buffer, '.data.lk."SV MOD A2C".value')) and IsNumber(Json_Get($buffer, '.data.lk."SV MOD A4C".value')) then
		Json_Put($buffer, '.data.lk.SV-biplane.value', Round((Json_Get($buffer, '.data.lk."SV MOD A4C".value') + Json_Get($buffer, '.data.lk."SV MOD A2C".value'))/2, 1), True)
	endif
	;EDVi
	if IsNumber(Json_Get($buffer, '.data.lk."LVEDV MOD BP".value')) and IsNumber(Json_Get($buffer, '.bsa')) then
		Json_Put($buffer, '.data.lk.EDVi.value', Round(Json_Get($buffer, '.data.lk."LVEDV MOD BP".value')/Json_Get($buffer, '.bsa'), 1), True)
	endif
	;ESVi
	if IsNumber(Json_Get($buffer, '.data.lk."LVESV MOD BP".value')) and IsNumber(Json_Get($buffer, '.bsa')) then
		Json_Put($buffer, '.data.lk.ESVi.value', Round(Json_Get($buffer, '.data.lk."LVESV MOD BP".value')/Json_Get($buffer, '.bsa'), 1), True)
	endif
	; LAV-A4C
	if IsNumber(Json_Get($buffer, '.data.ls."LAEDV A-L A4C".value')) and IsNumber(Json_Get($buffer, '.data.ls."LAEDV MOD A4C".value')) then
		Json_Put($buffer, '.data.ls.LAV-A4C.value', Round((Json_Get($buffer, '.data.ls."LAEDV A-L A4C".value') + Json_Get($buffer, '.data.ls."LAEDV MOD A4C".value'))/2, 1), True)
	endif
	; LAV-2D
	if IsNumber(Json_Get($buffer,'.data.ls.LAV-A4C.value')) and IsNumber(Json_Get($buffer, '.data.ls."LAEDV A-L A2C".value')) and IsNumber(Json_Get($buffer, '.data.ls."LAEDV MOD A2C".value')) then
		Json_Put($buffer, '.data.ls.LAV-2D.value',Round((Json_Get($buffer, '.data.ls.LAV-A4C.value')+(Json_Get($buffer, '.data.ls."LAEDV A-L A2C".value') + Json_Get($buffer, '.data.ls."LAEDV MOD A2C".value'))/2)/2, 1), True)
	endif
	; LAVi-2D
	if IsNumber(Json_Get($buffer,'.data.ls.LAV-2D.value')) and IsNumber(Json_Get($buffer, '.bsa')) then
		Json_Put($buffer, '.data.ls.LAVi-2D.value', Round(Json_Get($buffer, '.data.ls.LAV-2D.value')/Json_Get($buffer, '.bsa'), 1), True)
	endif
	; FAC%
	if IsNumber(Json_Get($buffer,'.data.pk.EDA.value')) and IsNumber(Json_Get($buffer, '.data.pk.ESA.value')) then
		Json_Put($buffer, '.data.ls."FAC%".value', Round(Json_Get($buffer, '.data.pk.EDA.value')/ 100 * Json_Get($buffer, '.data.pk.ESA.value'), 1), True)
	endif
	if $is_export then
		;MR Rad
		if IsNumber(Json_Get($buffer,'.data.mch."MR Rad".value')) then
			Json_Put($buffer, '.data.mch."MR Rad".value', Round(Json_Get($buffer, '.data.mch."MR Rad".value')*100, 1), True)
		endif
		;AR Rad
		if IsNumber(Json_Get($buffer,'.data.ach."AR Rad".value')) then
			Json_Put($buffer, '.data.ach."AR Rad".value', Round(Json_Get($buffer, '.data.ach."AR Rad".value')*100, 1), True)
		endif
		;PV Vmax
		if IsNumber(Json_Get($buffer,'.data.pch."PV Vmax".value')) then
			Json_Put($buffer, '.data.pch."PV Vmax".value', Round(Json_Get($buffer, '.data.pch."PV Vmax".value')/100, 1), True)
		endif
	endif
	; PV max/meanPG
	if IsNumber(Json_Get($buffer,'.data.pch."PV maxPG".value')) and IsNumber(Json_Get($buffer, '.data.pch."PV maxPG".value')) then
		Json_Put($buffer, '.data.pch."PV max/meanPG".value', Json_Get($buffer, '.data.pch."PV maxPG".value') & '/' & Json_Get($buffer, '.data.pch."PV meanPG".value'), True)
	endif
	; PR max/meanPG
	if IsNumber(Json_Get($buffer,'.data.pch."PR maxPG".value')) and IsNumber(Json_Get($buffer, '.data.pch."PR maxPG".value')) then
		Json_Put($buffer, '.data.pch."PR max/meanPG".value', Json_Get($buffer, '.data.pch."PR maxPG".value') & '/' & Json_Get($buffer, '.data.pch."PR meanPG".value'), True)
	endif
	; MV max/meanPG
	if IsNumber(Json_Get($buffer,'.data.mch."MV maxPG".value')) and IsNumber(Json_Get($buffer, '.data.mch."MV maxPG".value')) then
		Json_Put($buffer, '.data.mch."MV max/meanPG".value', Round(Json_Get($buffer, '.data.mch."MV maxPG".value'), 2) & '/' & Round(Json_Get($buffer, '.data.mch."MV meanPG".value'), 1), True)
	endif
	; MVA-PHT
	if IsNumber(Json_Get($buffer,'.data.mch."MV PHT".value')) then
		Json_Put($buffer, '.data.mch."MVA-PHT".value', Round(220/Json_Get($buffer, '.data.mch."MV PHT".value'), 1), True)
	endif
	; MVAi-PHT
	if IsNumber(Json_Get($buffer,'.data.mch."MVA-PHT".value')) and IsNumber(Json_Get($buffer,'.bsa')) then
		Json_Put($buffer, '.data.mch."MVAi-PHT".value', Round(Json_Get($buffer, '.data.mch."MV PHT".value')/Json_Get($buffer, '.bsa'), 1), True)
	endif
	;E/Em
	if IsNumber(Json_Get($buffer, '.data.mch."MV E Vel".value')) and IsNumber(Json_Get($buffer,'.data.mch.EmSept.value')) and IsNumber(Json_Get($buffer,'.data.mch.EmLat.value')) then
		Json_Put($buffer, '.data.mch."E/Em".value', Round(2 * Json_Get($buffer, '.data.mch."MV E Vel".value')/(Json_Get($buffer, '.data.mch.EmSept.value') + Json_Get($buffer, '.data.mch.EmLat.value')), 1), True)
	endif
	; TV max/meanPG
	if IsNumber(Json_Get($buffer,'.data.tch."TV maxPG".value')) and IsNumber(Json_Get($buffer, '.data.tch."TV maxPG".value')) then
		Json_Put($buffer, '.data.tch."TV max/meanPG".value', Round(Json_Get($buffer, '.data.tch."TV maxPG".value'), 2) & '/' & Round(Json_Get($buffer, '.data.tch."TV meanPG".value'), 1), True)
	endif
	; AV max/meanPG
	if IsNumber(Json_Get($buffer,'.data.ach."AV maxPG".value')) and IsNumber(Json_Get($buffer, '.data.ach."AV maxPG".value')) then
		Json_Put($buffer, '.data.ach."AV max/meanPG".value', Round(Json_Get($buffer, '.data.ach."AV maxPG".value'), 2) & '/' & Round(Json_Get($buffer, '.data.ach."AV meanPG".value'), 1), True)
	endif
	; SV
	if IsNumber(Json_Get($buffer,'.data.ach."LVOT Diam".value')) and IsNumber(Json_Get($buffer, '.data.ach."LVOT VTI".value')) then
		Json_Put($buffer, '.data.ach.SV.value', Round(Json_Get($buffer,'.data.ach."LVOT VTI".value')*Json_Get($buffer,'.data.ach."LVOT Diam".value')^2*3.4159265/4/100, 1), True)
	endif
	; SVi
	if IsNumber(Json_Get($buffer,'.data.ach.SV.value')) and IsNumber(Json_Get($buffer, '.bsa')) then
		Json_Put($buffer, '.data.ach.SVi.value', Round(Json_Get($buffer,'.data.ach.SV.value')/Json_Get($buffer,'.bsa'), 1), True)
	endif
	; SV/SVi
	if IsNumber(Json_Get($buffer,'.data.ach.SV.value')) and IsNumber(Json_Get($buffer, '.data.ach.SVi.value')) then
		Json_Put($buffer, '.data.ach."SV/SVi".value', Round(Json_Get($buffer,'.data.ach.SV.value'), 2) & '/' & Round(Json_Get($buffer,'.data.ach.SVi.value'), 1), True)
	endif
	; AVA
	if IsNumber(Json_Get($buffer,'.data.ach."LVOT Diam".value')) and IsNumber(Json_Get($buffer, '.data.ach."LVOT VTI".value')) and IsNumber(Json_Get($buffer, '.data.ach."AV VTI".value')) then
		Json_Put($buffer, '.data.ach.AVA.value', Round(Json_Get($buffer,'.data.ach."LVOT VTI".value')*Json_Get($buffer,'.data.ach."LVOT Diam".value')^2*3.4159265/4/Json_Get($buffer,'.data.ach."LVOT Diam".value')/100, 1), True)
	endif
	; AVAi
	if IsNumber(Json_Get($buffer,'.data.ach.AVA.value')) and IsNumber(Json_Get($buffer, '.bsa')) then
		Json_Put($buffer, '.data.ach.AVAi.value', Round(Json_Get($buffer,'.data.ach.AVA.value')/Json_Get($buffer,'.bsa'), 1), True)
	endif
	; VTI LVOT/Ao
	if IsNumber(Json_Get($buffer, '.data.ach."LVOT VTI".value')) and IsNumber(Json_Get($buffer, '.data.ach."AV VTI".value')) then
		Json_Put($buffer, '.data.ach."VTI LVOT/Ao".value', Round(Json_Get($buffer,'.data.ach."LVOT VTI".value')/Json_Get($buffer,'.data.ach."AV VTI".value'), 1), True)
	endif
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
	if @error then return SetError(1, 0, 'Nelze spustit aplikaci Excel.')
	$book = _Excel_BookNew($excel)
	if @error then return SetError(1, 0, 'Nelze vytvořit book.')
	; default font
	$book.Activesheet.Range('A1:E46').Font.Size = 8
	; columns height
	$book.Activesheet.Range('A1:E46').RowHeight = 10
	; number format
	$book.Activesheet.Range('A1:E46').NumberFormat = "@"; string
	; columns width [ group. label | member.label | member.value | member.unit | ... ]
	$book.Activesheet.Range('A1').ColumnWidth = 14.5; group A-E
	for $i = 0 to 3; four columns starts B[66]
		$book.Activesheet.Range(Chr(66 + $i) & '1').ColumnWidth = 17.5
	Next
endFunc

func not_empty_group($group)
	if StringLen(GUICtrlRead(Json_Get($buffer, '.group.' & $group & '.id'))) > 0 then return True
	for $member in Json_Get($history, '.data.' & $group)
		if GUICtrlRead(Json_Get($buffer, '.data.' & $group & '."' & $member & '".id')) then return True
	next
	return False
endFunc

; update XLS data & write clipboard
func dekurz()
	;clear the clip
	_ClipBoard_Open(0)
	_ClipBoard_Empty()
	_ClipBoard_Close()

	$row_index = 1
	$column_index = 65; 65 A, 66 B, 67 C, 68 D, 69 E
	; top line
	With $book.Activesheet.Range('A' & $row_index & ':E' & $row_index).Borders(8); $xlEdgeTop
		.LineStyle = 1
		.Weight = 2
	EndWith
	; generate data
	for $group in Json_Get($order, '.group')
		if not_empty_group($group) then
			; group label
			$book.Activesheet.Range('A' & $row_index).Font.Bold = True
			$book.Activesheet.Range('A' & $row_index).Font.Size = 9
			_Excel_RangeWrite($book, $book.Activesheet, Json_Get($buffer, '.group.' & $group & '.label'), 'A' & $row_index)
			for $member in Json_Get($order, '.data.' & $group)
				if GUICtrlRead(Json_Get($buffer, '.data.' & $group & '."' & $member & '".id')) then; has value
					; update index
					if $column_index = 69 Then; reset
						$column_index = 65
						$row_index+=1
					endif
					; data
					_Excel_RangeWrite($book, $book.Activesheet, Json_Get($buffer, '.data.' & $group & '."' & $member & '".label') & ': ' & StringReplace(GUICtrlRead(Json_Get($buffer, '.data.' & $group & '."' & $member & '".id')), ',', '.') & ' ' & Json_Get($buffer, '.data.' & $group & '."' & $member & '".unit'), Chr($column_index + 1) & $row_index)
					; update index
					$column_index+=1
				endif
			next
			; note
			if StringLen(GUICtrlRead(Json_Get($buffer,'.group.' & $group & '.id'))) > 0 then
				if $column_index <> 65 then $row_index+=1; not only note
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
	$book.Activesheet.Range('A' & $row_index & ':E' & $row_index).MergeCells = True
	_Excel_RangeWrite($book, $book.Activesheet, GUICtrlRead($edit_dekurz), 'A' & $row_index)
	; bottom line
	With $book.Activesheet.Range('A' & $row_index & ':E' & $row_index).Borders(9); $xlEdgeBottom
		.LineStyle = 1
		.Weight = 2
	EndWith
	; clip
	_Excel_RangeCopyPaste($book.ActiveSheet, 'A1:E' & $row_index)
	if @error then return SetError(1, 0, 'Nelze kopirovat data.')
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
	if $printer = 0 then return SetError(1, 0, 'Printer error: ' & $printer_error)
	; printer create page
	_PrintStartPrint($printer)

	$max_height = _PrintGetPageHeight($printer) - _PrintGetYOffset($printer)
	$max_width = _PrintGetPageWidth($printer) - _PrintGetXOffset($printer)
	$line_offset = 5
	$top_offset = 0

	;logo
	_PrintImageFromDC($printer, $logo_handle, 0, 0, 128, 128, 50, 45, 338, 338); 128 x 128 inch 96 DPI => 338 mm
	; QR code
	_PrintImageFromDC($printer, $qr_handle, 0, 0, 123, 123, $max_width - 325 - 50, 50, 325, 325); 123 x 123 inch 96 DPI => 325 mm
	; address
	_PrintSetFont($printer,'Arial',12, Default, Default)
	$text_height = _PrintGetTextHeight($printer, 'Arial')
	$top_offset += 125
	_PrintText($printer, 'Kardiologie - Jan Škoda', ($max_width - _PrintGetTextWidth($printer, 'Kardiologie - Jan Škoda'))/2, $top_offset)
	$top_offset+=$text_height + $line_offset
	_PrintText($printer, 'Žufanova 1113/3', ($max_width - _PrintGetTextWidth($printer, 'Žufanova 1113/3'))/2, $top_offset)
	$top_offset+=$text_height + $line_offset
	_PrintText($printer, 'Praha 17 16300', ($max_width - _PrintGetTextWidth($printer, 'Praha 17 16300'))/2, $top_offset)
	$top_offset+=$text_height + $line_offset
	_PrintText($printer, 'Tel: +420/235 318 915', ($max_width - _PrintGetTextWidth($printer, 'Tel: +420/235 318 915'))/2, $top_offset)
	$top_offset+=$text_height + $line_offset
	; separator
	_PrintSetLineWid($printer, 2)
	_PrintLine($printer, 50, $top_offset + 75, $max_width - 50, $top_offset + 75)
	$top_offset+=75
	; patient
	_PrintSetFont($printer, 'Arial',10, Default, Default)
	$text_height = _PrintGetTextHeight($printer, 'Arial')
	$top_offset += 25
	_PrintText($printer, 'Jméno: ' & $cmdline[2]& ' ' & $cmdline[3], 50, $top_offset)
	_PrintText($printer, 'Výška: ' & StringReplace(GUICtrlRead($input_height), ',', '.') & ' cm', 550, $top_offset)
	_PrintText($printer, 'BSA: ' & GUICtrlRead($input_bsa) & ' m²', 1050, $top_offset)
	_PrintText($printer, 'Datum: ' & $runtime, 1550, $top_offset)
	$top_offset+=$text_height + $line_offset
	_PrintText($printer, 'Rodné číslo: ' & $cmdline[1], 50, $top_offset)
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
	for $group in Json_Get($order, '.group')
		if not_empty_group($group) then
			; check new page
			if $top_offset + 50 >= $max_height Then
				_PrintNewPage($printer)
				$top_offset = 50
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
			_PrintText($printer, Json_Get($buffer,'.group.' & $group & '.label'), 50, $top_offset)
			$top_offset += $text_height + $line_offset; step down
			; group data
			_PrintSetFont($printer, 'Arial', 8, Default, Default)
			for $member in Json_Get($order, '.data.' & $group)
				if GUICtrlRead(Json_Get($buffer, '.data.' & $group & '."' & $member & '".id')) then; has value
					if $line_index = 5 Then
						$line_index = 1
						$top_offset += $text_height + $line_offset
					endif
					_PrintText($printer, Json_Get($buffer,'.data.' & $group & '."' & $member & '".label') & ': ' & StringReplace(String(GuiCtrlRead(Json_Get($buffer,'.data.' & $group & '."' & $member & '".id'))), ',', '.') & ' ' & Json_Get($buffer,'.data.' & $group & '."' & $member & '".unit'), 400*$line_index, $top_offset)
					$line_index+=1
				endif
			next
			; update offset
			if $line_index <> 1 then $top_offset += $text_height + $line_offset
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
	_PrintSetLineCol($printer, 0x000000)
	_PrintSetLineWid($printer, 2)
	_PrintLine($printer, 50, $top_offset + 15, $max_width - 50, $top_offset + 15)
	$top_offset += 35
	; result label
	_PrintSetFont($printer, 'Arial', 9, Default, 'bold')
	_PrintText($printer, 'Závěr', 50, $top_offset)
	$top_offset += $text_height + $line_offset + 5
	; result
	_PrintSetFont($printer, 'Arial', 9, Default, Default)
	$text_height = _PrintGetTextHeight($printer, 'Arial')
	$line_len = 50
	for $word in StringSplit(GUICtrlRead($edit_dekurz), ' ', 2); no count
		if _PrintGetTextWidth($printer, ' ' & $word) + $line_len > $max_width - 80 Then
			$line_len=50
			$top_offset+=$text_height + $line_offset
		EndIf
		_PrintText($printer, ' ' & $word, $line_len, $top_offset)
		$line_len+=_PrintGetTextWidth($printer, ' ' & $word)
	next
	$top_offset += $text_height + $line_offset
	; date
	$top_offset += 10
	_PrintText($printer, 'Datum: ' & $runtime, 50, $max_height - 100)
	; singnature
	_PrintText($printer, 'Podpis:', 1500, $max_height - 100)
	_PrintSetLineWid($printer, 2)
	_PrintLine($printer, 1650, $max_height - 70, $max_width - 50, $max_height - 70)
	; print
	_PrintEndPrint($printer)
	_PrintNewPage($printer)
	_printDllClose($printer)
	; GDI+ de-init
	 _WinAPI_DeleteObject($logo_handle)
	 _WinAPI_DeleteObject($qr_handle)
	_GDIPlus_ImageDispose($logo)
	_GDIPlus_ImageDispose($qr)
	_GDIPlus_Shutdown()
EndFunc
