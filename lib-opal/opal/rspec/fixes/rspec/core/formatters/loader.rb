class ::RSpec::Core::Formatters::Loader
  def string_const?(str)
    # Incompatible regex (\A flag and \z flag)
    # str.is_a?(String) && /\A[A-Z][a-zA-Z0-9_:]*\z/ =~ str
    str.is_a?(String) && /^[A-Z][a-zA-Z0-9_:]*$/ =~ str
  end

  def underscore(camel_cased_word)
    # string mutation
    word = camel_cased_word.to_s.dup
    word = word.gsub(/::/, '/')
    word = word.gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
    word = word.gsub(/([a-z\d])([A-Z])/, '\1_\2')
    word = word.tr("-", "_")
    word.downcase
  end

  alias add_without_fix add
  def add(formatter_to_use, *paths)
    paths = paths.map{|p| String === p ? file_at(p) : p }
    add_without_fix(formatter_to_use, *paths)
  end

  def custom_formatter(formatter_ref)
    if Class === formatter_ref
      formatter_ref
    elsif string_const?(formatter_ref)
      # retry not supported on opal
      # begin
      #   formatter_ref.gsub(/^::/, '').split('::').inject(Object) { |a, e| a.const_get e }
      # rescue NameError
      #   require(path_for(formatter_ref)) ? retry : raise
      # end
      while true
        begin
          return formatter_ref.gsub(/^::/, '').split('::').inject(Object) { |a, e| a.const_get e }
        rescue NameError
          raise unless require(path_for(formatter_ref))
        end
      end
    end
  end
end

