#lang info
(define collection 'multi)
(define deps '("base" "db-lib" "rackunit-lib"))
(define build-deps '("scribble-lib" "racket-doc" "rackunit-lib" "db-doc"))

(define pkg-desc "Library for accessing Neo4j database")
(define version "0.2")
(define pkg-authors '("Tomasz Barański"))
