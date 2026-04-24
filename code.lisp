;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; paths
(defun pathp (p)
  (if (endp p)
      t
    (and (symbolp (car p))
         (pathp (cdr p)))))

(defun inop (x)
  (natp x))
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; tree nodes
(defun filep (x)
  (and (consp x)
       (equal (car x) :file)
       (consp (cdr x))
       (null (cddr x))
       (inop (cadr x))))

(mutual-recursion

 (defun dirp (x)
   (declare (xargs :measure (acl2-count x)))
   (and (consp x)
        (equal (car x) :dir)
        (consp (cdr x))
        (consp (cddr x))
        (null (cdddr x))
        (inop (cadr x))
        (entriesp (caddr x))))

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

(defun valid-tree (fs)
  (dirp fs))
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; inodes
(defun inodep (x)
  (and (consp x)
       (equal (car x) :inode)
       (consp (cdr x))
       (consp (cddr x))
       (consp (cdddr x))
       (consp (cddddr x))
       (null (cdr (cddddr x)))
       (inop (cadr x))
       (or (equal (caddr x) :file)
           (equal (caddr x) :dir))
       (symbolp (cadddr x))
       (natp (car (cddddr x)))))

(defun inode-entry-p (x)
  (and (consp x)
       (inop (car x))
       (inodep (cdr x))))

(defun inode-table-p (tbl)
  (if (endp tbl)
      t
    (and (inode-entry-p (car tbl))
         (inode-table-p (cdr tbl)))))
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; whole file system !
(defun hfs-p (x)
  (and (consp x)
       (equal (car x) :fs)
       (consp (cdr x))
       (consp (cddr x))
       (null (cdddr x))
       (valid-tree (cadr x))
       (inode-table-p (caddr x))))
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; tree helpers
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

(defun remove-name (name entries)
  (if (endp entries)
      nil
    (if (equal name (caar entries))
        (cdr entries)
      (cons (car entries)
            (remove-name name (cdr entries))))))

(defun node-ino (node)
  (if (filep node)
      (cadr node)
    (if (dirp node)
        (cadr node)
      nil)))
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; inode table helpers
(defun lookup-inode (ino tbl)
  (if (endp tbl)
      nil
    (if (equal ino (caar tbl))
        (cdar tbl)
      (lookup-inode ino (cdr tbl)))))

(defun put-inode (ino inode tbl)
  (if (endp tbl)
      (list (cons ino inode))
    (if (equal ino (caar tbl))
        (cons (cons ino inode)
              (cdr tbl))
      (cons (car tbl)
            (put-inode ino inode (cdr tbl))))))

(defun remove-inode (ino tbl)
  (if (endp tbl)
      nil
    (if (equal ino (caar tbl))
        (cdr tbl)
      (cons (car tbl)
            (remove-inode ino (cdr tbl))))))

(defun remove-inode-list (inos tbl)
  (if (endp inos)
      tbl
    (remove-inode-list (cdr inos)
                       (remove-inode (car inos) tbl))))
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; lookup
(defun lookup-path-tree (p fs)
  (if (endp p)
      fs
    (if (dirp fs)
        (lookup-path-tree (cdr p)
                          (lookup-name (car p) (caddr fs)))
      nil)))

(defun lookup-path (p hfs)
  (if (hfs-p hfs)
      (lookup-path-tree p (cadr hfs))
    nil))

(defun lookup-path-inode (p hfs)
  (let ((node (lookup-path p hfs)))
    (if (and (hfs-p hfs)
             (nodep node))
        (lookup-inode (node-ino node)
                      (caddr hfs))
      nil)))
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; insert and delete path tree
(defun insert-path-tree (p name newnode fs)
  (if (not (dirp fs))
      fs
    (if (endp p)
        (list :dir
              (cadr fs)
              (put-name name newnode (caddr fs)))
      (let ((child (lookup-name (car p) (caddr fs))))
        (if (dirp child)
            (list :dir
                  (cadr fs)
                  (put-name (car p)
                            (insert-path-tree (cdr p) name newnode child)
                            (caddr fs)))
          fs)))))

(defun delete-path-tree (p name fs)
  (if (not (dirp fs))
      fs
    (if (endp p)
        (list :dir
              (cadr fs)
              (remove-name name (caddr fs)))
      (let ((child (lookup-name (car p) (caddr fs))))
        (if (dirp child)
            (list :dir
                  (cadr fs)
                  (put-name (car p)
                            (delete-path-tree (cdr p) name child)
                            (caddr fs)))
          fs)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; collect inode numbers in a subtree
(mutual-recursion

 (defun collect-inos-node (node)
   (declare (xargs :measure (acl2-count node)))
   (if (filep node)
       (list (cadr node))
     (if (dirp node)
         (cons (cadr node)
               (collect-inos-entries (caddr node)))
       nil)))

 (defun collect-inos-entries (entries)
   (declare (xargs :measure (acl2-count entries)))
   (if (endp entries)
       nil
     (append (collect-inos-node (cdar entries))
             (collect-inos-entries (cdr entries))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; insert and delete path
(defun insert-path (p name newnode newinode hfs)
  (if (not (hfs-p hfs))
      hfs
    (let ((newtree (insert-path-tree p name newnode (cadr hfs))))
      (if (equal newtree (cadr hfs))
          hfs
        (list :fs
              newtree
              (put-inode (node-ino newnode)
                         newinode
                         (caddr hfs)))))))

(defun delete-path (p name hfs)
  (if (not (hfs-p hfs))
      hfs
    (let* ((victim (lookup-path-tree (append p (list name)) (cadr hfs)))
           (newtree (delete-path-tree p name (cadr hfs)))
           (inos-to-remove (collect-inos-node victim))
           (newtbl (remove-inode-list inos-to-remove (caddr hfs))))
      (list :fs newtree newtbl))))

; theorems
(defthm insert-path-preserves-or-updates-inode-table
  (implies (and (hfs-p hfs)
                (pathp p)
                (symbolp name)
                (nodep newnode)
                (inodep newinode))
           (or (equal (caddr (insert-path p name newnode newinode hfs))
                      (caddr hfs))
               (equal (caddr (insert-path p name newnode newinode hfs))
                      (put-inode (node-ino newnode)
                                 newinode
                                 (caddr hfs))))))
(defthm delete-path-updates-inode-table
  (implies (and (hfs-p hfs)
                (pathp p)
                (symbolp name))
           (or (equal (caddr (delete-path p name hfs))
                      (caddr hfs))
               (equal (caddr (delete-path p name hfs))
                      (remove-inode-list
                       (collect-inos-node
                        (lookup-path-tree (append p (list name))
                                          (cadr hfs)))
                       (caddr hfs))))))
(defthm insert-path-preserves-or-updates-tree
  (implies (and (hfs-p hfs)
                (pathp p)
                (symbolp name)
                (nodep newnode))
           (or (equal (cadr (insert-path p name newnode newinode hfs))
                      (cadr hfs))
               (equal (cadr (insert-path p name newnode newinode hfs))
                      (insert-path-tree p name newnode (cadr hfs))))))
(defthm delete-path-updates-tree
  (implies (and (hfs-p hfs)
                (pathp p)
                (symbolp name))
           (equal (cadr (delete-path p name hfs))
                  (delete-path-tree p name (cadr hfs)))))



