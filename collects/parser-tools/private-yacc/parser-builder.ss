#cs
(module parser-builder mzscheme
  
  (require "input-file-parser.ss"
           "table.ss"
           "parser-actions.ss"
           "grammar.ss")
  
  (provide build-parser)
  
  (define (build-parser start input-terms assocs prods filename runtime src)
    (let* ((grammar (parse-input start input-terms assocs prods runtime))
           (table (build-table grammar filename))
           (table-code 
            (cons 'vector 
                  (map (lambda (action)
                         (cond
                           ((shift? action)
                            `(make-shift ,(shift-state action)))
                           ((reduce? action)
                            `(make-reduce ,(reduce-prod-num action)
                                          ,(reduce-lhs-num action)
                                          ,(reduce-rhs-length action)))
                           ((accept? action)
                            `(make-accept))
                           (else action)))
                       (vector->list table))))
            
           (num-non-terms (length (grammar-non-terms grammar)))

           (token-code
            `(let ((ht (make-hash-table)))
               (begin
                 ,@(map (lambda (term)
                          `(hash-table-put! ht 
                                            ',(gram-sym-symbol term)
                                            ,(+ num-non-terms (gram-sym-index term))))
                        (grammar-terms grammar))
                 ht)))
           
           (actions-code
            `(vector ,@(map prod-action (grammar-prods grammar))))
           
           (parser-code
            `(letrec ((term-sym->index ,token-code)
                      (table ,table-code)
                      (actions ,actions-code)
                      (pop-x
                       (lambda (s n)
                         (if (> n 0)
                             (pop-x (cdr s) (sub1 n))
                             s))))
               (lambda (get-token)
                 (let loop ((stack (list 0))
                            (ip (get-token)))
                   (display stack)
                   (newline)
                   (display (if (token? ip) (token-name ip) ip))
                   (newline)
                   (let* ((s (car stack))
                          (a (hash-table-get term-sym->index 
                                             (if (token? ip)
                                                 (token-name ip)
                                                 ip)))
                          (action (array2d-ref table s a)))
                     (cond
                       ((shift? action)
                        (printf "shift:~a~n" (shift-state action))
                        (loop (cons (shift-state action) stack) (get-token)))
                       ((reduce? action)
                        (printf "reduce:~a~n" (reduce-prod-num action))
                        (let* ((A (reduce-lhs-num action))
                               (new-stack (pop-x stack (reduce-rhs-length action)))
                               (goto (array2d-ref table (car new-stack) A)))
                          (loop (cons goto new-stack) ip)))
                       ((accept? action)
                        (printf "accept~n"))
                       (else (error 'parser)))))))))
      (datum->syntax-object
       runtime
       parser-code
       src))))
           