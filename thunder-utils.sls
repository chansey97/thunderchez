;;
;; Copyright 2016 Aldo Nicolas Bruno
;;
;; Licensed under the Apache License, Version 2.0 (the "License");
;; you may not use this file except in compliance with the License.
;; You may obtain a copy of the License at
;;
;;     http://www.apache.org/licenses/LICENSE-2.0
;;
;; Unless required by applicable law or agreed to in writing, software
;; distributed under the License is distributed on an "AS IS" BASIS,
;; WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
;; See the License for the specific language governing permissions and
;; limitations under the License.

(library (thunder-utils)
  (export string-split string-replace bytevector-copy* read-string
	  print-stack-trace
	  sub-bytevector  sub-bytevector=?
	  load-bytevector save-bytevector)
  
  (import (scheme) (srfi s14 char-sets))

  ;; s is a string , c is a character-set or a list of chars
  ;; null strings are discarded from result by default unless #f is specified as third argument
  (define string-split
    (case-lambda
     [(s c)
      (string-split s c #t)]
     [(s c discard-null?)
      (define res '())
      (let loop ([l (string->list s)] [t '()])
	(if (null? l) 
	    (if (and (null? t) discard-null?)
		res (append res (list (list->string t))))
	    (if (or (and (char-set? c) (char-set-contains? c (car l)))
		    (and (pair? c) (memv (car l) c)))
		(begin 
		  (unless (and (null? t) discard-null?)
			  (set! res (append res (list (list->string t)))))
		  (loop (cdr l) '()))
		(loop (cdr l) (append t (list (car l)))))))]))
  
  ;; POSSIBLE THAT THIS NOT EXIST?
  ;; if x is a character: (eqv?  s[i] x) => s[i] = y
  ;; if x is a list:      (memq s[i] x) => s[i] = y

  (define (string-replace s x y)
    (list->string  
     (let ([cmp (if (list? x) memv eqv?)])
       (map (lambda (z) (if (cmp z x) y z)) (string->list s)))))

  ;; WHY THERE NOT EXISTS BYTEVECTOR-COPY WITH src-start and n? F*** YOU
  (define bytevector-copy*
    (case-lambda
     [(bv) (bytevector-copy bv)]
     [(bv start)
      (bytevector-copy* bv start (- (bytevector-length bv) start))]
     [(bv start n)
      (let ([dst (make-bytevector n)])
	(bytevector-copy! bv start dst 0 n) dst)]))

  (define read-string
    (case-lambda
     [() (read-string #f)]
     [(n) (read-string n (current-input-port))]
     [(n port)
      (if n
	  (get-string-n port n)
	  (get-string-all port))]))

  (define (print-stack-trace depth)
    (printf "stack-trace:\n")
    (call/cc 
     (lambda (k)
       (let loop ((cur (inspect/object k))
		  (i 0))
	 (if (and (< i depth)
		  (> (cur 'depth) 1))
	     (let* ([name (cond [((cur 'code) 'name) => (lambda (x) x)]
				[else "*"])]
		    [source ((cur 'code) 'source)]
		    [source-txt (if source
				    (let ([ss (with-output-to-string
						(lambda ()
						  (source 'write (current-output-port))))])
					  (if (> (string-length ss) 50)
					      (string-truncate! ss 50)
					      ss))
				    "*")])
	       (call-with-values
		   (lambda () (cur 'source-path))
		 (case-lambda
		  [() (printf "[no source] [~a]: ~a\n" name source-txt)]
		  [(fn bfp) (printf "~a char ~a [~a]: ~a\n" fn bfp name source-txt)]
		  [(fn line char) (printf "~a:~a:~a [~a]: ~a\n" fn line char name source-txt)]))
	       (loop (cur 'link) (+ i 1)))))))
    (printf "stack-trace end.\n"))


  (define sub-bytevector
    (case-lambda
      [(b start)
       (sub-bytevector b start (bytevector-length b))]
      [(b start end)
       (let* ([n (- end start)]
	      [x (make-bytevector n)])
	 (bytevector-copy! b start x 0 n)
	 x)]))

  (define (sub-bytevector=? b1 start1 b2 start2 len)
    (bytevector=? (sub-bytevector b1 start1 (+ start1 len))
		  (sub-bytevector b2 start2 (+ start2 len))))

  (define (load-bytevector path)
    (call-with-port (open-file-input-port path)
		    (lambda (p) (get-bytevector-all p))))
  
  (define (save-bytevector path data)
    (call-with-port (open-file-output-port path)
		    (lambda (p) (put-bytevector p data))))

  
  (define-syntax (nest stx)
    (syntax-case stx ()
      ((nest outer ... inner)
       (fold-right (lambda (o i)
		     (with-syntax (((outer ...) o)
				   (inner i))
		       #'(outer ... inner)))
		   #'inner (syntax->list #'(outer ...))))))


  );library

