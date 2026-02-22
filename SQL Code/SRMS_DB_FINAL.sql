/* =========================================================
   SRMS_DB — Term Project (FINAL) — Part 1
   Database + Core Tables (Schema Only)

   Roles:
     Admin, Instructor, TA, Student, Guestrole

   MLS Clearance Levels:
     1 = Unclassified (Public)
     2 = Confidential (Student data)
     3 = Secret (Grades / Attendance)
     4 = Instructor / Auth
     5 = Admin
   ========================================================= */

---------------------------------------------------------
-- 1.0 DROP + CREATE DATABASE
---------------------------------------------------------
IF DB_ID('SRMS_DB') IS NOT NULL
BEGIN
    ALTER DATABASE SRMS_DB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE SRMS_DB;
END
GO

CREATE DATABASE SRMS_DB;
GO
USE SRMS_DB;
GO

---------------------------------------------------------
-- 1.1 DROP TABLES (Safe Order)
---------------------------------------------------------
DROP TABLE IF EXISTS dbo.ATTENDANCE;
DROP TABLE IF EXISTS dbo.GRADES;
DROP TABLE IF EXISTS dbo.COURSE_STUDENT;
DROP TABLE IF EXISTS dbo.TA_COURSE;
DROP TABLE IF EXISTS dbo.INSTRUCTOR_COURSE;
DROP TABLE IF EXISTS dbo.ROLE_REQUESTS;
DROP TABLE IF EXISTS dbo.USERS;
DROP TABLE IF EXISTS dbo.TA;
DROP TABLE IF EXISTS dbo.INSTRUCTOR;
DROP TABLE IF EXISTS dbo.STUDENT;
DROP TABLE IF EXISTS dbo.COURSE;
DROP TABLE IF EXISTS dbo.LOGS;
GO

---------------------------------------------------------
-- 1.2 CORE TABLES
---------------------------------------------------------

/* STUDENT — Confidential */
CREATE TABLE dbo.STUDENT (
    StudentID       INT IDENTITY(100,1) PRIMARY KEY,
    FullName        NVARCHAR(100) NOT NULL,
    Email           NVARCHAR(100) NOT NULL,
    DOB             DATE NOT NULL,
    Department      NVARCHAR(50) NOT NULL,

    ClearanceLevel  INT NOT NULL DEFAULT 2,
    EncryptedPhone  VARBINARY(MAX) NULL,

    IsDeleted       BIT NOT NULL DEFAULT 0,

    CONSTRAINT CK_STUDENT_Clearance CHECK (ClearanceLevel BETWEEN 1 AND 5),
    CONSTRAINT UQ_STUDENT_Email UNIQUE (Email)
);
GO

/* INSTRUCTOR — Level 4 */
CREATE TABLE dbo.INSTRUCTOR (
    InstructorID    INT IDENTITY(200,1) PRIMARY KEY,
    FullName        NVARCHAR(100) NOT NULL,
    Email           NVARCHAR(100) NOT NULL,

    ClearanceLevel  INT NOT NULL DEFAULT 4,
    IsDeleted       BIT NOT NULL DEFAULT 0,

    CONSTRAINT CK_INSTRUCTOR_Clearance CHECK (ClearanceLevel BETWEEN 1 AND 5),
    CONSTRAINT UQ_INSTRUCTOR_Email UNIQUE (Email)
);
GO

/* TA — Level 3 */
CREATE TABLE dbo.TA (
    TAID            INT IDENTITY(3000,1) PRIMARY KEY,
    FullName        NVARCHAR(100) NOT NULL,
    Email           NVARCHAR(100) NOT NULL,

    ClearanceLevel  INT NOT NULL DEFAULT 3,
    IsDeleted       BIT NOT NULL DEFAULT 0,

    CONSTRAINT CK_TA_Clearance CHECK (ClearanceLevel BETWEEN 1 AND 5),
    CONSTRAINT UQ_TA_Email UNIQUE (Email)
);
GO

/* COURSE — Unclassified */
CREATE TABLE dbo.COURSE (
    CourseID        INT IDENTITY(300,1) PRIMARY KEY,
    CourseName      NVARCHAR(100) NOT NULL,
    Description     NVARCHAR(MAX) NULL,
    PublicInfo      NVARCHAR(MAX) NULL,

    ClearanceLevel  INT NOT NULL DEFAULT 1,
    IsDeleted       BIT NOT NULL DEFAULT 0,

    CONSTRAINT CK_COURSE_Clearance CHECK (ClearanceLevel BETWEEN 1 AND 5),
    CONSTRAINT UQ_COURSE_Name UNIQUE (CourseName)
);
GO

/* USERS — Authentication + RBAC + MLS */
CREATE TABLE dbo.USERS (
    Username          NVARCHAR(50) PRIMARY KEY,
    Password          VARBINARY(MAX) NOT NULL,
    Role              NVARCHAR(20) NOT NULL,
    ClearanceLevel    INT NOT NULL,

    StudentID         INT NULL,
    InstructorID      INT NULL,
    TAID              INT NULL,

    EncryptedUsername VARBINARY(MAX) NULL,
    IsDeleted         BIT NOT NULL DEFAULT 0,

    CONSTRAINT CK_USERS_Clearance CHECK (ClearanceLevel BETWEEN 1 AND 5),
    CONSTRAINT CK_USERS_Role CHECK (Role IN ('Admin','Instructor','TA','Student','Guestrole')),

    CONSTRAINT FK_USERS_STUDENT    FOREIGN KEY (StudentID)    REFERENCES dbo.STUDENT(StudentID),
    CONSTRAINT FK_USERS_INSTRUCTOR FOREIGN KEY (InstructorID) REFERENCES dbo.INSTRUCTOR(InstructorID),
    CONSTRAINT FK_USERS_TA         FOREIGN KEY (TAID)         REFERENCES dbo.TA(TAID),

    CONSTRAINT CK_USERS_ROLE_LINK CHECK (
        (Role IN ('Admin','Guestrole') AND StudentID IS NULL AND InstructorID IS NULL AND TAID IS NULL)
        OR (Role = 'Student'    AND StudentID IS NOT NULL)
        OR (Role = 'Instructor' AND InstructorID IS NOT NULL)
        OR (Role = 'TA'         AND TAID IS NOT NULL)
    )
);
GO




/* GRADES — Secret */
CREATE TABLE dbo.GRADES (
    GradeID             INT IDENTITY(400,1) PRIMARY KEY,
    StudentID           INT NOT NULL,
    CourseID            INT NOT NULL,
    DateEntered         DATETIME NOT NULL DEFAULT GETDATE(),

    EncryptedGradeValue VARBINARY(MAX) NOT NULL,
    IsDeleted           BIT NOT NULL DEFAULT 0,

    CONSTRAINT FK_GRADES_STUDENT FOREIGN KEY (StudentID) REFERENCES dbo.STUDENT(StudentID),
    CONSTRAINT FK_GRADES_COURSE  FOREIGN KEY (CourseID)  REFERENCES dbo.COURSE(CourseID),
    CONSTRAINT UQ_GRADES UNIQUE (StudentID, CourseID)
);
GO

/* ATTENDANCE — Secret */
CREATE TABLE dbo.ATTENDANCE (
    AttendanceID   INT IDENTITY(500,1) PRIMARY KEY,
    StudentID      INT NOT NULL,
    CourseID       INT NOT NULL,
    Status         BIT NOT NULL,
    DateRecorded DATE NOT NULL DEFAULT CAST(GETDATE() AS DATE),

    IsDeleted      BIT NOT NULL DEFAULT 0,

    CONSTRAINT FK_ATT_STUDENT FOREIGN KEY (StudentID) REFERENCES dbo.STUDENT(StudentID),
    CONSTRAINT FK_ATT_COURSE  FOREIGN KEY (CourseID)  REFERENCES dbo.COURSE(CourseID),
    CONSTRAINT UQ_ATT UNIQUE (StudentID, CourseID, DateRecorded)
);
GO

/* ROLE REQUESTS — Part B */
CREATE TABLE dbo.ROLE_REQUESTS (
    RequestID     INT IDENTITY(1,1) PRIMARY KEY,
    Username      NVARCHAR(50) NOT NULL,
    CurrentRole   NVARCHAR(20) NOT NULL,
    RequestedRole NVARCHAR(20) NOT NULL,
    Reason        NVARCHAR(300) NOT NULL,
    Comments      NVARCHAR(300) NULL,
    Status        NVARCHAR(20) NOT NULL DEFAULT 'Pending',
    DateSubmitted DATETIME NOT NULL DEFAULT GETDATE(),

    CONSTRAINT FK_ROLE_REQ_USER FOREIGN KEY (Username) REFERENCES dbo.USERS(Username),
    CONSTRAINT CK_ROLE_REQ_STATUS CHECK (Status IN ('Pending','Approved','Denied'))
);
GO

---------------------------------------------------------
-- 1.3 MAPPING TABLES
---------------------------------------------------------
CREATE TABLE dbo.INSTRUCTOR_COURSE (
    InstructorID INT NOT NULL,
    CourseID     INT NOT NULL,
    CONSTRAINT PK_INSTRUCTOR_COURSE PRIMARY KEY (InstructorID, CourseID),
    CONSTRAINT FK_IC_INSTRUCTOR FOREIGN KEY (InstructorID) REFERENCES dbo.INSTRUCTOR(InstructorID),
    CONSTRAINT FK_IC_COURSE     FOREIGN KEY (CourseID)     REFERENCES dbo.COURSE(CourseID)
);
GO

CREATE TABLE dbo.TA_COURSE (
    TAUsername NVARCHAR(50) NOT NULL,
    CourseID   INT NOT NULL,
    CONSTRAINT PK_TA_COURSE PRIMARY KEY (TAUsername, CourseID),
    CONSTRAINT FK_TC_USER   FOREIGN KEY (TAUsername) REFERENCES dbo.USERS(Username),
    CONSTRAINT FK_TC_COURSE FOREIGN KEY (CourseID)   REFERENCES dbo.COURSE(CourseID)
);
GO

CREATE TABLE dbo.COURSE_STUDENT (
    CourseID  INT NOT NULL,
    StudentID INT NOT NULL,
    CONSTRAINT PK_COURSE_STUDENT PRIMARY KEY (CourseID, StudentID),
    CONSTRAINT FK_CS_COURSE  FOREIGN KEY (CourseID)  REFERENCES dbo.COURSE(CourseID),
    CONSTRAINT FK_CS_STUDENT FOREIGN KEY (StudentID) REFERENCES dbo.STUDENT(StudentID)
);
GO

---------------------------------------------------------
-- 1.4 LOGS
---------------------------------------------------------
CREATE TABLE dbo.LOGS (
    LogID    INT IDENTITY(1,1) PRIMARY KEY,
    Username NVARCHAR(50) NULL,
    Action   NVARCHAR(200) NOT NULL,
    Details  NVARCHAR(4000) NULL,
    LogTime  DATETIME NOT NULL DEFAULT GETDATE()
);
GO

---------------------------------------------------------
-- 1.5 INDEXES
---------------------------------------------------------
CREATE INDEX IX_STUDENT_Email   ON dbo.STUDENT(Email);
CREATE INDEX IX_USERS_Role      ON dbo.USERS(Role);
CREATE INDEX IX_USERS_Clearance ON dbo.USERS(ClearanceLevel);
CREATE INDEX IX_GRADES_Student  ON dbo.GRADES(StudentID);
CREATE INDEX IX_ATT_Student     ON dbo.ATTENDANCE(StudentID);
GO

/* =========================
   END OF PART 1
   ========================= */







/* =========================================================
   SRMS_DB — Term Project (FINAL) — Part 2 [FINAL]
   Roles, RBAC & Security Infrastructure

   Depends on:
     - Part 1 (Database + Core Tables)

   Guarantees:
     - EXECUTE-ONLY access model
     - No direct SELECT/INSERT/UPDATE/DELETE on tables
     - Clear RBAC hierarchy via RBAC_RANK
     - Idempotent (safe re-run)
   ========================================================= */

---------------------------------------------------------
-- Part 2.1 — CREATE DATABASE ROLES (Idempotent)
---------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'Admin' AND type = 'R')
    CREATE ROLE [Admin];
GO

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'Instructor' AND type = 'R')
    CREATE ROLE [Instructor];
GO

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'TA' AND type = 'R')
    CREATE ROLE [TA];
GO

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'Student' AND type = 'R')
    CREATE ROLE [Student];
GO

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'Guestrole' AND type = 'R')
    CREATE ROLE [Guestrole];
GO

---------------------------------------------------------
-- Part 2.2 — DENY ALL DIRECT TABLE ACCESS
-- Defense-in-depth: even Admin uses stored procedures only
---------------------------------------------------------

-- Core tables
DENY SELECT, INSERT, UPDATE, DELETE ON dbo.STUDENT        TO [Admin], [Instructor], [TA], [Student], [Guestrole];
DENY SELECT, INSERT, UPDATE, DELETE ON dbo.INSTRUCTOR     TO [Admin], [Instructor], [TA], [Student], [Guestrole];
DENY SELECT, INSERT, UPDATE, DELETE ON dbo.TA             TO [Admin], [Instructor], [TA], [Student], [Guestrole];
DENY SELECT, INSERT, UPDATE, DELETE ON dbo.COURSE         TO [Admin], [Instructor], [TA], [Student], [Guestrole];
DENY SELECT, INSERT, UPDATE, DELETE ON dbo.USERS          TO [Admin], [Instructor], [TA], [Student], [Guestrole];
DENY SELECT, INSERT, UPDATE, DELETE ON dbo.GRADES         TO [Admin], [Instructor], [TA], [Student], [Guestrole];
DENY SELECT, INSERT, UPDATE, DELETE ON dbo.ATTENDANCE     TO [Admin], [Instructor], [TA], [Student], [Guestrole];
DENY SELECT, INSERT, UPDATE, DELETE ON dbo.ROLE_REQUESTS  TO [Admin], [Instructor], [TA], [Student], [Guestrole];

-- Mapping tables
DENY SELECT, INSERT, UPDATE, DELETE ON dbo.INSTRUCTOR_COURSE TO [Admin], [Instructor], [TA], [Student], [Guestrole];
DENY SELECT, INSERT, UPDATE, DELETE ON dbo.TA_COURSE         TO [Admin], [Instructor], [TA], [Student], [Guestrole];
DENY SELECT, INSERT, UPDATE, DELETE ON dbo.COURSE_STUDENT    TO [Admin], [Instructor], [TA], [Student], [Guestrole];

-- Logs
DENY SELECT, INSERT, UPDATE, DELETE ON dbo.LOGS           TO [Admin], [Instructor], [TA], [Student], [Guestrole];
GO

---------------------------------------------------------
-- Part 2.3 — GRANT EXECUTE ONLY
-- All operations go through Stored Procedures
---------------------------------------------------------
GRANT EXECUTE TO [Admin];
GRANT EXECUTE TO [Instructor];
GRANT EXECUTE TO [TA];
GRANT EXECUTE TO [Student];
GRANT EXECUTE TO [Guestrole];
GO

