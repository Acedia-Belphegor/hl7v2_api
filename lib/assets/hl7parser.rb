# encoding: UTF-8
require 'json'

class HL7Parser
    def initialize(raw_message = nil)
        # セグメントターミネータ
        @segment_delim = "\r"
        # フィールドセパレータ
        @field_delim = "|"
        # 成分セパレータ
        @element_delim = "^"
        # 反復セパレータ
        @repeat_delim = "~"

        # データ型を定義したJSONファイルを読み込む        
        @hl7_datatypes = open(Rails.root.join('lib/assets/json/HL7_DATATYPE.json')) do |io|
        # @hl7_datatypes = open("./json/HL7_DATATYPE.json") do |io|
            JSON.load(io)
        end

        # セグメントを定義したJSONファイルを読み込む        
        @hl7_segments = open(Rails.root.join('lib/assets/json/HL7_SEGMENT.json')) do |io|
        # @hl7_segments = open("./json/HL7_SEGMENT.json") do |io|
            JSON.load(io)
        end

        # 引数にRawデータが設定されている場合はパースする
        if !raw_message.nil? then
            parse(raw_message)
            @raw_message = raw_message
        end
    end

    # セグメントオブジェクトを返す
    def get_new_segment(id)
        Marshal.load(Marshal.dump(@hl7_segments[id]))
    end

    # データ型オブジェクトを返す
    def get_new_datatype(id)
        Marshal.load(Marshal.dump(@hl7_datatypes[id]))
    end

    # JSONパースされたメッセージを返す
    def get_parsed_message()
        return @parsed_message
    end

    def get_parsed_segments(segment_id)
        return @parsed_message.select{ |seg| seg[0]['value'] == segment_id }
    end

    def get_parsed_fields(segment_id, field_name)
        segments = get_parsed_segments(segment_id)
        if !segments.nil? then
            return segments.first.select{ |fld| fld['name'] == field_name }
        end
    end

    def get_parsed_value(segment_id, field_name)
        segments = get_parsed_segments(segment_id)
        if !segments.nil? then
            field = segments.first.find{ |fld| fld['name'] == field_name }
            if !field.nil? then
                return field['value']
            end
        end
    end

    # HL7メッセージ(Raw Data)をJSON形式にパースする
    def parse(raw_message)
        begin
            # 改行コード(セグメントターミネータ)が「\n」の場合は「\r」に置換する
            raw_message.gsub!("\n", "\r")
            # セグメント分割
            segments = raw_message.split(@segment_delim)
            result = Array[]
        
            segments.each do |seg|
                # メッセージ終端の場合は処理を抜ける
                if /\x1c/.match(seg) then
                    break
                end
                # 暫定処置：HL7のエンコードは「ISO-2022-JP」を基本とするが、UTF-8で送られてきた場合はそのまま使用する
                if seg.encoding().to_s != "UTF-8" then
                    seg_encoded = seg.force_encoding("ISO-2022-JP").encode("UTF-8")
                else
                    seg_encoded = seg  
                end
                # フィールド分割
                fields = seg_encoded.split(@field_delim)
                seg_id = fields[0]
                seg_json = get_new_segment(seg_id)
                seg_idx = 0

                seg_json.each do |fld|
                    # MSH-1は強制的にフィールドセパレータをセットする
                    if seg_id == "MSH" && fld["name"] == "Field Separator" then
                        value = @field_delim
                    else
                        if fields.length > seg_idx then
                            value = fields[seg_idx]
                        else
                            value = ""
                        end
                        seg_idx += 1
                    end
                    # 分割したフィールドの値をvalue要素として追加する
                    fld.store("value", value)
                    repeat_fields = Array[]

                    # MSH-2(コード化文字)には反復セパレータ(~)が含まれているので無視する
                    if seg_id == "MSH" && fld["name"] == "Encoding Characters" then
                        repeat_fields = Array[value]
                    else
                        # 反復フィールド分割
                        repeat_fields = value.split(@repeat_delim)
                    end
                    # データ型
                    type_id = fld["type"]
                    elm_jsons = Array[]

                    repeat_fields.each do |rep|
                        # フィールドデータを再帰的にパースする
                        ele_value = element_parse(rep, type_id, @element_delim)
                        if !ele_value.nil? then
                            elm_jsons.push(ele_value)
                        end
                    end
                    # 不要な要素を削除する
                    fld.delete("ssmix2-required")
                    fld.delete("nho_name")
                    
                    if elm_jsons.length > 0 then
                        fld.store("array_data", elm_jsons)
                    end
                end                
                result.push(seg_json)
            end
            @parsed_message = result
            return result
                
        rescue => exception
            # 例外
            puts exception
        end
    end

    private
    def element_parse(raw_data, type_id, delim)
        elm_json = get_new_datatype(type_id)
        elm_array = raw_data.split(delim)
        elm_idx = 0

        if elm_json.instance_of?(Array) then
            elm_json.each do |elm|
                elm.delete("nho_name")
                if elm_array.length > elm_idx then
                    value = elm_array[elm_idx]
                else
                    value = ""
                end
                elm.store("value", value)
                if !value.empty? then
                    array_data = element_parse(value, elm["type"], "&")
                    if !array_data.nil? then
                        elm.store("array_data", array_data)
                    end
                end
                elm_idx += 1
            end
            return elm_json
        end
    end
end