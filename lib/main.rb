require 'faraday'
require "telegram/bot"
require_relative "yandex_api_wrapper"

#  t.me/KmarVoiceTranscriberBot
TELEGRAM_TOKEN = ARGV[0]
YANDEX_TOKEN = ARGV[1]
YANDEX_FOLDER_ID = ARGV[2] || 'b1gkh904kt4q1hmo83eh' # TODO ? there is a complicated way of getting a list of folders, but no way of determining which one is correct

SERVICE_URI = 'https://stt.api.cloud.yandex.net/speech/v1/stt:recognize'

yandex_api = YandexApiWrapper.new(YANDEX_TOKEN, YANDEX_FOLDER_ID)
yandex_api.test_token

def download_file(file_path)
  result = Faraday.new(url: "https://api.telegram.org/file/bot#{TELEGRAM_TOKEN}/#{file_path}").get
  # TODO: perhaps some logs for working with tg api?
  result.body
end

Telegram::Bot::Client.run(TELEGRAM_TOKEN) do |bot|
  bot.listen do |message|
  	# puts "DEBUG: message = #{message}"
  	# message media_group_id

    # minimal tg bot requirements: support of /start, /help, /settings, i only really need the /help option


  	if message.voice.nil?
  	  bot.api.send_message(chat_id: message.chat.id, text: "I need an audio file")
  	else
      text = 'No speech conversion services are responding'
      file_query = bot.api.get_file(file_id: message.voice.file_id)

      unless file_query['ok']
        # TODO: log error here
        raise StandardError
      end

      file_path = file_query['result']['file_path']
      voice = download_file(file_path)

      if yandex_api.available?
        if yandex_api.expired?
          yandex_api = YandexApiWrapper.new(YANDEX_TOKEN, YANDEX_FOLDER_ID)
        end

        text = yandex_api.speech_to_text(voice)
      else
        # alternative api should be selected here
        # or a local method of speech to text
        # everything that falls into this branch should be considered out-of-scope for now
      end

      bot.api.send_message(chat_id: message.chat.id, text: text)
  		# message.voice has file_id, file_unique_id, duration, mime_type, file_size
  	  # bot.api.transcribedAudio(chat_id: message.chat.id, msg_id: message.message_id)
  	  # bot.api.send_message(chat_id: message.chat.id, text: text)
  	end
  end
end



# bot.on("voice",ctx => {
#   ctx.telegram.getFileLink(ctx.message.vioce.file_id).then((url) => {
#       axios.get(url, { responseType: "arraybuffer" }).then((voice) => {
#       fs.writefile(`./lib/voices/${ctx.from.id}/${ctx.message.vioce.file_id}.ogg`,voice)})
#   })
# })
{
  "ok"=>true,
  "result"=>{
    "file_id"=>"AwACAgIAAxkBAAMOY96e8cNfT2Dci2owp1JxCLaB13oAAoYlAAKHM_BKvneYYQ5N8wsuBA",
    "file_unique_id"=>"AgADhiUAAocz8Eo",
    "file_size"=>8093,
    "file_path"=>"voice/file_0.oga"
  }
}
