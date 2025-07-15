# Orbital Queue

[![CI](https://github.com/reasonset/orbital-queue/actions/workflows/ci.yml/badge.svg)](https://github.com/reasonset/orbital-queue/actions/workflows/ci.yml)

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
item = queue.pop
data = item.data

# Something, something...

item.complete
```

Calling `#pop` retrieves a single item from the queue in no particular order.

```ruby
queue = OrbitalQueue.new("/path/to/queue")
item = queue.pop!

# Something, something...
```

The retrieved item enters a checkout state, and must be finalized by calling `#complete` once processing is finished.

If guaranteed completion is not required and the item should be removed immediately upon retrieval, use `#pop!` instead.

Both `#pop` and `#pop!` methods returns `OrbitalQueue::QueueObject` object.
You can access queue data via `OrbitalQueue::QueueObject#data`.

When calling `#complete`, `#destruct`, or `#defer` directly on `OrbitalQueue`, `queue_id` must be given.  
If you use these methods via `OrbitalQueue::QueueObject`, the `queue_id` is internally handled and can be omitted.

### Dequeue with block

You can call `#pop` with a block.

When call with block, block is called with queue data as an argument.

queue item automatically complete when blocke ends without error.

The `#pop` method can be called with an optional block.  
When used this way, the block is invoked with the item's data.  
After successful execution (without exceptions), the item is considered complete and removed from the queue.

```ruby
queue = OrbitalQueue.new("/path/to/queue")
queue.pop do |data|
  #...
end
```

### Dequeue loop

While technically possible to loop over `#pop`, it doesn't support block-based iteration.

Use `#each` when you want to process items with a block in a loop.  
It provides a clean and idiomatic Ruby style for sequential processing.

For full control over each item, use `#each_item`, which yields a `QueueObject` instead of just the data.

`#each_item` iterates over queue items as `QueueObject` instances, not raw data.  
This allows direct control over each job—for example, deferring its execution using `#defer`.

Unlike `#each`, which automatically marks items as complete after the block runs,  
`#each_item` exposes queue control for cases where completion isn't guaranteed or deferred handling is needed.

### Job deferral

`OrbitalQueue` supports job deferral, enabling queue items to be scheduled for retry or postponed execution with precise control.

Calling `#defer` transitions a queue item into the deferred state.  
This moves the item's file into the `.defer` directory and creates a retry metadata file in `.retry`.

Once an item has been deferred, it is associated with retry information, referred to as `retry_data`.  
This is a `Hash` object that tracks rescheduling behavior.

`#defer` uses `retry_data` to determine whether the item can be retried, including retry count limits.  
When called with a block, `#defer` yields `retry_data` as an argument, allowing custom modifications.

Regardless of how it's called, `retry_data` is persisted after the method returns.  
To control deferral behavior, modify values inside `retry_data`—typically by changing the `:until` field (Unix timestamp).  
This field specifies when the item should become eligible for re-queueing, making it ideal for implementing backoff strategies.

```ruby
queue.each_item do |item|
  begin
    # Something...
  rescue
    item.defer(Time.now + 300)     # Retry after 5 minutes.
  end
end
```

with block:

```ruby
queue.each_item do |item|
  begin
    # Something...
  rescue
    item.defer do |retry_item|
      if retry_item[:count] > 5
        item.destruct
      else
        retry_item[:until] = Time.now + 300 * retry_item[:count]
      end
    end
  end
end
```

The `#defer` method's main role is to move the queue item file into the `.defer` directory.  
Since `OrbitalQueue` operates without a server, it cannot scan `.defer` efficiently or restore deferred items automatically.

Aside from the internal keys `:count` and `:until`, all other values in `retry_data` are preserved as-is.  
You can freely store custom metadata inside it—such as failure reasons or backoff parameters.

The `#destruct` method removes all files associated with a queue item and raises `OrbitalQueue::ItemDestructed`.  
This exception is caught inside `#defer`, allowing `#destruct` to abort the entire deferral process.

⚠️ Do not rescue `OrbitalQueue::ItemDestructed` within a `#defer` block.  
If the block completes normally after destruction, queue integrity may be violated.

The `#archive` method creates a Marshal-serialized file under `.archive`, containing the original data, its `retry_data`, and an `archiveinfo` hash.  
After archiving, it calls `#destruct` to remove the live queue item.

Archived files are never accessed by OrbitalQueue itself.

Note: Because `archive` discards in-memory `retry_data`, you cannot modify it before archiving.  
Instead, extra metadata should be passed as arguments to `archive` and will be merged into `archiveinfo`.

```ruby
queue.each_item do |item|
  begin
    #...
  rescue
    item.defer do |retry_data|
      if retry_data[:count] > 5
        item.archive({reason: "Host timeout"})
      end
    end
  end
end
```

### Resume deferred job

Deferred queue items must be manually restored using the `resume` method.  
This method is typically executed by a separate worker from the one handling regular queue operations.

It is defined as an instance method:

```ruby
queue = OrbitalQueue.new("/path/to/queue")
queue.resume
```

For convenience, resume can also be called as a class method:

```ruby
OrbitalQueue.resume("/path/to/queue")
```

# About Orbital Design

## Description

Orbital Design is a programming pattern optimized for distributed systems.  
It is especially well-suited to environments where:

* New data constantly arrives without pause
* Processing workloads vary in complexity and demand asymmetric distribution
* Systems start small but must scale seamlessly to clustered deployments

## Philosophy

Orbital Design distinguishes between "agents" and "workers".  
In most cases, an agent refers to a program, while a worker is a process.

The core principle is that **workers only need to care about what they do**.  
Upon starting, a worker picks a single available job prepared for it and executes it—no coordination or negotiation required.

This behavior mirrors that of individuals in a larger society, or cells within a living organism.  
Each unit performs its specific role independently.

This philosophy is deeply aligned with the Unix principle:  
_"Do one thing, and do it well."_

## Core Rules of Orbital Design

Orbital Design defines a set of principles to preserve decoupling, clarity, and safety in distributed systems:

- *Agents must remain small and focused*.  
  Each agent is responsible for doing one thing, and doing it well.

- *Workers must not access data unrelated to their task*, nor inspect other workers' state or progress.

- *Write access to a database or dataset must be held by exactly one agent*.  
  This prevents conflicting updates and maintains integrity.

- *Deletion from a database may only be performed by:*
  - A worker with exclusive read access to the data, or
  - A sweeper worker that receives notifications from all readers

- *Agents must not block on I/O*.  
  Blocking input/output disrupts concurrency and undermines distributed fairness.

## Benefits of Orbital Design

### Ease of Implementation

Each program is small and focused, with clearly defined responsibilities.  
Because agents cannot access global state and avoid blocking operations, race conditions are structurally prevented.

This allows each unit to concentrate solely on its task—no need to worry about concurrency or system state.

## Simplicity

Orbital Design requires minimal complexity.  
It does not depend on heavy frameworks or advanced techniques.

It can be fully implemented using standard OS features such as file systems, processes, and signals.  
No special measures are needed to achieve scalability.

## Language Agnosticism

Programs are isolated and do not interfere with one another.  
This allows you to implement each agent in any language that suits the task.

You can choose a language based on convenience, libraries, or performance.
Critical paths can be written in C, C++, Rust, or Nim as needed, while simpler agents may use scripting languages.

Even agents with similar functionality can be written in different languages depending on input format or operational context.

## Parallelism and Decomposition

Restricted I/O paths eliminate contention during parallel execution.  
By following the design pattern, concurrency becomes straightforward.

No locking or synchronization is required—so parallel processing not only becomes easier to write, but also more performance-effective.

Additionally, replacing I/O layers with network interfaces naturally extends the system into distributed computing.

## Signal Friendliness

Although OS-level signals are simple and often underutilized for concurrency,  
Orbital Design enables practical use of signals for multi-worker environments.

This can provide a minor advantage when building cooperative worker pools.

## Compatibility with Systemd

Systemd's `@.service` unit files support multi-instance execution.

Agents designed with Orbital Design require no more than a worker name as an argument, making them trivially scalable to multiple instances.  
This provides a low-effort pathway to multi-worker deployments, with restarts handled by Systemd itself.

## Compatibility with Job Schedulers

Orbital Design is not limited to multi-worker or multi-instance models.  
It is especially well-suited to systems that rely on periodic execution by job schedulers.

While worker-driven systems react to runtime state, job schedulers operate on time-based triggers.  
Thanks to its stateless model, Orbital Design allows agents to run regardless of timing or system condition.

## Shell Script Friendly

Each agent has a clear and narrow scope, with no need for shared database schemas.  
This makes it easy to write parts of the system in shell scripts where appropriate.

In practice, this results in simpler and more maintainable solutions in more cases than expected.

## Replaceable Components

Programs in Orbital Design are small and well-scoped.  
When a language, library, or performance characteristic becomes a limitation, swapping out components comes at low cost.

This helps maintain long-term system health and avoids software decay.

# Finally

“The library is minimal. The idea is not.”

Orbital Design is not a framework. It's a way of thinking. It thrives where ideas are shared freely.