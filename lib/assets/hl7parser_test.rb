# encoding: utf-8
require 'json'
require './hl7parser'
include HL7Parser

req_body = 
"MSH|^~\&|MIRAIs|送信施設|GW|受信施設|20161028143312.3521||ADT^A08^ADT_A01|20161028000000002134|P|2.5||||||~ISO IR87||ISO 2022-1994|SS-MIX2_1.20^SS-MIX2^1.2.392.200250.2.1.100.1.2.120^ISO
EVN||20161028143309|||D100||送信施設
PID|0001||99990010||テスト^患者１０^^^^^L^I~テスト^カンジャ10^^^^^L^P||19791101|M|||^^^^1510071^JPN^H^東京都渋谷区本町三丁目１２番１号住友不動産西新宿ビル６号館||^PRN^PH^^^^^^^^^03-1234-5678||||||||||||||||||||20161028143309||||||
NK1|1|テスト^花子^^^^^L^I|^実母^99zzz||^PRN^PH^^^^^^^^^090-xxxx-xxxx||||||||
PV1|0001|O|01^^^^^C||||||||||||||||||||||||||||||||||||||||||
DB1|1|PT||N
OBX|1|NM|9N001000000000001^身長^JC10||165.10|cm^cm^ISO+|||||F||||||||
OBX|2|NM|9N006000000000001^体重^JC10||51.20|kg^kg^ISO+|||||F||||||||
AL1|1|DA^薬剤アレルギー^HL70127|11I^ヨード^99zzz|||
AL1|2|FA^食物アレルギー^HL70127|237^青魚^99zzz|||
AL1|3|MA^様々なアレルギー^HL70127|351^花粉症^99zzz|||
IN1|1|06^組合管掌健康保険^JHSD0001|06050116|||||||９２０４５|１０|19990514|||||SEL^本人^HL70063"

result = parse(req_body)
puts result