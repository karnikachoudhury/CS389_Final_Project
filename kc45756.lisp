This filesystem model is directly inspired by the design principles of Unix-like systems. In Unix, 
files are not stored directly in directories; instead, directories act as mappings from names to inode 
numbers, while the actual file data and metadata are stored separately in an inode table. These principles
are reflected in the project through the implementation of parallel data structured illustrating file
system state. There is a directory tree structure that is a hierarchical organization of ACL2 conses, 
mirroring Unix directories by mapping names to inode numbers rather than storing the content directly.
There is also an inode table structure which reflects the inode table in Unix, storing information such
as file types, owner, and size. This separation allows for flexibility, such as allowing multiple names
to reference the same underlying inode (as hard links) and decouples names from storage. Overall, this 
design captures the key Unix idea that a filesystem is composed of two interacting layers—naming and 
storage—which together provide a powerful and flexible abstraction for managing files.

; Organization 
;
The system is divided into two tightly connected parallel data structures.

The first of these is the directory tree, the naming layer. The directory tree represents the hierarchical
structure, where a directory maps name to inode number. There are three different types of structures.
The first is directory entires that map names to file/directory nodes and are represented as the pair
(name . node), where name is the name of the file or directory and node is the file or directory node.
The second type structure is a directory node that is a list with three elements (:dir inode_number entries),
where :dir is an identifier for the directory node, inode_number is the inode number that is also present
in the inode table, and entries is a list of the elements in that directory. 

The second of these is the inode table, which has information about the file/directory metadata. The table
is a list of inodes. Each inode is a pair of inode number and metadata elements 
(inode_number . (:inode inode_number node_type owner size)), where the metadata elements include whether
the inode is for a file or directory (node_type), owner and size. 

The structural predicates define the shape and validity of the file system representation. These include 
functions such as pathp, nodep, dirp, and hfs-p, which ensure that paths, nodes, directories, and the 
overall file system are well-formed. Helper functions are used to manipulate and query the directory tree and inode table. These include 
functions such as lookup-name, put-name, and lookup-path-tree, which operate on the directory structure, 
as well as lookup-inode and put-inode, which operate on the inode table. The core operations are 
insert-path and delete-path. The insert-path function inserts a new file or directory into the tree and 
updates the inode table accordingly. The delete-path function removes a file or directory and also 
removes the associated inode entries. These operations rely on recursive helper functions such as 
insert-path-tree and delete-path-tree to traverse and modify the directory structure. 

; Specification Functions
;
This project defines a variety of key functions that specify the behavior of the file system.

The function lookup-path retrieves a node from the directory tree given a path. It recursively traverses
the directory structure, following the components of the path until it reaches the desired node. The 
function lookup-path-inode extends this by retrieving the metadata associated with the given path.
It first uses lookup-path to find the node, then uses the inode number stored inside the node to look up
the corresponding metadata in the inode table. 

The The insert-path function adds a new entry to the file system. It inserts a new node into the 
directory tree using insert-path-tree, and if the insertion modifies the tree, it updates the inode table
by adding a new inode entry. 

The delete-path function removes an entry from the file system. It deletes the corresponding node from 
the directory tree using delete-path-tree, and removes the associated inode entries from the inode table 
using helper functions that collect and remove inode numbers. s. However, if the path is invalid or the 
entry does not exist, the operation leaves the file system unchanged. Additionally, the model does not 
account for advanced features such as hard links or reference counting, and assumes a one-to-one 
correspondence between directory entries and inodes.

;
; Theorems
The correctness of these operations is captured through theorems that describe how the directory tree 
and inode table are updated. In particular, the theorems show that after insertion or deletion, the 
inode table is either unchanged or updated in a way that is consistent with the modification to the 
directory tree. The primary purpose of these theorems is to illustrate that, upon file system modifications,
both parallel data structures are updated. 

Since the tree functions are recursive in nature (traversing paths, modifying subtrees, rebuild structure)
ACL2 needs to induct on the structure of the tree or path. The proofs are formatted such that the base
case is an empty path while the inductive step is a step into a subtree. The theorems also had to have
a few structural predicates such as (hfs-p hfs) (pathp p) (nodep newnode) to restrict inputs to valid structures.
Moreover, because insert-path and delete-path have failure cases, these cases needed to be addressed
in the theorem. ACL2 has to be able to reason about the success and failure case, where success is that
a change occurs (i.e. file is inserted), and failure is that a change does not occur (ex. invalid path so
file is not inserted).

