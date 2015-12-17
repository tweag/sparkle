# Spark: Internal Architecture

## Components

   User program (SparkContext)
   	   /  \
  ______________
 |  Spark client | (RDD graph, Scheduler,
 |  (app master) | Block tracker, Shuffle
 |_______________| tracker)
      ^     |
      |     |  cluster manager
  ____|_____v______
 |  Spark worker   | (Task threads, Block
 | (many of those) | manager)
 |_________________|
    ^  |
  __|__v____
 |  HDFS,   |
 |  HBase,  |
 |  ...     |
 |__________|

- Nothing is actually computed until
  an "Action" is run: count(), collect(), save(), ...

* RDD Graph

- Data is separated into "partitions"
- Each partition is taken care of by
  a "task". There is one or more task(s)
  that gets run on each worker.

* Data locality

- On first run, data is put in cache
- If anything falls out of cache,
  go back to HDFS (or w/e you're using)

## Life of a job

### Scheduling process

- RDD Objects
    build a DAG of operators
    (map, join, groupBy, filter, ...)

- DAG Scheduler
    split graph into stages of tasks

    -> at the partition level!

    a stage is a group of partition-level
    operations that get batched together
    and will be run concurrently, i.e
    a set of tasks.

    submit each stage as soon as it's
    ready (i.e all the computations
    completed)

    agnostic to the operators used,
    just cares about "the shape".

- Task Scheduler
    launch tasks via the cluster
    manager, without looking
    inside the tasks.

    retry failed/excessively slow
    tasks, goes back
    to the DAG Scheduler when
    that happens.

    doesn't know about "stages",
    just cares about "tasks".

- Worker
    execute tasks in threads

    store and serve blocks, through
    the Block Manager.

### RDDs

#### RDD Abstraction

- Big collection of data
  * Distributed
  * Immutable
  * Lazily evaluated
  * Cacheable
  * Typed

- Want to support wide array of
  operators.

- Don't want to modify the scheduler
  whenever we add a new operator.

- RDDs can be stored in memory between
  queries without requiring replication.
  They rebuild lost data on failure by
  remembering how they were built from
  other RDDs.

- If a partition of an RDD is lost,
  the RDD has enough information
  about how it was derived from other
  RDDs to recompute just that partition.

#### RDD Interface

- Set of partitions (splits)
- List of dependencies on parent RDDs
- Function to compute a partition given
  its parents
- (Optional) Preferred locations
- (Optional) Partitioning info

-> Captures all current Spark
   operations!

Example: Hadoop RDD
  - partitions = one per HDFS block
  - dependencies = none
  - compute(partition)
      = read corresponding block
  - preferredLocations(partition)
      = HDFS block location
  - no partitioner (partitioning info)

Example: Filtered RDD
  - partitions = same as parent RDD
  - dependencies = one to one on parent
    (each partition in this RDD depends
    on the corresponding one in the
    parent -- i.e the RDD we're
    filtering elements out of)
  - compute(partition)
      = compute parent and filter it
  - preferredLocations(partition)
      = none -- use the parent's
  - partitioner = none

Example: Joined RDD (union)
  - partitions = one per reduce task
  - dependencies = shuffle on each
    parent (i.e randomly group
    data from both datasets
    together)
  - compute(partition)
      = read an join shuffled data
  - preferredLocations(partition)
      = none
  - partitioner
      = HashPartitioner(numTasks)
    -> Spark will know this data
       is hashed (and shuffled).

RDD partitions are shipped around
along with tasks
(as part of the closure)

#### Dependencies

2 types of dependencies:

- Narrow deps:
  each partition in a parent goes
  to one partition in a child

  (map, filter, union, join with
  inputs co-partitioned)

- Wide (shuffle) deps:
  Each output partition depends on
  all input partitions

  (groupByKey, join with inputs not
  co-partitioned)

co-partitioned: "partitioned the 
                 same way"

#### DAG Scheduler

Interface: receives a "target" RDD, a
           function to run on each
           partition, and a listener
           for results that's
           triggered whenever a
           computation completes.

Role:
  - Build stages of Task objects
    (code + preferred location)
  - Submit them to the Task Scheduler
    as soon as they're ready
  - Resubmit failed stages if outputs
    are lost

#### Scheduler optimizations

- Pipelines "narrow" operations
  within a stage

- Picks join algorithms based on
  partitioning
  (minimizing shuffles)

- Reuses previously cached data

#### Task details

- Stage boundaries are only at input
  RDDs or on "shuffle" operations

- Each task looks like:

 Ext storage _
              \
   and/or      ->|       Task  (f1 . f2)      -> map to output file
               ->|                               or send back to master
 fetch map  __/
 outputs

- Shuffle outputs are written to RAM/disk
  to allow retries

- Any task can run on any node, at the cost
  of sometimes ending up recomputing things

#### Worker

- Implemented by the Executor class

- Receives self-contained Task objects
  and calls run() on them
  (powered by a thread pool, one per core
  by default)

- Reports results or exceptions to master


- Users can provide a custom executor
  (to run on smth else than mesos, etc)

#### Block Manager

- "Write once" key-value store, one on
  each worker

- Serves shuffle data as well as cached RDDs

- Tracks the storage level for each block
  (RAM, disk, ...)

- Can drop data to disk if running low
  on RAM

- Can replicate data accross nodes

#### Communication Manager

- Async I/O based networking library

- Allows fetching blocks from Block Managers

- Allows prioritization / chunking accross
  connections

- Fetch logic tries to optimize for block
  sizes

#### Map output tracker

- Tracks where each "map" task
  in a shuffle ran

- Tells reduce tasks the map locations

- Each worker caches the locations to avoid
  refetching

- A "generation ID" gets passed with each Task.
  Allows invalidating the cache when map
  outputs are lost.

## Extension points

- Extend RDDs:
  add new input sources or transformations

- Scheduler backend:
  add new cluster managers

- Spark serializer:
  customize object storage

# Performance-oriented view

3 major components of interest:

- Execution model
- Shuffle: how data gets moved around
           accross the network, communication.
- Caching

## Execution model

1) Create DAG of RDDs to represent
   computation

