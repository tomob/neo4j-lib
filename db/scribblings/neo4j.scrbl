#lang scribble/manual
@require[@for-label[db/neo4j
                    db
                    racket/base]]
@(require scribble/example
          racket/runtime-path
          db
          db/neo4j)

@(define-runtime-path log-file "log-for-exaples.rktd")
@(define log-mode 'replay)
@(define the-eval (let ([ev (make-log-based-eval log-file log-mode)])
                    (ev '(require db/neo4j racket/string))
                    ev))

@title{Neo4j – interface to Neo4j database}
@author{Tomasz Barański}

@defmodule[db/neo4j]

The @racketmodname[db/neo4j] module provides support for querying Neo4j database with
Racket @racketmodname[db] module's functions.

@section{Quick start}

The following examples demonstrate how to connect to Neo4j and perform simple queries.
The examples assume minimal familiarity with `db` and Neo4j.

@examples[#:eval the-eval
(require db db/neo4j)]

First, we create a connection. Used without parameters, @racket[neo4j-connection]
connects to the default database without credentials.

@examples[#:eval the-eval
(define neo4j-c (neo4j-connect))]

Use @racket[query-exec] to create some nodes.

@examples[#:eval the-eval
(query-exec neo4j-c "CREATE (bob:Person {name: 'Bob'})")
]

Regular @racket[query] can also be used. In this case the query statistics are returned,
wrapped in @racket[simple-result] struct.

@examples[#:eval the-eval
(query neo4j-c "CREATE (dave:Person {name: 'Dave'})")
]

The query string can include a number of Cypher statements.

@examples[#:eval the-eval
(define queries (string-join (list
  "CREATE (john:Person {name: 'John'})"
  "CREATE (joe:Person {name: 'Joe'})"
  "CREATE (steve:Person {name: 'Steve'})"
  "CREATE (sara:Person {name: 'Sara'})"
  "CREATE (maria:Person {name: 'Maria'})"
  "CREATE (john)-[:FRIEND]->(joe)-[:FRIEND]->(steve)"
  "CREATE (john)-[:FRIEND]->(sara)-[:FRIEND]->(maria)")))
(query neo4j-c queries)
]

The data can of course be queried.

@examples[#:eval the-eval
(query neo4j-c "MATCH (john {name: 'John'})-[:FRIEND]->()-[:FRIEND]->(fof) RETURN john.name, fof.name")]

Other functions are also supported.

@examples[#:eval the-eval
(query-rows neo4j-c "MATCH (john {name: 'John'})-[:FRIEND]->()-[:FRIEND]->(fof) RETURN john.name, fof.name")
(query-row neo4j-c "MATCH (john {name: 'John'})-[:FRIEND]->()-[:FRIEND]->(fof) WHERE fof.name =~ 'St.*' RETURN john.name, fof.name")
(query-list neo4j-c "MATCH (john {name: 'John'})-[:FRIEND]->()-[:FRIEND]->(fof) RETURN fof.name")
(query-value neo4j-c "MATCH (john {name: 'John'})-[:FRIEND]->()-[:FRIEND]->(fof) WHERE fof.name =~ 'St.*' RETURN fof.name")
(query-maybe-value neo4j-c "MATCH (john {name: 'John'})-[:FRIEND]->()-[:FRIEND]->(fof) WHERE fof.name =~ 'B.*' RETURN fof.name")
(for ([(friend fof) (in-query neo4j-c "MATCH (john {name: 'John'})-[:FRIEND]->(friend)-[:FRIEND]->(fof) RETURN friend.name, fof.name")])
    (printf "John's friend ~a's friend is ~a\n" friend fof))
]

Queries can include parameters. You can either provide a @racket[hash] with all params
or list their values in the order in which they appear in the query. Keys of the hash
must be symbols. When the same parameter occurs more then one time in the query, you must
use a hash parameter

@examples[#:eval the-eval
(query-rows neo4j-c "MATCH (john {name: $name})-[:FRIEND]->()-[:FRIEND]->(fof) WHERE fof.name =~ 'St.*' RETURN john.name, fof.name" (hash 'name "John"))
(query-rows neo4j-c "MATCH (john {name: $name})-[:FRIEND]->()-[:FRIEND]->(fof) WHERE fof.name =~ 'St.*' RETURN john.name, fof.name" #hash((name ."John")))
(query-rows neo4j-c "MATCH (john {name: $name})-[:FRIEND]->()-[:FRIEND]->(fof) WHERE fof.name =~ 'St.*' RETURN john.name, fof.name" "John")
]

@examples[#:eval the-eval #:hidden
;; Cleanup
(query-exec neo4j-c "MATCH p=(n)-[r:FRIEND]->(f) delete n,r,f")
(query-exec neo4j-c "MATCH (n:Person) delete n")
]

@section{Connecting to Neo4j}

@defproc[(neo4j-connect [#:server server string? "localhost"]
                        [#:port port exact-positive-integer? 7474]
                        [#:database database string? "neo4j"]
                        [#:user user (or/c string? #f) #f]
                        [#:password password (or/c string? #f) #f]
                        [#:debug? debug? boolean? #f])
          connection?]{
Opens the connection to Neo4j. The returned connection
can be used with @racketmodname[db]'s query functions.
}