---------------------------------------------------------
-- Part 2.4 — RBAC_RANK TABLE (Role Hierarchy)
-- Used by sp_CheckAccess later
-- Idempotent: Create-if-not-exists + reset content
---------------------------------------------------------
IF OBJECT_ID('dbo.RBAC_RANK', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.RBAC_RANK (
        RoleName NVARCHAR(20) NOT NULL PRIMARY KEY,
        Rank     INT NOT NULL
    );
END
GO

-- Reset & seed (idempotent)
DELETE FROM dbo.RBAC_RANK;
GO

INSERT INTO dbo.RBAC_RANK (RoleName, Rank) VALUES
('Guestrole', 1),
('Student',   2),
('TA',        3),
('Instructor',4),
('Admin',     5);
GO

---------------------------------------------------------
-- (Optional Hardening) DENY direct table access to RBAC_RANK too
-- Keeps "no direct access" consistent
---------------------------------------------------------
DENY SELECT, INSERT, UPDATE, DELETE ON dbo.RBAC_RANK TO [Admin], [Instructor], [TA], [Student], [Guestrole];
GO

---------------------------------------------------------
-- Part 2.5 — SECURITY/PERFORMANCE INDEXES (Idempotent)
---------------------------------------------------------

-- USERS (RBAC / MLS lookups)
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_USERS_Role_RBAC' AND object_id = OBJECT_ID('dbo.USERS'))
    CREATE INDEX IX_USERS_Role_RBAC ON dbo.USERS(Role);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_USERS_Clearance_RBAC' AND object_id = OBJECT_ID('dbo.USERS'))
    CREATE INDEX IX_USERS_Clearance_RBAC ON dbo.USERS(ClearanceLevel);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_USERS_Role_Clearance' AND object_id = OBJECT_ID('dbo.USERS'))
    CREATE INDEX IX_USERS_Role_Clearance ON dbo.USERS(Role, ClearanceLevel);

-- ROLE_REQUESTS (Part B workflow)
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_ROLE_REQUESTS_Status_RBAC' AND object_id = OBJECT_ID('dbo.ROLE_REQUESTS'))
    CREATE INDEX IX_ROLE_REQUESTS_Status_RBAC ON dbo.ROLE_REQUESTS(Status);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_ROLE_REQUESTS_User_RBAC' AND object_id = OBJECT_ID('dbo.ROLE_REQUESTS'))
    CREATE INDEX IX_ROLE_REQUESTS_User_RBAC ON dbo.ROLE_REQUESTS(Username);

-- Mappings (authorization checks)
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_IC_Instructor' AND object_id = OBJECT_ID('dbo.INSTRUCTOR_COURSE'))
    CREATE INDEX IX_IC_Instructor ON dbo.INSTRUCTOR_COURSE(InstructorID);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_TC_TAUsername' AND object_id = OBJECT_ID('dbo.TA_COURSE'))
    CREATE INDEX IX_TC_TAUsername ON dbo.TA_COURSE(TAUsername);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_CS_Enrollment' AND object_id = OBJECT_ID('dbo.COURSE_STUDENT'))
    CREATE INDEX IX_CS_Enrollment ON dbo.COURSE_STUDENT(StudentID, CourseID);
GO

/* ===========================
   END OF PART 2 (FINAL)
   =========================== */












/* =========================================================
   SRMS_DB — Term Project (FINAL) — Part 3 (FINAL)
   Encryption + Core Security Procedures

   Depends on:
     - Part 1 (DB + Tables)
     - Part 2 (Roles + RBAC_RANK + EXECUTE-only model)

   Includes:
   - Master Key
   - Certificate
   - Symmetric Key (AES-256)
   - sp_Key_Open / sp_Key_Close
   - sp_LogAction
   - sp_CheckAccess (RBAC + MLS Bell–LaPadula)
     ✅ No Read Up
     ✅ No Write Down
   ========================================================= */

---------------------------------------------------------
-- Part 3.1 — MASTER KEY (Root of Encryption) [Idempotent]
---------------------------------------------------------
IF NOT EXISTS (
    SELECT 1 FROM sys.symmetric_keys
    WHERE name = '##MS_DatabaseMasterKey##'
)
BEGIN
    CREATE MASTER KEY
    ENCRYPTION BY PASSWORD = 'SRMS_MasterKey_StrongPassword_2025!';
END
GO

---------------------------------------------------------
-- Part 3.2 — CERTIFICATE (Protects Symmetric Key) [Idempotent]
---------------------------------------------------------
IF NOT EXISTS (
    SELECT 1 FROM sys.certificates
    WHERE name = 'SRMSCert'
)
BEGIN
    CREATE CERTIFICATE SRMSCert
    WITH SUBJECT = 'SRMS Encryption Certificate';
END
GO

---------------------------------------------------------
-- Part 3.3 — SYMMETRIC KEY (AES-256) [Idempotent]
---------------------------------------------------------
IF NOT EXISTS (
    SELECT 1 FROM sys.symmetric_keys
    WHERE name = 'SRMSSymmetricKey'
)
BEGIN
    CREATE SYMMETRIC KEY SRMSSymmetricKey
    WITH ALGORITHM = AES_256
    ENCRYPTION BY CERTIFICATE SRMSCert;
END
GO

---------------------------------------------------------
-- Part 3.4 — HELPER: OPEN SYMMETRIC KEY (Safe)
---------------------------------------------------------
IF OBJECT_ID('dbo.sp_Key_Open', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_Key_Open;
GO

CREATE PROCEDURE dbo.sp_Key_Open
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        OPEN SYMMETRIC KEY SRMSSymmetricKey
            DECRYPTION BY CERTIFICATE SRMSCert;
    END TRY
    BEGIN CATCH
        -- Ignore "already open" error; rethrow anything else
        IF ERROR_NUMBER() <> 15315
            THROW;
    END CATCH
END
GO

---------------------------------------------------------
-- Part 3.5 — HELPER: CLOSE SYMMETRIC KEY (Safe)
---------------------------------------------------------
IF OBJECT_ID('dbo.sp_Key_Close', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_Key_Close;
GO

CREATE PROCEDURE dbo.sp_Key_Close
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        CLOSE SYMMETRIC KEY SRMSSymmetricKey;
    END TRY
    BEGIN CATCH
        -- If key isn't open, CLOSE may error; ignore that case
        -- Re-throw anything unexpected
        IF ERROR_NUMBER() NOT IN (15313, 15315)
            THROW;
    END CATCH
END
GO

---------------------------------------------------------
-- Part 3.6 — CENTRAL LOGGING PROCEDURE
---------------------------------------------------------
IF OBJECT_ID('dbo.sp_LogAction', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_LogAction;
GO

CREATE PROCEDURE dbo.sp_LogAction
(
    @Username NVARCHAR(50),
    @Action   NVARCHAR(200),
    @Details  NVARCHAR(4000) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.LOGS (Username, Action, Details)
    VALUES (@Username, @Action, @Details);
END
GO

---------------------------------------------------------
-- Part 3.7 — CENTRAL ACCESS CHECK (RBAC + MLS) [FINAL]
-- Bell–LaPadula Enforcement:
--   ✅ No Read Up    (READ:  user clearance >= object clearance)
--   ✅ No Write Down (WRITE: user clearance <= object clearance)
--
-- RBAC:
--   - If @RequiredRole contains comma => Allow-list (exact roles)
--   - Else => Minimum-role (hierarchy rank via RBAC_RANK)
---------------------------------------------------------
IF OBJECT_ID('dbo.sp_CheckAccess', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_CheckAccess;
GO

CREATE PROCEDURE dbo.sp_CheckAccess
(
    @CurrentUsername   NVARCHAR(50),
    @RequiredRole      NVARCHAR(200),  -- 'Instructor' OR 'TA,Instructor' OR 'Instructor,Admin'
    @RequiredClearance INT,            -- object classification level (1..5)
    @Mode              NVARCHAR(10)    -- 'READ' / 'WRITE'
)
AS
BEGIN
    SET NOCOUNT ON;

    -----------------------------------------------------
    -- Normalize + validate inputs
    -----------------------------------------------------
    SET @CurrentUsername = LTRIM(RTRIM(@CurrentUsername));
    SET @RequiredRole    = LTRIM(RTRIM(@RequiredRole));
    SET @Mode            = UPPER(LTRIM(RTRIM(@Mode)));

    IF @CurrentUsername IS NULL OR @CurrentUsername = ''
    BEGIN
        RAISERROR('Access Denied: Missing username.', 16, 1);
        RETURN;
    END

    IF @RequiredRole IS NULL OR @RequiredRole = ''
    BEGIN
        RAISERROR('Access Denied: Missing required role.', 16, 1);
        RETURN;
    END

    IF @Mode NOT IN ('READ','WRITE')
    BEGIN
        RAISERROR('Invalid Mode. Use READ or WRITE.', 16, 1);
        RETURN;
    END

    IF @RequiredClearance IS NULL OR @RequiredClearance NOT BETWEEN 1 AND 5
    BEGIN
        RAISERROR('Invalid RequiredClearance. Use 1..5.', 16, 1);
        RETURN;
    END

    -----------------------------------------------------
    -- Load current user role + clearance
    -----------------------------------------------------
    DECLARE @UserRole NVARCHAR(20);
    DECLARE @UserClearance INT;

    SELECT
        @UserRole      = Role,
        @UserClearance = ClearanceLevel
    FROM dbo.USERS
    WHERE Username = @CurrentUsername
      AND IsDeleted = 0;

    IF @UserRole IS NULL
    BEGIN
        RAISERROR('Access Denied: Unknown user.', 16, 1);
        RETURN;
    END

    -----------------------------------------------------
    -- Admin bypass (RBAC + MLS) for management operations
    -- NOTE: Still no direct table access due to DENY policy (Part 2).
    -----------------------------------------------------
    IF @UserRole = 'Admin'
        RETURN;

    -----------------------------------------------------
    -- RBAC Check
    -----------------------------------------------------
    DECLARE @UserRank INT;
    SELECT @UserRank = Rank
    FROM dbo.RBAC_RANK
    WHERE RoleName = @UserRole;

    IF @UserRank IS NULL
    BEGIN
        RAISERROR('Access Denied: Role rank missing (RBAC_RANK).', 16, 1);
        RETURN;
    END

    -- Case A: Allow-list CSV (exact roles) e.g. 'TA,Instructor'
    IF CHARINDEX(',', @RequiredRole) > 0
    BEGIN
        IF NOT EXISTS (
            SELECT 1
            FROM string_split(@RequiredRole, ',') s
            WHERE LTRIM(RTRIM(s.value)) = @UserRole
        )
        BEGIN
            RAISERROR('Access Denied: Role not permitted.', 16, 1);
            RETURN;
        END
    END
    ELSE
    BEGIN
        -- Case B: Minimum-role (hierarchy) e.g. RequiredRole='Instructor'
        DECLARE @RequiredRank INT;

        SELECT @RequiredRank = Rank
        FROM dbo.RBAC_RANK
        WHERE RoleName = @RequiredRole;

        IF @RequiredRank IS NULL
        BEGIN
            RAISERROR('Access Denied: Required role rank missing (RBAC_RANK).', 16, 1);
            RETURN;
        END

        IF @UserRank < @RequiredRank
        BEGIN
            RAISERROR('Access Denied: Role not permitted.', 16, 1);
            RETURN;
        END
    END

    -----------------------------------------------------
    -- MLS: Bell–LaPadula
    -----------------------------------------------------
    -- ✅ No Read Up
    IF @Mode = 'READ' AND @UserClearance < @RequiredClearance
    BEGIN
        RAISERROR('MLS Violation: No Read Up.', 16, 1);
        RETURN;
    END

    -- ✅ No Write Down
    IF @Mode = 'WRITE' AND @UserClearance > @RequiredClearance
    BEGIN
        RAISERROR('MLS Violation: No Write Down.', 16, 1);
        RETURN;
    END
END
GO

/* ===========================
   END OF PART 3 (FINAL)
   =========================== */

















/* =========================================================
   SRMS_DB — Term Project (FINAL) — Part 4
   Views (By Role) + Inference Control Views (No Decrypt Here)

   Depends on:
     - Part 1 (Tables)
     - Part 2 (DENY direct table access)
     - Part 3 (encryption infra for later SPs)

   IMPORTANT:
     - Do NOT decrypt inside views.
       Decryption happens in Stored Procedures (Part 5) after sp_Key_Open.

   CRITICAL (Compatibility with Part 2):
     - Since Part 2 DENY SELECT on tables for all roles,
       users must be granted SELECT on VIEWS ONLY.
   ========================================================= */

---------------------------------------------------------
-- Part 4.1 — PUBLIC VIEWS (Guestrole)
---------------------------------------------------------
IF OBJECT_ID('dbo.vw_Course_Public', 'V') IS NOT NULL
    DROP VIEW dbo.vw_Course_Public;
GO

CREATE VIEW dbo.vw_Course_Public
AS
SELECT
    CourseID,
    CourseName,
    Description,
    PublicInfo
FROM dbo.COURSE
WHERE IsDeleted = 0
  AND ClearanceLevel = 1;
GO

---------------------------------------------------------
-- Part 4.2 — ADMIN VIEWS
-- Admin typically needs full visibility (including deleted),
-- but you can add filters if you prefer.
---------------------------------------------------------
IF OBJECT_ID('dbo.vw_Admin_Students', 'V') IS NOT NULL
    DROP VIEW dbo.vw_Admin_Students;
GO

CREATE VIEW dbo.vw_Admin_Students
AS
SELECT
    StudentID,
    FullName,
    Email,
    DOB,
    Department,
    ClearanceLevel,
    IsDeleted
FROM dbo.STUDENT;
GO

IF OBJECT_ID('dbo.vw_Admin_Instructors', 'V') IS NOT NULL
    DROP VIEW dbo.vw_Admin_Instructors;
GO

CREATE VIEW dbo.vw_Admin_Instructors
AS
SELECT
    InstructorID,
    FullName,
    Email,
    ClearanceLevel,
    IsDeleted
FROM dbo.INSTRUCTOR;
GO

IF OBJECT_ID('dbo.vw_Admin_TAs', 'V') IS NOT NULL
    DROP VIEW dbo.vw_Admin_TAs;
GO

CREATE VIEW dbo.vw_Admin_TAs
AS
SELECT
    TAID,
    FullName,
    Email,
    ClearanceLevel,
    IsDeleted
FROM dbo.TA;
GO

IF OBJECT_ID('dbo.vw_Admin_Courses', 'V') IS NOT NULL
    DROP VIEW dbo.vw_Admin_Courses;
GO

CREATE VIEW dbo.vw_Admin_Courses
AS
SELECT
    CourseID,
    CourseName,
    Description,
    PublicInfo,
    ClearanceLevel,
    IsDeleted
FROM dbo.COURSE;
GO

IF OBJECT_ID('dbo.vw_Admin_Users', 'V') IS NOT NULL
    DROP VIEW dbo.vw_Admin_Users;
GO

CREATE VIEW dbo.vw_Admin_Users
AS
SELECT
    Username,
    Role,
    ClearanceLevel,
    StudentID,
    InstructorID,
    TAID,
    IsDeleted
FROM dbo.USERS;
GO

IF OBJECT_ID('dbo.vw_Admin_RoleRequests', 'V') IS NOT NULL
    DROP VIEW dbo.vw_Admin_RoleRequests;
GO

CREATE VIEW dbo.vw_Admin_RoleRequests
AS
SELECT
    RequestID,
    Username,
    CurrentRole,
    RequestedRole,
    Reason,
    Comments,
    Status,
    DateSubmitted
FROM dbo.ROLE_REQUESTS;
GO

IF OBJECT_ID('dbo.vw_Admin_Logs', 'V') IS NOT NULL
    DROP VIEW dbo.vw_Admin_Logs;
GO

CREATE VIEW dbo.vw_Admin_Logs
AS
SELECT
    LogID,
    Username,
    Action,
    Details,
    LogTime
FROM dbo.LOGS;
GO

---------------------------------------------------------
-- Part 4.3 — INSTRUCTOR VIEWS (scoped by Username)
---------------------------------------------------------
IF OBJECT_ID('dbo.vw_Instructor_Courses', 'V') IS NOT NULL
    DROP VIEW dbo.vw_Instructor_Courses;
GO

CREATE VIEW dbo.vw_Instructor_Courses
AS
SELECT
    U.Username,
    IC.InstructorID,
    C.CourseID,
    C.CourseName,
    C.Description,
    C.PublicInfo,
    C.ClearanceLevel
FROM dbo.INSTRUCTOR_COURSE IC
JOIN dbo.USERS U
    ON U.InstructorID = IC.InstructorID
JOIN dbo.COURSE C
    ON C.CourseID = IC.CourseID
WHERE U.IsDeleted = 0
  AND C.IsDeleted = 0;
GO

IF OBJECT_ID('dbo.vw_Instructor_Students', 'V') IS NOT NULL
    DROP VIEW dbo.vw_Instructor_Students;
GO

CREATE VIEW dbo.vw_Instructor_Students
AS
SELECT DISTINCT
    U.Username,
    IC.InstructorID,
    CS.CourseID,
    S.StudentID,
    S.FullName,
    S.Email,
    S.Department
FROM dbo.INSTRUCTOR_COURSE IC
JOIN dbo.USERS U
    ON U.InstructorID = IC.InstructorID
JOIN dbo.COURSE_STUDENT CS
    ON CS.CourseID = IC.CourseID
JOIN dbo.STUDENT S
    ON S.StudentID = CS.StudentID
WHERE U.IsDeleted = 0
  AND S.IsDeleted = 0;
GO

IF OBJECT_ID('dbo.vw_Instructor_Grades', 'V') IS NOT NULL
    DROP VIEW dbo.vw_Instructor_Grades;
GO

CREATE VIEW dbo.vw_Instructor_Grades
AS
SELECT
    U.Username,
    IC.InstructorID,
    G.GradeID,
    G.StudentID,
    G.CourseID,
    G.DateEntered,
    G.EncryptedGradeValue
FROM dbo.INSTRUCTOR_COURSE IC
JOIN dbo.USERS U
    ON U.InstructorID = IC.InstructorID
JOIN dbo.GRADES G
    ON G.CourseID = IC.CourseID
WHERE U.IsDeleted = 0
  AND G.IsDeleted = 0;
GO

IF OBJECT_ID('dbo.vw_Instructor_Attendance', 'V') IS NOT NULL
    DROP VIEW dbo.vw_Instructor_Attendance;
GO

CREATE VIEW dbo.vw_Instructor_Attendance
AS
SELECT
    U.Username,
    IC.InstructorID,
    A.AttendanceID,
    A.StudentID,
    A.CourseID,
    A.Status,
    A.DateRecorded
FROM dbo.INSTRUCTOR_COURSE IC
JOIN dbo.USERS U
    ON U.InstructorID = IC.InstructorID
JOIN dbo.ATTENDANCE A
    ON A.CourseID = IC.CourseID
WHERE U.IsDeleted = 0
  AND A.IsDeleted = 0;
GO

---------------------------------------------------------
-- Part 4.4 — TA VIEWS (scoped by TAUsername)
---------------------------------------------------------
IF OBJECT_ID('dbo.vw_TA_Courses', 'V') IS NOT NULL
    DROP VIEW dbo.vw_TA_Courses;
GO

CREATE VIEW dbo.vw_TA_Courses
AS
SELECT
    TC.TAUsername,
    TC.CourseID,
    C.CourseName,
    C.Description,
    C.PublicInfo,
    C.ClearanceLevel
FROM dbo.TA_COURSE TC
JOIN dbo.COURSE C
    ON C.CourseID = TC.CourseID
JOIN dbo.USERS U
    ON U.Username = TC.TAUsername
WHERE U.IsDeleted = 0
  AND C.IsDeleted = 0;
GO

IF OBJECT_ID('dbo.vw_TA_Students', 'V') IS NOT NULL
    DROP VIEW dbo.vw_TA_Students;
GO

CREATE VIEW dbo.vw_TA_Students
AS
SELECT DISTINCT
    TC.TAUsername,
    CS.CourseID,
    S.StudentID,
    S.FullName,
    S.Email,
    S.Department
FROM dbo.TA_COURSE TC
JOIN dbo.USERS U
    ON U.Username = TC.TAUsername
JOIN dbo.COURSE_STUDENT CS
    ON CS.CourseID = TC.CourseID
JOIN dbo.STUDENT S
    ON S.StudentID = CS.StudentID
WHERE U.IsDeleted = 0
  AND S.IsDeleted = 0;
GO

IF OBJECT_ID('dbo.vw_TA_Attendance', 'V') IS NOT NULL
    DROP VIEW dbo.vw_TA_Attendance;
GO

CREATE VIEW dbo.vw_TA_Attendance
AS
SELECT
    TC.TAUsername,
    A.AttendanceID,
    A.StudentID,
    A.CourseID,
    A.Status,
    A.DateRecorded
FROM dbo.TA_COURSE TC
JOIN dbo.USERS U
    ON U.Username = TC.TAUsername
JOIN dbo.ATTENDANCE A
    ON A.CourseID = TC.CourseID
WHERE U.IsDeleted = 0
  AND A.IsDeleted = 0;
GO

---------------------------------------------------------
-- Part 4.5 — STUDENT VIEWS (self scoped by Username)
---------------------------------------------------------
IF OBJECT_ID('dbo.vw_Student_Self', 'V') IS NOT NULL
    DROP VIEW dbo.vw_Student_Self;
GO

CREATE VIEW dbo.vw_Student_Self
AS
SELECT
    U.Username,
    S.StudentID,
    S.FullName,
    S.Email,
    S.DOB,
    S.Department,
    S.EncryptedPhone
FROM dbo.USERS U
JOIN dbo.STUDENT S
    ON S.StudentID = U.StudentID
WHERE U.IsDeleted = 0
  AND S.IsDeleted = 0;
GO

IF OBJECT_ID('dbo.vw_Student_Courses', 'V') IS NOT NULL
    DROP VIEW dbo.vw_Student_Courses;
GO

CREATE VIEW dbo.vw_Student_Courses
AS
SELECT
    U.Username,
    CS.StudentID,
    C.CourseID,
    C.CourseName,
    C.Description,
    C.PublicInfo,
    C.ClearanceLevel
FROM dbo.USERS U
JOIN dbo.COURSE_STUDENT CS
    ON CS.StudentID = U.StudentID
JOIN dbo.COURSE C
    ON C.CourseID = CS.CourseID
WHERE U.IsDeleted = 0
  AND C.IsDeleted = 0;
GO

IF OBJECT_ID('dbo.vw_Student_Grades', 'V') IS NOT NULL
    DROP VIEW dbo.vw_Student_Grades;
GO

CREATE VIEW dbo.vw_Student_Grades
AS
SELECT
    U.Username,
    G.GradeID,
    G.StudentID,
    G.CourseID,
    G.DateEntered,
    G.EncryptedGradeValue
FROM dbo.USERS U
JOIN dbo.GRADES G
    ON G.StudentID = U.StudentID
WHERE U.IsDeleted = 0
  AND G.IsDeleted = 0;
GO

IF OBJECT_ID('dbo.vw_Student_Attendance', 'V') IS NOT NULL
    DROP VIEW dbo.vw_Student_Attendance;
GO

CREATE VIEW dbo.vw_Student_Attendance
AS
SELECT
    U.Username,
    A.AttendanceID,
    A.StudentID,
    A.CourseID,
    A.Status,
    A.DateRecorded
FROM dbo.USERS U
JOIN dbo.ATTENDANCE A
    ON A.StudentID = U.StudentID
WHERE U.IsDeleted = 0
  AND A.IsDeleted = 0;
GO

---------------------------------------------------------
-- Part 4.6 — INFERENCE CONTROL (Query Set Size ≥ 3)
-- IMPORTANT: No Decrypt in views.
-- We'll implement AvgGrade in SP in Part 5 (open key + decrypt + HAVING >=3).
---------------------------------------------------------
IF OBJECT_ID('dbo.vw_Grades_GroupSize_Safe', 'V') IS NOT NULL
    DROP VIEW dbo.vw_Grades_GroupSize_Safe;
GO

CREATE VIEW dbo.vw_Grades_GroupSize_Safe
AS
SELECT
    CourseID,
    COUNT(*) AS StudentCount
FROM dbo.GRADES
WHERE IsDeleted = 0
GROUP BY CourseID
HAVING COUNT(*) >= 3;
GO

IF OBJECT_ID('dbo.vw_Attendance_Aggregate_Safe', 'V') IS NOT NULL
    DROP VIEW dbo.vw_Attendance_Aggregate_Safe;
GO

CREATE VIEW dbo.vw_Attendance_Aggregate_Safe
AS
SELECT
    CourseID,
    COUNT(*) AS TotalRecords,
    SUM(CASE WHEN Status = 1 THEN 1 ELSE 0 END) AS PresentCount
FROM dbo.ATTENDANCE
WHERE IsDeleted = 0
GROUP BY CourseID
HAVING COUNT(*) >= 3;
GO

---------------------------------------------------------
-- Part 4.7 — GRANT SELECT ON VIEWS (Required with Part 2 DENY)
---------------------------------------------------------

-- Guestrole (public)
GRANT SELECT ON dbo.vw_Course_Public TO [Guestrole];

-- Admin (full admin views)
GRANT SELECT ON dbo.vw_Admin_Students      TO [Admin];
GRANT SELECT ON dbo.vw_Admin_Instructors   TO [Admin];
GRANT SELECT ON dbo.vw_Admin_TAs           TO [Admin];
GRANT SELECT ON dbo.vw_Admin_Courses       TO [Admin];
GRANT SELECT ON dbo.vw_Admin_Users         TO [Admin];
GRANT SELECT ON dbo.vw_Admin_RoleRequests  TO [Admin];
GRANT SELECT ON dbo.vw_Admin_Logs          TO [Admin];

-- Instructor
GRANT SELECT ON dbo.vw_Instructor_Courses     TO [Instructor];
GRANT SELECT ON dbo.vw_Instructor_Students    TO [Instructor];
GRANT SELECT ON dbo.vw_Instructor_Grades      TO [Instructor];
GRANT SELECT ON dbo.vw_Instructor_Attendance  TO [Instructor];

-- TA
GRANT SELECT ON dbo.vw_TA_Courses     TO [TA];
GRANT SELECT ON dbo.vw_TA_Students    TO [TA];
GRANT SELECT ON dbo.vw_TA_Attendance  TO [TA];

-- Student
GRANT SELECT ON dbo.vw_Student_Self        TO [Student];
GRANT SELECT ON dbo.vw_Student_Courses     TO [Student];
GRANT SELECT ON dbo.vw_Student_Grades      TO [Student];
GRANT SELECT ON dbo.vw_Student_Attendance  TO [Student];

-- Safe aggregate (optional, if you want to expose safely)
-- You can grant these to Instructor/TA/Admin depending on requirements:
GRANT SELECT ON dbo.vw_Grades_GroupSize_Safe      TO [Instructor];
GRANT SELECT ON dbo.vw_Attendance_Aggregate_Safe  TO [Instructor];

GRANT SELECT ON dbo.vw_Grades_GroupSize_Safe      TO [Admin];
GRANT SELECT ON dbo.vw_Attendance_Aggregate_Safe  TO [Admin];
GO

/* ===========================
   END OF PART 4 (FINAL)
   =========================== */


















/* =========================================================
   SRMS_DB — Term Project (FINAL)
   Part 5A — Shared Helpers + Student Procedures (FINAL)

   Depends on:
     - Part 1 (Schema + Tables)
     - Part 2 (EXECUTE-only + DENY table access)
     - Part 3 (Encryption infra + sp_Key_Open/sp_Key_Close + sp_LogAction + sp_CheckAccess)
     - Part 4 (Views without decrypt)

   Notes:
     - All reads/writes via Stored Procedures only.
     - Decrypt happens ONLY inside SPs after sp_Key_Open.
   ========================================================= */

/* =========================================================
   SHARED HELPERS (Common validations)
   ========================================================= */

---------------------------------------------------------
-- Helper: Ensure Course exists and is active
---------------------------------------------------------
IF OBJECT_ID('dbo.sp__EnsureCourseActive','P') IS NOT NULL
    DROP PROCEDURE dbo.sp__EnsureCourseActive;
GO
CREATE PROCEDURE dbo.sp__EnsureCourseActive
(
    @CourseID INT
)
AS
BEGIN
    SET NOCOUNT ON;

    IF @CourseID IS NULL
    BEGIN
        RAISERROR('CourseID is required.', 16, 1);
        RETURN;
    END

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.COURSE
        WHERE CourseID = @CourseID
          AND IsDeleted = 0
    )
    BEGIN
        RAISERROR('Course not found or deleted.', 16, 1);
        RETURN;
    END
END
GO

---------------------------------------------------------
-- Helper: Ensure Student exists and is active
---------------------------------------------------------
IF OBJECT_ID('dbo.sp__EnsureStudentActive','P') IS NOT NULL
    DROP PROCEDURE dbo.sp__EnsureStudentActive;
GO
CREATE PROCEDURE dbo.sp__EnsureStudentActive
(
    @StudentID INT
)
AS
BEGIN
    SET NOCOUNT ON;

    IF @StudentID IS NULL
    BEGIN
        RAISERROR('StudentID is required.', 16, 1);
        RETURN;
    END

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.STUDENT
        WHERE StudentID = @StudentID
          AND IsDeleted = 0
    )
    BEGIN
        RAISERROR('Student not found or deleted.', 16, 1);
        RETURN;
    END
END
GO

---------------------------------------------------------
-- Helper: Resolve current StudentID for a Student user (active linkage)
---------------------------------------------------------
IF OBJECT_ID('dbo.sp__GetCurrentStudentID','P') IS NOT NULL
    DROP PROCEDURE dbo.sp__GetCurrentStudentID;
GO
CREATE PROCEDURE dbo.sp__GetCurrentStudentID
(
    @CurrentUsername NVARCHAR(50),
    @StudentID INT OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;

    SET @CurrentUsername = LTRIM(RTRIM(@CurrentUsername));

    IF @CurrentUsername IS NULL OR @CurrentUsername = ''
    BEGIN
        RAISERROR('Missing username.', 16, 1);
        RETURN;
    END

    SELECT @StudentID = U.StudentID
    FROM dbo.USERS U
    WHERE U.Username = @CurrentUsername
      AND U.IsDeleted = 0
      AND U.Role = 'Student';

    IF @StudentID IS NULL
    BEGIN
        RAISERROR('Student linkage not found or user is not an active Student.', 16, 1);
        RETURN;
    END

    -- Ensure underlying student row is active
    IF NOT EXISTS (SELECT 1 FROM dbo.STUDENT WHERE StudentID = @StudentID AND IsDeleted = 0)
    BEGIN
        RAISERROR('Linked student record not found or deleted.', 16, 1);
        RETURN;
    END
END
GO


/* =========================================================
   SECTION A — STUDENT PROCEDURES
   ========================================================= */

---------------------------------------------------------
-- A1. Student: View Own Profile (Decrypt Phone)
---------------------------------------------------------
IF OBJECT_ID('dbo.sp_Student_ViewProfile','P') IS NOT NULL
    DROP PROCEDURE dbo.sp_Student_ViewProfile;
GO
CREATE PROCEDURE dbo.sp_Student_ViewProfile
(
    @CurrentUsername NVARCHAR(50)
)
AS
BEGIN
    SET NOCOUNT ON;

    EXEC dbo.sp_CheckAccess
        @CurrentUsername   = @CurrentUsername,
        @RequiredRole      = 'Student',
        @RequiredClearance = 2,
        @Mode              = 'READ';

    DECLARE @StudentID INT;
    EXEC dbo.sp__GetCurrentStudentID
        @CurrentUsername = @CurrentUsername,
        @StudentID = @StudentID OUTPUT;

    BEGIN TRY
        EXEC dbo.sp_Key_Open;

        SELECT
            S.StudentID,
            S.FullName,
            S.Email,
            S.DOB,
            S.Department,
            CONVERT(NVARCHAR(20), DecryptByKey(S.EncryptedPhone)) AS Phone
        FROM dbo.STUDENT S
        WHERE S.StudentID = @StudentID
          AND S.IsDeleted = 0;

        EXEC dbo.sp_Key_Close;

        DECLARE @Details NVARCHAR(4000);
        SET @Details = N'StudentID=' + CAST(@StudentID AS NVARCHAR(20));

        EXEC dbo.sp_LogAction
        @Username = @CurrentUsername,
        @Action   = 'STUDENT_VIEW_PROFILE',
        @Details  = @Details;

    END TRY
    BEGIN CATCH
    DECLARE @Err NVARCHAR(4000) = ERROR_MESSAGE();
    RAISERROR(@Err, 16, 1);
    RETURN;
    END CATCH
END
GO


---------------------------------------------------------
-- A2. Student: Update Own Phone (Encrypt)
---------------------------------------------------------
IF OBJECT_ID('dbo.sp_Student_UpdateOwnPhone','P') IS NOT NULL
    DROP PROCEDURE dbo.sp_Student_UpdateOwnPhone;
GO
CREATE PROCEDURE dbo.sp_Student_UpdateOwnPhone
(
    @CurrentUsername NVARCHAR(50),
    @NewPhone        NVARCHAR(20)
)
AS
BEGIN
    SET NOCOUNT ON;

    EXEC dbo.sp_CheckAccess
        @CurrentUsername   = @CurrentUsername,
        @RequiredRole      = 'Student',
        @RequiredClearance = 2,
        @Mode              = 'WRITE';

    SET @NewPhone = LTRIM(RTRIM(@NewPhone));
    IF @NewPhone IS NULL OR @NewPhone = ''
    BEGIN
        RAISERROR('NewPhone is required.', 16, 1);
        RETURN;
    END

    DECLARE @StudentID INT;
    EXEC dbo.sp__GetCurrentStudentID
        @CurrentUsername = @CurrentUsername,
        @StudentID = @StudentID OUTPUT;

    BEGIN TRY
        EXEC dbo.sp_Key_Open;

        UPDATE dbo.STUDENT
        SET EncryptedPhone = EncryptByKey(Key_GUID('SRMSSymmetricKey'), @NewPhone)
        WHERE StudentID = @StudentID
          AND IsDeleted = 0;

        EXEC dbo.sp_Key_Close;

		DECLARE @Details NVARCHAR(4000);
        SET @Details = N'StudentID=' + CAST(@StudentID AS NVARCHAR(20));
        EXEC dbo.sp_LogAction
            @Username = @CurrentUsername,
            @Action   = 'STUDENT_UPDATE_PHONE',
            @Details = @Details ;
    END TRY
    BEGIN CATCH
    DECLARE @Err NVARCHAR(4000) = ERROR_MESSAGE();
    RAISERROR(@Err, 16, 1);
    RETURN;
    END CATCH

END
GO


---------------------------------------------------------
-- A3. Student: View Own Courses
---------------------------------------------------------
IF OBJECT_ID('dbo.sp_Student_ViewCourses','P') IS NOT NULL
    DROP PROCEDURE dbo.sp_Student_ViewCourses;
GO
CREATE PROCEDURE dbo.sp_Student_ViewCourses
(
    @CurrentUsername NVARCHAR(50)
)
AS
BEGIN
    SET NOCOUNT ON;

    EXEC dbo.sp_CheckAccess
        @CurrentUsername   = @CurrentUsername,
        @RequiredRole      = 'Student',
        @RequiredClearance = 1,
        @Mode              = 'READ';

    DECLARE @StudentID INT;
    EXEC dbo.sp__GetCurrentStudentID
        @CurrentUsername = @CurrentUsername,
        @StudentID = @StudentID OUTPUT;

    SELECT
        C.CourseID,
        C.CourseName,
        C.Description,
        C.PublicInfo
    FROM dbo.COURSE_STUDENT CS
    JOIN dbo.COURSE C ON C.CourseID = CS.CourseID
    WHERE CS.StudentID = @StudentID
      AND C.IsDeleted = 0;

	  DECLARE @Details NVARCHAR(4000);
        SET @Details = N'StudentID=' + CAST(@StudentID AS NVARCHAR(20));
    EXEC dbo.sp_LogAction
        @Username = @CurrentUsername,
        @Action   = 'STUDENT_VIEW_COURSES',
        @Details  = @Details;
END
GO


---------------------------------------------------------
-- A4. Student: View Own Grades (Decrypt)
---------------------------------------------------------
IF OBJECT_ID('dbo.sp_Student_ViewGrades','P') IS NOT NULL
    DROP PROCEDURE dbo.sp_Student_ViewGrades;
GO

CREATE PROCEDURE dbo.sp_Student_ViewGrades
(
    @CurrentUsername NVARCHAR(50)
)
AS
BEGIN
    SET NOCOUNT ON;

    -------------------------------------------------
    -- Student only (Clearance = 2)
    -------------------------------------------------
    EXEC dbo.sp_CheckAccess
        @CurrentUsername   = @CurrentUsername,
        @RequiredRole      = 'Student',
        @RequiredClearance = 2,
        @Mode              = 'READ';

    -------------------------------------------------
    -- Get StudentID safely
    -------------------------------------------------
    DECLARE @StudentID INT;
    EXEC dbo.sp__GetCurrentStudentID
        @CurrentUsername = @CurrentUsername,
        @StudentID = @StudentID OUTPUT;

    IF @StudentID IS NULL
        RAISERROR('Student profile not found.',16,1);

    -------------------------------------------------
    -- View Grades (MLS SAFE)
    -------------------------------------------------
    BEGIN TRY
        EXEC dbo.sp_Key_Open;

        SELECT
            G.GradeID,
            G.CourseID,
            C.CourseName,
            TRY_CONVERT(
                DECIMAL(10,2),
                CONVERT(NVARCHAR(50), DecryptByKey(G.EncryptedGradeValue))
            ) AS Grade,
            G.DateEntered
        FROM dbo.GRADES G
        JOIN dbo.COURSE C
            ON C.CourseID = G.CourseID
        WHERE G.StudentID = @StudentID
          AND G.IsDeleted = 0
          AND C.IsDeleted = 0
          AND C.ClearanceLevel <= 2   -- ✅ MLS FILTER
          AND G.EncryptedGradeValue IS NOT NULL;

        EXEC dbo.sp_Key_Close;

        -------------------------------------------------
        -- Audit
        -------------------------------------------------
        DECLARE @Details NVARCHAR(4000);
        SET @Details = N'StudentID=' + CAST(@StudentID AS NVARCHAR(20));

        EXEC dbo.sp_LogAction
            @Username = @CurrentUsername,
            @Action   = 'STUDENT_VIEW_GRADES',
            @Details  = @Details;
    END TRY
    BEGIN CATCH
        DECLARE @Err NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@Err, 16, 1);
        RETURN;
    END CATCH
END
GO

---------------------------------------------------------
-- A5. Student: View Own Attendance (SAFE - MLS)
---------------------------------------------------------
IF OBJECT_ID('dbo.sp_Student_ViewAttendance','P') IS NOT NULL
    DROP PROCEDURE dbo.sp_Student_ViewAttendance;
GO

CREATE PROCEDURE dbo.sp_Student_ViewAttendance
(
    @CurrentUsername NVARCHAR(50)
)
AS
BEGIN
    SET NOCOUNT ON;

    -------------------------------------------------
    -- Student only (CLEARANCE = 2)
    -------------------------------------------------
    EXEC dbo.sp_CheckAccess
        @CurrentUsername   = @CurrentUsername,
        @RequiredRole      = 'Student',
        @RequiredClearance = 2,
        @Mode              = 'READ';

    -------------------------------------------------
    -- Get StudentID safely
    -------------------------------------------------
    DECLARE @StudentID INT;
    EXEC dbo.sp__GetCurrentStudentID
        @CurrentUsername = @CurrentUsername,
        @StudentID       = @StudentID OUTPUT;

    IF @StudentID IS NULL
        RAISERROR('Student profile not found.',16,1);

    -------------------------------------------------
    -- SAFE MLS QUERY
    -------------------------------------------------
    SELECT
        A.AttendanceID,
        C.CourseName,
        CASE A.Status
            WHEN 1 THEN 'Present'
            WHEN 0 THEN 'Absent'
            ELSE 'Unknown'
        END AS StatusText,
        A.DateRecorded
    FROM dbo.ATTENDANCE A
    JOIN dbo.COURSE C
        ON A.CourseID = C.CourseID
    WHERE A.StudentID = @StudentID
      AND A.IsDeleted = 0
      AND C.IsDeleted = 0
      AND C.ClearanceLevel <= 2;   -- 🔐 MLS FILTER

    -------------------------------------------------
    -- Audit log
    -------------------------------------------------
    DECLARE @Details NVARCHAR(4000);
    SET @Details = N'StudentID=' + CAST(@StudentID AS NVARCHAR(20));

    EXEC dbo.sp_LogAction
        @Username = @CurrentUsername,
        @Action   = 'STUDENT_VIEW_ATTENDANCE',
        @Details  = @Details;
END
GO




/* ===========================
   END OF PART 5A
   =========================== */












/* =========================================================
   SRMS_DB — Term Project (FINAL)
   Part 5B — Instructor Procedures

   Depends on:
     Part 1, Part 2, Part 3, Part 4
   Requires Part 5A helpers:
     - sp__EnsureCourseActive
     - sp__EnsureStudentActive
   ========================================================= */

USE SRMS_DB;
GO

/* =========================================================
   SHARED (Instructor Ownership Helper)
   ========================================================= */

---------------------------------------------------------
-- Helper: Ensure Instructor owns the course
---------------------------------------------------------
IF OBJECT_ID('dbo.sp__EnsureInstructorOwnsCourse','P') IS NOT NULL
    DROP PROCEDURE dbo.sp__EnsureInstructorOwnsCourse;
GO
CREATE PROCEDURE dbo.sp__EnsureInstructorOwnsCourse
(
    @CurrentUsername NVARCHAR(50),
    @CourseID INT
)
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.USERS U
        JOIN dbo.INSTRUCTOR_COURSE IC ON IC.InstructorID = U.InstructorID
        WHERE U.Username = @CurrentUsername
          AND U.IsDeleted = 0
          AND IC.CourseID = @CourseID
    )
    BEGIN
        RAISERROR('Access Denied: Course not assigned to this instructor.', 16, 1);
        RETURN;
    END
END
GO

/* =========================================================
   SECTION B — INSTRUCTOR PROCEDURES
   ========================================================= */

---------------------------------------------------------
-- B1. Instructor: View Courses
---------------------------------------------------------
IF OBJECT_ID('dbo.sp_Instructor_ViewCourses','P') IS NOT NULL
    DROP PROCEDURE dbo.sp_Instructor_ViewCourses;
GO
CREATE PROCEDURE dbo.sp_Instructor_ViewCourses
(
    @CurrentUsername NVARCHAR(50)
)
AS
BEGIN
    SET NOCOUNT ON;

    EXEC dbo.sp_CheckAccess
        @CurrentUsername   = @CurrentUsername,
        @RequiredRole      = 'Instructor',
        @RequiredClearance = 1,
        @Mode              = 'READ';

    SELECT
        C.CourseID,
        C.CourseName,
        C.Description,
        C.PublicInfo
    FROM dbo.USERS U
    JOIN dbo.INSTRUCTOR_COURSE IC ON IC.InstructorID = U.InstructorID
    JOIN dbo.COURSE C ON C.CourseID = IC.CourseID
    WHERE U.Username = @CurrentUsername
      AND U.IsDeleted = 0
      AND C.IsDeleted = 0;

    EXEC dbo.sp_LogAction
        @Username = @CurrentUsername,
        @Action   = 'INSTRUCTOR_VIEW_COURSES',
        @Details  = NULL;
END
GO

---------------------------------------------------------
-- B2. Instructor: View Students By Course (owned course)
---------------------------------------------------------
IF OBJECT_ID('dbo.sp_Instructor_ViewStudentsByCourse','P') IS NOT NULL
    DROP PROCEDURE dbo.sp_Instructor_ViewStudentsByCourse;
GO
CREATE PROCEDURE dbo.sp_Instructor_ViewStudentsByCourse
(
    @CurrentUsername NVARCHAR(50),
    @CourseID INT
)
AS
BEGIN
    SET NOCOUNT ON;

    EXEC dbo.sp_CheckAccess
        @CurrentUsername   = @CurrentUsername,
        @RequiredRole      = 'Instructor',
        @RequiredClearance = 2,
        @Mode              = 'READ';

    EXEC dbo.sp__EnsureCourseActive @CourseID;
    EXEC dbo.sp__EnsureInstructorOwnsCourse @CurrentUsername, @CourseID;

    SELECT
        S.StudentID,
        S.FullName,
        S.Email,
        S.Department
    FROM dbo.COURSE_STUDENT CS
    JOIN dbo.STUDENT S ON S.StudentID = CS.StudentID
    WHERE CS.CourseID = @CourseID
      AND S.IsDeleted = 0;

	  DECLARE @Details NVARCHAR(4000);
      SET @Details = N'CourseID=' + CAST(@CourseID AS NVARCHAR(20));

    EXEC dbo.sp_LogAction
        @Username = @CurrentUsername,
        @Action   = 'INSTRUCTOR_VIEW_STUDENTS_BY_COURSE',
        @Details  = @CourseID ;
END
GO

---------------------------------------------------------
-- B3. Instructor: Insert/Update Grade (Encrypt)  [Create/Update]
---------------------------------------------------------
IF OBJECT_ID('dbo.sp_Instructor_SaveGrade','P') IS NOT NULL
    DROP PROCEDURE dbo.sp_Instructor_SaveGrade;
GO
CREATE PROCEDURE dbo.sp_Instructor_SaveGrade
(
    @CurrentUsername NVARCHAR(50),
    @StudentID INT,
    @CourseID  INT,
    @Grade     DECIMAL(5,2)
)
AS
BEGIN
    SET NOCOUNT ON;

    -- WRITE at Instructor level to avoid MLS "No Write Down" false blocks
    EXEC dbo.sp_CheckAccess
        @CurrentUsername   = @CurrentUsername,
        @RequiredRole      = 'Instructor',
        @RequiredClearance = 4,
        @Mode              = 'WRITE';

    EXEC dbo.sp__EnsureCourseActive  @CourseID;
    EXEC dbo.sp__EnsureStudentActive @StudentID;
    EXEC dbo.sp__EnsureInstructorOwnsCourse @CurrentUsername, @CourseID;

    -- Enrollment validation
    IF NOT EXISTS (
        SELECT 1
        FROM dbo.COURSE_STUDENT
        WHERE CourseID = @CourseID
          AND StudentID = @StudentID
    )
    BEGIN
        RAISERROR('Student is not enrolled in this course.', 16, 1);
        RETURN;
    END

    BEGIN TRY
        EXEC dbo.sp_Key_Open;

        MERGE dbo.GRADES AS tgt
        USING (SELECT @StudentID AS StudentID, @CourseID AS CourseID) src
        ON (tgt.StudentID = src.StudentID AND tgt.CourseID = src.CourseID)
        WHEN MATCHED THEN
            UPDATE SET
                EncryptedGradeValue =
                    EncryptByKey(Key_GUID('SRMSSymmetricKey'), CAST(@Grade AS NVARCHAR(20))),
                DateEntered = GETDATE(),
                IsDeleted = 0
        WHEN NOT MATCHED THEN
            INSERT (StudentID, CourseID, EncryptedGradeValue)
            VALUES (
                @StudentID,
                @CourseID,
                EncryptByKey(Key_GUID('SRMSSymmetricKey'), CAST(@Grade AS NVARCHAR(20)))
            );

        EXEC dbo.sp_Key_Close;

        DECLARE @Details NVARCHAR(4000);

        SET @Details =
           N'StudentID=' + CAST(@StudentID AS NVARCHAR(20)) +
           N', CourseID=' + CAST(@CourseID AS NVARCHAR(20));

        EXEC dbo.sp_LogAction
        @Username = @CurrentUsername,
        @Action   = 'INSTRUCTOR_SAVE_GRADE',
        @Details  = @Details;

    END TRY
    BEGIN CATCH
        BEGIN TRY EXEC dbo.sp_Key_Close; END TRY BEGIN CATCH END CATCH;
        THROW;
    END CATCH
END
GO

---------------------------------------------------------
-- B4. Instructor: Get Grade (by student+course) [Read]
---------------------------------------------------------
IF OBJECT_ID('dbo.sp_Instructor_GetGrade','P') IS NOT NULL
    DROP PROCEDURE dbo.sp_Instructor_GetGrade;
GO
CREATE PROCEDURE dbo.sp_Instructor_GetGrade
(
    @CurrentUsername NVARCHAR(50),
    @StudentID INT,
    @CourseID  INT
)
AS
BEGIN
    SET NOCOUNT ON;

    EXEC dbo.sp_CheckAccess
        @CurrentUsername   = @CurrentUsername,
        @RequiredRole      = 'Instructor',
        @RequiredClearance = 3,
        @Mode              = 'READ';

    EXEC dbo.sp__EnsureCourseActive  @CourseID;
    EXEC dbo.sp__EnsureStudentActive @StudentID;
    EXEC dbo.sp__EnsureInstructorOwnsCourse @CurrentUsername, @CourseID;

    BEGIN TRY
        EXEC dbo.sp_Key_Open;

        SELECT
            G.GradeID,
            G.StudentID,
            G.CourseID,
            TRY_CONVERT(DECIMAL(10,2), CONVERT(NVARCHAR(50), DecryptByKey(G.EncryptedGradeValue))) AS Grade,
            G.DateEntered,
            G.IsDeleted
        FROM dbo.GRADES G
        WHERE G.StudentID = @StudentID
          AND G.CourseID  = @CourseID;

        EXEC dbo.sp_Key_Close;

        DECLARE @Details NVARCHAR(4000);

        SET @Details =
           N'StudentID=' + CAST(@StudentID AS NVARCHAR(20)) +
           N', CourseID=' + CAST(@CourseID AS NVARCHAR(20));

        EXEC dbo.sp_LogAction
        @Username = @CurrentUsername,
        @Action   = 'INSTRUCTOR_GET_GRADE',
        @Details  = @Details;
    END TRY
    BEGIN CATCH
        BEGIN TRY EXEC dbo.sp_Key_Close; END TRY BEGIN CATCH END CATCH;
        THROW;
    END CATCH
END
GO

---------------------------------------------------------
-- B5. Instructor: View Grades By Course (owned course) [Read]
---------------------------------------------------------
IF OBJECT_ID('dbo.sp_Instructor_ViewGradesByCourse','P') IS NOT NULL
    DROP PROCEDURE dbo.sp_Instructor_ViewGradesByCourse;
GO
CREATE PROCEDURE dbo.sp_Instructor_ViewGradesByCourse
(
    @CurrentUsername NVARCHAR(50),
    @CourseID INT
)
AS
BEGIN
    SET NOCOUNT ON;

    EXEC dbo.sp_CheckAccess
        @CurrentUsername   = @CurrentUsername,
        @RequiredRole      = 'Instructor',
        @RequiredClearance = 3,
        @Mode              = 'READ';

    EXEC dbo.sp__EnsureCourseActive @CourseID;
    EXEC dbo.sp__EnsureInstructorOwnsCourse @CurrentUsername, @CourseID;

    BEGIN TRY
        EXEC dbo.sp_Key_Open;

        SELECT
            G.GradeID,
            G.StudentID,
            S.FullName,
            TRY_CONVERT(DECIMAL(10,2), CONVERT(NVARCHAR(50), DecryptByKey(G.EncryptedGradeValue))) AS Grade,
            G.DateEntered
        FROM dbo.GRADES G
        JOIN dbo.STUDENT S ON S.StudentID = G.StudentID
        WHERE G.CourseID = @CourseID
          AND G.IsDeleted = 0
          AND S.IsDeleted = 0
          AND G.EncryptedGradeValue IS NOT NULL;

        EXEC dbo.sp_Key_Close;

		
        DECLARE @Details NVARCHAR(4000);

        SET @Details =
           N', CourseID=' + CAST(@CourseID AS NVARCHAR(20));


        EXEC dbo.sp_LogAction
            @Username = @CurrentUsername,
            @Action   = 'INSTRUCTOR_VIEW_GRADES_BY_COURSE',
            @Details  = @Details;
    END TRY
    BEGIN CATCH
        BEGIN TRY EXEC dbo.sp_Key_Close; END TRY BEGIN CATCH END CATCH;
        THROW;
    END CATCH
END
GO

---------------------------------------------------------
-- B6. Instructor: Delete Grade (soft delete) [Delete]
---------------------------------------------------------
IF OBJECT_ID('dbo.sp_Instructor_DeleteGrade','P') IS NOT NULL
    DROP PROCEDURE dbo.sp_Instructor_DeleteGrade;
GO
CREATE PROCEDURE dbo.sp_Instructor_DeleteGrade
(
    @CurrentUsername NVARCHAR(50),
    @StudentID INT,
    @CourseID  INT
)
AS
BEGIN
    SET NOCOUNT ON;

    -- WRITE at Instructor level to avoid MLS false blocks
    EXEC dbo.sp_CheckAccess
        @CurrentUsername   = @CurrentUsername,
        @RequiredRole      = 'Instructor',
        @RequiredClearance = 4,
        @Mode              = 'WRITE';

    EXEC dbo.sp__EnsureCourseActive  @CourseID;
    EXEC dbo.sp__EnsureStudentActive @StudentID;
    EXEC dbo.sp__EnsureInstructorOwnsCourse @CurrentUsername, @CourseID;

    UPDATE dbo.GRADES
    SET IsDeleted = 1
    WHERE StudentID = @StudentID
      AND CourseID  = @CourseID;

	DECLARE @Details NVARCHAR(4000);

        SET @Details =
           N'StudentID=' + CAST(@StudentID AS NVARCHAR(20)) +
           N', CourseID=' + CAST(@CourseID AS NVARCHAR(20));

    EXEC dbo.sp_LogAction
        @Username = @CurrentUsername,
        @Action   = 'INSTRUCTOR_DELETE_GRADE',
        @Details  = @Details;
END
GO

---------------------------------------------------------
-- B7. Instructor: View Attendance By Course (owned course) [Read]
---------------------------------------------------------
IF OBJECT_ID('dbo.sp_Instructor_ViewAttendanceByCourse','P') IS NOT NULL
    DROP PROCEDURE dbo.sp_Instructor_ViewAttendanceByCourse;
GO
CREATE PROCEDURE dbo.sp_Instructor_ViewAttendanceByCourse
(
    @CurrentUsername NVARCHAR(50),
    @CourseID INT
)
AS
BEGIN
    SET NOCOUNT ON;

    EXEC dbo.sp_CheckAccess
        @CurrentUsername   = @CurrentUsername,
        @RequiredRole      = 'Instructor',
        @RequiredClearance = 3,
        @Mode              = 'READ';

    EXEC dbo.sp__EnsureCourseActive @CourseID;
    EXEC dbo.sp__EnsureInstructorOwnsCourse @CurrentUsername, @CourseID;

    SELECT
        A.AttendanceID,
        A.StudentID,
        S.FullName,
        A.Status,
        A.DateRecorded
    FROM dbo.ATTENDANCE A
    JOIN dbo.STUDENT S ON S.StudentID = A.StudentID
    WHERE A.CourseID = @CourseID
      AND A.IsDeleted = 0
      AND S.IsDeleted = 0;

	DECLARE @Details NVARCHAR(4000);

        SET @Details =
           N', CourseID=' + CAST(@CourseID AS NVARCHAR(20));
    EXEC dbo.sp_LogAction
        @Username = @CurrentUsername,
        @Action   = 'INSTRUCTOR_VIEW_ATTENDANCE_BY_COURSE',
        @Details  = @Details;
END
GO


---------------------------------------------------------
-- B8. Instructor
---------------------------------------------------------
IF OBJECT_ID('dbo.sp_Instructor_ViewProfile','P') IS NOT NULL
    DROP PROCEDURE dbo.sp_Instructor_ViewProfile;
GO
CREATE PROCEDURE dbo.sp_Instructor_ViewProfile
(
    @CurrentUsername NVARCHAR(50)
)
AS
BEGIN
    SET NOCOUNT ON;

    EXEC dbo.sp_CheckAccess
        @CurrentUsername,'Instructor',4,'READ';

    SELECT
        I.InstructorID,
        I.FullName,
        I.Email,
        I.ClearanceLevel
    FROM dbo.USERS U
    JOIN dbo.INSTRUCTOR I
        ON I.InstructorID = U.InstructorID
    WHERE U.Username = @CurrentUsername
      AND U.IsDeleted = 0
      AND I.IsDeleted = 0;

    EXEC dbo.sp_LogAction
        @Username = @CurrentUsername,
        @Action   = 'INSTRUCTOR_VIEW_PROFILE',
        @Details  = NULL;
END
GO

---------------------------------------------------------
-- B9. Instructor
---------------------------------------------------------
IF OBJECT_ID('dbo.sp_Instructor_UpdateProfile','P') IS NOT NULL
    DROP PROCEDURE dbo.sp_Instructor_UpdateProfile;
GO
CREATE PROCEDURE dbo.sp_Instructor_UpdateProfile
(
    @CurrentUsername NVARCHAR(50),
    @FullName NVARCHAR(100) = NULL,
    @Email    NVARCHAR(100) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    EXEC dbo.sp_CheckAccess
        @CurrentUsername,'Instructor',4,'WRITE';

    UPDATE I
    SET
        FullName = COALESCE(NULLIF(LTRIM(RTRIM(@FullName)),''), FullName),
        Email    = COALESCE(NULLIF(LTRIM(RTRIM(@Email)),''), Email)
    FROM dbo.INSTRUCTOR I
    JOIN dbo.USERS U ON U.InstructorID = I.InstructorID
    WHERE U.Username = @CurrentUsername
      AND U.IsDeleted = 0
      AND I.IsDeleted = 0;

    EXEC dbo.sp_LogAction
        @Username = @CurrentUsername,
        @Action   = 'INSTRUCTOR_UPDATE_PROFILE',
        @Details  = NULL;
END
GO

---------------------------------------------------------
-- B10. Instructor
---------------------------------------------------------
IF OBJECT_ID('dbo.sp_Instructor_GetMyCourses','P') IS NOT NULL
    DROP PROCEDURE dbo.sp_Instructor_GetMyCourses;
GO
CREATE PROCEDURE dbo.sp_Instructor_GetMyCourses
(
    @CurrentUsername NVARCHAR(50)
)
AS
BEGIN
    SET NOCOUNT ON;

    EXEC dbo.sp_CheckAccess
        @CurrentUsername,'Instructor',1,'READ';

    SELECT
        C.CourseID,
        C.CourseName
    FROM dbo.USERS U
    JOIN dbo.INSTRUCTOR_COURSE IC ON IC.InstructorID = U.InstructorID
    JOIN dbo.COURSE C ON C.CourseID = IC.CourseID
    WHERE U.Username = @CurrentUsername
      AND U.IsDeleted = 0
      AND C.IsDeleted = 0
    ORDER BY C.CourseName;
END
GO

---------------------------------------------------------
-- B11. Instructor
---------------------------------------------------------
IF OBJECT_ID('dbo.sp_Instructor_GetMyStudentsByCourse_UI','P') IS NOT NULL
    DROP PROCEDURE dbo.sp_Instructor_GetMyStudentsByCourse_UI;
GO
CREATE PROCEDURE dbo.sp_Instructor_GetMyStudentsByCourse_UI
(
    @CurrentUsername NVARCHAR(50),
    @CourseID INT
)
AS
BEGIN
    SET NOCOUNT ON;

    EXEC dbo.sp_CheckAccess
        @CurrentUsername,'Instructor',2,'READ';

    EXEC dbo.sp__EnsureCourseActive @CourseID;
    EXEC dbo.sp__EnsureInstructorOwnsCourse @CurrentUsername, @CourseID;

    SELECT
        S.StudentID,
        S.FullName
    FROM dbo.COURSE_STUDENT CS
    JOIN dbo.STUDENT S ON S.StudentID = CS.StudentID
    WHERE CS.CourseID = @CourseID
      AND S.IsDeleted = 0
    ORDER BY S.FullName;
END
GO


---------------------------------------------------------
-- B12. Instructor
---------------------------------------------------------
IF OBJECT_ID('dbo.sp_Instructor_GetMyTAsByCourse','P') IS NOT NULL
    DROP PROCEDURE dbo.sp_Instructor_GetMyTAsByCourse;
GO
CREATE PROCEDURE dbo.sp_Instructor_GetMyTAsByCourse
(
    @CurrentUsername NVARCHAR(50),
    @CourseID INT
)
AS
BEGIN
    SET NOCOUNT ON;

    EXEC dbo.sp_CheckAccess
        @CurrentUsername,'Instructor',3,'READ';

    EXEC dbo.sp__EnsureCourseActive @CourseID;
    EXEC dbo.sp__EnsureInstructorOwnsCourse @CurrentUsername, @CourseID;

    SELECT
        TC.TAUsername
    FROM dbo.TA_COURSE TC
    WHERE TC.CourseID = @CourseID
    ORDER BY TC.TAUsername;
END
GO



/* ===========================
   END OF PART 5B
   =========================== */







   /* =========================================================
   SRMS_DB — Term Project (FINAL)
   Part 5C — TA Procedures (Complete, Final)

   Includes:
     - sp__EnsureTAOwnsCourse
     - sp_TA_ViewCourses
     - sp_TA_ViewStudentsByCourse
     - sp_TA_RecordAttendance   (MERGE per day, no duplicates)
     - sp_TA_UpdateAttendance   (must belong to TA course)
     - sp_TA_DeleteAttendance   (soft delete, must belong to TA course)

   Depends on:
     - Part 1 (tables)
     - Part 2 (DENY direct table access + EXECUTE-only)
     - Part 3 (sp_CheckAccess, sp_LogAction)
     - Part 5A shared helpers (sp__EnsureCourseActive, sp__EnsureStudentActive)
   ========================================================= */

USE SRMS_DB;
GO

/* =========================================================
   HELPER — Ensure TA owns course
   ========================================================= */
IF OBJECT_ID('dbo.sp__EnsureTAOwnsCourse','P') IS NOT NULL
    DROP PROCEDURE dbo.sp__EnsureTAOwnsCourse;
GO

CREATE PROCEDURE dbo.sp__EnsureTAOwnsCourse
(
    @CurrentUsername NVARCHAR(50),
    @CourseID        INT
)
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.TA_COURSE TC
        JOIN dbo.USERS U
          ON U.Username = TC.TAUsername
        WHERE TC.TAUsername = @CurrentUsername
          AND TC.CourseID   = @CourseID
          AND U.IsDeleted   = 0
    )
    BEGIN
        RAISERROR('Access Denied: Course not assigned to this TA.', 16, 1);
        RETURN;
    END
END
GO

/* =========================================================
   C1 — TA: View Courses
   ========================================================= */
IF OBJECT_ID('dbo.sp_TA_ViewCourses','P') IS NOT NULL
    DROP PROCEDURE dbo.sp_TA_ViewCourses;
GO

CREATE PROCEDURE dbo.sp_TA_ViewCourses
(
    @CurrentUsername NVARCHAR(50)
)
AS
BEGIN
    SET NOCOUNT ON;

    EXEC dbo.sp_CheckAccess
        @CurrentUsername   = @CurrentUsername,
        @RequiredRole      = 'TA',
        @RequiredClearance = 1,
        @Mode              = 'READ';

    SELECT
        C.CourseID,
        C.CourseName,
        C.Description,
        C.PublicInfo
    FROM dbo.TA_COURSE TC
    JOIN dbo.COURSE C
      ON C.CourseID = TC.CourseID
    JOIN dbo.USERS U
      ON U.Username = TC.TAUsername
    WHERE TC.TAUsername = @CurrentUsername
      AND U.IsDeleted = 0
      AND C.IsDeleted = 0;

    EXEC dbo.sp_LogAction
        @Username = @CurrentUsername,
        @Action   = 'TA_VIEW_COURSES',
        @Details  = NULL;
END
GO

/* =========================================================
   C2 — TA: View Students By Course (TA assigned)
   ========================================================= */
---------------------------------------------------------
-- C2 — TA: View Students By Course (OPTIONAL CourseID)
---------------------------------------------------------
IF OBJECT_ID('dbo.sp_TA_ViewStudentsByCourse','P') IS NOT NULL
    DROP PROCEDURE dbo.sp_TA_ViewStudentsByCourse;
GO

CREATE PROCEDURE dbo.sp_TA_ViewStudentsByCourse
(
    @CurrentUsername NVARCHAR(50),
    @CourseID        INT = NULL   -- ✅ OPTIONAL
)
AS
BEGIN
    SET NOCOUNT ON;

    EXEC dbo.sp_CheckAccess
        @CurrentUsername   = @CurrentUsername,
        @RequiredRole      = 'TA',
        @RequiredClearance = 2,
        @Mode              = 'READ';

    -- لو CourseID اتبعت → تأكيد إن الكورس للـ TA
    IF @CourseID IS NOT NULL
    BEGIN
        EXEC dbo.sp__EnsureCourseActive @CourseID;
        EXEC dbo.sp__EnsureTAOwnsCourse @CurrentUsername, @CourseID;
    END

    SELECT
        S.StudentID,
        S.FullName,
        S.Email,
        S.Department,
        C.CourseName
    FROM dbo.TA_COURSE TC
    JOIN dbo.COURSE_STUDENT CS
        ON CS.CourseID = TC.CourseID
    JOIN dbo.STUDENT S
        ON S.StudentID = CS.StudentID
    JOIN dbo.COURSE C
        ON C.CourseID = TC.CourseID
    WHERE TC.TAUsername = @CurrentUsername
      AND S.IsDeleted = 0
      AND C.IsDeleted = 0
      AND (
            @CourseID IS NULL
            OR TC.CourseID = @CourseID
          );

    DECLARE @Details NVARCHAR(4000);
    SET @Details =
        CASE
            WHEN @CourseID IS NULL
            THEN N'All courses'
            ELSE N'CourseID=' + CAST(@CourseID AS NVARCHAR(20))
        END;

    EXEC dbo.sp_LogAction
        @Username = @CurrentUsername,
        @Action   = 'TA_VIEW_STUDENTS',
        @Details  = @Details;
END
GO


/* =========================================================
   C3 — TA: Record / Update Attendance (MERGE per day)
   - No duplicates per student/course/day
   - Must be TA assigned + student enrolled
   ========================================================= */
IF OBJECT_ID('dbo.sp_TA_RecordAttendance','P') IS NOT NULL
    DROP PROCEDURE dbo.sp_TA_RecordAttendance;
GO

CREATE PROCEDURE dbo.sp_TA_RecordAttendance
(
    @CurrentUsername NVARCHAR(50),
    @StudentID       INT,
    @CourseID        INT,
    @Status          BIT
)
AS
BEGIN
    SET NOCOUNT ON;

    EXEC dbo.sp_CheckAccess
        @CurrentUsername   = @CurrentUsername,
        @RequiredRole      = 'TA',
        @RequiredClearance = 3,
        @Mode              = 'WRITE';

    EXEC dbo.sp__EnsureCourseActive @CourseID;
    EXEC dbo.sp__EnsureStudentActive @StudentID;
    EXEC dbo.sp__EnsureTAOwnsCourse @CurrentUsername, @CourseID;

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.COURSE_STUDENT
        WHERE CourseID = @CourseID
          AND StudentID = @StudentID
    )
    BEGIN
        RAISERROR('Student is not enrolled in this course.', 16, 1);
        RETURN;
    END

    BEGIN TRY
        MERGE dbo.ATTENDANCE AS tgt
        USING (
            SELECT
                @StudentID AS StudentID,
                @CourseID  AS CourseID,
                CAST(GETDATE() AS DATE) AS AttDate
        ) AS src
        ON (
            tgt.StudentID = src.StudentID
            AND tgt.CourseID = src.CourseID
            AND CAST(tgt.DateRecorded AS DATE) = src.AttDate
        )
        WHEN MATCHED THEN
            UPDATE SET
                Status       = @Status,
                DateRecorded = GETDATE(),
                IsDeleted    = 0
        WHEN NOT MATCHED THEN
            INSERT (StudentID, CourseID, Status)
            VALUES (@StudentID, @CourseID, @Status);


		DECLARE @Details NVARCHAR(4000);

        SET @Details =
           N'StudentID=' + CAST(@StudentID AS NVARCHAR(20)) +
           N', CourseID=' + CAST(@CourseID AS NVARCHAR(20));
        EXEC dbo.sp_LogAction
            @Username = @CurrentUsername,
            @Action   = 'TA_RECORD_ATTENDANCE',
            @Details  = @Details;
    END TRY
    BEGIN CATCH
        -- Keep same error message but bubble up properly
        THROW;
    END CATCH
END
GO

/* =========================================================
   C4 — TA: Update Attendance (by AttendanceID)
   - Record must exist and be active
   - Course must be assigned to TA
   ========================================================= */
IF OBJECT_ID('dbo.sp_TA_UpdateAttendance','P') IS NOT NULL
    DROP PROCEDURE dbo.sp_TA_UpdateAttendance;
GO

CREATE PROCEDURE dbo.sp_TA_UpdateAttendance
(
    @CurrentUsername NVARCHAR(50),
    @AttendanceID    INT,
    @Status          BIT
)
AS
BEGIN
    SET NOCOUNT ON;

    EXEC dbo.sp_CheckAccess
        @CurrentUsername   = @CurrentUsername,
        @RequiredRole      = 'TA',
        @RequiredClearance = 3,
        @Mode              = 'WRITE';

    DECLARE @CourseID INT;

    SELECT @CourseID = CourseID
    FROM dbo.ATTENDANCE
    WHERE AttendanceID = @AttendanceID
      AND IsDeleted = 0;

    IF @CourseID IS NULL
    BEGIN
        RAISERROR('Attendance record not found or deleted.', 16, 1);
        RETURN;
    END

    EXEC dbo.sp__EnsureCourseActive @CourseID;
    EXEC dbo.sp__EnsureTAOwnsCourse @CurrentUsername, @CourseID;

    UPDATE dbo.ATTENDANCE
    SET Status = @Status,
        DateRecorded = GETDATE()
    WHERE AttendanceID = @AttendanceID
      AND IsDeleted = 0;

	DECLARE @Details NVARCHAR(4000);

        SET @Details =
           N'AttendanceID=' + CAST(@AttendanceID AS NVARCHAR(20)) 
    EXEC dbo.sp_LogAction
        @Username = @CurrentUsername,
        @Action   = 'TA_UPDATE_ATTENDANCE',
        @Details  = @Details;
END
GO

/* =========================================================
   C5 — TA: Delete Attendance (Soft Delete)
   - Record must exist and be active
   - Course must be assigned to TA
   ========================================================= */
IF OBJECT_ID('dbo.sp_TA_DeleteAttendance','P') IS NOT NULL
    DROP PROCEDURE dbo.sp_TA_DeleteAttendance;
GO

CREATE PROCEDURE dbo.sp_TA_DeleteAttendance
(
    @CurrentUsername NVARCHAR(50),
    @AttendanceID    INT
)
AS
BEGIN
    SET NOCOUNT ON;

    EXEC dbo.sp_CheckAccess
        @CurrentUsername   = @CurrentUsername,
        @RequiredRole      = 'TA',
        @RequiredClearance = 3,
        @Mode              = 'WRITE';

    DECLARE @CourseID INT;

    SELECT @CourseID = CourseID
    FROM dbo.ATTENDANCE
    WHERE AttendanceID = @AttendanceID
      AND IsDeleted = 0;

    IF @CourseID IS NULL
    BEGIN
        RAISERROR('Attendance record not found or already deleted.', 16, 1);
        RETURN;
    END

    EXEC dbo.sp__EnsureCourseActive @CourseID;
    EXEC dbo.sp__EnsureTAOwnsCourse @CurrentUsername, @CourseID;

    UPDATE dbo.ATTENDANCE
    SET IsDeleted = 1
    WHERE AttendanceID = @AttendanceID
      AND IsDeleted = 0;


	DECLARE @Details NVARCHAR(4000);

        SET @Details =
           N'AttendanceID=' + CAST(@AttendanceID AS NVARCHAR(20)) 
    EXEC dbo.sp_LogAction
        @Username = @CurrentUsername,
        @Action   = 'TA_DELETE_ATTENDANCE',
        @Details  = @Details;
END
GO



---------------------------------------------------------
-- C6 — TA: View Attendance (All courses assigned to TA)
---------------------------------------------------------
IF OBJECT_ID('dbo.sp_TA_ViewAttendance','P') IS NOT NULL
    DROP PROCEDURE dbo.sp_TA_ViewAttendance;
GO

CREATE PROCEDURE dbo.sp_TA_ViewAttendance
(
    @CurrentUsername NVARCHAR(50)
)
AS
BEGIN
    SET NOCOUNT ON;

    -------------------------------------------------
    -- Security Check
    -------------------------------------------------
    EXEC dbo.sp_CheckAccess
        @CurrentUsername   = @CurrentUsername,
        @RequiredRole      = 'TA',
        @RequiredClearance = 2,
        @Mode              = 'READ';

    -------------------------------------------------
    -- Return attendance for TA courses only
    -------------------------------------------------
    SELECT
        A.AttendanceID,
        A.StudentID,
        C.CourseName,
        CASE 
            WHEN A.Status = 1 THEN 'Present'
            ELSE 'Absent'
        END AS StatusText,
        A.DateRecorded
    FROM dbo.ATTENDANCE A
    JOIN dbo.COURSE C
        ON C.CourseID = A.CourseID
    JOIN dbo.TA_COURSE TC
        ON TC.CourseID = A.CourseID
    WHERE TC.TAUsername = @CurrentUsername
      AND A.IsDeleted = 0
      AND C.IsDeleted = 0;

    -------------------------------------------------
    -- Audit log
    -------------------------------------------------
    EXEC dbo.sp_LogAction
        @Username = @CurrentUsername,
        @Action   = 'TA_VIEW_ATTENDANCE',
        @Details  = NULL;
END
GO


/* ===========================
   END OF PART 5C
   =========================== */












   /* =========================================================
   SRMS_DB — Term Project (FINAL)
   Part 5D + Part 5E
   Admin Procedures + Enrollment/Assignments (FINAL)

   Depends on:
     - Part 1 (Tables)
     - Part 2 (DENY direct access + EXECUTE-only model)
     - Part 3 (sp_CheckAccess + sp_LogAction)
     - Part 5A helpers: sp__EnsureCourseActive, sp__EnsureStudentActive
       (This script re-creates missing helpers safely if needed.)

   Notes:
     - For WRITE operations by Admin, we pass RequiredClearance = 5
       (to avoid MLS "No Write Down" violations).
   ========================================================= */

/* =========================================================
   EXTRA HELPERS (Admin needs)
   ========================================================= */

---------------------------------------------------------
-- Ensure Instructor exists and active
---------------------------------------------------------
IF OBJECT_ID('dbo.sp__EnsureInstructorActive','P') IS NOT NULL
    DROP PROCEDURE dbo.sp__EnsureInstructorActive;
GO
CREATE PROCEDURE dbo.sp__EnsureInstructorActive
(
    @InstructorID INT
)
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.INSTRUCTOR
        WHERE InstructorID = @InstructorID
          AND IsDeleted = 0
    )
    BEGIN
        RAISERROR('Instructor not found or deleted.', 16, 1);
        RETURN;
    END
END
GO

---------------------------------------------------------
-- Ensure User exists and active
---------------------------------------------------------
IF OBJECT_ID('dbo.sp__EnsureUserActive','P') IS NOT NULL
    DROP PROCEDURE dbo.sp__EnsureUserActive;
GO
CREATE PROCEDURE dbo.sp__EnsureUserActive
(
    @Username NVARCHAR(50)
)
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.USERS
        WHERE Username = @Username
          AND IsDeleted = 0
    )
    BEGIN
        RAISERROR('User not found or deleted.', 16, 1);
        RETURN;
    END
