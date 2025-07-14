# orbital-queue

## Synopsis

File-based queue library for orbital design pattern.

## Usage

### Initialize queue

```ruby
require 'orbitalqueue'

queue = OrbitalQueue.new("/path/to/queue")
```

`.new` raises an `OrbitalQueue::QueueUnexisting` exception if the specified directory does not exist. If `true` is passed as the second argument, the directory is created recursively when missing.

### Enqueue

```ruby
require 'orbitalqueue'

queue = OrbitalQueue.new("/path/to/queue")
data = {foo: 123}

queue.push(data)
```

Calling `#push` enqueues the given object into the queue. The object's class can be arbitrary.

Since enqueued objects are serialized using `Marshal` and persisted as files, caution is required when using custom classes.

### Dequeue

```ruby
require 'orbitalqueue'

queue = OrbitalQueue.new("/path/to/queue")
data = queue.pop

# Something, something...

queue.complete data[:queue_id]
```

Calling `#pop` retrieves a single item from the queue in no particular order.

The retrieved item enters a checkout state, and must be finalized by calling `#complete` once processing is finished.

If guaranteed completion is not required and the item should be removed immediately upon retrieval, use `#pop!` instead.

Both `#pop` and `#pop!` return a queue item as a `Hash`. If the original object was not a `Hash`, it will be stored under the `:data` key. Regardless of the original type, the queue ID is always stored under the `:queue_id` key.

