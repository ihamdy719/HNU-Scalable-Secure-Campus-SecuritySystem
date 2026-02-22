# Secure Student Records Management System (SRMS)

## 📌 Project Overview

Secure Student Records Management System (SRMS) is a database-centric academic management system designed with security-first principles.

The system integrates a Python Tkinter GUI with a Microsoft SQL Server backend, where all authentication, authorization, encryption, and auditing logic are enforced inside the database layer.

The GUI acts strictly as a presentation layer.

---

## 🏗 System Architecture

Architecture Model: Database-Centric Security

* Presentation Layer: Python (Tkinter GUI)
* Security & Logic Layer: SQL Server Stored Procedures
* Encryption: AES-256 Symmetric Key
* Hashing: SHA2_256
* Access Control: RBAC + MLS (Bell–LaPadula)
* Auditing: Full action logging via LOGS table

All operations are executed through stored procedures only.
Direct table access is prohibited.

---

## 🔐 Security Models Implemented

### 1️⃣ Authentication

* Stored Procedure: `sp_User_Login`
* Password hashing using SHA2_256
* No plaintext password storage
* Authentication fully handled inside SQL Server

---

### 2️⃣ Role-Based Access Control (RBAC)

* Role hierarchy stored in `RBAC_RANK`
* Central enforcement via `sp_CheckAccess`
* One role per user
* Explicit permission validation per action

Roles:

* Admin
* Instructor
* TA
* Student
* Guest

---

### 3️⃣ Mandatory Access Control (MAC – MLS)

Bell–LaPadula Model:

Clearance Levels:

1. Public
2. Student
3. TA
4. Instructor
5. Admin

Rules:

* No Read Up
* No Write Down

Enforced inside stored procedures.

---

### 4️⃣ Cryptographic Data Protection

Encryption Hierarchy:

* Database Master Key
* Certificate
* AES-256 Symmetric Key

Encrypted Attributes:

* Usernames
* Student phone numbers
* Grades
* Sensitive classified data

Encryption/decryption is performed only inside SQL Server.

---

### 5️⃣ Auditing & Accountability

* Logging Stored Procedure: `sp_LogAction`
* Logs Table: `LOGS`
* Admin Read-Only View: `vw_Admin_Logs`
* Ensures non-repudiation and traceability

---

## 📂 Project Structure

```
Project_Data_Security/
│
├── Reports/
│   ├── report.pdf
│
│
├── Dashboards/
│   ├── dashboard_admin.py
│   ├── dashboard_guest.py
│   ├── dashboard_instructor.py
│   ├── dashboard_student.py
│   └── dashboard_ta.py
│
├── Connections_and_Database/
│   ├── db.py
│   ├── login.py
│   ├── security.py
│   ├── session.py
│   └── tempCodeRunnerFile.py
│
├── SQL Code/
│   └── SRMS_DB_FINAL.sql
│
├──  project_requirements.pdf
└── main.py
```

---

## 🗄 Database Design

Core Tables:

* USERS
* STUDENT
* INSTRUCTOR
* TA
* COURSE
* GRADES (Encrypted)
* ATTENDANCE
* COURSE_STUDENT
* INSTRUCTOR_COURSE
* TA_COURSE
* ROLE_REQUESTS
* LOGS
* RBAC_RANK

Design Principles:

* Soft Deletes
* Foreign Key Integrity
* Centralized Access Control
* Encrypted Sensitive Data
* Strict Separation of Duties

---

## ⚙️ How to Run

1. Execute `SRMS_DB_FINAL.sql` in SQL Server.
2. Configure database connection inside `db.py`.
3. Run:

```bash
python main.py
```

---

## 🎯 Key Features

* Fully centralized authentication
* Multi-level security enforcement
* Secure role upgrade workflow
* Controlled instructor/TA assignment
* Encrypted academic records
* Full audit trail
* Thin and untrusted GUI design

---

## 📚 Documentation

* `Reports/report.pdf` → Full technical documentation
* `Reports/project_requirements.pdf` → Project specification

---

## 👨‍💻 Developed For

Database Security & Secure Systems Architecture Project

---
