(in-package :adhoc-polymorphic-functions)

(define-condition lambda-list-has-changed (error)
  ((name :initarg :name
         :reader name
         :initform (error "NAME must be supplied!"))
   (new-lambda-list :initarg :new-lambda-list
                    :reader new-lambda-list
                    :initform (error "NEW LAMBDA LIST must be supplied!")))
  (:report (lambda (condition stream)
             (let* ((name (name condition))
                    (apf  (fdefinition name)))
               (format stream "New lambda list~%  ~S~%does not match the old lambda list~%  ~S
of the ADHOC-POLYMORPHIC-FUNCTION ~S with TYPE-LISTS:~%~{~^    ~S~%~}

Do you want to delete these POLYMORPHs to associate a new ones?"
                       (new-lambda-list condition)
                       (polymorphic-function-lambda-list apf)
                       name
                       (polymorphic-function-type-lists  apf))))))

(define-condition not-a-ahp (error)
  ((name :initarg :name
         :reader name
         :initform (error "NAME must be supplied!")))
  (:report (lambda (condition stream)
             (let* ((name (name condition)))
               (format stream "There already exists a FUNCTION ~S associated with NAME ~S.~%Do you want to delete the existing FUNCTION and associate a new~%POLYMORPHIC-FUNCTION with NAME ~S?"
                       (fdefinition name) name name)))))

(define-condition no-applicable-polymorph (error)
  ((arg-list :initarg :arg-list
             :initform (error "ARG-LIST not specified")
             :reader arg-list)
   (type-lists :initarg :type-lists
               :initform (error "TYPE-LISTS not specified")
               :reader type-lists))
  (:report (lambda (condition stream)
             (format stream
                     "~%No applicable POLYMORPH discovered for ARG-LIST ~S.~%Available TYPE-LISTs include:~%   ~{~S~^~%   ~}"
                     (arg-list condition)
                     (type-lists condition)))))

(defun note-null-env (form datum &rest arguments)
  (let ((*print-pretty* t))
    (pprint-logical-block (*error-output* nil :per-line-prefix "; ")
      (format *error-output* "~%Inlining~%~A~%in null environment leads to the following warnings~%~A"
              (with-output-to-string (*error-output*)
                (pprint-logical-block (*error-output* nil :per-line-prefix "  ")
                  (format *error-output* "~S" form)))
              (format nil "~&  ~A"
                      (handler-case (apply #'signal datum arguments)
                        (condition (c) c)))))))

(defun note-no-inline (form datum &rest arguments)
  (let ((*print-pretty* t))
    (pprint-logical-block (*error-output* nil :per-line-prefix "; " :suffix (string #\newline))
      (format *error-output* "~%Will not inline~%~A~%because~A"
              (with-output-to-string (*error-output*)
                (pprint-logical-block (*error-output* nil :per-line-prefix "  ")
                  (format *error-output* "~S" form)))
              (if (string= "" datum)
                  ""
                  (format nil "~&~A"
                          (handler-case (apply #'signal datum arguments)
                            (condition (c) c))))))))

(define-condition form-type-failure (condition)
  ((form :initarg :form
         :initform (error "FORM not specified")
         :reader form))
  (:report (lambda (condition stream)
             (format stream "~%Type of ~%  ~S~%could not be determined" (form condition)))))

(define-condition polymorph-has-no-inline-lambda-body (condition)
  ((name :initarg :name
         :initform (error "NAME not specified")
         :reader name)
   (type-list :initarg :type-list
              :initform (error "TYPE-LIST not specified")
              :reader type-list))
  (:report (lambda (condition stream)
             (format stream "~S with TYPE-LIST ~%  ~S~%has no stored INLINE-LAMBDA-BODY"
                     (name condition)
                     (type-list condition)))))
