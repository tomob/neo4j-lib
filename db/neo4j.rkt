#lang racket/base
(require racket/contract/base
         db/base
         "private/neo4j.rkt")

(provide/contract
 [neo4j-connect
  (->* []
       [#:server string?
        #:port exact-positive-integer?
        #:database string?
        #:user (or/c string? #f)
        #:password (or/c string? #f)
        #:debug? boolean?]
       connection?)])
