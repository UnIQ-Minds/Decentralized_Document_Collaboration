import List "mo:base/List";
import Time "mo:base/Time";
import Principal "mo:base/Principal";
import Int "mo:base/Int";
import Text "mo:base/Text";
import Nat "mo:base/Nat";

actor Docollab {
  // Data Types
  type Document = {
    id: Nat;               // Unique ID of the document
    title: Text;           // Title of the document
    content: Text;         // Content of the document
    owner: Principal;      // Owner of the document
    createdAt: Time.Time;  // Creation timestamp
    updatedAt: Time.Time;  // Last update timestamp
  };

  type collaborator = {
    docId: Nat;            // Associated document ID
    user: Principal;       // Collaborator's Principal ID
    edit: Bool;            // Permission to edit
  };

  type User = {
    id: Principal;         // Unique user ID (Principal)
    name: Text;            // User's name
    email: Text;           // User's email
    createdAt: Time.Time;  // Registration timestamp
  };

  type Version = {
    content: Text;         // Version content
    timestamp: Time.Time;  // Timestamp of the version
    docId: Nat;            // Associated document ID
  };
  type Lock ={
    docId: Nat;
    user: Principal;
  };

  // Stable Variables
  stable var documents: List.List<Document> = List.nil<Document>(); // All documents
  stable var users: List.List<User> = List.nil<User>();             // Registered users
  stable var collaborators: List.List<collaborator> = List.nil<collaborator>(); // Collaborators
  stable var versions: List.List<Version> = List.nil<Version>();   // Document versions
  stable var documentLocks: List.List<Lock> = List.nil<Lock>(); // Locked documents

  // DOCUMENT MANAGEMENT
  public func createDocument(user: Principal, title: Text, content: Text): async Text {
    let newId = List.size(documents) + 1;
    let timestamp = Time.now();
    let newDocument = {
      id = newId;
      title = title;
      content = content;
      owner = user;
      createdAt = timestamp;
      updatedAt = timestamp;
    };
    documents := List.push(newDocument, documents);
    saveVersion(newId, content, timestamp);
    return "New Document Created successfully";
  };

  public func getDocument(docId: Nat): async [Document] {
    return List.toArray(documents);
  };

  public func editDocument(docId: Nat, user: Principal, newContent: Text): async Text {
    let documentopt = List.find<Document>(documents, func(d: Document): Bool { d.id == docId });
    let collabopt = List.find<collaborator>(collaborators, func(c: collaborator): Bool { c.docId == docId });
    switch (documentopt, collabopt) {
      case (?doc, ?col) {
        if (doc.owner == user or (col.user == user and col.edit == true)) {
          let timestamp = Time.now();
          saveVersion(docId, newContent, timestamp);
          documents := List.map<Document, Document>(documents, func(m: Document): Document {
            if (m.id == docId) {
              { m with content = newContent; updatedAt = Time.now() }
            } else {
              m
            }
          });
          return "Document Updated successfully";
        } else {
          return "You don't have access to update this document";
        };
      };
      case (null, _) {
        return "Document does not exist!";
      };
      case (_, null) {
        return "You are not a collaborator on this document";
      };
    };
  };

  // VERSION CONTROL
  public func saveVersion(docId: Nat, content: Text, timestamp: Time.Time) {
    let newVersion: Version = {
      content = content;
      timestamp = timestamp;
      docId = docId;
    };
    versions := List.push<Version>(newVersion, versions);
  };

  public func getVersionHistory(docId: Nat): async [Version] {
    let versionAv = List.filter<Version>(versions, func(v: Version): Bool { v.docId == docId });
    return List.toArray(versionAv);
  };

  // USER MANAGEMENT
  public func registerUser(name: Text, email: Text): async Text {
    let newUserId: Principal = Principal.fromActor(Docollab);
    let userOpt = List.find<User>(users, func(u: User): Bool { u.id == newUserId });
    if (userOpt != null) {
      return "User already Registered!";
    };
    let newUser: User = {
      id = newUserId;
      name = name;
      email = email;
      createdAt = Time.now();
    };
    users := List.push<User>(newUser, users);
    return "New user Registered successfully";
  };

  public func getUser(userId: Principal): async [User] {
    let userAv = List.filter<User>(users, func(u: User): Bool { u.id == userId });
    return List.toArray(userAv);
  };

  // COLLABORATION AND SHARING
  public func addCollaborator(docId: Nat, collaborator: Principal, edit: Bool): async Text {
    let collabopt = List.find<collaborator>(collaborators, func(c: collaborator): Bool { c.user == collaborator });
    switch (collabopt) {
      case (?col) {
        return "Collaborator already exists";
      };
      case null {
        let newCollab: collaborator = {
          docId = docId;
          user = collaborator;
          edit = edit;
        };
        collaborators := List.push<collaborator>(newCollab, collaborators);
        return "Collaborator added successfully";
      };
    };
  };

  public func removeCollaborator(docId: Nat, collaborator: Principal): async Bool {
    let collaboratorExists = List.find<collaborator>(collaborators, func(c: collaborator): Bool {
      c.docId == docId and c.user == collaborator
    });
    switch (collaboratorExists) {
      case (?col) {
        collaborators := List.filter<collaborator>(collaborators, func(c: collaborator): Bool {
          not (c.docId == docId and c.user == collaborator)
        });
        return true;
      };
      case null {
        return false;
      };
    };
  };

  public func listCollaborators(docId: Nat): async [Principal] {
    let docCollaborators = List.filter<collaborator>(collaborators, func(c: collaborator): Bool { c.docId == docId });
    return List.toArray<Principal>(
      List.map<collaborator, Principal>(docCollaborators, func(c: collaborator): Principal { c.user })
    );
  };

  // REAL-TIME COLLABORATION
  public func lockDocument(docId: Nat, user: Principal): async Bool {
    let lockOpt = List.find<Lock>(documentLocks, func(lock: Lock): Bool { lock.docId == docId});
        if (lockOpt == true) {
      return false; // Document already locked
    };
    let newLock : Lock ={
      docId = docId;
      user = user;
    };
    documentLocks := List.push<Lock>(newLock, documentLocks);
    return true;
  };

  public func unlockDocument(docId: Nat, user: Principal): async Bool {
    documentLocks := List.filter<Lock>(documentLocks, func(lock: Lock): Bool {
      not (lock.docId == docId and lock.user == user)
    });
    return true;
  };

  public func mergeChanges(docId: Nat, user: Principal, changes: Text): async Bool {
    let documentOpt = List.find<Document>(documents, func(d: Document): Bool { d.id == docId });
    switch (documentOpt) {
      case (?doc) {
        if (doc.owner == user) {
          documents := List.map<Document, Document>(documents, func(d: Document): Document {
            if (d.id == docId) { { d with content = d.content # changes; updatedAt = Time.now() } } else { d }
          });
          return true;
        } else {
          return false; // No permission
        };
      };
      case null {
        return false; // Document not found
      };
    };
  };

  // ACCESS CONTROL
  public func checkPermissions(docId: Nat, user: Principal): async Bool {
    let documentOpt = List.find<Document>(documents, func(d: Document): Bool { d.id == docId });
    switch (documentOpt) {
      case (?doc) {
        if (doc.owner == user) { return true; };
      };
      case null {};
    };
    return false;
  };

  // STORAGE OPTIMIZATION
  public func compressVersions(docId: Nat): async Bool {
    let docVersions = List.filter<Version>(versions, func(v: Version): Bool { v.docId == docId });
    if (List.size(docVersions) <= 2) { return false; };
    versions := List.filter<Version>(versions, func(v: Version): Bool { v.docId != docId });
    return true;
  };
};