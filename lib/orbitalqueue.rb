#!/bin/env ruby
require 'securerandom'

class OrbitalQueue
  ##
  # File-based queue for Orbital design pattern.

  class QueueError < StandardError
  end

  class QueueRemoveError < QueueError
  end

  class QueueUnexisting < QueueError
  end

  class ItemDestructed < QueueError
  end

  # Return deferred item to queue
  def self.resume dir
    self.new(dir).resume
  end

  # Create queue master in presented dir.
  #
  # dir:: Queue directory
  # create:: If true is given, creates the queue directory when it is missing
  def initialize dir, create=false
    @queue_dir = dir

    %w:.checkout .defer .retry .archive:.each do |subdir|
      unless File.exist?(File.join(dir, subdir))
        if create
          require 'fileutils'
          FileUtils.mkdir_p(File.join(dir, subdir))
        else
          raise QueueUnexisting.new("Queue directory #{dir} does not exist.")
        end
      end
    end
  end

  # Push data to queue.
  def push data
    queue_id = sprintf("%d-%d-%s", Time.now.to_i ,$$ , SecureRandom.hex(3))
    queue_filepath = File.join(@queue_dir, (queue_id + ".marshal"))

    File.open(queue_filepath, "w") do |f|
      Marshal.dump data, f
    end

    queue_id
  end
  
  # Pop data from queue.
  # Popped queue items are placed in the checkout directory. After processing is complete, +#complete+ must be called to remove the item from the queue.
  #
  # If block is given, complete automatically after yield.
  #
  # :call-seq:
  #   pop()               -> queue_object
  #   pop() {|data| ... } -> queue_id
  def pop
    queue_data = nil
    queue_id = nil
    queue_files = Dir.children(@queue_dir)
    queue_files.each do |qf|
      next if qf[0] == "."
      begin
        File.rename(File.join(@queue_dir, qf), File.join(@queue_dir, ".checkout", qf))
      rescue Errno::ENOENT
        next
      end

      data = Marshal.load(File.read File.join(@queue_dir, ".checkout", File.basename(qf)))
      queue_id = File.basename qf, ".marshal"

      queue_data = OrbitalQueue::QueueObject.new(self, data, queue_id)
      break
    end

    if queue_data && block_given?
      yield queue_data.data
      complete queue_id
    else
      queue_data
    end
  end

  # Pop data and remove it from queue.
  #
  # :call-seq:
  #   pop!() -> queue_object
  def pop!
    queue_item = pop
    if queue_item
      queue_item.complete
    end

    queue_item
  end

  # Iterate each queue item data.
  def each
    while item = pop
      yield item.data
      item.complete
    end
  end

  # Iterate each queue item.
  def each_item
    while item = pop
      yield item
      item.complete unless item.deferred?
    end
  end

  # Remove checked out queue item.
  def complete queue_id
    begin
      checkout_file = File.join(@queue_dir, ".checkout", (queue_id + ".marshal"))
      retry_file = File.join(@queue_dir, ".retry", (queue_id + ".marshal"))
      File.delete(checkout_file)
      File.delete(retry_file) if File.exist?(retry_file)
    rescue SystemCallError => e
      raise QueueRemoveError, "Failed to complete queue #{queue_id}: #{e.class}"
    end

    queue_id
  end

  # Delete all related files with queue_id, and raise ItemDectructed exception.
  def destruct queue_id
    queue_files = Dir.glob([@queue_dir, "**", (queue_id + ".marshal")].join("/"), File::FNM_DOTMATCH)
    File.delete(*queue_files) unless queue_files.empty?
    raise ItemDestructed, "#{queue_id} is destructed."
  end

  # Archive current queue relative data and call +destruct+.
  # This method should be called from QueueObject.
  def archive queue_id, data, archiveinfo_additional={} # :nodoc:
    archiveinfo = archiveinfo_additional.merge({
      archived_at: Time.now.to_i
    })

    retry_data = load_retryobj queue_id

    archive_data = {
      archiveinfo: archiveinfo,
      retry_data: retry_data,
      data: data
    }

    File.open(File.join(@queue_dir, ".archive", (["archive", archiveinfo[:archived_at], queue_id].join("-") + ".marshal")), "w") {|f| Marshal.dump archive_data, f}

    destruct queue_id
  end

  # Mark queue item as deferred.
  # 
  # :call-seq:
  #   defer(queue_id, time_at, max_count=nil) -> retry_data | nil
  #   defer() {|retry_data| ... }             -> retry_data | nil
  def defer queue_id, time_at=nil, max_count=nil
    retry_data = load_retryobj queue_id
    retry_data[:count] += 1
    if block_given?
      yield retry_data
      retry_data[:until] = retry_data[:until].to_i
    else
      unless time_at
        raise ArgumentError, "time_at is required when no block is given."
      end

      if max_count && retry_data[:count] > max_count
        destruct queue_id
      end
      retry_data[:until] = time_at.to_i
    end

    dump_retryobj queue_id, retry_data

    checkout_path = File.join(@queue_dir, ".checkout", (queue_id) + ".marshal")
    defer_path = File.join(@queue_dir, ".defer", (queue_id) + ".marshal")
    File.rename checkout_path, defer_path

    retry_data
  rescue ItemDestructed
    nil
  end

  # Return deferred item to queue.
  def resume
    now = Time.now.to_i
    deferred_files = Dir.children(File.join(@queue_dir, ".retry"))
    deferred_files.each do |fn|
      retry_path = File.join(@queue_dir, ".retry", fn)
      retry_data = Marshal.load File.read retry_path

      if retry_data[:until] < now
        queue_path = File.join(@queue_dir, fn)
        defer_path = File.join(@queue_dir, ".defer", fn)
        File.rename(defer_path, queue_path)
      end
    end

    nil
  end

  private

  # Save to .retry
  def dump_retryobj queue_id, data
    retry_path = File.join(@queue_dir, ".retry", (queue_id) + ".marshal")
    File.open(retry_path, "w") {|f| Marshal.dump data, f }
    nil
  end

  # Load from .retry
  def load_retryobj queue_id
    retry_path = File.join(@queue_dir, ".retry", (queue_id) + ".marshal")
    retry_data = nil
    if File.exist? retry_path
      retry_data = Marshal.load File.read retry_path
    else
      retry_data = {
        count: 0,
        until: nil
      }
    end

    retry_data
  end
end

# Queue item capsule.
class OrbitalQueue::QueueObject
  def initialize(queue, data, queue_id)
    @queue = queue
    @data = data
    @queue_id = queue_id
    @completed = false
    @deferred = false
  end

  attr_reader :data

  # Another complete interface.
  def complete
    if @completed
      nil
    else
      @queue.complete(@queue_id)
      @completed = true
      @queue_id
    end
  end

  # Wrap for the end of queue item.
  def destruct
    @completed = true
    @queue.destruct(@queue_id)
  end

  # Archive current queue relative data and call +destruct+.
  def archive archiveinfo_additional={}
    @completed = true
    @queue.archive @queue_id, @data, archiveinfo_additional
  end

  # Terrible redundunt method.
  def complete? # :nodoc:
    @completed
  end

  # Retry later.
  #
  # time_at:: Deferring retry until this time
  # max_count:: Retry count limit
  #
  # :call-seq:
  #   defer(time_at, max_count=nil) -> retry_data
  #   defer() {|retry_data| ... }   -> retry_data
  def defer time_at=nil, max_count=nil, &block
    if block
      @queue.defer(@queue_id, &block)
    else
      @queue.defer(@queue_id, time_at, max_count)
    end
    @deferred = true
  end

  def deferred?
    @deferred
  end
end
