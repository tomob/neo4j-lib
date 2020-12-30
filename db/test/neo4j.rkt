#lang racket
(require db
         db/private/neo4j
         rackunit
         net/url)
(require/expose db/private/neo4j (discovery-url decode-result))

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
