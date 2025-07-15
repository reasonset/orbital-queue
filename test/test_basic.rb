#!/bin/env ruby
require 'minitest/autorun'
require 'tmpdir'

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'orbitalqueue'

class TestQueue < Minitest::Test
  def test_push_and_pop
    test_data = {str: "HelloTest"}
    result = nil

    Dir.mktmpdir do |dir|
      q = OrbitalQueue.new(dir, true)

      q.push test_data

      result = q.pop

      qid = result.complete
      assert_instance_of String, qid
      assert_equal [".checkout"], Dir.children(dir)
      assert Dir.children(File.join(dir, ".checkout")).length.zero?
    end
    assert_instance_of OrbitalQueue::QueueObject, result
    assert_equal "HelloTest", result.data[:str]
    assert result.complete?
  end

  def test_push_and_pop_block
    test_data = {str: "HelloTestBlock"}
    result_data = nil

    Dir.mktmpdir do |dir|
      q = OrbitalQueue.new(dir, true)

      q.push test_data

      q.pop do |data|
        result_data = data
      end
      assert_equal [".checkout"], Dir.children(dir)
      assert Dir.children(File.join(dir, ".checkout")).length.zero?
    end
    assert_equal "HelloTestBlock", result_data[:str]
  end

  def test_pop_force
    test_data = {str: "HelloTest!"}
    result = nil

    Dir.mktmpdir do |dir|
      q = OrbitalQueue.new(dir, true)

      q.push test_data

      result = q.pop!
      assert_equal [".checkout"], Dir.children(dir)
      assert Dir.children(File.join(dir, ".checkout")).length.zero?
    end

    assert_instance_of OrbitalQueue::QueueObject, result
    assert_equal "HelloTest!", result.data[:str]
    assert result.complete?
  end
end