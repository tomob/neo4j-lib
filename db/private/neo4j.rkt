#lang racket/base
(require racket/class
         racket/pretty
         racket/string
         racket/list
         racket/port
         net/url
         net/head
         json
         "dbsystem.rkt"
         db/private/generic/interfaces
         db/private/generic/prepared
         db/private/generic/common)

(provide neo4j-connect)

(define (discovery-url server port)
  (make-url "http" #f server port #t null null #f))

(define (decode-result sym result)
  (let ([errors (hash-ref result 'errors)]
        [results (hash-ref result 'results)])
    (cond
      [(not (empty? errors)) (raise-error sym errors)]
      [(and (empty? (hash-ref (car results) 'columns))
            (empty? (hash-ref (car results) 'data)))
        (format-simple-result (car results))]
      [else (format-rows-result (car results))])))

(define (format-rows-result results)
  (rows-result (hash-ref results 'columns)
                (map (lambda (v) (list->vector (hash-ref v 'row)))
                    (hash-ref results 'data))))

(define (format-simple-result results)
  (simple-result (hash-ref results `stats)))

(define (raise-error who errors)
  (raise-sql-error who
                    (hash-ref (car errors) 'code)
                    (hash-ref (car errors) 'message)
                    null))

;; gets param names as symbols
(define (get-params query)
  (let-values ([(params _in-str in-param param)
                (for/fold ([params '()]
                           [in-str #f]
                           [in-param #f]
                           [param ""])
                          ([char (in-string query)])
                  (cond
                    [(char=? char #\")
                     (values params (not in-str) in-param param)]
                    [(and (not in-str) (char=? char #\$))
                     (values params in-str #t "")]
                    [(and in-param (or (char-alphabetic? char) (char-numeric? char) (member char '(#\_) char=?)))
                     (values params in-str in-param (string-append param (string char)))]
                    [in-param
                     (values (cons (string->symbol param) params) in-str #f "")]
                    [else
                     (values params in-str in-param param)] ))] )
    (reverse (remove-duplicates (if in-param ;; Case when param ends the query
                                    (cons (string->symbol param) params)
                                    params)))))

(define (convert-params prep hash-or-list)
  (if (and (= 1 (length hash-or-list)) (hash? (first hash-or-list)))
      (first hash-or-list)
      (for/hash ([param (get-params (send prep get-stmt))]
                 [val hash-or-list])
        (values param val))))

(define (parse-headers headers)
  (define (parse-header header)
    (let ([parsed (first (extract-all-fields header))])
      (cons (string->symbol (bytes->string/utf-8 (car parsed)))
            (bytes->string/utf-8 (cdr parsed)))))
  (make-hash (map parse-header headers)))

(define connection%
  (class* statement-cache% (connection<%>)
    (inherit dprintf
             call-with-lock
             get-tx-status
             set-tx-status!)
    (init-field [connecton-fn http-sendrecv/url])
    (inherit-field DEBUG?)
    (super-new)

    (define connected #f)
    (define tx-url null)
    (define single-url null)
    (define headers '(#"Accept: application/json"
                      #"Content-Type: application/json"))
    (define info null)
    (define current-transaction-url null)
    (define current-transaction-commit-url null)
    (define current-transaction-expiry null)


    (define/public (start-connection-protocol server port database user password)
      (let*-values ([(disc-url) (discovery-url server port)]
                    [(status _ content) (connecton-fn disc-url #:headers headers)])
        (when (string-suffix? (bytes->string/utf-8 status) "200 OK")
          (setup-object (read-json content) database))))

    (define/private (setup-object parsed-info database)
      (set! connected #t)
      (set! info parsed-info)
      (when DEBUG? (dprintf "  ** connected to ~a\n" (pretty-format info)))
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
      dbsystem)

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
      (let-values ([(result-json _) (util:send-and-receive-json current-transaction-url
                                                                (prepare-data statement))])
        (result:decode-result sym result-json)))

    (define/private (query:single-query sym statement)
      (let-values ([(result-json _) (util:send-and-receive-json single-url
                                                                (prepare-data statement))])
        (result:decode-result sym result-json)))

    (define/private (util:send-and-receive-json url data [method #"POST"])
      (dprintf "  >> sending ~a request to ~a: ~a\n" method (url->string url) (pretty-format data))
      (let*-values ([(status headers in) (connecton-fn url
                                                       #:method method
                                                       #:headers headers
                                                       #:data data)]
                    [(input) (port->string in #:close? #t)]
                    [(result-json) (string->jsexpr input )])
        (dprintf "  << received result: ~a\n" (pretty-format result-json))
        (values result-json headers)))

    (define/private (prepare-data binding)
      (cond
        [(statement-binding? binding) (prepare:bound-statement binding)]
        [else (prepare:simple-query binding)]))

    (define/private (prepare:bound-statement binding)
      (let* ([prep (statement-binding-pst binding)]
             [params (convert-params prep (statement-binding-params binding))]
             [query (send prep get-stmt)])
      (jsexpr->string (hash 'statements (list (hash 'statement query
                                                    'parameters params
                                                    'includeStats  #t))))))

    (define/private (prepare:simple-query stmt)
      (jsexpr->string (hash 'statements (list (hash 'statement stmt
                                                    'includeStats  #t)))))

    (define/private (result:decode-result sym result)
      (decode-result sym result))

    (define/override (prepare1* fsym sql close-on-exec? stmt-type)
      (new prepared-statement%
          (handle "stmt")
          (close-on-exec? close-on-exec?)
          (param-typeids (for/list ([_ (length (get-params sql))]) 'any))
          (result-dvecs (list #('any))) ;;TODO Should this return the right number of return values?
          (stmt-type 'statement)
          (stmt sql)
          (owner this)))

    (define/override (classify-stmt stmt)
      ;; Never use statemet cache
      #f)

    ;; fetch/cursor  : symbol cursor nat -> #f or (listof vector)
    (define/public (fetch/cursor)
      null)

    ;; get-base      : -> connection<%> or #f (#f means base isn't fixed)
    (define/public (get-base)
      this)

    ;; list-tables   : symbol symbol -> (listof string)
    (define/public (list-tables sym _)
      (error/no-support sym "listing tables"))

    ;; Transactions
    (define/override (start-transaction* sym isolation option)
      (cond
        [(get-tx-status) (error/no-support sym "nested transactions")]
        [isolation (error/no-support sym "isolation level other than database-dependent")]
        [else
         (begin
           (dprintf "  ** starting transaction\n")
           (let-values ([(result headers) (util:send-and-receive-json tx-url (jsexpr->string (hash 'statements '())))])
             (tx:decode-transaction-start sym result headers)
             (set-tx-status! sym #t)))]))

    (define/override (end-transaction* sym mode _savepoint)
      (case mode
        [(rollback) (tx:rollback sym)]
        [(commit) (tx:commit sym)]))

    (define/private (tx:rollback sym)
      (dprintf "  ** rolling back transaction\n")
      (let-values ([(result headers) (util:send-and-receive-json current-transaction-url
                                                                 (jsexpr->string (hash 'statements '()))
                                                                 #"DELETE")])
        (tx:decode-transaction-end sym result headers)
        (set-tx-status! sym #f)))

    (define/private (tx:commit sym)
      (dprintf "  ** commiting transaction\n")
      (let-values ([(result headers) (util:send-and-receive-json current-transaction-commit-url
                                                                 (jsexpr->string (hash 'statements '())))])
        (tx:decode-transaction-end sym result headers)
        (set-tx-status! sym #f)))

    (define/private (tx:decode-transaction-start sym result headers)
      (let ([errors (hash-ref result 'errors)])
        (if (not (empty? errors))
            (raise-error sym errors)
            (let ([commit-url (hash-ref result 'commit)]
                  [transaction-url (hash-ref (parse-headers headers) 'Location)]
                  [transaction (hash-ref result 'transaction)])
              (set! current-transaction-url (string->url transaction-url))
              (set! current-transaction-commit-url (string->url commit-url))
              (set! current-transaction-expiry (hash-ref transaction 'expires))
              (dprintf "  ** transaction transaction url ~a\n" transaction-url)
              (dprintf "  ** transaction commit url ~a\n" commit-url)
              (dprintf "  ** transaction expiry ~a\n" current-transaction-expiry)))))

    (define/private (tx:decode-transaction-end sym result headers)
      (let ([errors (hash-ref result 'errors)])
        (if (not (empty? errors))
            (raise-error sym errors)
            (begin
              (set! current-transaction-url null)
              (set! current-transaction-commit-url null)
              (set! current-transaction-expiry null)))))

    (define/public (free-statement _stmt _needs-lock?)
      ;; No resources allocated on server, no need for any cleenup
      (void))
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
