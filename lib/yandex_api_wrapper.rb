require 'uri'
require 'net/http'
require 'json'
require 'time'
require "securerandom"
require 'faraday'
require 'tempfile'
require 'faraday/multipart'

class YandexApiWrapper
  class RequestFormatError < StandardError; end
  class BadOAuthToken      < StandardError; end
  class Unauthorized       < StandardError; end
  class CloudUnavailable   < StandardError; end
  class UnexpectedError    < StandardError; end

  TOKEN_ADDR          = 'https://iam.api.cloud.yandex.net'.freeze
  TOKEN_PATH          = '/iam/v1/tokens'.freeze
  SPEECH_TO_TEXT_ADDR = 'https://stt.api.cloud.yandex.net'.freeze
  SPEECH_TO_TEXT_PATH = '/speech/v1/stt:recognize'.freeze
  FOLDER_ADDR         = 'https://resource-manager.api.cloud.yandex.net/resource-manager/v1/folders'

  attr_reader :token, :expires_at

  def initialize(yandex_token, folder_id)
    @available = false
    @folder_id = folder_id
  	fill_token(yandex_token)
    @available = true
  end

  def valid?
  	Time.now < @expires_at
  end

  def invalid?
  	!valid?
  end

  alias expired? invalid?

  def available?
    @available
  end

  def test_token
    headers = {
      'Authorization' => "Bearer #{@token}"
    }

    conn = Faraday.new(
      url: 'https://resource-manager.api.cloud.yandex.net/resource-manager/v1/clouds',
      headers: headers
    )

    response = conn.get

    @available = false unless response.status == 200

    response.status == 200
  end

  # def curl_speech_to_text(file)

  #   tempfile = Tempfile.new(['speech_to_text','.ogg'])
  #   tempfile.write file

  #   puts "DEBUG: @token = #{@token}"

  #   cmd = [
  #     'curl -X POST -H ',
  #     '"Authorization: Bearer ',
  #     @token,
  #     '" "https://stt.api.cloud.yandex.net/speech/v1/stt:recognize?folderId=',
  #     @folder_id,
  #     '&lang=ru-RU"'
  #   ].join('')


  #   # cmd = 'curl -X POST -H '
  #   # cmd +=  "\"Authorization: Bearer #{@token}\" \"https://stt.api.cloud.yandex.net/speech/v1/stt:recognize?folderId=#{@folder_id}&lang=ru-RU\""

  #   # cmd = "curl -X POST -H \"authorization: Bearer #{@token}\"  -H \"Transfer-Encoding: chunked\" --data-binary @#{tempfile.path} \"https://stt.api.cloud.yandex.net/speech/v1/stt:recognize?folderId=#{@folder_id}\""

  #   puts "DEBUG: cmd = #{cmd}"
  #   res = `#{cmd}`

  #   puts "DEBUG: res = #{res}"
  # ensure
  #   tempfile.close
  #   tempfile.unlink
  # end


  def speech_to_text(file)
    headers = {
      'Authorization'          => "Bearer #{@token}",
      'Transfer-Encoding'      => 'chunked',
      'x-client-request-id'    => SecureRandom.uuid,
      'x-data-logging-enabled' => 'true'
    }

    puts "DEBUG: @token = #{@token}"
    puts "DEBUG: @folder_id = #{@folder_id}"

    tempfile = Tempfile.new(['speech_to_text','.ogg'])
    tempfile.write file

    conn = Faraday.new(url: SPEECH_TO_TEXT_ADDR, params: {folderId: @folder_id, lang: :auto}, headers: headers) do |faraday|
      faraday.request :multipart
      faraday.request :url_encoded
      faraday.adapter :net_http
    end

    conn.post(SPEECH_TO_TEXT_PATH) do |req|
      req.headers['Content-Type'] = 'octet/stream'
      req.body = Faraday::UploadIO.new(tempfile, 'octet/stream')
    end

    response = conn.post(SPEECH_TO_TEXT_PATH, file)


    puts "DEBUG: response.status = #{response.status}"
    puts "DEBUG: response.body = #{response.body}"

    case response.status
    when 200
      text = JSON.parse(response.body)['result']
      # TODO: add logging
      return text
    when 401
      # this happens due to free clouds not actually working
      if response.body.include? 'The cloud'
        @available = false
        raise CloudUnavailable
      end

      raise Unauthorized, "#{response.status}: #{response.body}"
    when 429
      # TODO: too many requests
    else
      #TODO: add logging
      raise UnexpectedError, "#{response.status}: #{response.body}"
    end
  ensure
    tempfile.close
    tempfile.unlink
  end

  private

  def fill_token(yandex_token)
    conn = Faraday.new(url: TOKEN_ADDR)

    response = conn.post(TOKEN_PATH) do |req|
      req.body = {yandexPassportOauthToken: yandex_token}.to_json
    end

  	case response.status
  	when 200
  		body = JSON.parse(response.body)
  		@token = body['iamToken']
  		@expires_at = Time.strptime(body['expiresAt'], '%FT%T')
  	when 400
  		# bad format?
  		raise RequestFormatError, response.body
  	when 401
  		# bad token
  		raise BadOAuthToken
  	else
  		raise UnexpectedError, "#{response.status}: #{response.body}"
  	end
  end
end
