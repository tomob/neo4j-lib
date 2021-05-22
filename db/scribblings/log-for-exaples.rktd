;; This file was created by make-log-based-eval
((require db/neo4j racket/string)
 ((3) 0 () 0 () () (c values c (void)))
 #""
 #"")
((require db db/neo4j) ((3) 0 () 0 () () (c values c (void))) #"" #"")
((define neo4j-c (neo4j-connect))
 ((3) 0 () 0 () () (c values c (void)))
 #""
 #"")
((query-exec neo4j-c "CREATE (bob:Person {name: 'Bob'})")
 ((3) 0 () 0 () () (c values c (void)))
 #""
 #"")
((query neo4j-c "CREATE (dave:Person {name: 'Dave'})")
 ((3)
  1
  (((lib "db/private/generic/interfaces.rkt")
    .
    deserialize-info:simple-result-v0))
  0
  ()
  ()
  (c
   values
   c
   (0
    (h
     -
     ()
     (indexes_removed . 0)
     (nodes_deleted . 0)
     (relationships_created . 0)
     (indexes_added . 0)
     (contains_system_updates . #f)
     (labels_added . 1)
     (labels_removed . 0)
     (system_updates . 0)
     (constraints_added . 0)
     (contains_updates . #t)
     (nodes_created . 1)
     (properties_set . 1)
     (relationship_deleted . 0)
     (constraints_removed . 0)))))
 #""
 #"")
((define queries
   (string-join
    (list
     "CREATE (john:Person {name: 'John'})"
     "CREATE (joe:Person {name: 'Joe'})"
     "CREATE (steve:Person {name: 'Steve'})"
     "CREATE (sara:Person {name: 'Sara'})"
     "CREATE (maria:Person {name: 'Maria'})"
     "CREATE (john)-[:FRIEND]->(joe)-[:FRIEND]->(steve)"
     "CREATE (john)-[:FRIEND]->(sara)-[:FRIEND]->(maria)")))
 ((3) 0 () 0 () () (c values c (void)))
 #""
 #"")
((query neo4j-c queries)
 ((3)
  1
  (((lib "db/private/generic/interfaces.rkt")
    .
    deserialize-info:simple-result-v0))
  0
  ()
  ()
  (c
   values
   c
   (0
    (h
     -
     ()
     (indexes_removed . 0)
     (nodes_deleted . 0)
     (relationships_created . 4)
     (indexes_added . 0)
     (contains_system_updates . #f)
     (labels_added . 5)
     (labels_removed . 0)
     (system_updates . 0)
     (constraints_added . 0)
     (contains_updates . #t)
     (nodes_created . 5)
     (properties_set . 5)
     (relationship_deleted . 0)
     (constraints_removed . 0)))))
 #""
 #"")
((query
  neo4j-c
  "MATCH (john {name: 'John'})-[:FRIEND]->()-[:FRIEND]->(fof) RETURN john.name, fof.name")
 ((3)
  1
  (((lib "db/private/generic/interfaces.rkt")
    .
    deserialize-info:rows-result-v0))
  0
  ()
  ()
  (c
   values
   c
   (0
    (c (u . "john.name") c (u . "fof.name"))
    (c (v! (u . "John") (u . "Steve")) c (v! (u . "John") (u . "Maria"))))))
 #""
 #"")
((query-rows
  neo4j-c
  "MATCH (john {name: 'John'})-[:FRIEND]->()-[:FRIEND]->(fof) RETURN john.name, fof.name")
 ((3)
  0
  ()
  0
  ()
  ()
  (c
   values
   c
   (c (v! (u . "John") (u . "Steve")) c (v! (u . "John") (u . "Maria")))))
 #""
 #"")
((query-row
  neo4j-c
  "MATCH (john {name: 'John'})-[:FRIEND]->()-[:FRIEND]->(fof) WHERE fof.name =~ 'St.*' RETURN john.name, fof.name")
 ((3) 0 () 0 () () (c values c (v! (u . "John") (u . "Steve"))))
 #""
 #"")
((query-list
  neo4j-c
  "MATCH (john {name: 'John'})-[:FRIEND]->()-[:FRIEND]->(fof) RETURN fof.name")
 ((3) 0 () 0 () () (c values c (c (u . "Steve") c (u . "Maria"))))
 #""
 #"")
((query-value
  neo4j-c
  "MATCH (john {name: 'John'})-[:FRIEND]->()-[:FRIEND]->(fof) WHERE fof.name =~ 'St.*' RETURN fof.name")
 ((3) 0 () 0 () () (c values c (u . "Steve")))
 #""
 #"")
((query-maybe-value
  neo4j-c
  "MATCH (john {name: 'John'})-[:FRIEND]->()-[:FRIEND]->(fof) WHERE fof.name =~ 'B.*' RETURN fof.name")
 ((3) 0 () 0 () () (q values #f))
 #""
 #"")
((for
  (((friend fof)
    (in-query
     neo4j-c
     "MATCH (john {name: 'John'})-[:FRIEND]->(friend)-[:FRIEND]->(fof) RETURN friend.name, fof.name")))
  (printf "John's friend ~a's friend is ~a\n" friend fof))
 ((3) 0 () 0 () () (c values c (void)))
 #"John's friend Joe's friend is Steve\nJohn's friend Sara's friend is Maria\n"
 #"")
((query-rows
  neo4j-c
  "MATCH (john {name: $name})-[:FRIEND]->()-[:FRIEND]->(fof) WHERE fof.name =~ 'St.*' RETURN john.name, fof.name"
  (hash 'name "John"))
 ((3) 0 () 0 () () (c values c (c (v! (u . "John") (u . "Steve")))))
 #""
 #"")
((query-rows
  neo4j-c
  "MATCH (john {name: $name})-[:FRIEND]->()-[:FRIEND]->(fof) WHERE fof.name =~ 'St.*' RETURN john.name, fof.name"
  #hash((name . "John")))
 ((3) 0 () 0 () () (c values c (c (v! (u . "John") (u . "Steve")))))
 #""
 #"")
((query-rows
  neo4j-c
  "MATCH (john {name: $name})-[:FRIEND]->()-[:FRIEND]->(fof) WHERE fof.name =~ 'St.*' RETURN john.name, fof.name"
  "John")
 ((3) 0 () 0 () () (c values c (c (v! (u . "John") (u . "Steve")))))
 #""
 #"")
((start-transaction neo4j-c) ((3) 0 () 0 () () (c values c (void))) #"" #"")
((query-exec
  neo4j-c
  "MATCH (bob:Person {name: 'Bob'}) MATCH (dave:Person {name: 'Dave'}) CREATE (dave)-[:FRIEND]->(bob)")
 ((3) 0 () 0 () () (c values c (void)))
 #""
 #"")
((query-value
  neo4j-c
  "MATCH (dave:Person {name: 'Dave'})-[:FRIEND]->(who) RETURN who.name")
 ((3) 0 () 0 () () (c values c (u . "Bob")))
 #""
 #"")
((rollback-transaction neo4j-c) ((3) 0 () 0 () () (c values c (void))) #"" #"")
((query-rows
  neo4j-c
  "MATCH (dave:Person {name: 'Dave'})-[:FRIEND]->(who) RETURN who.name")
 ((3) 0 () 0 () () (q values ()))
 #""
 #"")
((query-exec neo4j-c "MATCH p=(n)-[r:FRIEND]->(f) delete n,r,f")
 ((3) 0 () 0 () () (c values c (void)))
 #""
 #"")
((query-exec neo4j-c "MATCH (n:Person) delete n")
 ((3) 0 () 0 () () (c values c (void)))
 #""
 #"")
