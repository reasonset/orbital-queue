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
      assert_equal 4, Dir.children(dir).length
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
      assert_equal 4, Dir.children(dir).length
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
      assert_equal 4, Dir.children(dir).length
      assert Dir.children(File.join(dir, ".checkout")).length.zero?
    end

    assert_instance_of OrbitalQueue::QueueObject, result
    assert_equal "HelloTest!", result.data[:str]
    assert result.complete?
  end

  def test_each
    total_vol = 0

    Dir.mktmpdir do |dir|
      q = OrbitalQueue.new(dir, true)

      3.times do |i|
        q.push({vol: (i+1)})
      end

      q.each do |data|
        total_vol += data[:vol]
      end
    end

    assert_equal 6, total_vol
  end

  def test_each_item
    total_vol = 0

    Dir.mktmpdir do |dir|
      q = OrbitalQueue.new(dir, true)

      3.times do |i|
        q.push({vol: (i+1)})
      end

      q.each_item do |item|
        assert_instance_of OrbitalQueue::QueueObject, item
      end
    end
  end

  def test_defer
    test_data = {str: "HelloTest!!!"}
    result = nil

    Dir.mktmpdir do |dir|
      q = OrbitalQueue.new(dir, true)

      q.push test_data

      result = q.pop
      result.defer(Time.now)

      sleep 2

      q.resume
      result = q.pop
      result.complete
    end

    assert_instance_of OrbitalQueue::QueueObject, result
    assert_equal "HelloTest!!!", result.data[:str]
    assert result.complete?
  end

  def test_defer_destruct
    test_data = {str: "HelloTest!!!"}
    result = nil

    Dir.mktmpdir do |dir|
      q = OrbitalQueue.new(dir, true)

      q.push test_data

      result = q.pop
      result.defer do |retry_data|
        assert_instance_of Hash, retry_data
        result.destruct
      end

      assert Dir.glob([dir, "**", "*.marshal"].join("/"), File::FNM_DOTMATCH).empty?
    end

    assert result.complete?
  end

  def test_defer_archive
    test_data = {str: "HelloTest!!!"}
    result = nil

    Dir.mktmpdir do |dir|
      q = OrbitalQueue.new(dir, true)

      q.push test_data

      result = q.pop
      result.defer do |retry_data|
        assert_instance_of Hash, retry_data
        result.archive
      end

      assert_equal 1, Dir.glob([dir, "**", "*.marshal"].join("/"), File::FNM_DOTMATCH).size
    end

    assert result.complete?
  end
end