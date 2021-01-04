#lang racket
(require db
         db/private/neo4j
         rackunit
         net/url)
(require/expose db/private/neo4j (discovery-url
                                  decode-result
                                  get-params))

(test-case "discovery-url"
  (test-true "should return url" (url? (discovery-url "test" 1234)))
  (test-equal? "should point to root of the server"
               (url->string (discovery-url "server.fake" 1234)) "http://server.fake:1234"))

(test-case "decode-result"
  (test-equal? "should return simple-result if data field is empty"
    (simple-result "test")
    (decode-result 'who (hash `errors '() `results (list (hash 'columns '() 'data '() 'stats "test")))))
  (test-equal? "should return rows-result if there are data"
    (rows-result '("column1" "column2") `(#(1 2) #(3 4)))
    (decode-result 'who (hash 'errors '()
                              'results (list (hash 'columns '("column1" "column2")
                                                   'data (list (hash 'row '(1 2)) (hash 'row '(3 4)))
                                                   'stats "whatever")))))
  (test-exn "should raise sql exception if result contains errors"
    exn:fail:sql?
    (λ () (decode-result 'who (hash 'errors (list (hash 'code "something" 'message "exception message"))
                                    'results '())))))

(test-case "get-params"
  (test-equal? "should return empty list if no params are used"
    '()
    (get-params "MATCH (n:Something) RETURN n"))
  (test-equal? "should return list of single param if single param is used"
    '(name)
    (get-params "MATCH (n {name:$name}) RETURN n"))
  (test-equal? "should return all params in MATCH"
    '(name test reg prefix list_of_ids)
    (get-params "MATCH (n:Something {name: $name}) WHEN n.whatever=$test AND n.x =~ $reg AND n.x STARTS WITH $prefix AND id(n) in $list_of_ids RETURN n"))
  (test-equal? "should return params in CREATE"
    '(props)
    (get-params "CREATE ($props)"))
  (test-equal? "should return params in UNWIND"
    '(props)
    (get-params "UNWIND $props AS properties CREATE (n:Node) set n = properties RETURN n"))
  (test-equal? "should return params in SET"
    '(y props)
    (get-params "MATCH (n:Node) WHERE n.x=$y SET n=$props"))
  (test-equal? "should return params in SKIP and LIMIT"
    '(n m)
    (get-params "MATCH (n:Node) RETURN n SKIP $n LIMIT $m"))
  (test-equal? "should return params of functio call"
    '(params)
    (get-params "CALL function($params)"))
  )