END
GO

---------------------------------------------------------
-- Ensure Course exists and active (fallback if 5A not run)
---------------------------------------------------------
IF OBJECT_ID('dbo.sp__EnsureCourseActive','P') IS NULL
EXEC('
CREATE PROCEDURE dbo.sp__EnsureCourseActive (@CourseID INT)
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM dbo.COURSE WHERE CourseID=@CourseID AND IsDeleted=0)
    BEGIN
        RAISERROR(''Course not found or deleted.'',16,1);
        RETURN;
    END
END
');
GO

---------------------------------------------------------
-- Ensure Student exists and active (fallback if 5A not run)
---------------------------------------------------------
IF OBJECT_ID('dbo.sp__EnsureStudentActive','P') IS NULL
EXEC('
CREATE PROCEDURE dbo.sp__EnsureStudentActive (@StudentID INT)
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM dbo.STUDENT WHERE StudentID=@StudentID AND IsDeleted=0)
    BEGIN
        RAISERROR(''Student not found or deleted.'',16,1);
        RETURN;
    END
END
');
GO

/* =========================================================
   PART 5D — ADMIN: COURSE CRUD
   ========================================================= */

---------------------------------------------------------
-- D1. Admin: Create Course
---------------------------------------------------------
IF OBJECT_ID('dbo.sp_Admin_CreateCourse','P') IS NOT NULL
    DROP PROCEDURE dbo.sp_Admin_CreateCourse;
