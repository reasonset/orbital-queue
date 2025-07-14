#!/bin/env ruby
require 'minitest/autorun'
require 'tmpdir'

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'orbitalqueue'

class TestQueue < Minitest::Test
  def test_push_and_pop
    test_data = {str: "HelloTest"}
    result_data = nil

    Dir.mktmpdir do |dir|
      q = OrbitalQueue.new(dir, true)

      q.push test_data

      result_data = q.pop

      qid = q.complete(result_data[:queue_id])
      assert_instance_of String, qid
    end
    assert_equal "HelloTest", result_data[:str]
  end

  def test_pop_force
    test_data = {str: "HelloTest!"}
    result_data = nil

    Dir.mktmpdir do |dir|
      q = OrbitalQueue.new(dir, true)

      q.push test_data

      result_data = q.pop!
    end

    assert_equal "HelloTest!", result_data[:str]
    assert_instance_of String, result_data[:queue_id]
  end
end