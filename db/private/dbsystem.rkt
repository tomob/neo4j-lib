#lang racket
(require db/private/generic/interfaces
         db/private/generic/common)

(provide dbsystem)

(define neo4j-dbsystem%
  (class* dbsystem-base% (dbsystem<%>)
    (super-new)
    (define/public (get-short-name) 'neo4j)

    ;; (listof typeid) -> (listof ParameterHandler)
    (define/public (get-parameter-handlers param-typeids)
      (map (lambda (param-typeid) check-param)
           param-typeids))

    ;; (listof field-dvec) -> (listof typeid)
    (define/public (field-dvecs->typeids dvecs)
      (map (lambda (dvec) (vector-ref dvec 0))
           dvecs))

    ;; (listof typeid) -> (listof TypeDesc)
    (define/public (describe-params typeids)
      (map (lambda _ '(#t any #f)) typeids))

    (define/public (describe-fields dvecs)
      (map (lambda _ '(#t any #f)) dvecs))
  ))

(define (check-param fsym param)
  (unless (or (real? param)
              (string? param)
              (hash? param))
    (error/no-convert fsym "Neo4j" "parameter" param))
  param)

(define dbsystem (new neo4j-dbsystem%))
