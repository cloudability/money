module CurrencyLoader
  extend self

  DATA_PATH = File.expand_path("../../../config", __FILE__)

  # Loads and returns the currencies stored in JSON files in the config directory.
  #
  # @return [Hash]
  def load_currencies(silence_missing_ids_error = false)
    currencies = parse_currency_file("currency.json")
    currencies.merge! parse_currency_file("currency_bc.json")
    currencies.each do |key, currency|
      if(!currency.has_key?(:key))
        currency[:key] = key
      else
        raise Exception.new("Currency already has key (#{currency[:key]}) but we want to give it a new one (#{key})!")
      end
    end

    begin
      parse_currency_file("currency_ids.json").
        each_pair { |key, id| currencies[key][:id] = id }
      missing_ids = currencies.values.select { |currency| !currency.has_key?(:id) }

      if(missing_ids.count > 0)
        missing_keys = missing_ids.map { |currency| currency[:iso_code] }.join(', ')
        raise Exception.new("The following currencies are missing short IDs.  Go run 'rake assign_ids' to fix it: #{missing_keys}")
      end
    rescue Exception => e
      unless(silence_missing_ids_error)
        raise e
      end
    end

    return currencies
  end

  private

  def parse_currency_file(filename)
    json = File.read("#{DATA_PATH}/#{filename}")
    json.force_encoding(::Encoding::UTF_8) if defined?(::Encoding)
    JSON.parse(json, :symbolize_names => true)
  end
end
