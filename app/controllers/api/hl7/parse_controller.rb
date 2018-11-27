# encoding: utf-8
require 'json'
require './lib/assets/hl7parser'
require './lib/assets/hl7sample'
include HL7Sample

class Api::Hl7::ParseController < ApplicationController
    def index
        # GET：HL7サンプルメッセージを返す
        raw_message = get_message_rde()
        raw_message = raw_message.force_encoding("utf-8")
        parser = HL7Parser.new(raw_message)        
        render json: parser.get_parsed_message()
    end
  
    def create
        # POST：リクエストBODYに設定されたHL7RawDataを電子処方箋CDA形式にパースして返す
        raw_message = request.body.read
        raw_message = raw_message.force_encoding("utf-8")
        parser = HL7Parser.new(raw_message)        
        render json: parser.get_parsed_message()
    end
end