GO
CREATE PROCEDURE dbo.sp_Admin_CreateCourse
(
    @CurrentUsername NVARCHAR(50),
    @CourseName      NVARCHAR(100),
    @Description     NVARCHAR(MAX) = NULL,
    @PublicInfo      NVARCHAR(MAX) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    EXEC dbo.sp_CheckAccess
        @CurrentUsername   = @CurrentUsername,
        @RequiredRole      = 'Admin',
        @RequiredClearance = 5,
        @Mode              = 'WRITE';

    IF @CourseName IS NULL OR LTRIM(RTRIM(@CourseName)) = ''
    BEGIN
        RAISERROR('CourseName is required.', 16, 1);
        RETURN;
    END

    IF EXISTS (
        SELECT 1
        FROM dbo.COURSE
        WHERE CourseName = @CourseName
          AND IsDeleted = 0
    )
    BEGIN
        RAISERROR('CourseName already exists.', 16, 1);
        RETURN;
    END

    BEGIN TRY
        INSERT INTO dbo.COURSE (CourseName, Description, PublicInfo, ClearanceLevel, IsDeleted)
        VALUES (@CourseName, @Description, @PublicInfo, 1, 0);

        EXEC dbo.sp_LogAction
            @Username = @CurrentUsername,
            @Action   = 'ADMIN_CREATE_COURSE',
            @Details  = @CourseName;
    END TRY
    BEGIN CATCH
    DECLARE @Err NVARCHAR(4000) = ERROR_MESSAGE();
    RAISERROR(@Err, 16, 1);
    RETURN;
    END CATCH
END
GO

---------------------------------------------------------
-- D2. Admin: Update Course (partial update allowed)
---------------------------------------------------------
IF OBJECT_ID('dbo.sp_Admin_UpdateCourse','P') IS NOT NULL
    DROP PROCEDURE dbo.sp_Admin_UpdateCourse;
GO
CREATE PROCEDURE dbo.sp_Admin_UpdateCourse
(
    @CurrentUsername NVARCHAR(50),
    @CourseID        INT,
    @CourseName      NVARCHAR(100) = NULL,
    @Description     NVARCHAR(MAX) = NULL,
    @PublicInfo      NVARCHAR(MAX) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    EXEC dbo.sp_CheckAccess
        @CurrentUsername   = @CurrentUsername,
        @RequiredRole      = 'Admin',
        @RequiredClearance = 5,
        @Mode              = 'WRITE';

    EXEC dbo.sp__EnsureCourseActive @CourseID;

    IF @CourseName IS NOT NULL AND LTRIM(RTRIM(@CourseName)) <> ''
    BEGIN
        IF EXISTS (
            SELECT 1
            FROM dbo.COURSE
            WHERE CourseName = @CourseName
              AND CourseID  <> @CourseID
              AND IsDeleted = 0
        )
        BEGIN
            RAISERROR('Another course already has this name.', 16, 1);
            RETURN;
        END
    END

    BEGIN TRY
        UPDATE dbo.COURSE
        SET
            CourseName  = COALESCE(NULLIF(LTRIM(RTRIM(@CourseName)), ''), CourseName),
            Description = COALESCE(@Description, Description),
            PublicInfo  = COALESCE(@PublicInfo, PublicInfo)
        WHERE CourseID = @CourseID;

		DECLARE @Details NVARCHAR(4000);

        SET @Details =
           N'CourseID=' + CAST(@CourseID AS NVARCHAR(20)) 
        EXEC dbo.sp_LogAction
            @Username = @CurrentUsername,
            @Action   = 'ADMIN_UPDATE_COURSE',
            @Details  = @Details;
    END TRY
    BEGIN CATCH
    DECLARE @Err NVARCHAR(4000) = ERROR_MESSAGE();
    RAISERROR(@Err, 16, 1);
    RETURN;
    END CATCH
END
GO

---------------------------------------------------------
-- D3. Admin: Delete Course (soft delete)
---------------------------------------------------------
IF OBJECT_ID('dbo.sp_Admin_DeleteCourse','P') IS NOT NULL
    DROP PROCEDURE dbo.sp_Admin_DeleteCourse;
GO
CREATE PROCEDURE dbo.sp_Admin_DeleteCourse
(
    @CurrentUsername NVARCHAR(50),
    @CourseID        INT
)
AS
BEGIN
    SET NOCOUNT ON;

    EXEC dbo.sp_CheckAccess
        @CurrentUsername   = @CurrentUsername,
        @RequiredRole      = 'Admin',
        @RequiredClearance = 5,
        @Mode              = 'WRITE';

    EXEC dbo.sp__EnsureCourseActive @CourseID;

    BEGIN TRY
        UPDATE dbo.COURSE
        SET IsDeleted = 1
        WHERE CourseID = @CourseID;

		DECLARE @Details NVARCHAR(4000);

        SET @Details =
           N'CourseID=' + CAST(@CourseID AS NVARCHAR(20)) 
        EXEC dbo.sp_LogAction
            @Username = @CurrentUsername,
            @Action   = 'ADMIN_DELETE_COURSE',
            @Details  = @Details;
    END TRY
    BEGIN CATCH
    DECLARE @Err NVARCHAR(4000) = ERROR_MESSAGE();
    RAISERROR(@Err, 16, 1);
    RETURN;
    END CATCH
END
GO

---------------------------------------------------------
-- D4. Admin: Get Courses (includes deleted for admin audit)
---------------------------------------------------------
IF OBJECT_ID('dbo.sp_Admin_GetCourses','P') IS NOT NULL
    DROP PROCEDURE dbo.sp_Admin_GetCourses;
GO
CREATE PROCEDURE dbo.sp_Admin_GetCourses
(
    @CurrentUsername NVARCHAR(50)
)
AS
BEGIN
    SET NOCOUNT ON;

    EXEC dbo.sp_CheckAccess
        @CurrentUsername   = @CurrentUsername,
        @RequiredRole      = 'Admin',
        @RequiredClearance = 1,
        @Mode              = 'READ';

    SELECT
        CourseID,
        CourseName,
        Description,
        PublicInfo,
        ClearanceLevel,
        IsDeleted
    FROM dbo.COURSE;

    EXEC dbo.sp_LogAction
        @Username = @CurrentUsername,
        @Action   = 'ADMIN_GET_COURSES',
        @Details  = NULL;
END
GO

IF OBJECT_ID('dbo.sp_User_UpdateRole','P') IS NOT NULL
    DROP PROCEDURE dbo.sp_User_UpdateRole;
GO

CREATE PROCEDURE dbo.sp_User_UpdateRole
(
    @AdminUsername NVARCHAR(50),
    @TargetUsername NVARCHAR(50),
    @NewRole NVARCHAR(20),

    @FullName NVARCHAR(100)=NULL,
    @Email NVARCHAR(100)=NULL,
    @Phone NVARCHAR(20)=NULL,
    @DOB DATE=NULL,
    @Department NVARCHAR(50)=NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    EXEC dbo.sp_CheckAccess
        @AdminUsername,'Admin',5,'WRITE';

    UPDATE dbo.USERS
    SET Role = @NewRole
    WHERE Username = @TargetUsername
      AND IsDeleted = 0;

	  DECLARE @Details NVARCHAR(4000);
      SET @Details = N'User=' + CAST(@TargetUsername AS NVARCHAR(200)) + N' NewRole=' + CAST(@NewRole AS NVARCHAR(50));

    EXEC dbo.sp_LogAction
    @Username = @AdminUsername,
    @Action   = N'UPDATE_ROLE',
    @Details  = @Details;

END
GO



/* =========================================================
   PART 5E — ADMIN: ENROLLMENT + ASSIGNMENTS
   ========================================================= */

---------------------------------------------------------
-- E1. Admin: Enroll Student in Course
---------------------------------------------------------
IF OBJECT_ID('dbo.sp_Admin_EnrollStudentInCourse','P') IS NOT NULL
    DROP PROCEDURE dbo.sp_Admin_EnrollStudentInCourse;
GO
CREATE PROCEDURE dbo.sp_Admin_EnrollStudentInCourse
(
    @CurrentUsername NVARCHAR(50),
    @StudentID       INT,
    @CourseID        INT
)
AS
BEGIN
    SET NOCOUNT ON;

    EXEC dbo.sp_CheckAccess
        @CurrentUsername   = @CurrentUsername,
        @RequiredRole      = 'Admin',
        @RequiredClearance = 5,
        @Mode              = 'WRITE';

    EXEC dbo.sp__EnsureCourseActive  @CourseID;
    EXEC dbo.sp__EnsureStudentActive @StudentID;

    IF EXISTS (
        SELECT 1
        FROM dbo.COURSE_STUDENT
        WHERE CourseID  = @CourseID
          AND StudentID = @StudentID
    )
    BEGIN
        RAISERROR('Student already enrolled in this course.', 16, 1);
        RETURN;
    END

    BEGIN TRY
        INSERT INTO dbo.COURSE_STUDENT (CourseID, StudentID)
        VALUES (@CourseID, @StudentID);

		DECLARE @Details NVARCHAR(4000);

        SET @Details =
        N'StudentID=' + CAST(@StudentID AS NVARCHAR(20)) +
        N', CourseID=' + CAST(@CourseID AS NVARCHAR(20));
        EXEC dbo.sp_LogAction
            @Username = @CurrentUsername,
            @Action   = 'ADMIN_ENROLL_STUDENT',
            @Details  = @Details;
    END TRY
    BEGIN CATCH
    DECLARE @Err NVARCHAR(4000) = ERROR_MESSAGE();
    RAISERROR(@Err, 16, 1);
    RETURN;
    END CATCH
END
GO

---------------------------------------------------------
-- E2. Admin: Remove Enrollment
---------------------------------------------------------
IF OBJECT_ID('dbo.sp_Admin_RemoveEnrollment','P') IS NOT NULL
    DROP PROCEDURE dbo.sp_Admin_RemoveEnrollment;
GO
CREATE PROCEDURE dbo.sp_Admin_RemoveEnrollment
(
    @CurrentUsername NVARCHAR(50),
    @StudentID       INT,
    @CourseID        INT
)
AS
BEGIN
    SET NOCOUNT ON;

    EXEC dbo.sp_CheckAccess
        @CurrentUsername   = @CurrentUsername,
        @RequiredRole      = 'Admin',
        @RequiredClearance = 5,
        @Mode              = 'WRITE';

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.COURSE_STUDENT
        WHERE CourseID  = @CourseID
          AND StudentID = @StudentID
    )
    BEGIN
        RAISERROR('Enrollment not found.', 16, 1);
        RETURN;
    END

    BEGIN TRY
        DELETE FROM dbo.COURSE_STUDENT
        WHERE CourseID  = @CourseID
          AND StudentID = @StudentID;
		  DECLARE @Details NVARCHAR(4000);

          SET @Details =
          N'StudentID=' + CAST(@StudentID AS NVARCHAR(20)) +
          N', CourseID=' + CAST(@CourseID AS NVARCHAR(20));
        EXEC dbo.sp_LogAction
            @Username = @CurrentUsername,
            @Action   = 'ADMIN_REMOVE_ENROLLMENT',
            @Details  = @Details;
    END TRY
    BEGIN CATCH
    DECLARE @Err NVARCHAR(4000) = ERROR_MESSAGE();
    RAISERROR(@Err, 16, 1);
    RETURN;
    END CATCH
END
GO

---------------------------------------------------------
-- E3. Admin: Assign Instructor to Course
---------------------------------------------------------
IF OBJECT_ID('dbo.sp_Admin_AssignInstructorToCourse','P') IS NOT NULL
    DROP PROCEDURE dbo.sp_Admin_AssignInstructorToCourse;
GO
CREATE PROCEDURE dbo.sp_Admin_AssignInstructorToCourse
(
    @CurrentUsername NVARCHAR(50),
    @InstructorID    INT,
    @CourseID        INT
)
AS
BEGIN
    SET NOCOUNT ON;

    EXEC dbo.sp_CheckAccess
        @CurrentUsername   = @CurrentUsername,
        @RequiredRole      = 'Admin',
        @RequiredClearance = 5,
        @Mode              = 'WRITE';

    EXEC dbo.sp__EnsureCourseActive      @CourseID;
    EXEC dbo.sp__EnsureInstructorActive  @InstructorID;

    IF EXISTS (
        SELECT 1
        FROM dbo.INSTRUCTOR_COURSE
        WHERE InstructorID = @InstructorID
          AND CourseID     = @CourseID
    )
    BEGIN
        RAISERROR('Instructor already assigned to this course.', 16, 1);
        RETURN;
    END

    BEGIN TRY
        INSERT INTO dbo.INSTRUCTOR_COURSE (InstructorID, CourseID)
        VALUES (@InstructorID, @CourseID);

		DECLARE @Details NVARCHAR(4000);

        SET @Details =
        N'InstructorID=' + CAST(@InstructorID AS NVARCHAR(20)) +
        N', CourseID=' + CAST(@CourseID AS NVARCHAR(20));
        EXEC dbo.sp_LogAction
            @Username = @CurrentUsername,
            @Action   = 'ADMIN_ASSIGN_INSTRUCTOR',
            @Details  =@Details;
    END TRY
    BEGIN CATCH
    DECLARE @Err NVARCHAR(4000) = ERROR_MESSAGE();
    RAISERROR(@Err, 16, 1);
    RETURN;
    END CATCH
END
GO

---------------------------------------------------------
-- E4. Admin: Unassign Instructor from Course
---------------------------------------------------------
IF OBJECT_ID('dbo.sp_Admin_UnassignInstructorFromCourse','P') IS NOT NULL
    DROP PROCEDURE dbo.sp_Admin_UnassignInstructorFromCourse;
GO
CREATE PROCEDURE dbo.sp_Admin_UnassignInstructorFromCourse
(
    @CurrentUsername NVARCHAR(50),
    @InstructorID    INT,
    @CourseID        INT
)
AS
BEGIN
    SET NOCOUNT ON;

    EXEC dbo.sp_CheckAccess
        @CurrentUsername   = @CurrentUsername,
        @RequiredRole      = 'Admin',
        @RequiredClearance = 5,
        @Mode              = 'WRITE';

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.INSTRUCTOR_COURSE
        WHERE InstructorID = @InstructorID
          AND CourseID     = @CourseID
    )
    BEGIN
        RAISERROR('Instructor assignment not found.', 16, 1);
        RETURN;
    END

    BEGIN TRY
        DELETE FROM dbo.INSTRUCTOR_COURSE
        WHERE InstructorID = @InstructorID
          AND CourseID     = @CourseID;



		DECLARE @Details NVARCHAR(4000);

        SET @Details =
        N'InstructorID=' + CAST(@InstructorID AS NVARCHAR(20)) +
        N', CourseID=' + CAST(@CourseID AS NVARCHAR(20));
        EXEC dbo.sp_LogAction
            @Username = @CurrentUsername,
            @Action   = 'ADMIN_UNASSIGN_INSTRUCTOR',
            @Details  =@Details ;
    END TRY
    BEGIN CATCH
    DECLARE @Err NVARCHAR(4000) = ERROR_MESSAGE();
    RAISERROR(@Err, 16, 1);
    RETURN;
    END CATCH
END
GO

---------------------------------------------------------
-- E5. Admin: Assign TA (by username) to Course
---------------------------------------------------------
IF OBJECT_ID('dbo.sp_Admin_AssignTAtoCourse','P') IS NOT NULL
    DROP PROCEDURE dbo.sp_Admin_AssignTAtoCourse;
GO
CREATE PROCEDURE dbo.sp_Admin_AssignTAtoCourse
(
    @CurrentUsername NVARCHAR(50),
    @TAUsername      NVARCHAR(50),
    @CourseID        INT
)
AS
BEGIN
    SET NOCOUNT ON;

    EXEC dbo.sp_CheckAccess
        @CurrentUsername   = @CurrentUsername,
        @RequiredRole      = 'Admin',
        @RequiredClearance = 5,
        @Mode              = 'WRITE';

    EXEC dbo.sp__EnsureCourseActive @CourseID;
    EXEC dbo.sp__EnsureUserActive   @TAUsername;

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.USERS
        WHERE Username  = @TAUsername
          AND Role      = 'TA'
          AND IsDeleted = 0
    )
    BEGIN
        RAISERROR('TA user not found or not active TA.', 16, 1);
        RETURN;
    END

    IF EXISTS (
        SELECT 1
        FROM dbo.TA_COURSE
        WHERE TAUsername = @TAUsername
          AND CourseID   = @CourseID
    )
    BEGIN
        RAISERROR('TA already assigned to this course.', 16, 1);
        RETURN;
    END

    BEGIN TRY
        INSERT INTO dbo.TA_COURSE (TAUsername, CourseID)
        VALUES (@TAUsername, @CourseID);

		DECLARE @Details NVARCHAR(4000);

        SET @Details =
        N'TAUsername=' + CAST(@TAUsername AS NVARCHAR(20)) +
        N', CourseID=' + CAST(@CourseID AS NVARCHAR(20));
        EXEC dbo.sp_LogAction
            @Username = @CurrentUsername,
            @Action   = 'ADMIN_ASSIGN_TA',
            @Details  = @Details;
    END TRY
    BEGIN CATCH
    DECLARE @Err NVARCHAR(4000) = ERROR_MESSAGE();
    RAISERROR(@Err, 16, 1);
    RETURN;
    END CATCH
