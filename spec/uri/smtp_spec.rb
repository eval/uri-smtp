# frozen_string_literal: true

RSpec.describe URI::SMTP do
  it "has a version number" do
    expect(URI::SMTP::VERSION).not_to be nil
  end
end
