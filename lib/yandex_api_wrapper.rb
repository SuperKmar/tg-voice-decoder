# frozen_string_literal: true

require 'json'
require 'time'
require 'securerandom'
require 'faraday'
require 'faraday/multipart'

# Communication with yandex cloud, working with temporary tokens, sending files for speech_to_text
class YandexApiWrapper
  class RequestFormatError < StandardError; end
  class BadOAuthToken      < StandardError; end
  class Unauthorized       < StandardError; end
  class CloudUnavailable   < StandardError; end
  class UnexpectedError    < StandardError; end

  TOKEN_ADDR          = 'https://iam.api.cloud.yandex.net'
  TOKEN_PATH          = '/iam/v1/tokens'
  SPEECH_TO_TEXT_ADDR = 'https://stt.api.cloud.yandex.net'
  SPEECH_TO_TEXT_PATH = '/speech/v1/stt:recognize'
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
      headers:
    )

    response = conn.get

    @available = false unless response.status == 200

    response.status == 200
  end

  def speech_to_text(file)
    conn = speech_to_text_connection
    response = conn.post(SPEECH_TO_TEXT_PATH, file)

    case response.status
    when 200
      JSON.parse(response.body)['result']
      # TODO: add logging

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
      # TODO: add logging
      raise UnexpectedError, "#{response.status}: #{response.body}"
    end
  end

  private

  def fill_token(yandex_token)
    conn = Faraday.new(url: TOKEN_ADDR)

    response = conn.post(TOKEN_PATH, { yandexPassportOauthToken: yandex_token }.to_json)

    case response.status
    when 200
      body = JSON.parse(response.body)
      @token = body['iamToken']
      @expires_at = Time.strptime(body['expiresAt'], '%FT%T')
    when 401
      # bad token
      raise BadOAuthToken
    else
      raise UnexpectedError, "#{response.status}: #{response.body}"
    end
  end

  def speech_to_text_connection
    headers = {
      'Authorization' => "Bearer #{@token}",
      'Transfer-Encoding' => 'chunked',
      'x-client-request-id' => SecureRandom.uuid,
      'x-data-logging-enabled' => 'true',
      'Content-Type' => 'octet/stream'
    }

    Faraday.new(url: SPEECH_TO_TEXT_ADDR,
                params: { folderId: @folder_id, lang: :auto },
                headers:) do |faraday|
      faraday.request :multipart
      faraday.request :url_encoded
      faraday.adapter :net_http
    end
  end
end
