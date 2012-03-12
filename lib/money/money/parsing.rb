#encoding: utf-8

class Money
  module Parsing
    def self.included(base)
      base.extend ClassMethods
    end

    module ClassMethods
      # Parses the current string and converts it to a +Money+ object.
      # Excess characters will be discarded.
      #
      # @param [String, #to_s] input The input to parse.
      # @param [Currency, String, Symbol] currency The currency format.
      #   The currency to set the resulting +Money+ object to.
      #
      # @return [Money]
      #
      # @raise [ArgumentError] If any +currency+ is supplied and
      #   given value doesn't match the one extracted from
      #   the +input+ string.
      #
      # @example
      #   '100'.to_money                #=> #<Money @cents=10000>
      #   '100.37'.to_money             #=> #<Money @cents=10037>
      #   '100 USD'.to_money            #=> #<Money @cents=10000, @currency=#<Money::Currency id: usd>>
      #   'USD 100'.to_money            #=> #<Money @cents=10000, @currency=#<Money::Currency id: usd>>
      #   '$100 USD'.to_money           #=> #<Money @cents=10000, @currency=#<Money::Currency id: usd>>
      #   'hello 2000 world'.to_money   #=> #<Money @cents=200000 @currency=#<Money::Currency id: usd>>
      #
      # @example Mismatching currencies
      #   'USD 2000'.to_money("EUR")    #=> ArgumentError
      #
      # @see Money.from_string
      #
      def parse(input, currency = nil)
        i = input.to_s.strip

        # raise Money::Currency.table.collect{|c| c[1][:symbol]}.inspect

        # Check the first character for a currency symbol, alternatively get it
        # from the stated currency string
        c = if Money.assume_from_symbol && i =~ /^(\$|€|£)/
          case i
          when /^$/ then "USD"
          when /^€/ then "EUR"
          when /^£/ then "GBP"
          end
        else
          m = i.scan(/([A-Z]{2,3})/)
          m[0] ? m[0][0] : nil
        end

        # check that currency passed and embedded currency are the same,
        # and negotiate the final currency
        if currency.nil? and c.nil?
          currency = Money.default_currency
        elsif currency.nil?
          currency = c
        elsif c.nil?
          currency = currency
        elsif currency != c
          # TODO: ParseError
          raise ArgumentError, "Mismatching Currencies"
        end
        currency = Money::Currency.wrap(currency)

        cents = extract_cents(i, currency)
        new(cents, currency)
      end

      # Converts a String into a Money object treating the +value+
      # as dollars and converting them to the corresponding cents value,
      # according to +currency+ subunit property,
      # before instantiating the Money object.
      #
      # Behind the scenes, this method relies on {Money.from_bigdecimal}
      # to avoid problems with string-to-numeric conversion.
      #
      # @param [String, #to_s] value The money amount, in dollars.
      # @param [Currency, String, Symbol] currency
      #   The currency to set the resulting +Money+ object to.
      #
      # @return [Money]
      #
      # @example
      #   Money.from_string("100")
      #   #=> #<Money @cents=10000 @currency="USD">
      #   Money.from_string("100", "USD")
      #   #=> #<Money @cents=10000 @currency="USD">
      #   Money.from_string("100", "EUR")
      #   #=> #<Money @cents=10000 @currency="EUR">
      #   Money.from_string("100", "BHD")
      #   #=> #<Money @cents=100 @currency="BHD">
      #
      # @see String#to_money
      # @see Money.parse
      #
      def from_string(value, currency = Money.default_currency)
        from_non_string(BigDecimal.new(value.to_s), currency)
      end

      # Converts a numeric type into a Money object treating the +value+
      # as dollars and converting them to the corresponding cents value,
      # according to +currency+ subunit property,
      # before instantiating the Money object.
      #
      # @param [Fixnum, Float, or BigDecimal] value The money amount, in dollars.
      # @param [Currency, String, Symbol] currency The currency format.
      #
      # @return [Money]
      #
      # @example
      #   Money.from_non_string(100)
      #   #=> #<Money @cents=10000 @currency="USD">
      #   Money.from_non_string(100, "USD")
      #   #=> #<Money @cents=10000 @currency="USD">
      #   Money.from_non_string(100, "EUR")
      #   #=> #<Money @cents=10000 @currency="EUR">
      #   Money.from_non_string(100, "BHD")
      #   #=> #<Money @cents=100 @currency="BHD">
      #
      # @see Fixnum#to_money
      # @see Money.from_non_string
      #
      def from_non_string(value, currency = Money.default_currency)
        currency = Money::Currency.wrap(currency)
        amount   = value * currency.subunit_to_unit
        new(amount, currency)
      end

      # Takes a number string and attempts to massage out the number.
      #
      # @param [String] input The string containing a potential number.
      #
      # @return [Integer]
      #
      def extract_cents(input, currency = Money.default_currency)
        # remove anything that's not a number, potential thousands_separator, or minus sign
        num = input.
          gsub(/[^\d\.,\'\-]/, '').
          strip

        # set a boolean flag for if the number is negative or not
        negative = num =~ /^-|-$/ ? true : false

        # if negative, remove the minus sign from the number
        # if it's not negative, the hyphen makes the value invalid
        if negative
          num = num.sub(/^-|-$/, '')
        end

        raise ArgumentError, "Invalid currency amount (hyphen)" if num.include?('-')

        num = num.gsub(currency.delimiter, '').gsub(currency.separator, '.')
        digits = currency.subunit_to_unit.to_s.length - 1
        # TODO: This is an ugly hack to address the MGA tests failing, but
        # TODO: honestly, I'm not sure the behavior is 'correct' when we go to
        # TODO: more than a digit of precision for it.
        digits = 1 if digits < 1
        major = num.to_i
        minor = (BigDecimal.new(num) - major) * (10 ** digits)
        cents = (major * currency.subunit_to_unit) + minor

        # if negative, multiply by -1; otherwise, return positive cents
        cents = negative ? cents * -1 : cents
        return cents
      end
    end
  end
end
