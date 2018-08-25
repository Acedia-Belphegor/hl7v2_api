# encoding: utf-8
require 'json'
require './hl7parser'
require './hl7sample'
include HL7Parser
include HL7Sample

raw_message = get_message_rde()
# puts raw_message.encoding()
raw_message = raw_message.force_encoding("utf-8")
# puts raw_message.encoding()

@segment_delim = "\r"
@field_delim = "|"
@element_delim = "^"
@repeat_delim = "~"

@hl7_datatypes = open("./json/HL7_DATATYPE.json") do |io|
    JSON.load(io)
end

@hl7_segments = open("./json/HL7_SEGMENT.json") do |io|
    JSON.load(io)
end    

result = parse(raw_message)
puts result