END
GO

---------------------------------------------------------
-- E6. Admin: Unassign TA from Course
---------------------------------------------------------
IF OBJECT_ID('dbo.sp_Admin_UnassignTAFromCourse','P') IS NOT NULL
    DROP PROCEDURE dbo.sp_Admin_UnassignTAFromCourse;
GO
CREATE PROCEDURE dbo.sp_Admin_UnassignTAFromCourse
(
    @CurrentUsername NVARCHAR(50),
    @TAUsername      NVARCHAR(50),
    @CourseID        INT
)
AS
BEGIN
    SET NOCOUNT ON;

    EXEC dbo.sp_CheckAccess
        @CurrentUsername   = @CurrentUsername,
        @RequiredRole      = 'Admin',
        @RequiredClearance = 5,
        @Mode              = 'WRITE';

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.TA_COURSE
        WHERE TAUsername = @TAUsername
          AND CourseID   = @CourseID
    )
    BEGIN
        RAISERROR('TA assignment not found.', 16, 1);
        RETURN;
    END

    BEGIN TRY
        DELETE FROM dbo.TA_COURSE
        WHERE TAUsername = @TAUsername
          AND CourseID   = @CourseID;


		DECLARE @Details NVARCHAR(4000);

        SET @Details =
        N'TAUsername=' + CAST(@TAUsername AS NVARCHAR(20)) +
        N', CourseID=' + CAST(@CourseID AS NVARCHAR(20));
        EXEC dbo.sp_LogAction
            @Username = @CurrentUsername,
            @Action   = 'ADMIN_UNASSIGN_TA',
            @Details  = @Details;
    END TRY
    BEGIN CATCH
    DECLARE @Err NVARCHAR(4000) = ERROR_MESSAGE();
    RAISERROR(@Err, 16, 1);
    RETURN;
    END CATCH
