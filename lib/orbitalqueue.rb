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

  # Create queue master in presented dir.
  #
  # dir: Queue directory
  # create: If true is given, creates the queue directory when it is missing
  def initialize dir, create=false
    @queue_dir = dir

    unless File.exist?(File.join(dir, ".checkout"))
      if create
        require 'fileutils'
        FileUtils.mkdir_p(File.join(dir, ".checkout"))
      else
        raise QueueUnexisting.new("Queue directory #{dir} does not exist.")
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

      queue_data = Marshal.load(File.read File.join(@queue_dir, ".checkout", File.basename(qf)))
      queue_id = File.basename qf, ".marshal"

      if Hash === queue_data
        queue_data[:queue_id] = queue_id
      else
        queue_data = {queue_id: queue_id, data: queue_data}
      end
      break
    end

    queue_data
  end

  # Pop data from queue and remove it from queue.
  def pop!
    queue_data = pop
    if queue_data
      complete queue_data[:queue_id]
    end

    queue_data
  end

  # Remove checked out queue item.
  def complete queue_id
    begin
      File.delete(File.join(@queue_dir, ".checkout", (queue_id + ".marshal")))
    rescue SystemCallError => e
      raise QueueRemoveError, "Failed to complete queue #{queue_id}: #{e.class}"
    end

    queue_id
  end
end
