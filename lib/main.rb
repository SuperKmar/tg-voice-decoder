# frozen_string_literal: true

require 'logger'
require 'telegram/bot'
require_relative 'yandex_api_wrapper'
require_relative 'telegram_api'

#  t.me/KmarVoiceTranscriberBot
TELEGRAM_TOKEN = ARGV[0]
YANDEX_TOKEN = ARGV[1]
YANDEX_FOLDER_ID = ARGV[2]
logger = Logger.new($stdout)
yandex_api = YandexApiWrapper.new(YANDEX_TOKEN, YANDEX_FOLDER_ID, logger)
Telegram::Bot::Client.run(TELEGRAM_TOKEN) do |bot|
  tg_api = TelegramApi.new(bot, TELEGRAM_TOKEN, logger)

  bot.listen do |message|
    text = tg_api.response_text(message, yandex_api)
    bot.api.send_message(chat_id: message.chat.id, text:)
  end
end