END
GO

---------------------------------------------------------
-- E7. Admin: 
---------------------------------------------------------
IF OBJECT_ID('dbo.sp_Admin_GetCourses','P') IS NOT NULL
    DROP PROCEDURE dbo.sp_Admin_GetCourses;
GO
CREATE PROCEDURE dbo.sp_Admin_GetCourses
(
    @AdminUsername NVARCHAR(50)
)
AS
BEGIN
    SET NOCOUNT ON;

    EXEC dbo.sp_CheckAccess
        @AdminUsername,'Admin',5,'READ';

    SELECT CourseID, CourseName
    FROM dbo.COURSE
    WHERE IsDeleted = 0
    ORDER BY CourseName;
END
GO

---------------------------------------------------------
-- E8. Admin: 
---------------------------------------------------------
IF OBJECT_ID('dbo.sp_Admin_GetStudents','P') IS NOT NULL
    DROP PROCEDURE dbo.sp_Admin_GetStudents;
GO
CREATE PROCEDURE dbo.sp_Admin_GetStudents
(
    @AdminUsername NVARCHAR(50)
)
AS
BEGIN
    SET NOCOUNT ON;

    EXEC dbo.sp_CheckAccess
        @AdminUsername,'Admin',5,'READ';

    SELECT StudentID, FullName
    FROM dbo.STUDENT
    WHERE IsDeleted = 0
    ORDER BY FullName;
END
GO

---------------------------------------------------------
-- E9. Admin: 
---------------------------------------------------------
IF OBJECT_ID('dbo.sp_Admin_GetInstructors','P') IS NOT NULL
    DROP PROCEDURE dbo.sp_Admin_GetInstructors;
GO
CREATE PROCEDURE dbo.sp_Admin_GetInstructors
(
    @AdminUsername NVARCHAR(50)
)
AS
BEGIN
    SET NOCOUNT ON;

    EXEC dbo.sp_CheckAccess
        @AdminUsername,'Admin',5,'READ';

    SELECT InstructorID, FullName
    FROM dbo.INSTRUCTOR
    WHERE IsDeleted = 0
    ORDER BY FullName;
END
GO

---------------------------------------------------------
-- E10. Admin: 
---------------------------------------------------------
IF OBJECT_ID('dbo.sp_Admin_GetTAs','P') IS NOT NULL
    DROP PROCEDURE dbo.sp_Admin_GetTAs;
GO
CREATE PROCEDURE dbo.sp_Admin_GetTAs
(
    @AdminUsername NVARCHAR(50)
)
AS
BEGIN
    SET NOCOUNT ON;

    EXEC dbo.sp_CheckAccess
        @AdminUsername,'Admin',5,'READ';

    SELECT Username
    FROM dbo.USERS
    WHERE Role = 'TA'
      AND IsDeleted = 0
    ORDER BY Username;
END
GO