2) Create logical execution plan for DAG

3) Schedule and execute individual tasks

### DAG of RDDs

- Chains of different operations:
  * RDD from input source
    (hdfs, local file, DB, ...)
  * map/filter/groupBy/...
  * reduce/collect/...

### Execution plan

- Pipeline (fuse) as much as possible

- Batch operations into stages
  based on need to reorganize data

- E.g: groupBy introduces such a need,
  as data partitions can get arbitrarly
  mixed depending on grouping criterion
  -> shuffling

- map doesn't, since each partition's image
  can be computed independently

- Stages are usually separated by operations
  that introduce a shuffle.

### Schedule tasks

- Split each stage into a set of tasks

- A task is data + computation

- Execute all tasks within a stage
  before moving on

Example: if we have, say,
  hdfs://names/0.gz
  hdfs://names/1.gz
  hdfs://names/2.gz
  hdfs://names/3.gz

  i.e data split in 4 blocks,

  a map over this RDD gets split into 4 tasks,
  one per block.

  task 0 <-> 0.gz
  task 1 <-> 1.gz
  task 2 <-> 2.gz
  task 3 <-> 3.gz

### The shuffle

- Redistribute data among partitions

- Hash keys ("grouping criterion") into
  buckets

- Optimizations:
  * avoided when possible,
    if data is already properly partitioned.

  * partial aggregation reduces data movement

- Pull-based, not push-based. A lazy eval
  of sorts.

- Write intermediate files to disks.

#### Execution of a groupBy

- Build hash map within each partition

  Ex: A => [Andrew, Andy, ...]
      E => [Earl, Ed, ...]

     ^^^ this isn't good, we want
         more partitions!

- Can spill across keys, but a single
  key-value pair must fit in memory

### Things to pay attention to

- Ensure enough partitions for concurrency

- Minimize memory consumption, especially
  with sort and groupBy

- Minimize amount of data shuffled

# References

- Introduction to AmpLab Spark Internals
  <https://www.youtube.com/watch?v=49Hr5xZyTEA>

- A Deeper Understanding of Spark Internals
  <https://www.youtube.com/watch?v=dmL0N3qfSc8>

- Resilient Distributed Datasets:
    A Fault-Tolerant Abstraction for
    In-Memory Cluster Computing
  <http://people.csail.mit.edu/matei/papers/2012/nsdi_spark.pdf>