;
; Lessons Learned
There were two primary challenges with this project, the first of which was the dependency loop between
dirp, entryp, and entriesp. Because ACL2 requires independent functions to be defined before those 
that are dependent on them, this created a struggle of understanding which to define first. This was
resolved (with the assistance of Dr. Hunt), through the usage of ACL2's mutual recursion block which
allowed the three functions to be admitted. The second challenge was the structuring of the four 
theorems. Originally, I was trying to prove theorems that did not fully reflect the behavior of the 
success and failure cases in the file system. An example of this was my attempt to prove that the 
invocation of insert-path would always lead to a change in the file system structure, which is not
true if a given path is invalid. Thus, it took a bit to get the consequents of the implication 
theorems to a point where it could be proven with ACL2's theorem prover.

;
; Conclusion
An important outcome of this work was the refinement of specifications to accurately match the behavior 
of the implementation. Initial attempts at stronger correctness properties revealed edge cases where 
operations may not succeed, emphasizing the need for precise and realistic specifications in formal 
verification. Overall, this project illustrates how real-world system concepts can be modeled and reasoned
about in a formal setting. It highlights the usefulness of theorem proving in validating system behavior
and provides a foundation for extending the model to support more advanced features such as permissions,
links, or richer metadata.

; End of Report

; checks whether p is a valid path
(defun pathp (p)
  (if (endp p)
      t
    (and (symbolp (car p))
         (pathp (cdr p)))))

; only natural numbers are valid inode numbers
(defun inop (x)
  (natp x))

; checks whether x is file node (:file inode-number)
(defun filep (x)
  (and (consp x)
       (equal (car x) :file)
       (consp (cdr x))
       (null (cddr x))
       (inop (cadr x))))

(mutual-recursion

; checks whether x is a directory node (:dir inode-number entries)
 (defun dirp (x)
   (declare (xargs :measure (acl2-count x)))
   (and (consp x)
        (equal (car x) :dir)
        (consp (cdr x))
        (consp (cddr x))
        (null (cdddr x))
        (inop (cadr x))
        (entriesp (caddr x))))

; checks whether directory entry maps a symbol name to either a file node or directory node
 (defun entryp (x)
   (declare (xargs :measure (acl2-count x)))
   (and (consp x)
        (symbolp (car x))
        (or (filep (cdr x))
            (dirp (cdr x)))))

; recursively checks if all entries meet entryp properties
 (defun entriesp (entries)
   (declare (xargs :measure (acl2-count entries)))
   (if (endp entries)
       t
     (and (entryp (car entries))
          (entriesp (cdr entries))))))

; check whether node is file or directory node
(defun nodep (x)
  (or (filep x)
      (dirp x)))

; root of tree must be directory
(defun valid-tree (fs)
  (dirp fs))

;
; inode functions
;
; checks if inode has form (:inode inode-number type owner size)
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

; checks whether each inode table entry maps inode number to inode metadata
(defun inode-entry-p (x)
  (and (consp x)
       (inop (car x))
       (inodep (cdr x))))

; recursively checks if each inode meets inode-entry-p specifications
(defun inode-table-p (tbl)
  (if (endp tbl)
      t
    (and (inode-entry-p (car tbl))
         (inode-table-p (cdr tbl)))))

; checks whether full file system is valid (:fs directory-tree inode-table)
(defun hfs-p (x)
  (and (consp x)
       (equal (car x) :fs)
       (consp (cdr x))
       (consp (cddr x))
       (null (cdddr x))
       (valid-tree (cadr x))
       (inode-table-p (caddr x))))

; looks up name in directory entries, returning node associated with name or nil
(defun lookup-name (name entries)
  (if (endp entries)
      nil
    (if (equal name (caar entries))
        (cdar entries)
      (lookup-name name (cdr entries)))))

; adds or replaces a name-node pair in a directory's entries
(defun put-name (name node entries)
  (if (endp entries)
      (list (cons name node))
    (if (equal name (caar entries))
        (cons (cons name node)
              (cdr entries))
      (cons (car entries)
            (put-name name node (cdr entries))))))