---------------------------------------------------------
-- E11. Admin: 
---------------------------------------------------------
IF OBJECT_ID('dbo.sp_Admin_GetInstructorAssignments','P') IS NOT NULL
    DROP PROCEDURE dbo.sp_Admin_GetInstructorAssignments
GO
CREATE PROCEDURE dbo.sp_Admin_GetInstructorAssignments
(
    @AdminUsername NVARCHAR(50)
)
AS
BEGIN
    SET NOCOUNT ON;

    EXEC dbo.sp_CheckAccess
        @AdminUsername,'Admin',5,'READ';

    SELECT
        ic.InstructorID,
        i.FullName AS InstructorName,
        ic.CourseID,
        c.CourseName
    FROM dbo.INSTRUCTOR_COURSE ic
    JOIN dbo.INSTRUCTOR i ON ic.InstructorID = i.InstructorID
    JOIN dbo.COURSE c ON ic.CourseID = c.CourseID
    WHERE c.IsDeleted = 0;
END
GO

---------------------------------------------------------
-- E12. Admin: 
---------------------------------------------------------
IF OBJECT_ID('dbo.sp_Admin_GetTAAssignments','P') IS NOT NULL
    DROP PROCEDURE dbo.sp_Admin_GetTAAssignments;
GO
CREATE PROCEDURE dbo.sp_Admin_GetTAAssignments
(
    @AdminUsername NVARCHAR(50)
)
AS
BEGIN
    SET NOCOUNT ON;

    EXEC dbo.sp_CheckAccess
        @AdminUsername,'Admin',5,'READ';

    SELECT
        tc.TAUsername,
        tc.CourseID,
        c.CourseName
    FROM dbo.TA_COURSE tc
    JOIN dbo.COURSE c ON tc.CourseID = c.CourseID
    WHERE c.IsDeleted = 0;
END
GO



---------------------------------------------------------
-- E. Admin: User_GetAll
---------------------------------------------------------
IF OBJECT_ID('dbo.sp_User_GetAll','P') IS NOT NULL
    DROP PROCEDURE dbo.sp_User_GetAll;
GO

CREATE PROCEDURE dbo.sp_User_GetAll
(
    @CurrentUsername NVARCHAR(50)
)
AS
BEGIN
    SET NOCOUNT ON;

    -------------------------------------------------
    -- Security Check (Admin only)
    -------------------------------------------------
    EXEC dbo.sp_CheckAccess
        @CurrentUsername   = @CurrentUsername,
        @RequiredRole      = 'Admin',
        @RequiredClearance = 4,
        @Mode              = 'READ';

    -------------------------------------------------
    -- Return users from ADMIN VIEW (NOT table)
    -------------------------------------------------
    SELECT
        Username,
        Role,
        ClearanceLevel
    FROM dbo.vw_Admin_Users
    WHERE IsDeleted = 0
    ORDER BY Username;

    -------------------------------------------------
    -- Audit log
    -------------------------------------------------
    EXEC dbo.sp_LogAction
        @Username = @CurrentUsername,
        @Action   = 'ADMIN_VIEW_USERS',
        @Details  = NULL;
END
GO


---------------------------------------------------------
-- E. Guest: sp_Get_PublicCourses
---------------------------------------------------------
IF OBJECT_ID('dbo.sp_Get_PublicCourses','P') IS NOT NULL
    DROP PROCEDURE dbo.sp_Get_PublicCourses;
GO
CREATE PROCEDURE dbo.sp_Get_PublicCourses
(
    @CurrentUsername NVARCHAR(50)
)
AS
BEGIN
    SET NOCOUNT ON;

    EXEC dbo.sp_CheckAccess
        @CurrentUsername,'Guestrole',1,'READ';

    SELECT
        CourseID,
        CourseName,
        Description,
        PublicInfo
    FROM dbo.COURSE
    WHERE IsDeleted = 0
      AND ClearanceLevel = 1
    ORDER BY CourseName;
END
GO



/* ===========================
   END OF PART 5D + 5E
   =========================== */






/* =========================================================
   SRMS_DB — Term Project (FINAL)
   Part 5F — Inference-safe aggregates

   Depends on: Part 1, 2, 3, 4 + Part 5A/B helpers
   ========================================================= */

---------------------------------------------------------
-- F1. Instructor/Admin: Average Grade per Course (>=3) [SAFE]
-- Notes:
-- - No decrypt in views; decrypt happens here after open key.
-- - Inference control: group size must be >= 3.
-- - Ownership: if Instructor then must own the course.
---------------------------------------------------------
IF OBJECT_ID('dbo.sp_Get_AvgGrade_Safe','P') IS NOT NULL
    DROP PROCEDURE dbo.sp_Get_AvgGrade_Safe;
GO
CREATE PROCEDURE dbo.sp_Get_AvgGrade_Safe
(
    @CurrentUsername NVARCHAR(50),
    @CourseID INT
)
AS
BEGIN
    SET NOCOUNT ON;

    EXEC dbo.sp_CheckAccess
        @CurrentUsername   = @CurrentUsername,
        @RequiredRole      = 'Instructor,Admin',
        @RequiredClearance = 3,
        @Mode              = 'READ';

    EXEC dbo.sp__EnsureCourseActive @CourseID;

    -- If Instructor -> must own course
    DECLARE @Role NVARCHAR(20);
    SELECT @Role = Role
    FROM dbo.USERS
    WHERE Username=@CurrentUsername AND IsDeleted=0;

    IF @Role = 'Instructor'
        EXEC dbo.sp__EnsureInstructorOwnsCourse @CurrentUsername, @CourseID;

    -- Inference control: >= 3 rows
    IF NOT EXISTS (
        SELECT 1
        FROM dbo.GRADES
        WHERE CourseID = @CourseID
          AND IsDeleted = 0
          AND EncryptedGradeValue IS NOT NULL
        GROUP BY CourseID
        HAVING COUNT(*) >= 3
    )
    BEGIN
        RAISERROR('Inference Control: Group size < 3.',16,1);
        RETURN;
    END

    BEGIN TRY
        EXEC dbo.sp_Key_Open;

        SELECT
            AVG(
                TRY_CONVERT(
                    DECIMAL(10,2),
                    CONVERT(NVARCHAR(50), DecryptByKey(EncryptedGradeValue))
                )
            ) AS AvgGrade
        FROM dbo.GRADES
        WHERE CourseID=@CourseID
          AND IsDeleted=0
          AND EncryptedGradeValue IS NOT NULL;

        EXEC dbo.sp_Key_Close;

		DECLARE @Details NVARCHAR(4000);

        SET @Details =
        N', CourseID=' + CAST(@CourseID AS NVARCHAR(20));
        EXEC dbo.sp_LogAction
            @Username = @CurrentUsername,
            @Action   = 'VIEW_AVG_GRADE_SAFE',
            @Details  = @Details;
    END TRY
    BEGIN CATCH
        BEGIN TRY EXEC dbo.sp_Key_Close; END TRY BEGIN CATCH END CATCH;
        THROW;
    END CATCH
END
GO











/* =========================================================
   PART 6 — USER MANAGEMENT + ROLE REQUESTS (FINAL)
   SAFE VERSION (NO CONCAT / NO + INSIDE EXEC)
   ========================================================= */


/* =========================================================
   6.1 — USER REGISTER (PUBLIC)
   ========================================================= */
IF OBJECT_ID('dbo.sp_User_Register','P') IS NOT NULL
    DROP PROCEDURE dbo.sp_User_Register;
GO

