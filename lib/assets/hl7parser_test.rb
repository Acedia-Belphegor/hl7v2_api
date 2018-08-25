# encoding: utf-8
require 'json'
require './hl7parser'
require './hl7sample'
include HL7Parser
include HL7Sample

file_path = "/Users/yoshinori/SSMIX2_Sample_STD/999/900/99990010/-/ADT-00/99990010_-_ADT-00_999999999999999_20161028143312352_-_1"
file = File.open(file_path)
raw_data = file.read
# puts raw_data.encoding()
# raw_data = raw_data.force_encoding("utf-8")
file.close

# raw_data = get_message_rde()
# # puts raw_data.encoding()
# raw_data = raw_data.force_encoding("utf-8")

@segment_delim = "\r"
# @segment_delim = "\r".force_encoding("ISO-2022-JP")
@field_delim = "|"
@element_delim = "^"
@repeat_delim = "~"

@hl7_datatypes = open("./json/HL7_DATATYPE.json") do |io|
    JSON.load(io)
end

@hl7_segments = open("./json/HL7_SEGMENT.json") do |io|
    JSON.load(io)
end    

result = parse(raw_data)
puts result
