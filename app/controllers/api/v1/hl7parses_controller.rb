# encoding: utf-8
require 'json'
require './lib/assets/hl7parser'
require './lib/assets/hl7sample'
include HL7Parser
include HL7Sample

class Api::V1::Hl7parsesController < ApplicationController
    def index
        # GET：HL7サンプルメッセージを返す
        raw_message = get_message_adt()
        raw_message = raw_message.force_encoding("utf-8")
        result = parse(raw_message)
        render json: result
    end
  
    def create
        # POST：リクエストBODYに設定されたHL7RawDataをJSON形式にパースして返す
        raw_message = request.body.read
        raw_message = raw_message.force_encoding("utf-8")
        result = parse(raw_message)
        render json: result
    end
end