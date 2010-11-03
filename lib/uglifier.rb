require "v8"

class Uglifier
  # Raised when compilation fails
  class Error < StandardError; end

  DEFAULTS = {
    :mangle => true,
    :toplevel => false,
    :squeeze => true,
    :seqs => true,
    :dead_code => true,
    :beautify => false,
    :beautify_options => {
      :indent_level => 4,
      :indent_start => 0,
      :quote_keys => false,
      :space_colon => 0
    }
  }

  def initialize(options = {})
    @options = DEFAULTS.merge options
  end

  def compile(source)
    V8::Context.new do |cxt|
      initialize_v8(cxt)
      begin
        return generate_code(cxt, ast(cxt, source))
      rescue Exception => e
        raise Error.new(e.message)
      end
    end
  end

  private

  def generate_code(cxt, ast)
    cxt["gen_code"].call(ast, @options[:beautify] && @options[:beautify_options])
  end

  def ast(cxt, source)
    squeeze(cxt, mangle(cxt, cxt["parse"].call(source)))
  end

  def mangle(cxt, ast)
    cxt["ast_mangle"].call(ast, @options[:toplevel])
  end

  def squeeze(cxt, ast)
    cxt["ast_squeeze"].call(ast, {
      "make_seqs" => @options[:seqs],
      "dead_code" => @options[:dead_code]
    })
  end

  def initialize_v8(cxt)
    cxt["process"] = { :version => "v1" }
    exports = {
      "sys" => {
        :debug => lambda { |m| puts m }
      },
      "./parse-js" => load_file(cxt, "vendor/uglifyjs/lib/parse-js.js")
    }

    cxt["require"] = lambda do |file|
      exports[file]
    end

    load_file(cxt, "vendor/uglifyjs/lib/process.js")
  end

  def load_file(cxt, file)
    cxt["exports"] = {}
    cxt.load(File.join(File.dirname(__FILE__), "..", file))
    cxt["exports"]
  end
end
