#lang info
(define collection 'multi)
(define deps '("base" "db-lib"))
(define build-deps '("scribble-lib" "racket-doc" "rackunit-lib"))
(define scribblings '(("scribblings/neo4j-lib.scrbl" ())))
(define pkg-desc "Interface to Neo4j database")
(define version "0.1")
(define pkg-authors '("Tomasz Barański"))
