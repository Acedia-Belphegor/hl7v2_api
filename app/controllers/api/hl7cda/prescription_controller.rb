# encoding: utf-8
require 'json'
require './lib/assets/hl7prescription_cda'
require './lib/assets/hl7sample'
include HL7Sample

class Api::Hl7cda::PrescriptionController < ApplicationController
    def index
        # GET：HL7サンプルメッセージを返す
        raw_message = get_message_rde()
        raw_message = raw_message.force_encoding("utf-8")
        cda = HL7PrescriptionCda.new(raw_message)        
        render xml: cda.generate_cda()
        # respond_to do |format|
        #     format.xml do
        #         send_data render_to_string, filename: 'HL7CDA.xml', type: 'application/xml; charset=utf-8'
        #     end
        # end
    end
  
    def create
        # POST：リクエストBODYに設定されたHL7RawDataを電子処方箋CDA形式にパースして返す
        raw_message = request.body.read
        raw_message = raw_message.force_encoding("utf-8")
        cda = HL7PrescriptionCda.new(raw_message)        
        render xml: cda.generate_cda()
    end
end