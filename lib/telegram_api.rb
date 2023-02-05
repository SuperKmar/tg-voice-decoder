# frozen_string_literal: true

require 'faraday'

# helper methods for working with telegram api
class TelegramApi
  HELP_TEXT = File.read('data/help.txt')
  TELEGRAM_URL = 'https://api.telegram.org'

  class FileDownloadError < StandardError; end

  def initialize(bot, token, logger)
    @bot = bot
    @token = token
    @logger = logger
  end

  def response_text(message, yandex_api)
    # minimal tg bot requirements: support of /start, /help, /settings
    # I only really need the /help option (the only one that makes sense)
    if message.text&.index('/help')&.zero?
      HELP_TEXT
    elsif message.voice.nil?
      'I need a voice message in .ogg format'
    elsif message.voice.mime_type == 'audio/ogg'
      yandex_generated_text(message, yandex_api)
    else
      'Somehow your voice message has an incorrect mime type. Only .ogg format is supported'
    end
  end

  private

  def yandex_generated_text(message, yandex_api)
    voice_file = proccess_voice_message(@bot.api.get_file(file_id: message.voice.file_id))

    raise 'No speech_to_text methods available' unless yandex_api.available?

    yandex_api.update_token if yandex_api.expired?

    yandex_api.speech_to_text(voice_file)
  end

  def proccess_voice_message(file_query)
    unless file_query['ok']
      @logger.fatal("Error when retrieving file from telegram: #{file_query}")
      raise StandardError
    end

    download_file(file_query['result']['file_path'])
  end

  def download_file(file_path)
    conn = Faraday.new(url: TELEGRAM_URL)

    response = conn.get("/file/bot#{@token}/#{file_path}")

    if response.status == 200
      @logger.debug("tg file download: #{file_path}. Status: #{response.status}")
    else
      @logger.fatal("error on tg file download: #{response.body}")
      raise FileDownloadError, response.body
    end

    response.body
  end
end
