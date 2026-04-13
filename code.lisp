; structure verifiers
(defun pathp (p)
        (if (endp p)
            t
        (and (symbolp (car p))
            (pathp (cdr p)))))
    (defun filep (x)
        (and (consp x)
            (equal (car x) :file)
            (consp (cdr x))
            (null (cddr x))))

    (mutual-recursion
    
        (defun dirp (x)
            (declare (xargs :measure (acl2-count x)))
            (and (consp x)
                (equal (car x) :dir)
                (consp (cdr x))
                (null (cddr x))
                (entriesp (cadr x))))

            (defun entryp (x)
                (declare (xargs :measure (acl2-count x)))
                (and (consp x)
                    (symbolp (car x))
                    (or (filep (cdr x))
                    (dirp (cdr x)))))

            (defun entriesp (entries)
                (declare (xargs :measure (acl2-count entries)))
                (if (endp entries)
                    t
                (and (entryp (car entries))
                    (entriesp (cdr entries))))))

    (defun nodep (x)
            (or (filep x)
                (dirp x)))  
    ; functions 

    (defun lookup-name (name entries)
        (if (endp entries)
            nil
            (if (equal name (caar entries))
                (cdar entries)
            (lookup-name name (cdr entries)))))

    (defun put-name (name node entries)
        (if (endp entries)
            (list (cons name node))
        (if (equal name (caar entries))
            (cons (cons name node)
              (cdr entries))
            (cons (car entries)
                (put-name name node (cdr entries))))))
    (defun lookup-path (p fs)
        (if (endp p)
            fs
            (if (dirp fs)
                (lookup-path (cdr p)
                     (lookup-name (car p) (cadr fs))) nil)))
    (defun insert-path (p newnode fs)
        (if (or (endp p) (not (dirp fs)))
            fs
            (if (endp (cdr p))
                (list :dir
                    (put-name (car p) newnode (cadr fs)))
                (let ((child (lookup-name (car p) (cadr fs))))
                    (if (dirp child)
                    (list :dir
                        (put-name (car p)(insert-path (cdr p) newnode child)
                        (cadr fs))) fs)))))
    (defun valid-fs (fs)
        (dirp fs))

    ; theorem to be proved
    (DEFTHM FINAL-PROJECT
        (IMPLIES (AND (VALID-FS FS) (PATHP P) (NODEP V))
           (VALID-FS (INSERT-PATH P V FS)))
        :INSTRUCTIONS (:PROVE))            