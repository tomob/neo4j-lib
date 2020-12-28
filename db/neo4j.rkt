#lang racket/base
(require racket/contract/base
         db/base
         "private/neo4j.rkt")

(provide/contract
 [neo4j-connect
  (->* []
       [#:server (or/c string? #f)
        #:port (or/c exact-positive-integer? #f)
        #:user (or/c string? #f)
        #:password (or/c string? #f)
        #:debug? any/c]
       connection?)])
