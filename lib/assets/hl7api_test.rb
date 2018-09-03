# encoding: utf-8
require 'net/http'
require 'uri'
require 'json'
require 'openssl'

file_path = "/Users/yoshinori/SSMIX2_Sample_STD/999/900/99990010/-/ADT-00/99990010_-_ADT-00_999999999999999_20161028143312352_-_1"
file = File.open(file_path)
raw_data = file.read
raw_data = raw_data.force_encoding("ISO-2022-JP").encode("UTF-8")
file.close

# url = URI.parse(URI.escape('https://hl7v2-api.herokuapp.com/api/v1/hl7parses'))
# res = Net::HTTP.start(url.host, url.port, use_ssl: true){|http|
#     http.get(url.path + "?" + url.query);
# }
# obj = JSON.parse(res.body)

uri = URI.parse("https://hl7v2-api.herokuapp.com/api/v1/hl7parses/")
http = Net::HTTP.new(uri.host, uri.port)

http.use_ssl = true
http.verify_mode = OpenSSL::SSL::VERIFY_NONE

req = Net::HTTP::Post.new(uri.path)
req["Content-Type"] = "text/plain"
req.body = raw_data

res = http.request(req)
obj = JSON.parse(res.body)

puts obj
