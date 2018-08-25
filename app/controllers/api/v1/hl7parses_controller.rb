# encoding: utf-8
require 'json'
require './lib/assets/hl7parser'
require './lib/assets/hl7sample'
include HL7Parser
include HL7Sample

class Api::V1::Hl7parsesController < ApplicationController
    def index
        raw_message = get_message_adt()
        raw_message = raw_message.force_encoding("utf-8")
        result = parse(raw_message)
        render json: result
    end
  
    def create
        # render json: { test1: "aaaa", test2: request.headers['test-key'] }

        # s = request.body.read.to_s.encode("UTF-8", "ISO-2022-JP")
        # s = request.body.to_s.encode("UTF-8", "ISO-2022-JP")
        s = request.body.read
        s = s.force_encoding("utf-8")

        # s = s.to_s.encode("ISO-2022-JP", "UTF-8")

        # puts s.encoding()
        # puts s
        # s = s.force_encoding("ISO-2022-JP")

        # parser = new HL7Parser()
        result = parse(s)
        # puts result

        render json: result

        # render json: { 
        #     test1: "aaaa", 
        #     test2: request.headers['Content-Type'],
        #     test3: "あああ",
        #     test4: s.force_encoding("utf-8")
        # }
    end
end