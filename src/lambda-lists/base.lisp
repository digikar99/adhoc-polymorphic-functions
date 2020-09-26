(in-package typed-dispatch)

;; In this file, our main functions/macros are
;; DEFINE-LAMBDA-LIST-HELPER
;; - LAMBDA-LIST-TYPE
;; - DEFUN-LAMBDA-LIST
;; - DEFUN-BODY
;; - LAMBDA-DECLARATIONS

;; THE BASICS ==================================================================

(define-constant +lambda-list-types+
    (list 'required
          'required-optional
          'required-key)
  :test #'equalp)

(defun lambda-list-type-p (object)
  "Checks whhether the OBJECT is in +LAMBDA-LIST-TYPES+"
  (member object +lambda-list-types+))

(deftype lambda-list-type () `(satisfies lambda-list-type-p))

(5am:def-suite lambda-list :in :typed-dispatch)

(defun valid-parameter-name-p (name)
  (and (symbolp name)
       (not (constantp name))
       (not (member name lambda-list-keywords))))

(defun potential-type-of-lambda-list (lambda-list)
  ;; "potential" because it does not check the symbols
  (declare (type list lambda-list))
  (the lambda-list-type
       (let ((intersection (intersection lambda-list lambda-list-keywords)))
         ;; premature optimization and over-abstraction:/
         (cond ((null intersection)
                'required)
               ((and (car intersection) (null (cdr intersection)) ; length is 1
                     (member '&optional intersection))
                'required-optional)
               ((and (car intersection) (null (cdr intersection)) ; length is 1
                     (member '&key intersection))
                'required-key)
               (t
                (error "Neither of ~A types" +lambda-list-types+))))))

(defvar *potential-type*)
(setf (documentation '*potential-type* 'variable)
      "POTENTIAL-TYPE of the LAMBDA-LIST of the typed function being compiled.
Bound inside the functions defined by TYPED-DISPATCH::DEFINE-LAMBDA-LIST-HELPER")

(defvar *lambda-list*)
(setf (documentation '*lambda-list* 'variable)
      "LAMBDA-LIST of the typed function being compiled. Bound inside the functions
defined by TYPED-DISPATCH::DEFINE-LAMBDA-LIST-HELPER")

(defvar *name*)
(setf (documentation '*name* 'variable)
      "NAME of the typed function being compiled. Bound inside DEFINE-TYPED-FUNCTION")

(defvar *lambda-list-typed-p*)
(setf (documentation '*lambda-list-typed-p* 'variable)
      "Is T if the *LAMBDA-LIST* being processed is to be treated as if it had type
specifiers. Bound inside the functions defined by TYPED-DISPATCH::DEFINE-LAMBDA-LIST-HELPER")

(defmacro define-lambda-list-helper ((outer-name outer-documentation)
                                     (inner-name inner-documentation)
                                     &body action-form)
  "ACTION-FORM should be defined in terms of *POTENTIAL-TYPE* and *LAMBDA-LIST* variables."
  `(progn
     (defun ,outer-name (lambda-list &key typed)
       ,outer-documentation
       (declare (type list lambda-list))
       (let ((*potential-type*      (potential-type-of-lambda-list lambda-list))
             (*lambda-list*         lambda-list)
             (*lambda-list-typed-p* typed))
         (if (%lambda-list-type *potential-type* lambda-list)
             (progn ,@action-form)
             (error "LAMBDA-LIST ~A is neither of ~%  ~A" lambda-list +lambda-list-types+))))
     (defgeneric ,inner-name (potential-lambda-list-type lambda-list)
       (:documentation ,inner-documentation))
     ;; For better error reporting
     (defmethod ,inner-name ((type t) (lambda-list t))
       (assert (typep type 'lambda-list-type)
               ()
               "Expected POTENTIAL-LAMBDA-LIST-TYPE to be one of ~%  ~A~%but is ~A"
               +lambda-list-types+ type)
       (assert (typep lambda-list 'list)
               ()
               "Expected LAMBDA-LIST to be a LIST but is ~A"
               lambda-list)
       (error "No potential type found for LAMBDA-LIST ~A from amongst ~%  ~A"
              lambda-list +lambda-list-types+))))

;; LAMBDA-LIST-TYPE ============================================================

(define-constant +lambda-list-type-doc+
  "Returns the type of LAMBDA-LIST from amongst +LAMBDA-LIST-TYPES+.
Raises an ERROR otherwise."
  :test 'string=)

(define-lambda-list-helper
    (lambda-list-type  #.+lambda-list-type-doc+)
    (%lambda-list-type "Checks whether LAMBDA-LIST is of type POTENTIAL-LAMBDA-LIST-TYPE")
  *potential-type*)

(defun untyped-lambda-list-p (lambda-list)
  (ignore-errors (lambda-list-type lambda-list)))
(defun typed-lambda-list-p (lambda-list)
  (ignore-errors (lambda-list-type lambda-list :typed t)))
(deftype untyped-lambda-list ()
  "Examples:
  (a b)
  (a b &optional c)
Non-examples:
  ((a string))"
  `(satisfies untyped-lambda-list-p))
(deftype typed-lambda-list ()
  "Examples:
  ((a integer) (b integer))
  ((a integer) &optional ((b integer) 0 b-supplied-p))"
  `(satisfies typed-lambda-list-p))

;; DEFUN-LAMBDA-LIST ===========================================================

(define-constant +defun-lambda-list-doc+
  "Processes LAMBDA-LIST to return another lambda-list suitable for the DEFUN generated by the DEFINE-TYPED-FUNCTION. Raises an error if %LAMBDA-LIST-TYPE fails on *POTENTIAL-TYPE*."
  :test 'string=)

(define-constant +defun-lambda-list-doc-helper+
  "Processes LAMBDA-LIST assuming it is of type TYPE, and returns another lambda-list that is suitable for the DEFUN generated by the DEFINE-TYPED-FUNCTION. IF *LAMBDA-LIST-TYPED-P* is T, 
the second value is the type-list corresponding to the LAMBDA-LIST"
  :test 'string=)

(define-lambda-list-helper
    (defun-lambda-list  #.+defun-lambda-list-doc+)
    (%defun-lambda-list #.+defun-lambda-list-doc-helper+)
  (%defun-lambda-list *potential-type* *lambda-list*))

(5am:def-suite defun-lambda-list :in lambda-list)

;; DEFUN-BODY ==================================================================

(define-constant +defun-body-doc+
  "Processes LAMBDA-LIST to return code suitable for the caller part
inside the DEFUN generated by the DEFINE-TYPED-FUNCTION. Raises an error if
%LAMBDA-LIST-TYPE fails on *POTENTIAL-TYPE*."
  :test 'string=)

(define-constant +defun-body-doc-helper+
  "Processes LAMBDA-LIST assuming it is of type TYPE, and returns code that is
is suitable for caller part inside DEFUN generated by the DEFINE-TYPED-FUNCTION."
  :test 'string=)

(define-lambda-list-helper
    (defun-body  #.+defun-body-doc+)
    (%defun-body #.+defun-body-doc-helper+)
  (let ((defun-lambda-list (%defun-lambda-list *potential-type* *lambda-list*)))
    (values (%defun-body *potential-type* defun-lambda-list)
            defun-lambda-list)))

;; LAMBDA-DECLARATIONS =========================================================

(define-constant +lambda-declarations-doc+
  "Returns the list of declarations given the LAMBDA-LIST. the LAMBDA-LIST should
be a TYPED-LAMBDA-LIST"
  :test 'string=)

(define-lambda-list-helper
    (lambda-declarations  #.+lambda-declarations-doc+)
    (%lambda-declarations #.+lambda-declarations-doc+)
  (progn
    (assert (typed-lambda-list-p *lambda-list*))
    (%lambda-declarations *potential-type* *lambda-list*)))

;; TYPE-LIST-APPLICABLE-P ======================================================

(defgeneric type-list-applicable-p (lambda-list-type arg-list type-list))

(defmethod type-list-applicable-p ((type t)
                                   (arg-list t)
                                   (typed-lambda-list t))
  (assert (typep type 'lambda-list-type) nil
          "Expected LAMBDA-LIST-TYPE to be one of ~%  ~a~%but is ~a"
          +lambda-list-types+ type)
  (assert (typep type-list 'type-list) nil
          "Expected TYPE-LIST to be a TYPE-LIST but is ~a" type-list)
  (assert (typep arg-list 'list) nil
          "Expected ARG-LIST to be a LIST but is ~a" arg-list)
  (error "This code shouldn't have reached here; perhaps file a bug report!"))

(5am:def-suite type-list-applicable-p :in lambda-list)

(defun our-typep (arg type)
  (if *compiler-macro-expanding-p*
      (progn
        (when (and (symbolp arg) ; type-declared-p
                   (not (cdr (assoc 'type
                                    (nth-value 2
                                               (variable-information arg *environment*))))))
          (signal "Type of ~S is not declared" arg))
        (subtypep (cm:form-type arg *environment*) type))
      (typep arg type)))
