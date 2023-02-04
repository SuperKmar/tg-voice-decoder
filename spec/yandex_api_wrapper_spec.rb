# TODO specs designed to work locally
# TODO

require 'yandex_api_wrapper'
require 'securerandom'

describe YandexApiWrapper do
  subject(:ya_wrapper) { described_class.new(oauth_token, folder_id) }

  let(:folder_id) { 'b1gkh904kt4q1hmo83eh' }
  let(:oauth_token) { File.read('.yandex_token').chomp }

  describe 'creating an API token' do
  	context 'correct oatuth token' do
  	  it { expect{ ya_wrapper }.to_not raise_error }
  	  it { expect(ya_wrapper.token).not_to be_nil}
  	  it { expect(ya_wrapper.expires_at).not_to be_nil}
  	end

  	context 'incorrect oauth token' do
  	  let(:oauth_token) { SecureRandom.hex }

  	  it { expect{ ya_wrapper }.to raise_error YandexApiWrapper::BadOAuthToken }
  	end
  end

  describe '#valid?' do
  end

  describe '#invalid?' do
  end

  describe '#test_token' do
  	it { expect(ya_wrapper.test_token).to eq true }
  end

  describe '#speech_to_text' do
  	let(:file) { IO.read('spec/examples/audio_2023-02-01_20-26-35.ogg')}

  	context 'correct file' do
  	  it { expect(ya_wrapper.speech_to_text(file)).to eq('this is a test') }
  	end
  end

end
