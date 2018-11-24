require_relative 'hl7sample'
require_relative 'hl7prescription_cda'
include HL7Sample

raw_data = get_message_rde()
raw_data = raw_data.force_encoding("utf-8")

cda = HL7PrescriptionCda.new(raw_data)
xml = cda.generate_cda()

# xml = cda.build_document()

puts xml

# parser = HL7Parser.new()
# json_data = parser.parse(raw_data)

# puts json_data
