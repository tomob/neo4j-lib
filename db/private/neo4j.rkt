#lang racket/base
(require racket/class
         racket/string
         net/url
         json
         db/private/generic/interfaces
         db/private/generic/common)

(provide neo4j-connect)

(define connection%
  (class* transactions% (connection<%>)
    (inherit dprintf
             call-with-lock
             get-tx-status)
    (inherit-field DEBUG?)

    (define connected #f)
    (define url null)
    (define commit-url null)
    (define headers '(#"Accept: application/json"
                      #"Content-Type: application/json"))
    (define info null)

    (super-new)

    (define/public (start-connection-protocol server port database user password)
      (define discovery-url (make-url "http" #f server port #t null null #f))
      (let-values ([(status headers content) (http-sendrecv/url discovery-url #:headers headers)])
        (when (string-suffix? (bytes->string/utf-8 status) "200 OK")
          (set! connected #t)
          (set! info (read-json content))
          (when DEBUG? (dprintf "Connected to ~a\n" info))
          (set! url (string->url (string-replace (hash-ref info 'transaction) "{databaseName}" database))))
          (set! commit-url (string->url (string-append (url->string url) "/commit")))
          ))

    (define/public (get-info)
      info)

    ;; connected? : -> boolean
    (define/override (connected?)
      connected)

    ;; disconnect    : -> void
    (define/override (disconnect)
      (set! connected #f))

    ;; get-dbsystem  : -> dbsystem<%>
    (define/public (get-dbsystem)
      null)

    ;; query         : symbol statement boolean -> QueryResult
    (define/public (query sym statement cursor?)
      (if connected
        (call-with-lock sym (lambda () (query:query statement)))
        (error sym "Not connected")))

    (define/private (query:query statement)
      (if (get-tx-status)
        (query:in-transaction statement)
        (query:single-query statement)))

    (define/private (query:in-transaction statemet)
      null)

    (define/private (query:single-query statement)
      (let*-values ([(data) (prepare-data statement)]
                    [(status headers in) (http-sendrecv/url commit-url
                                                           #:method #"POST"
                                                           #:headers headers
                                                           #:data data)]
                    [(result-json) (read-json in)])
        (decode-result result-json)))

    (define/private (prepare-data stat)
      (jsexpr->string (make-hash `((statements . (,(make-hash `((statement . ,stat)))))))))

    (define/private (decode-result result)
      (rows-result (hash-ref (car (hash-ref result 'results)) 'columns)
                   (map (lambda (v) (list->vector (hash-ref v 'row)))
                        (hash-ref (car (hash-ref result 'results)) 'data)
                             )))

    ;; prepare       : symbol preparable boolean -> prepared-statement<%>
    (define/public (prepare)
      null)

    ;; fetch/cursor  : symbol cursor nat -> #f or (listof vector)
    (define/public (fetch/cursor)
      null)

    ;; get-base      : -> connection<%> or #f (#f means base isn't fixed)
    (define/public (get-base)
      null)

    ;; list-tables   : symbol symbol -> (listof string)
    (define/public (list-tables)
      null)

    ;; Transactions
    (define/override (start-transaction* sym isolation option)
      null)

    ;; end-transaction    : symbol (U 'commit 'rollback) boolean -> void
    (define/override (end-transaction)
      null)

    ;; transaction-status : symbol -> (U boolean 'invalid)
    (define/override (transaction-status)
      null)

    ;; free-statement     : prepared-statement<%> boolean -> void
    (define/public (free-statement)
      null)
    ))

(define (neo4j-connect #:server [server "localhost"]
                       #:port [port 7474]
                       #:database [database "neo4j"]
                       #:user [user #f]
                       #:password [password #f]
                       #:debug? [debug? #f])
  (let ([c (new connection%)])
    (when debug? (send c debug #t))
    (send c start-connection-protocol server port database user password)
    c))