; removes a name-node pair from a directory's entries
(defun remove-name (name entries)
  (if (endp entries)
      nil
    (if (equal name (caar entries))
        (cdr entries)
      (cons (car entries)
            (remove-name name (cdr entries))))))

; extracts the inode number from a file or directory node
(defun node-ino (node)
  (if (filep node)
      (cadr node)
    (if (dirp node)
        (cadr node)
      nil)))

; looks up an inode number in the inode table
(defun lookup-inode (ino tbl)
  (if (endp tbl)
      nil
    (if (equal ino (caar tbl))
        (cdar tbl)
      (lookup-inode ino (cdr tbl)))))

; adds or replaces an inode record in the inode table
(defun put-inode (ino inode tbl)
  (if (endp tbl)
      (list (cons ino inode))
    (if (equal ino (caar tbl))
        (cons (cons ino inode)
              (cdr tbl))
      (cons (car tbl)
            (put-inode ino inode (cdr tbl))))))

; removes an inode record from the inode table
(defun remove-inode (ino tbl)
  (if (endp tbl)
      nil
    (if (equal ino (caar tbl))
        (cdr tbl)
      (cons (car tbl)
            (remove-inode ino (cdr tbl))))))

; removes a list of inode numbers from the inode table
(defun remove-inode-list (inos tbl)
  (if (endp inos)
      tbl
    (remove-inode-list (cdr inos)
                       (remove-inode (car inos) tbl))))

; recursively follows a path through the directory tree
(defun lookup-path-tree (p fs)
  (if (endp p)
      fs
    (if (dirp fs)
        (lookup-path-tree (cdr p)
                          (lookup-name (car p) (caddr fs)))
      nil)))

; looks up a path in the full filesystem state
(defun lookup-path (p hfs)
  (if (hfs-p hfs)
      (lookup-path-tree p (cadr hfs))
    nil))

; looks up the inode metadata associated with a path
(defun lookup-path-inode (p hfs)
  (let ((node (lookup-path p hfs)))
    (if (and (hfs-p hfs)
             (nodep node))
        (lookup-inode (node-ino node)
                      (caddr hfs))
      nil)))

; inserts a new node into the directory tree
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

; deletes a node from the directory tree
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


; collects all inode numbers contained in a node
(mutual-recursion

 (defun collect-inos-node (node)
   (declare (xargs :measure (acl2-count node)))
   (if (filep node)
       (list (cadr node))
     (if (dirp node)
         (cons (cadr node)
               (collect-inos-entries (caddr node)))
       nil)))

; collects all inode numbers from a list of directory entries
 (defun collect-inos-entries (entries)
   (declare (xargs :measure (acl2-count entries)))
   (if (endp entries)
       nil
     (append (collect-inos-node (cdar entries))
             (collect-inos-entries (cdr entries))))))


; inserts a file or directory into the full filesystem
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

; deletes a file or directory from the full filesystem
(defun delete-path (p name hfs)
  (if (not (hfs-p hfs))
      hfs
    (let* ((victim (lookup-path-tree (append p (list name)) (cadr hfs)))
           (newtree (delete-path-tree p name (cadr hfs)))
           (inos-to-remove (collect-inos-node victim))
           (newtbl (remove-inode-list inos-to-remove (caddr hfs))))
      (list :fs newtree newtbl))))


; proves that insert path preserves structural invariant of inode table
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
; proves that delete path preserves structural invariant of inode table                                
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
; proves that insert path preserves structural invariant of directory tree                   
(defthm insert-path-preserves-or-updates-tree
  (implies (and (hfs-p hfs)
                (pathp p)
                (symbolp name)
                (nodep newnode))
           (or (equal (cadr (insert-path p name newnode newinode hfs))
                      (cadr hfs))
               (equal (cadr (insert-path p name newnode newinode hfs))
                      (insert-path-tree p name newnode (cadr hfs))))))
; proves that delete path preserves structural invariant of directory tree                  
(defthm delete-path-updates-tree
  (implies (and (hfs-p hfs)
                (pathp p)
                (symbolp name))
           (equal (cadr (delete-path p name hfs))
                  (delete-path-tree p name (cadr hfs)))))