# frozen_string_literal: true

# TODO: specs designed to work locally

require 'yandex_api_wrapper'
require 'timecop'

describe YandexApiWrapper do
  subject(:ya_wrapper) { described_class.new(oauth_token, folder_id) }

  let(:folder_id) { 'b1gkh904kt4q1hmo83eh' }
  let(:oauth_token) { File.read('.yandex_token').chomp }

  describe 'creating an API token' do
    context 'when oauth token is correct' do
      it { expect { ya_wrapper }.not_to raise_error }
      it { expect(ya_wrapper.token).not_to be_nil }
      it { expect(ya_wrapper.expires_at).not_to be_nil }
    end

    context 'when oauth token is incorrect' do
      let(:oauth_token) { SecureRandom.hex }

      it { expect { ya_wrapper }.to raise_error YandexApiWrapper::BadOAuthToken }
    end
  end

  describe '#valid?' do
    context 'when token is fresh' do
      it { expect(ya_wrapper.valid?).to eq true }
    end

    context 'when token is stale' do
      before do
        Timecop.travel(Time.now + WEEK_IN_SECONDS)
      end

      after do
        Timecop.return
      end

      it { expect(ya_wrapper.valid?).to eq false }
    end
  end

  describe '#test_token' do
    it { expect(ya_wrapper.test_token).to eq true }
  end

  describe '#speech_to_text' do
    let(:file) { IO.read('spec/examples/audio_2023-02-01_20-26-35.ogg') }

    context 'when correct audio file' do
      it { expect(ya_wrapper.speech_to_text(file)).to eq('this is a test') }
    end
  end
end
