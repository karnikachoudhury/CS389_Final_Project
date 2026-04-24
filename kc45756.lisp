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
