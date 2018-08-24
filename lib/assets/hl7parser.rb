# encoding: UTF-8
require 'json'

module HL7Parser

    def initialize()
        # @segment_delim = "\r"
        @segment_delim = "\n"
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
            segments = raw_message.split(@segment_delim)
            result = Array[]
        
            segments.each do |seg|
                # if /\x1c/.match(seg) then
                #     break
                # end
                # seg_encoded = seg.encode("UTF-8", "ISO-2022-JP")
                seg_encoded = seg
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
                    fld.store("raw_field", value)
                    repeat_fields = Array[]

                    if seg_id == "MSH" && fld["nho_name"] == "cdchar" then
                        repeat_fields = Array[value]
                    else
                        repeat_fields = value.split(@repeat_delim)
                    end
                    type_id = fld["type"]
                    elm_jsons = Array[]

                    repeat_fields.each do |rep|
                        elm_json = get_datatype(type_id)
                        elm_array = rep.split(@element_delim)
                        elm_idx = 0

                        if elm_json.instance_of?(Array) then
                            elm_json.each do |elm|
                                elm.store("value", elm_array[elm_idx])
                                elm_idx += 1
                            end
                            elm_jsons.push(elm_json)
                        else
                            elm_jsons.push(rep)
                        end
                    end
                    fld.store("fields", elm_jsons)
                end
                result.push(seg_json)
            end
            return result
                
        rescue => ex
            puts ex
        end
    end

    # temp = { test1: "aaaaa", test2: "bbbbb" }
    # jwk = JSON.parse(temp)

    # file_path = "../sample_data/99990010_-_ADT-00_999999999999999_20161028143312352_-_1"

    # f = File.open(file_path)
    # s = f.read
    # f.close

    # initialize()
    # hl7_parsed = HL7Parser.parse(s)

    # puts hl7_parsed
end