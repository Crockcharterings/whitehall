class Locale < Struct.new(:code)
  class << self
    def all
      I18n.available_locales.map do |l|
        new(l)
      end
    end

    def non_english
      all - [Locale.new(:en)]
    end
  end

  def native_language_name
    I18n.t("language_names.#{code}", locale: code)
  end

  def to_param
    code.to_s
  end
end

