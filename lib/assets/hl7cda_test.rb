# __END__
# require_relative 'cda_test'
# require_relative '../../vendor/ruby-cda/cda'
# require 'assets/cda_test'

# $LOAD_PATH.unshift File.join(File.dirname(__FILE__), '../')
# $LOAD_PATH.unshift File.join(File.dirname(__FILE__), '../lib')

require 'virtus'
# require 'lib/virtus_annotations'
# require 'lib/cda'
# require 'lib/ccd'
require 'virtus_annotations'
require 'cda'
require 'ccd'
require 'nokogiri'

file_name = File.join(File.dirname(__FILE__), 'HL7CDA.xml')
xml = Nokogiri::XML.parse(File.read(file_name))
xml.remove_namespaces!
# result = Cda::XmlParser
#   .new(xml.xpath('ClinicalDocument'), Ccd::Registry.instance)
#   .parse.record_target.first.patient_role.patient.name.first.given.first

result = Cda::XmlParser
  .new(xml.xpath('ClinicalDocument'), Ccd::Registry.instance).parse

puts result.record_target.first.patient_role.patient.name.first.given.first

pn = Ccd::ProgressNote.new()

pn.title = 'あああ'

record_target = Cda::RecordTarget.new()

patient_role = Cda::PatientRole.new()

patient = Cda::Patient.new()

name = Cda::PN.new()
name.given.push("てすと　たろー")

patient.name.push(name)
patient_role.patient = patient

record_target.patient_role = patient_role

pn.record_target.push(record_target)

# pn.record_target.push('aaa')
# pn.record_target[0].patient_role.patient.name.given = 'yoshinori'

builder = Cda::XmlBuilder.new(pn)

puts builder