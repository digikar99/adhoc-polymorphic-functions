(in-package polymorphic-functions)

;; In this file, our main functions/macros are
;; - DEFINE-LAMBDA-LIST-HELPER
;; - LAMBDA-LIST-TYPE
;; - COMPUTE-POLYMORPHIC-FUNCTION-LAMBDA-BODY
;; - SBCL-TRANSFORM-ARGS-FROM-LAMBDA-LIST-FORM
;; - TYPE-LIST-COMPATIBLE-P
;; - TYPE-LIST-SUBTYPE-P
;; - TYPE-LIST-CAUSES-AMBIGUOUS-CALL-P

;; THE BASICS ==================================================================

(define-constant +lambda-list-types+
    (list 'required
          'required-optional
          'required-key
          'rest)
  :test #'equalp)

(defun lambda-list-type-p (object)
  "Checks whhether the OBJECT is in +LAMBDA-LIST-TYPES+"
  (member object +lambda-list-types+))

(deftype lambda-list-type () `(satisfies lambda-list-type-p))

(5am:def-suite lambda-list :in :polymorphic-functions)

(defun valid-parameter-name-p (name)
  (and (symbolp name)
       (not (constantp name))
       (not (member name lambda-list-keywords))))

(defun potential-type-of-lambda-list (lambda-list)
  ;; "potential" because it does not check the symbols
  (declare (type list lambda-list))
  (the lambda-list-type
       (let ((intersection (intersection lambda-list lambda-list-keywords)))
         ;; premature optimization and over-abstraction :/
         (cond ((null intersection) 'required)
               ((and (car intersection) (null (cdr intersection)) ; length is 1
                     (member '&optional intersection))
                'required-optional)
               ((and (car intersection) (null (cdr intersection)) ; length is 1
                     (member '&key intersection))
                'required-key)
               ((member '&rest intersection) ; don't check the lengths
                'rest)
               (t
                (error "Neither of ~A types" +lambda-list-types+))))))

(defvar *potential-type*)
(setf (documentation '*potential-type* 'variable)
      "POTENTIAL-TYPE of the LAMBDA-LIST of the typed function being compiled.
Bound inside the functions defined by POLYMORPHS::DEFINE-LAMBDA-LIST-HELPER")

(defvar *lambda-list*)
(setf (documentation '*lambda-list* 'variable)
      "LAMBDA-LIST of the typed function being compiled. Bound inside the functions
defined by POLYMORPHS::DEFINE-LAMBDA-LIST-HELPER")

(defvar *lambda-list-typed-p*)
(setf (documentation '*lambda-list-typed-p* 'variable)
      "Is T if the *LAMBDA-LIST* being processed is to be treated as if it had type
specifiers. Bound inside the functions defined by POLYMORPHS::DEFINE-LAMBDA-LIST-HELPER")

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

;; COMPUTE-POLYMORPHIC-FUNCTION-LAMBDA-BODY ====================================

(defgeneric compute-polymorphic-function-lambda-body
    (lambda-list-type effective-untyped-lambda-list &optional invalidated-p)
  (:documentation #.+compute-polymorphic-function-lambda-body-doc+))

;; SBCL-TRANSFORM-ARG-LVARS-FROM-LAMBDA-LIST-FORM ==============================

(define-lambda-list-helper
    (sbcl-transform-arg-lvars-from-lambda-list-form
     #.+sbcl-transform-arg-lvars-from-lambda-list-form+)
    (%sbcl-transform-arg-lvars-from-lambda-list-form
     #.+sbcl-transform-arg-lvars-from-lambda-list-form+)
  (progn
    (assert (untyped-lambda-list-p *lambda-list*))
    (%sbcl-transform-arg-lvars-from-lambda-list-form *potential-type* *lambda-list*)))

;; TYPE-LIST-COMPATIBLE-P ======================================================

(defun type-list-compatible-p (lambda-list-type type-list effective-untyped-lambda-list)
  "Returns T if the given TYPE-LIST is compatible with the given UNTYPED-LAMBDA-LIST."
  (declare (type type-list type-list))
  (let ((*lambda-list-typed-p* nil)
        (*potential-type* lambda-list-type))
    (%type-list-compatible-p *potential-type* type-list effective-untyped-lambda-list)))

(defgeneric %type-list-compatible-p
    (potential-lambda-list-type type-list untyped-lambda-list))

(defmethod %type-list-compatible-p ((type t)
                                    (type-list t)
                                    (untyped-lambda-list t))
  (assert (typep type 'lambda-list-type) nil
          "Expected LAMBDA-LIST-TYPE to be one of ~%  ~a~%but is ~a"
          +lambda-list-types+ type)
  (assert (typep type-list 'type-list) nil
          "Expected TYPE-LIST to be a TYPE-LIST but is ~a" type-list)
  (assert (typep untyped-lambda-list 'untyped-lambda-list) nil
          "Expected ~A to be a UNTYPED-LAMBDA-LIST" untyped-lambda-list)
  (error "This code shouldn't have reached here; perhaps file a bug report!"))

(def-test type-list-compatible-p (:suite lambda-list)
  (5am:is-true  (type-list-compatible-p 'required '(string string) '(c d)))
  (5am:is-false (type-list-compatible-p 'required '(string) '(c d)))
  (5am:is-true  (type-list-compatible-p 'required-optional
                                        '(string number &optional t) '(c d &optional e)))
  (5am:is-false (type-list-compatible-p 'required-optional
                                        '(number) '(c d &optional d)))
  (5am:is-true  (type-list-compatible-p 'required-key
                                        '(string &key (:d number) (:e string))
                                        '(c &rest args &key (d nil dp) (e nil ep))))
  (5am:is-false (type-list-compatible-p 'required-key
                                        '(string &key (:d number))
                                        '(c &rest args &key (d nil dp) (e nil ep))))
  (5am:is-true  (type-list-compatible-p 'rest
                                        '(string) '(c &rest e)))
  (5am:is-true  (type-list-compatible-p 'rest
                                        '(number string) '(c &rest e)))
  (5am:is-false (type-list-compatible-p 'rest
                                        '(&rest) '(c &rest e))))

(defvar *name*)
(defvar *environment*)


;; TYPE-LIST-SUBTYPE-P =========================================================

(defun type-list-subtype-p (type-list-1 type-list-2)
  #.+type-list-subtype-p+
  (declare (type type-list type-list-1 type-list-2))
  (let ((*lambda-list-typed-p* nil))
    (%type-list-subtype-p (potential-type-of-lambda-list type-list-1)
                          (potential-type-of-lambda-list type-list-2)
                          type-list-1
                          type-list-2)))

(defgeneric %type-list-subtype-p (type-1 type-2 type-list-1 type-list-2)
  (:documentation #.+type-list-subtype-p+))

(5am:def-suite type-list-subtype-p :in lambda-list)

;; TYPE-LIST-CAUSES-AMBIGUOUS-CALL-P ===========================================

(defun type-list-causes-ambiguous-call-p (type-list-1 type-list-2)
  #.+type-list-causes-ambiguous-call-p+
  (declare (type type-list type-list-1 type-list-2))
  (let ((*lambda-list-typed-p* nil))
    (handler-case
        (%type-list-causes-ambiguous-call-p (potential-type-of-lambda-list type-list-1)
                                            (potential-type-of-lambda-list type-list-2)
                                            type-list-1
                                            type-list-2)
      (illegal-parametric-type ()
        t))))

(defgeneric %type-list-causes-ambiguous-call-p
    (type-1 type-2 type-list-1 type-list-2)
  (:documentation #.+type-list-causes-ambiguous-call-p+))

(5am:def-suite type-list-causes-ambiguous-call-p :in lambda-list)