CREATE PROCEDURE dbo.sp_User_Register
(
    @Username NVARCHAR(50),
    @PasswordPlain NVARCHAR(200),
    @Role NVARCHAR(20),

    @FullName NVARCHAR(100) = NULL,
    @Email NVARCHAR(100) = NULL,
    @Phone NVARCHAR(20) = NULL,
    @DOB DATE = NULL,
    @Department NVARCHAR(50) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    IF @Role NOT IN ('Admin','Instructor','TA','Student','Guestrole')
        THROW 50000, 'Invalid role.', 1;

    IF EXISTS (SELECT 1 FROM dbo.USERS WHERE Username=@Username AND IsDeleted=0)
        THROW 50001, 'Username already exists.', 1;

    DECLARE @PwdHash VARBINARY(MAX) =
        HASHBYTES('SHA2_256', @PasswordPlain);

    DECLARE @ClearanceLevel INT =
        CASE @Role
            WHEN 'Admin'      THEN 5
            WHEN 'Instructor' THEN 4
            WHEN 'TA'         THEN 3
            WHEN 'Student'    THEN 2
            WHEN 'Guestrole'  THEN 1
        END;

    DECLARE @StudentID INT = NULL;
    DECLARE @InstructorID INT = NULL;
    DECLARE @TAID INT = NULL;

    EXEC dbo.sp_Key_Open;

    -------------------------------------------------
    -- Student
    -------------------------------------------------
    IF @Role = 'Student'
    BEGIN
        IF @FullName IS NULL OR @Email IS NULL OR @Phone IS NULL
           OR @DOB IS NULL OR @Department IS NULL
            THROW 50002, 'Missing student fields.', 1;

        INSERT INTO dbo.STUDENT
        (FullName,Email,DOB,Department,ClearanceLevel,EncryptedPhone,IsDeleted)
        VALUES
        (@FullName,@Email,@DOB,@Department,2,
         EncryptByKey(Key_GUID('SRMSSymmetricKey'),@Phone),0);

        SET @StudentID = SCOPE_IDENTITY();
    END

    -------------------------------------------------
    -- Instructor
    -------------------------------------------------
    IF @Role = 'Instructor'
    BEGIN
        INSERT INTO dbo.INSTRUCTOR
        (FullName,Email,ClearanceLevel,IsDeleted)
        VALUES
        (ISNULL(@FullName,@Username),
         ISNULL(@Email,CONCAT(@Username,'@uni.edu')),
         4,0);

        SET @InstructorID = SCOPE_IDENTITY();
    END

    -------------------------------------------------
    -- TA
    -------------------------------------------------
    IF @Role = 'TA'
    BEGIN
        INSERT INTO dbo.TA
        (FullName,Email,ClearanceLevel,IsDeleted)
        VALUES
        (ISNULL(@FullName,@Username),
         ISNULL(@Email,CONCAT(@Username,'@uni.edu')),
         3,0);

        SET @TAID = SCOPE_IDENTITY();
    END

    -------------------------------------------------
    -- USERS
    -------------------------------------------------
    INSERT INTO dbo.USERS
    (Username,Password,Role,ClearanceLevel,
     StudentID,InstructorID,TAID,
     EncryptedUsername,IsDeleted)
    VALUES
    (@Username,@PwdHash,@Role,@ClearanceLevel,
     @StudentID,@InstructorID,@TAID,
     EncryptByKey(Key_GUID('SRMSSymmetricKey'),@Username),0);

    EXEC dbo.sp_Key_Close;

    EXEC dbo.sp_LogAction @Username,'REGISTER_USER',@Role;
END
GO



/* =========================================================
   6.2 — USER LOGIN
   ========================================================= */
IF OBJECT_ID('dbo.sp_User_Login','P') IS NOT NULL
    DROP PROCEDURE dbo.sp_User_Login;
GO
CREATE PROCEDURE dbo.sp_User_Login
(
    @Username NVARCHAR(50),
    @PasswordPlain NVARCHAR(200)
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @StoredHash VARBINARY(MAX);

    SELECT @StoredHash = [Password]
    FROM dbo.USERS
    WHERE Username=@Username AND IsDeleted=0;

    IF @StoredHash IS NULL
        THROW 50003, 'Invalid username.', 1;

    IF @StoredHash <> HASHBYTES('SHA2_256',@PasswordPlain)
        THROW 50004, 'Invalid password.', 1;

    SELECT Username,Role,ClearanceLevel,StudentID,InstructorID,TAID
    FROM dbo.USERS
    WHERE Username=@Username AND IsDeleted=0;

    EXEC dbo.sp_LogAction @Username,'LOGIN',NULL;
END
GO


/* =========================================================
   6.3 — ADMIN CREATE USER
   ========================================================= */
IF OBJECT_ID('dbo.sp_Admin_CreateUser','P') IS NOT NULL
    DROP PROCEDURE dbo.sp_Admin_CreateUser;
GO

CREATE PROCEDURE dbo.sp_Admin_CreateUser
(
    @CurrentUsername NVARCHAR(50),
    @Username NVARCHAR(50),
    @PasswordPlain NVARCHAR(200),
    @Role NVARCHAR(20),

    @FullName NVARCHAR(100)=NULL,
    @Email NVARCHAR(100)=NULL,
    @Phone NVARCHAR(20)=NULL,
    @DOB DATE=NULL,
    @Department NVARCHAR(50)=NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    -- Admin only
    EXEC dbo.sp_CheckAccess
        @CurrentUsername,'Admin',5,'WRITE';

    -- Delegate to unified register procedure
    EXEC dbo.sp_User_Register
        @Username      = @Username,
        @PasswordPlain = @PasswordPlain,
        @Role          = @Role,
        @FullName      = @FullName,
        @Email         = @Email,
        @Phone         = @Phone,
        @DOB           = @DOB,
        @Department    = @Department;

    EXEC dbo.sp_LogAction
        @CurrentUsername,
        'ADMIN_CREATE_USER';
END
GO


/* =========================================================
   6.4 — UPDATE PASSWORD
   ========================================================= */
IF OBJECT_ID('dbo.sp_User_UpdatePassword','P') IS NOT NULL
    DROP PROCEDURE dbo.sp_User_UpdatePassword;
GO
CREATE PROCEDURE dbo.sp_User_UpdatePassword
(
    @CurrentUsername NVARCHAR(50),
    @TargetUsername NVARCHAR(50),
    @NewPasswordPlain NVARCHAR(200)
)
AS
BEGIN
    SET NOCOUNT ON;

    IF @CurrentUsername<>@TargetUsername
        EXEC dbo.sp_CheckAccess
            @CurrentUsername,'Admin',4,'WRITE';

    UPDATE dbo.USERS
    SET [Password]=HASHBYTES('SHA2_256',@NewPasswordPlain)
    WHERE Username=@TargetUsername AND IsDeleted=0;

    DECLARE @Details NVARCHAR(200)=N'Password changed for '+@TargetUsername;
    EXEC dbo.sp_LogAction @CurrentUsername,'UPDATE_PASSWORD',@Details;
END
GO


/* =========================================================
   6.5 — UPDATE Role
   ========================================================= */
IF OBJECT_ID('dbo.sp_User_UpdateRole','P') IS NOT NULL
    DROP PROCEDURE dbo.sp_User_UpdateRole;
GO

CREATE PROCEDURE dbo.sp_User_UpdateRole
(
    @AdminUsername   NVARCHAR(50),
    @TargetUsername  NVARCHAR(50),
    @NewRole         NVARCHAR(20)
)
AS
BEGIN
    SET NOCOUNT ON;

    -------------------------------------------------
    -- Admin only
    -------------------------------------------------
    EXEC dbo.sp_CheckAccess
        @AdminUsername,'Admin',5,'WRITE';

    -------------------------------------------------
    -- Validate role
    -------------------------------------------------
    IF @NewRole NOT IN ('Admin','Instructor','TA','Student','Guestrole')
        RAISERROR('Invalid role.',16,1);

    -------------------------------------------------
    -- Load current user
    -------------------------------------------------
    DECLARE 
        @OldRole NVARCHAR(20),
        @StudentID INT,
        @InstructorID INT,
        @TAID INT;

    SELECT
        @OldRole = Role,
        @StudentID = StudentID,
        @InstructorID = InstructorID,
        @TAID = TAID
    FROM dbo.USERS
    WHERE Username = @TargetUsername
      AND IsDeleted = 0;

    IF @OldRole IS NULL
        RAISERROR('User not found.',16,1);

    -------------------------------------------------
    -- Clear old links
    -------------------------------------------------
    SET @StudentID = NULL;
    SET @InstructorID = NULL;
    SET @TAID = NULL;

    -------------------------------------------------
    -- Create required entity for new role
    -------------------------------------------------

    IF @NewRole = 'Student'
    BEGIN
        INSERT INTO dbo.STUDENT
        (FullName, Email, DOB, Department, ClearanceLevel, IsDeleted)
        VALUES
        (@TargetUsername, CONCAT(@TargetUsername,'@std.edu'),
         '2000-01-01', 'CS', 2, 0);

        SET @StudentID = SCOPE_IDENTITY();
    END

    ELSE IF @NewRole = 'Instructor'
    BEGIN
        INSERT INTO dbo.INSTRUCTOR
        (FullName, Email, ClearanceLevel, IsDeleted)
        VALUES
        (@TargetUsername, CONCAT(@TargetUsername,'@uni.edu'), 4, 0);

        SET @InstructorID = SCOPE_IDENTITY();
    END

    ELSE IF @NewRole = 'TA'
    BEGIN
        INSERT INTO dbo.TA
        (FullName, Email, ClearanceLevel, IsDeleted)
        VALUES
        (@TargetUsername, CONCAT(@TargetUsername,'@uni.edu'), 3, 0);

        SET @TAID = SCOPE_IDENTITY();
    END

    -------------------------------------------------
    -- Update USERS
    -------------------------------------------------
    UPDATE dbo.USERS
    SET
        Role = @NewRole,
        ClearanceLevel =
            CASE @NewRole
                WHEN 'Admin'      THEN 5
                WHEN 'Instructor' THEN 4
                WHEN 'TA'         THEN 3
                WHEN 'Student'    THEN 2
                WHEN 'Guestrole'  THEN 1
            END,
        StudentID    = @StudentID,
        InstructorID = @InstructorID,
        TAID         = @TAID
    WHERE Username = @TargetUsername;

    -------------------------------------------------
    -- Audit log
    -------------------------------------------------
    EXEC dbo.sp_LogAction
        @AdminUsername,
        'UPDATE_ROLE';
END
GO



/* =========================================================
   6.5 — user_delete
   ========================================================= */
IF OBJECT_ID('dbo.sp_User_Delete','P') IS NOT NULL
    DROP PROCEDURE dbo.sp_User_Delete;
GO

CREATE PROCEDURE dbo.sp_User_Delete
(
    @AdminUsername NVARCHAR(50),
    @TargetUsername NVARCHAR(50)
)
AS
BEGIN
    SET NOCOUNT ON;

    EXEC dbo.sp_CheckAccess
        @AdminUsername, 'Admin', 5, 'WRITE';

    IF NOT EXISTS (
        SELECT 1 FROM dbo.USERS
        WHERE Username = @TargetUsername AND IsDeleted = 0
    )
    BEGIN
        RAISERROR('User not found or already deleted.',16,1);
        RETURN;
    END

    UPDATE dbo.USERS
    SET IsDeleted = 1
    WHERE Username = @TargetUsername;

    EXEC dbo.sp_LogAction
        @AdminUsername,
        'DELETE_USER',
        @TargetUsername;
END
GO






/* =========================================================
   Part 6.2 — ROLE REQUEST WORKFLOW
   ========================================================= */

---------------------------------------------------------
-- Submit Role Request (Student / TA)
---------------------------------------------------------
IF OBJECT_ID('dbo.sp_RoleRequest_Submit','P') IS NOT NULL
    DROP PROCEDURE dbo.sp_RoleRequest_Submit;
GO
CREATE PROCEDURE dbo.sp_RoleRequest_Submit
(
    @CurrentUsername NVARCHAR(50),
    @RequestedRole   NVARCHAR(20),
    @Reason          NVARCHAR(300),
    @Comments        NVARCHAR(300) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @CurrentRole NVARCHAR(20);

    SELECT @CurrentRole = Role
    FROM dbo.USERS
    WHERE Username=@CurrentUsername AND IsDeleted=0;

    IF @CurrentRole NOT IN ('Student','TA')
        RAISERROR('Only Student or TA can request role upgrade.',16,1);

    IF NOT (
        (@CurrentRole='Student' AND @RequestedRole IN ('TA','Instructor'))
        OR
        (@CurrentRole='TA' AND @RequestedRole='Instructor')
    )
        RAISERROR('Invalid role upgrade path.',16,1);

    IF EXISTS (
        SELECT 1 FROM dbo.ROLE_REQUESTS
        WHERE Username=@CurrentUsername AND Status='Pending'
    )
        RAISERROR('You already have a pending request.',16,1);

    INSERT INTO dbo.ROLE_REQUESTS
    (
        Username, CurrentRole, RequestedRole,
        Reason, Comments, Status, DateSubmitted
    )
    VALUES
    (
        @CurrentUsername, @CurrentRole, @RequestedRole,
        @Reason, @Comments, 'Pending', GETDATE()
    );

    DECLARE @Details NVARCHAR(200) =
        N'From=' + @CurrentRole + N' To=' + @RequestedRole;

    EXEC dbo.sp_LogAction
        @CurrentUsername,
        'SUBMIT_ROLE_REQUEST',
        @Details;
END
GO


---------------------------------------------------------
-- Get My Role Requests
---------------------------------------------------------
IF OBJECT_ID('dbo.sp_RoleRequest_GetMy','P') IS NOT NULL
    DROP PROCEDURE dbo.sp_RoleRequest_GetMy;
GO
CREATE PROCEDURE dbo.sp_RoleRequest_GetMy
(
    @CurrentUsername NVARCHAR(50)
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        RequestID, CurrentRole, RequestedRole,
        Reason, Comments, Status, DateSubmitted
    FROM dbo.ROLE_REQUESTS
    WHERE Username=@CurrentUsername
    ORDER BY DateSubmitted DESC;

    EXEC dbo.sp_LogAction
        @CurrentUsername,
        'VIEW_MY_ROLE_REQUESTS',
        NULL;
END
GO


---------------------------------------------------------
-- Admin: View Pending Role Requests
---------------------------------------------------------
IF OBJECT_ID('dbo.sp_RoleRequest_GetPending','P') IS NOT NULL
    DROP PROCEDURE dbo.sp_RoleRequest_GetPending;
GO
CREATE PROCEDURE dbo.sp_RoleRequest_GetPending
(
    @AdminUsername NVARCHAR(50)
)
AS
BEGIN
    SET NOCOUNT ON;

    EXEC dbo.sp_CheckAccess
        @AdminUsername,'Admin',4,'READ';

    SELECT *
    FROM dbo.ROLE_REQUESTS
    WHERE Status='Pending'
    ORDER BY DateSubmitted;

    EXEC dbo.sp_LogAction
        @AdminUsername,
        'VIEW_PENDING_ROLE_REQUESTS',
        NULL;
END
GO

---------------------------------------------------------
-- Admin: dbo.sp_RoleRequest_Approve
---------------------------------------------------------
IF OBJECT_ID('dbo.sp_RoleRequest_Approve','P') IS NOT NULL
    DROP PROCEDURE dbo.sp_RoleRequest_Approve;
GO

CREATE PROCEDURE dbo.sp_RoleRequest_Approve
(
    @AdminUsername NVARCHAR(50),
    @RequestID INT
)
AS
BEGIN
    SET NOCOUNT ON;

    EXEC dbo.sp_CheckAccess
        @AdminUsername,'Admin',4,'WRITE';

    DECLARE
        @Username NVARCHAR(50),
        @CurrentRole NVARCHAR(20),
        @NewRole NVARCHAR(20),
        @StudentID INT;

    SELECT
        @Username = Username,
        @CurrentRole = CurrentRole,
        @NewRole = RequestedRole
    FROM dbo.ROLE_REQUESTS
    WHERE RequestID=@RequestID AND Status='Pending';

    IF @Username IS NULL
        RAISERROR('Request not found or already processed.',16,1);

    -------------------------------------------------
    -- Student → TA
    -------------------------------------------------
    IF @CurrentRole='Student' AND @NewRole='TA'
    BEGIN
        SELECT @StudentID = StudentID
        FROM dbo.USERS
        WHERE Username=@Username;

        INSERT INTO dbo.TA (FullName, Email, ClearanceLevel, IsDeleted)
        SELECT FullName, Email, 3, 0
        FROM dbo.STUDENT
        WHERE StudentID=@StudentID;

        UPDATE dbo.USERS
        SET Role='TA',
            ClearanceLevel=3,
            TAID = SCOPE_IDENTITY()
        WHERE Username=@Username;
    END

    -------------------------------------------------
    -- TA → Instructor
    -------------------------------------------------
    ELSE IF @CurrentRole='TA' AND @NewRole='Instructor'
    BEGIN
        INSERT INTO dbo.INSTRUCTOR (FullName, Email, ClearanceLevel, IsDeleted)
        SELECT FullName, Email, 4, 0
        FROM dbo.TA
        WHERE TAID = (
            SELECT TAID FROM dbo.USERS WHERE Username=@Username
        );

        UPDATE dbo.USERS
        SET Role='Instructor',
            ClearanceLevel=4,
            InstructorID = SCOPE_IDENTITY()
        WHERE Username=@Username;
    END
    ELSE
        RAISERROR('Invalid role transition.',16,1);

    UPDATE dbo.ROLE_REQUESTS
    SET Status='Approved'
    WHERE RequestID=@RequestID;

    EXEC dbo.sp_LogAction
        @AdminUsername,
        'APPROVE_ROLE_REQUEST';
END
GO




---------------------------------------------------------
-- Admin: Deny Role Request
---------------------------------------------------------
IF OBJECT_ID('dbo.sp_RoleRequest_Deny','P') IS NOT NULL
    DROP PROCEDURE dbo.sp_RoleRequest_Deny;
GO
CREATE PROCEDURE dbo.sp_RoleRequest_Deny
(
    @AdminUsername NVARCHAR(50),
    @RequestID INT
)
AS
BEGIN
    SET NOCOUNT ON;

    EXEC dbo.sp_CheckAccess
        @AdminUsername,'Admin',4,'WRITE';

    DECLARE @Username NVARCHAR(50);

    SELECT @Username = Username
    FROM dbo.ROLE_REQUESTS
    WHERE RequestID=@RequestID AND Status='Pending';

    IF @Username IS NULL
        RAISERROR('Request not found or already processed.',16,1);

    UPDATE dbo.ROLE_REQUESTS
    SET Status='Denied'
    WHERE RequestID=@RequestID;

    DECLARE @Details NVARCHAR(200) =
        N'RequestID=' + CAST(@RequestID AS NVARCHAR(20))
        + N' User=' + @Username;

    EXEC dbo.sp_LogAction
        @AdminUsername,
        'DENY_ROLE_REQUEST',
        @Details;
END
GO


---------------------------------------------------------
-- Security Matrix View
---------------------------------------------------------
IF OBJECT_ID('dbo.vw_Security_Matrix', 'V') IS NOT NULL
    DROP VIEW dbo.vw_Security_Matrix;
GO
CREATE VIEW dbo.vw_Security_Matrix
AS
SELECT
    CAST('Admin' AS NVARCHAR(20)) AS [Role],
    CAST('Manage users, roles, approvals; CRUD on all entities via stored procedures; audit logs; highest clearance.' AS NVARCHAR(500)) AS Permissions
UNION ALL
SELECT
    'Instructor',
    'View own courses; view enrolled students; insert/update grades for own courses; view attendance for own courses.'
UNION ALL
SELECT
    'TA',
    'View assigned courses; manage attendance for assigned courses; view enrolled students (no grades access).'
UNION ALL
SELECT
    'Student',
    'View own profile; view own courses; view own grades; view own attendance; submit role upgrade request.'
UNION ALL
SELECT
    'Guestrole',
    'View public course catalog only.';
GO



---------------------------------------------------------
-- MLS Levels View
---------------------------------------------------------
IF OBJECT_ID('dbo.vw_MLS_Levels', 'V') IS NOT NULL
    DROP VIEW dbo.vw_MLS_Levels;
GO
CREATE VIEW dbo.vw_MLS_Levels
AS
SELECT CAST('COURSE' AS NVARCHAR(30)) AS ObjectName,
       1 AS ClearanceLevel,
       'Unclassified public course information.' AS Description
UNION ALL
SELECT 'STUDENT', 2, 'Confidential student personal data.'
UNION ALL
SELECT 'ROLE_REQUESTS', 2, 'Confidential role upgrade workflow data.'
UNION ALL
SELECT 'GRADES', 3, 'Secret academic performance data.'
UNION ALL
SELECT 'ATTENDANCE', 3, 'Secret attendance records.'
UNION ALL
SELECT 'TA', 3, 'Teaching assistant records.'
UNION ALL
SELECT 'INSTRUCTOR', 4, 'Instructor records.'
UNION ALL
SELECT 'USERS', 4, 'Authentication and RBAC mapping.'
UNION ALL
SELECT 'LOGS', 4, 'Audit trail.';
GO






/* =========================================================
   Part 7.0 — Open Encryption Key (safe)
   ========================================================= */
BEGIN TRY
    EXEC dbo.sp_Key_Open;
END TRY
BEGIN CATCH
END CATCH;
GO

/* =========================================================
   Part 7.1 — COURSES (5 Courses)
   ========================================================= */
DECLARE @Courses TABLE (Name NVARCHAR(100), Descr NVARCHAR(200));

INSERT INTO @Courses VALUES
(N'Database Systems', N'Relational DB, SQL'),
(N'Operating Systems', N'Processes & Memory'),
(N'Computer Networks', N'Routing & TCP/IP'),
(N'Software Engineering', N'SDLC & Design'),
(N'Information Security', N'Crypto & Access Control');

INSERT INTO dbo.COURSE (CourseName, Description, PublicInfo, ClearanceLevel, IsDeleted)
SELECT Name, Descr, N'Core Course', 1, 0
FROM @Courses c
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.COURSE WHERE CourseName = c.Name AND IsDeleted = 0
);
GO

/* =========================================================
   Part 7.2 — INSTRUCTORS + USERS (3 Instructors)
   ========================================================= */
DECLARE @Instructors TABLE
(
    FullName NVARCHAR(100),
    Email NVARCHAR(100),
    Username NVARCHAR(50)
);

INSERT INTO @Instructors VALUES
(N'Dr. Hassan', N'hassan@uni.edu', N'DrHassan'),
(N'Dr. Mona',   N'mona@uni.edu',   N'DrMona'),
(N'Dr. Karim',  N'karim@uni.edu',  N'DrKarim');

INSERT INTO dbo.INSTRUCTOR (FullName, Email, ClearanceLevel, IsDeleted)
SELECT FullName, Email, 4, 0
FROM @Instructors i
WHERE NOT EXISTS (SELECT 1 FROM dbo.INSTRUCTOR WHERE Email=i.Email);

DECLARE @U NVARCHAR(50);
DECLARE cur_ins CURSOR FOR SELECT Username FROM @Instructors;

OPEN cur_ins;
FETCH NEXT FROM cur_ins INTO @U;

WHILE @@FETCH_STATUS = 0
BEGIN
    IF NOT EXISTS (SELECT 1 FROM dbo.USERS WHERE Username=@U)
        EXEC dbo.sp_User_Register
            @Username=@U,
            @PasswordPlain=N'1234',
            @Role=N'Instructor';

    FETCH NEXT FROM cur_ins INTO @U;
END

CLOSE cur_ins;
DEALLOCATE cur_ins;
GO

/* =========================================================
   Part 7.3 — TAs + USERS (4 TAs)
   ========================================================= */
DECLARE @TAs TABLE
(
    FullName NVARCHAR(100),
    Email NVARCHAR(100),
    Username NVARCHAR(50)
);

INSERT INTO @TAs VALUES
(N'Ashraf Hamdy', N'ashraf@uni.edu', N'AshrafTA'),
(N'Sara Adel',    N'sara@uni.edu',   N'SaraTA'),
(N'Omar Nabil',   N'omar@uni.edu',   N'OmarTA'),
(N'Laila Samy',   N'laila@uni.edu',  N'LailaTA');

INSERT INTO dbo.TA (FullName, Email, ClearanceLevel, IsDeleted)
SELECT FullName, Email, 3, 0
FROM @TAs t
WHERE NOT EXISTS (SELECT 1 FROM dbo.TA WHERE Email=t.Email);

DECLARE @TAUser NVARCHAR(50);
DECLARE cur_ta CURSOR FOR SELECT Username FROM @TAs;

OPEN cur_ta;
FETCH NEXT FROM cur_ta INTO @TAUser;

WHILE @@FETCH_STATUS = 0
BEGIN
    IF NOT EXISTS (SELECT 1 FROM dbo.USERS WHERE Username=@TAUser)
        EXEC dbo.sp_User_Register
            @Username=@TAUser,
            @PasswordPlain=N'1234',
            @Role=N'TA';

    FETCH NEXT FROM cur_ta INTO @TAUser;
END

CLOSE cur_ta;
DEALLOCATE cur_ta;
GO

/* =========================================================
   Part 7.4 — RESET STUDENTS (IMPORTANT)
   ========================================================= */
DELETE FROM dbo.USERS WHERE Role = 'Student';
DELETE FROM dbo.STUDENT;
GO

/* =========================================================
   Part 7.5 — STUDENTS + USERS (20 Students)
   ========================================================= */
DECLARE @i INT = 1;

WHILE @i <= 20
BEGIN
    DECLARE @Email NVARCHAR(100) = CONCAT(N'student', @i, N'@std.edu');
    DECLARE @Name  NVARCHAR(100) = CONCAT(N'Student ', @i);
    DECLARE @User  NVARCHAR(50)  = CONCAT(N'student', @i);
    DECLARE @Phone NVARCHAR(20)  = CONCAT(N'01000000', CAST(@i AS NVARCHAR(10)));

    EXEC dbo.sp_User_Register
        @Username      = @User,
        @PasswordPlain = N'1234',
        @Role          = N'Student',
        @FullName      = @Name,
        @Email         = @Email,
        @Phone         = @Phone,
        @DOB           = '2002-01-01',
        @Department    = N'CS';

    SET @i += 1;
END
GO

/* =========================================================
   Part 7.6 — ADMIN + GUEST
   ========================================================= */
IF NOT EXISTS (SELECT 1 FROM dbo.USERS WHERE Username='IbrahimHamdy')
    EXEC dbo.sp_User_Register
        @Username='IbrahimHamdy',
        @PasswordPlain=N'1234',
        @Role=N'Admin';


IF NOT EXISTS (SELECT 1 FROM dbo.USERS WHERE Username='AhmedMostafa')
    EXEC dbo.sp_User_Register
        @Username='AhmedMostafa',
        @PasswordPlain=N'1234',
        @Role=N'Admin';
IF NOT EXISTS (SELECT 1 FROM dbo.USERS WHERE Username='Guest1')
    EXEC dbo.sp_User_Register
        @Username='Guest1',
        @PasswordPlain=N'1234',
        @Role=N'Guestrole';
GO

/* =========================================================
   Part 7.7 — ASSIGN INSTRUCTORS + TAs TO COURSES
   ========================================================= */
INSERT INTO dbo.INSTRUCTOR_COURSE
SELECT i.InstructorID, c.CourseID
FROM dbo.INSTRUCTOR i
CROSS JOIN dbo.COURSE c
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.INSTRUCTOR_COURSE ic
    WHERE ic.InstructorID=i.InstructorID AND ic.CourseID=c.CourseID
);

INSERT INTO dbo.TA_COURSE
SELECT u.Username, c.CourseID
FROM dbo.USERS u
CROSS JOIN dbo.COURSE c
WHERE u.Role='TA'
AND NOT EXISTS (
    SELECT 1 FROM dbo.TA_COURSE tc
    WHERE tc.TAUsername=u.Username AND tc.CourseID=c.CourseID
);
GO

/* =========================================================
   Part 7.8 — ENROLL STUDENTS
   ========================================================= */
INSERT INTO dbo.COURSE_STUDENT
SELECT c.CourseID, s.StudentID
FROM dbo.COURSE c
CROSS JOIN dbo.STUDENT s
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.COURSE_STUDENT cs
    WHERE cs.CourseID=c.CourseID AND cs.StudentID=s.StudentID
);
GO

/* =========================================================
   Part 7.9 — GRADES (Encrypted)
   ========================================================= */
BEGIN TRY
    EXEC dbo.sp_Key_Open;
END TRY
BEGIN CATCH
END CATCH;
GO

INSERT INTO dbo.GRADES (StudentID, CourseID, EncryptedGradeValue, IsDeleted)
SELECT
    cs.StudentID,
    cs.CourseID,
    EncryptByKey(Key_GUID('SRMSSymmetricKey'),
        CAST(60 + (ABS(CHECKSUM(NEWID())) % 41) AS NVARCHAR(5))),
    0
FROM dbo.COURSE_STUDENT cs
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.GRADES g
    WHERE g.StudentID=cs.StudentID AND g.CourseID=cs.CourseID
);
GO

/* =========================================================
   Part 7.10 — ATTENDANCE
   ========================================================= */
DECLARE @d INT = 0;
WHILE @d < 5
BEGIN
    INSERT INTO dbo.ATTENDANCE (StudentID, CourseID, Status, DateRecorded, IsDeleted)
    SELECT
        cs.StudentID,
        cs.CourseID,
        ABS(CHECKSUM(NEWID())) % 2,
        DATEADD(DAY, -@d, CAST(GETDATE() AS DATE)),
        0
    FROM dbo.COURSE_STUDENT cs
    WHERE NOT EXISTS (
        SELECT 1 FROM dbo.ATTENDANCE a
        WHERE a.StudentID=cs.StudentID
          AND a.CourseID=cs.CourseID
          AND a.DateRecorded=DATEADD(DAY, -@d, CAST(GETDATE() AS DATE))
    );
    SET @d += 1;
END
GO

/* =========================================================
   Part 7.11 — ROLE REQUESTS
   ========================================================= */
INSERT INTO dbo.ROLE_REQUESTS
(Username, CurrentRole, RequestedRole, Reason, Status)
SELECT Username, 'Student','TA','Good performance','Pending'
FROM dbo.USERS
WHERE Role='Student'
AND NOT EXISTS (
    SELECT 1 FROM dbo.ROLE_REQUESTS r
    WHERE r.Username=dbo.USERS.Username AND r.Status='Pending'
);
GO

/* =========================================================
   Part 7.12 — Close Key
   ========================================================= */
BEGIN TRY
    EXEC dbo.sp_Key_Close;
END TRY
BEGIN CATCH
END CATCH;
GO

