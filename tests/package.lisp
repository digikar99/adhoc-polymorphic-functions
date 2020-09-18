(defpackage :typed-dispatch/tests
  (:use :cl :fiveam :typed-dispatch))

(in-package :typed-dispatch/tests)

(def-suite :typed-dispatch)
(in-suite :typed-dispatch)

(defmacro catch-condition (&body body)
  `(handler-case (progn
                   ,@body)
     (condition (condition) condition)))

(progn
  (define-typed-function my= (a b))
  (defun-typed my= ((a string) (b string))
    (string= a b))
  (defun-typed my= ((a number) (b number))
    (= a b))
  (define-compiler-macro-typed my= (number number) (&whole form a b)
    (declare (ignore b))
    (if (= 0 a)
        ''zero
        form))
  (defun my=-caller ()
    (declare (optimize speed))
    (my= 0 5)))

(def-test required-args-correctness ()
  (let ((obj1 "hello")
        (obj2 "world")
        (obj3 "hello")
        (obj4 5)
        (obj5 5.0))
    (is (eq t   (my= obj1 obj3)))
    (is (eq nil (my= obj1 obj2)))
    (is (eq t   (my= obj4 obj5)))
    (is (typep (catch-condition (my= obj1 obj4))
               'error))
    (is (eq 'zero (my=-caller)))))

(progn ; This requires SBCL version > 2.0.8: there's a commit after 2.0.8 was released.
  (define-typed-function bar (a &optional b c))
  (defun-typed bar ((str string) &optional ((b integer) 5) ((c integer) 7))
    (list str b c))
  (define-compiler-macro-typed bar (string &optional integer integer) (&whole form &rest args)
    (declare (ignore args))
    `(list ,form)) ; This usage of FORM also tests infinite recursion
  (defun bar-caller ()
    (declare (optimize speed))
    (bar "hello" 9)))

(def-test optional-args-correctness ()
  (is (equalp (bar "hello")
              '("hello" 5 7)))
  (is (equalp (bar "hello" 6)
              '("hello" 6 7)))
  (is (equalp (bar "hello" 6 9)
              '("hello" 6 9)))
  (is (equalp (bar-caller)
              '(("hello" 9 7)))))

(let ((a "hello")
      (b 5))
  (define-typed-function baz (c &optional d))
  (defun-typed baz ((c string) &optional ((d integer) b))
    (declare (ignore c))
    (list a d)))

(defun baz-caller (a1 a2)
  (baz a1 a2))

(defun baz-caller-inline (a1 a2)
  (declare (type string a1)
           (type integer a2)
           (optimize speed))
  (baz a1 a2))

(def-test non-null-environment-correctness ()
  (is (equalp (baz-caller "world" 7)
              '("hello" 7)))
  (is (equalp (baz-caller-inline "world" 7)
              '("hello" 7))))

(progn
  (define-typed-function foo (a &optional b))
  (defun-typed foo ((str1 string) &optional ((str2 string) "str2"))
    (declare (ignore str1 str2))
    'string)
  (defun-typed foo ((num1 number) &optional ((num2 number) pi))
    (declare (ignore num1 num2))
    'number))

(def-test untyped-rest-correctness ()
  (is (eq 'string (foo "hello")))
  (is (eq 'string (foo "hello" "world")))
  (is (eq 'number (foo 5.6)))
  (is (eq 'number (foo 5.6 6))))

(progn
  (define-typed-function foobar (a &key key b))
  (defun-typed foobar ((str string) &key ((key number) 5) ((b string) "world"))
    (declare (ignore str))
    (list 'string key b))
  (define-compiler-macro-typed foobar (number &key :key number :b string) (&whole form &rest args)
    (declare (ignore args))
    `(list ,form))
  (defun-typed foobar ((num number) &key ((key number) 6) ((b string) "world"))
    (declare (ignore num))
    (list 'number key b))
  (defun foobar-caller ()
    (declare (optimize speed))
    (foobar 7 :key 10)))

(def-test typed-key-correctness ()
  (is (equalp '(string 5 "world")    (foobar "hello")))
  (is (equalp '(string 5.6 "world")  (foobar "hello" :key 5.6)))
  (is (equalp '(number 6 "world")    (foobar 5.6)))
  (is (equalp '(number 9 "world")    (foobar 5.6 :key 9)))
  (is (equalp '((number 10 "world")) (foobar-caller)))
  (is (equalp '(number 6 "bye")      (foobar 5.6 :b "bye")))
  (is (equalp '(number 4.4 "bye")    (foobar 5.6 :b "bye" :key 4.4))))

(progn
  (define-typed-function foz (a))
  (defun-typed foz ((a number))
    (declare (optimize speed))
    (if (= a 5)
        'number
        (foz "hello")))
  (defun-typed foz ((a string))
    (declare (optimize speed))
    (if (string= a "hello")
        'string
        (foz 5)))
  ;; Will result in infinite expansion upon redefinition, if compilation is not done correctly
  (defun-typed foz ((a number))
    (declare (optimize speed))
    (if (= a 5)
        'number
        (foz "hello"))))

(def-test recursive-correctness ()
  (is (eq 'number (foz 5)))
  (is (eq 'string (foz "hello")))
  (is (eq 'number (foz "world")))
  (is (eq 'string (foz 7))))
