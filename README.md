neo4j-lib
=========

The db/neo4j module provides support for querying Neo4j database with
Racket db module's functions.

Installation
------------

Install the package with `raco`:

```shell
> raco pkg install neo4j-lib
```

Quick start
===========

(Copied from the documentation)

The following examples demonstrate how to connect to Neo4j and 
perform simple queries. The examples assume minimal familiarity with `db` module and Neo4j.

```racket
(require db db/neo4j)
```

First, we create a connection. Used without parameters, `neo4j-connection` connects to
the default database without credentials.

```racket
(define neo4j-c (neo4j-connect))
```

Use query-exec to create some nodes.

```racket
(query-exec neo4j-c "CREATE (bob:Person {name: 'Bob'})")
```

Regular query can also be used. In this case the query statistics are returned, wrapped
in `simple-result` struct.

```racket
> (query neo4j-c "CREATE (dave:Person {name: 'Dave'})")
(simple-result
     '#hasheq((constraints_added . 0)
              (constraints_removed . 0)
              (contains_system_updates . #f)
              (contains_updates . #t)
              (indexes_added . 0)
              (indexes_removed . 0)
              (labels_added . 1)
              (labels_removed . 0)
              (nodes_created . 1)
              (nodes_deleted . 0)
              (properties_set . 1)
              (relationship_deleted . 0)
              (relationships_created . 0)
              (system_updates . 0)))
```

The query string can include a number of Cypher statements.

```racket
    > (define queries (string-join (list
        "CREATE (john:Person {name: 'John'})"
        "CREATE (joe:Person {name: 'Joe'})"
        "CREATE (steve:Person {name: 'Steve'})"
        "CREATE (sara:Person {name: 'Sara'})"
        "CREATE (maria:Person {name: 'Maria'})"
        "CREATE (john)-[:FRIEND]->(joe)-[:FRIEND]->(steve)"
        "CREATE (john)-[:FRIEND]->(sara)-[:FRIEND]->(maria)")))

    > (query neo4j-c queries)
    (simple-result
    '#hasheq((constraints_added . 0)
              (constraints_removed . 0)
              (contains_system_updates . #f)
              (contains_updates . #t)
              (indexes_added . 0)
              (indexes_removed . 0)
              (labels_added . 5)
              (labels_removed . 0)
              (nodes_created . 5)
              (nodes_deleted . 0)
              (properties_set . 5)
              (relationship_deleted . 0)
              (relationships_created . 4)
              (system_updates . 0)))
```

The data can of course be queried.

```racket
    > (query neo4j-c "MATCH (john {name: 'John'})-[:FRIEND]->()-[:FRIEND]->(fof) RETURN john.name, fof.name")
    (rows-result '("john.name" "fof.name") '(#("John" "Maria") #("John" "Steve")))
```

Other functions are also supported.

Examples:
```racket
    > (query-rows neo4j-c "MATCH (john {name: 'John'})-[:FRIEND]->()-[:FRIEND]->(fof) RETURN john.name, fof.name")
    '(#("John" "Maria") #("John" "Steve"))
    
    > (query-row neo4j-c "MATCH (john {name: 'John'})-[:FRIEND]->()-[:FRIEND]->(fof) WHERE fof.name =~ 'St.*' RETURN john.name, fof.name")
    '#("John" "Steve")
    
    > (query-list neo4j-c "MATCH (john {name: 'John'})-[:FRIEND]->()-[:FRIEND]->(fof) RETURN fof.name")
    '("Maria" "Steve")
    
    > (query-value neo4j-c "MATCH (john {name: 'John'})-[:FRIEND]->()-[:FRIEND]->(fof) WHERE fof.name =~ 'St.*' RETURN fof.name")
    "Steve"
    
    > (query-maybe-value neo4j-c "MATCH (john {name: 'John'})-[:FRIEND]->()-[:FRIEND]->(fof) WHERE fof.name =~ 'B.*' RETURN fof.name")
    #f
    
    > (for ([(friend fof) (in-query neo4j-c "MATCH (john {name: 'John'})-[:FRIEND]->(friend)-[:FRIEND]->(fof) RETURN friend.name, fof.name")])
          (printf "John's friend ~a's friend is ~a\n" friend fof))
    John's friend Sara's friend is Maria
    John's friend Joe's friend is Steve
```

Parameters
----------

Queries can include parameters. You can either provide a hash with all params or
list their values in the order in which they appear in the query. Keys of the hash
must be symbols. When the same parameter occurs more then one time in the query,
you must use a hash parameter

Examples:
```racket
    > (query-rows neo4j-c 
                  "MATCH (john {name: $name})-[:FRIEND]->()-[:FRIEND]->(fof) WHERE fof.name =~ 'St.*' RETURN john.name, fof.name"
                  (hash 'name "John"))
    '(#("John" "Steve"))
    
    > (query-rows neo4j-c
                  "MATCH (john {name: $name})-[:FRIEND]->()-[:FRIEND]->(fof) WHERE fof.name =~ 'St.*' RETURN john.name, fof.name"
                  #hash((name . "John")))
    '(#("John" "Steve"))
    
    > (query-rows neo4j-c
                  "MATCH (john {name: $name})-[:FRIEND]->()-[:FRIEND]->(fof) WHERE fof.name =~ 'St.*' RETURN john.name, fof.name"
                  "John")
    '(#("John" "Steve"))
```

Transactions
------------

Transactions are supported but with two limitations: only managed transaction can
be used (i.e. those created with `start-transaction` or `call-with-transaction`)
and transaction cannot be nested.

Examples:
```racket
    > (start-transaction neo4j-c)
    > (query-exec neo4j-c "MATCH (bob:Person {name: 'Bob'}) MATCH (dave:Person {name: 'Dave'}) CREATE (dave)-[:FRIEND]->(bob)")
    > (query-value neo4j-c "MATCH (dave:Person {name: 'Dave'})-[:FRIEND]->(who) RETURN who.name")
    "Bob"
    > (rollback-transaction neo4j-c)
    > (query-rows neo4j-c "MATCH (dave:Person {name: 'Dave'})-[:FRIEND]->(who) RETURN who.name")
    '()
```

Prepared statements
-------------------

Prepared statemtents can be used, although they are handled completely at the client
side. No resources are allocated at the server.

Examples:
```racket
    > (define johns-fof
        (prepare neo4j-c "MATCH (john {name: $name})-[:FRIEND]->()-[:FRIEND]->(fof) WHERE fof.name =~ 'St.*' RETURN john.name, fof.name"))
    > (query-rows neo4j-c johns-fof "John")
    '(#("John" "Steve"))
    
    > (define bound-stmt (bind-prepared-statement johns-fof '("John")))
    > (query-rows neo4j-c bound-stmt)
    '(#("John" "Steve"))
```
