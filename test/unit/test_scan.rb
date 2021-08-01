# requires
require 'minitest/autorun'
require './lib/knight'

class KnightTest < Minitest::Test

  def setup
    @test_host = 'google.net'
  end

  def test_public_methods
    assert_equal(true, Knight::Scan.public_method_defined?(:scan))
    assert_equal(true, Knight::Scan.public_method_defined?(:add_target))
    assert_equal(true, Knight::Scan.public_method_defined?(:scan_from_plugin))
  end

  def test_private_methods
    assert_equal(true, Knight::Scan.private_method_defined?(:prepare_target))
    assert_equal(true, Knight::Scan.private_method_defined?(:make_target_list))
  end

  def test_invalid_url
    assert_raises 'No targets selected' do
      Knight::Scan.new(nil)
    end
    assert_raises 'No targets selected' do
      Knight::Scan.new('')
    end
    assert_raises 'No targets selected' do
      Knight::Scan.new([])
    end
    assert_raises 'No targets selected' do
      Knight::Scan.new({})
    end
    assert_raises 'No targets selected' do
      Knight::Scan.new([[]])
    end
    assert_raises 'No targets selected' do
      Knight::Scan.new([{}])
    end
  end

  def test_scanner
    scanner = Knight::Scan.new(@test_host)
    assert(scanner)
  end

  def test_scan
    max_redirects = 5
    plugins = PluginSupport.load_plugins
    assert(plugins)

    scanner = Knight::Scan.new(@test_host, max_threads: 25)

    scanner.scan do |target|
      assert(target)
      result = Knight::Parser.run_plugins(target, plugins, scanner: scanner)
      assert(result)

      Knight::Redirect.new(target, scanner, max_redirects)

      knight_result = Knight::Parser.parse(target, result)
      assert(knight_result['target'])
      assert(knight_result['status'])
      assert(knight_result['result'])
      countries = knight_result['result'].select { |a| a[0] == 'Country' }
      assert_equal('Country', countries.first[0])
    end
  end 
end