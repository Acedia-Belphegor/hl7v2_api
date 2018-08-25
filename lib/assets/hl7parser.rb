# encoding: UTF-8
require 'json'

module HL7Parser

    def initialize()
        @segment_delim = "\r"
        @field_delim = "|"
        @element_delim = "^"
        @repeat_delim = "~"

        @hl7_datatypes = open("lib/assets/json/HL7_DATATYPE.json") do |io|
            JSON.load(io)
        end

        @hl7_segments = open("lib/assets/json/HL7_SEGMENT.json") do |io|
            JSON.load(io)
        end    
    end

    def get_segment(id)
        Marshal.load(Marshal.dump(@hl7_segments[id]))
    end

    def get_datatype(id)
        Marshal.load(Marshal.dump(@hl7_datatypes[id]))
    end

    def parse(raw_message)
        begin
            raw_message.gsub!("\n", "\r")
            segments = raw_message.split(@segment_delim)
            result = Array[]
        
            segments.each do |seg|
                if /\x1c/.match(seg) then
                    break
                end
                if seg.encoding().to_s != "UTF-8" then
                    seg_encoded = seg.force_encoding("ISO-2022-JP").encode("UTF-8")
                else
                    seg_encoded = seg  
                end                
                fields = seg_encoded.split(@field_delim)
                seg_id = fields[0]
                seg_json = get_segment(seg_id)
                seg_idx = 0

                seg_json.each do |fld|
                    if seg_id == "MSH" && fld["nho_name"] == "fieldchar" then
                        value = @field_delim
                    else
                        if fields.length > seg_idx then
                            value = fields[seg_idx]
                        else
                            value = ""
                        end
                        seg_idx += 1
                    end
                    fld.store("value", value)
                    repeat_fields = Array[]

                    if seg_id == "MSH" && fld["nho_name"] == "cdchar" then
                        repeat_fields = Array[value]
                    else
                        repeat_fields = value.split(@repeat_delim)
                    end
                    type_id = fld["type"]
                    elm_jsons = Array[]

                    repeat_fields.each do |rep|
                        ele_value = element_parse(rep, type_id, @element_delim)
                        if !ele_value.nil? then
                            elm_jsons.push(ele_value)
                        end
                    end
                    fld.delete("ssmix2-required")
                    fld.delete("nho_name")
                    if elm_jsons.length > 0 then
                        fld.store("array_data", elm_jsons)
                    end
                end                
                result.push(seg_json)
            end
            return result
                
        rescue => exception
            puts exception
        end
    end

    def element_parse(raw_data, type_id, delim)
        elm_json = get_datatype(type_id)
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