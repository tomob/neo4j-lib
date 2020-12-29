#lang racket/base
(require racket/class
         racket/pretty
         racket/string
         racket/list
         net/url
         json
         db/private/generic/interfaces
         db/private/generic/common)

(provide neo4j-connect)

(define (discovery-url server port)
  (make-url "http" #f server port #t null null #f))

(define connection%
  (class* transactions% (connection<%>)
    (inherit dprintf
             call-with-lock
             get-tx-status)
    (init-field [connecton-fn http-sendrecv/url])
    (inherit-field DEBUG?)

    (define connected #f)
    (define tx-url null)
    (define single-url null)
    (define headers '(#"Accept: application/json"
                      #"Content-Type: application/json"))
    (define info null)

    (super-new)

    (define/public (start-connection-protocol server port database user password)
      (let*-values ([(disc-url) (discovery-url server port)]
                    [(status _ content) (connecton-fn disc-url #:headers headers)])
        (when (string-suffix? (bytes->string/utf-8 status) "200 OK")
          (setup-object (read-json content) database))))

    (define/private (setup-object parsed-info database)
      (set! connected #t)
      (set! info parsed-info)
      (when DEBUG? (dprintf "Connected to ~a\n" (pretty-format info)))
      (set! tx-url (string->url (string-replace (hash-ref info 'transaction) "{databaseName}" database)))
      (set! single-url (string->url (string-append (url->string tx-url) "/commit"))))

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
        (call-with-lock sym (lambda () (query:query sym statement)))
        (error sym "Not connected")))

    (define/private (query:query sym statement)
      (if (get-tx-status)
        (query:in-transaction sym statement)
        (query:single-query sym statement)))

    (define/private (query:in-transaction sym statement)
      null)

    (define/private (query:single-query sym statement)
      (let*-values ([(data) (prepare-data statement)]
                    [(status headers in) (connecton-fn single-url
                                                       #:method #"POST"
                                                       #:headers headers
                                                       #:data data)]
                    [(result-json) (read-json in)])
        (result:decode-result sym result-json)))

    (define/private (prepare-data stat)
      (jsexpr->string (make-hash `((statements . (,(make-hash `((statement . ,stat)))))))))

    (define/private (result:decode-result sym result)
      (let ([errors (hash-ref result 'errors)])
        (if (not (empty? errors))
            (result:raise-error sym errors)
            (result:format-rows-result (car (hash-ref result 'results))))))

    (define/private (result:format-rows-result results)
      (rows-result (hash-ref results 'columns)
                   (map (lambda (v) (list->vector (hash-ref v 'row)))
                        (hash-ref results 'data))))

    (define/private (result:raise-error who errors)
      (raise-sql-error who
                       (hash-ref (car errors) 'code)
                       (hash-ref (car errors) 'message)
                       null))

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
