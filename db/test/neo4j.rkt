#lang racket
(require db/private/neo4j
         rackunit
         net/url)
(require/expose db/private/neo4j (discovery-url))

(test-case "discovery-url"
  (test-true "should return url" (url? (discovery-url "test" 1234)))
  (test-equal? "should point to root of the server"
               (url->string (discovery-url "server.fake" 1234)) "http://server.fake:1234"))

(test-case "")
