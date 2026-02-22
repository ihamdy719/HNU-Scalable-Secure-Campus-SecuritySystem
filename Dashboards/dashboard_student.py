import tkinter as tk
from tkinter import messagebox

from session import Session
from db import call_sp_rows, call_sp_single_row, call_sp_non_query, DbError

# =========================================================
# UI COLORS
# =========================================================
BG = "#f5f6fa"
CARD = "#ffffff"
PRIMARY = "#2f3640"
ACCENT = "#487eb0"


# =========================================================
# MAIN STUDENT DASHBOARD
# =========================================================
def open():
    if not Session.is_logged_in() or Session.role != "Student":
        messagebox.showerror("Access Denied", "Students only.")
        return

    win = tk.Tk()
    win.title("Student Dashboard")
    win.geometry("550x480")
    win.resizable(False, False)
    win.configure(bg=BG)

    card = tk.Frame(win, bg=CARD, relief="flat")
    card.place(relx=0.5, rely=0.5, anchor="center", width=420, height=420)

    tk.Label(
        card,
        text=f"Welcome, {Session.username}",
        font=("Arial", 16, "bold"),
        bg=CARD,
        fg=PRIMARY
    ).pack(pady=20)

    btn = dict(width=28, height=2, bg=ACCENT, fg="white", relief="flat")

    tk.Button(card, text="View Profile", command=view_profile, **btn).pack(pady=6)
    tk.Button(card, text="Update Phone", command=update_phone, **btn).pack(pady=6)
    tk.Button(card, text="View Courses", command=view_courses, **btn).pack(pady=6)
    tk.Button(card, text="View Grades", command=view_grades, **btn).pack(pady=6)
    tk.Button(card, text="View Attendance", command=view_attendance, **btn).pack(pady=6)
    tk.Button(card, text="Request Role Upgrade", command=request_role, **btn).pack(pady=6)

    def logout():
        Session.clear()
        win.destroy()
        import login  # noqa

    tk.Button(
        card,
        text="Logout",
        width=28,
        height=2,
        bg="#e84118",
        fg="white",
        relief="flat",
        command=logout
    ).pack(pady=12)

    win.mainloop()


# =========================================================
# 1) VIEW PROFILE
# sp_Student_ViewProfile(@CurrentUsername)
# =========================================================
def view_profile():
    win = tk.Toplevel()
    win.title("My Profile")
    win.geometry("450x400")
    win.configure(bg=BG)

    tk.Label(win, text="My Profile", font=("Arial", 16, "bold"), bg=BG).pack(pady=15)

    try:
        data = call_sp_single_row(
            "sp_Student_ViewProfile",
            (Session.username,)
        )
    except DbError as e:
        messagebox.showerror("Error", str(e))
        return

    if not data:
        messagebox.showerror("Error", "Profile not found")
        return

    frame = tk.Frame(win, bg=BG)
    frame.pack(padx=20, pady=10)

    fields = [
        ("StudentID", "Student ID"),
        ("FullName", "Full Name"),
        ("Email", "Email"),
        ("Phone", "Phone"),
        ("DOB", "Date of Birth"),
        ("Department", "Department"),
    ]

    for i, (key, label) in enumerate(fields):
        tk.Label(frame, text=label + ":", bg=BG, fg=PRIMARY).grid(row=i, column=0, sticky="w", pady=4)
        tk.Label(frame, text=str(data.get(key, "")), bg=BG).grid(row=i, column=1, sticky="w", pady=4)


# =========================================================
# 2) UPDATE OWN PHONE
# sp_Student_UpdateOwnPhone(@CurrentUsername, @NewPhone)
# =========================================================
def update_phone():
    win = tk.Toplevel()
    win.title("Update Phone")
    win.geometry("350x220")
    win.configure(bg=BG)

    tk.Label(win, text="Update Phone Number", font=("Arial", 14, "bold"), bg=BG).pack(pady=15)

    tk.Label(win, text="New Phone", bg=BG).pack()
    entry = tk.Entry(win, width=30)
    entry.pack(pady=5)

    def submit():
        phone = entry.get().strip()
        if not phone:
            messagebox.showerror("Error", "Phone is required")
            return

        try:
            call_sp_non_query(
                "sp_Student_UpdateOwnPhone",
                (Session.username, phone)
            )
            messagebox.showinfo("Success", "Phone updated successfully")
            win.destroy()
        except DbError as e:
            messagebox.showerror("Error", str(e))

    tk.Button(win, text="Update", bg=ACCENT, fg="white", relief="flat", command=submit).pack(pady=15)


# =========================================================
# 3) VIEW COURSES
# sp_Student_ViewCourses(@CurrentUsername)
# =========================================================
def view_courses():
    win = tk.Toplevel()
    win.title("My Courses")
    win.geometry("650x420")
    win.configure(bg=BG)

    tk.Label(win, text="My Courses", font=("Arial", 16, "bold"), bg=BG).pack(pady=15)

    frame = tk.Frame(win, bg=BG)
    frame.pack()

    headers = ["CourseID", "CourseName", "Description"]
    for i, h in enumerate(headers):
        tk.Label(frame, text=h, width=22, bg=ACCENT, fg="white").grid(row=0, column=i)

    try:
        courses = call_sp_rows(
            "sp_Student_ViewCourses",
            (Session.username,)
        )
    except DbError as e:
        messagebox.showerror("Error", str(e))
        return

    for i, c in enumerate(courses):
        tk.Label(frame, text=c["CourseID"], width=22, bg=CARD).grid(row=i+1, column=0)
        tk.Label(frame, text=c["CourseName"], width=22, bg=CARD).grid(row=i+1, column=1)
        tk.Label(frame, text=c["Description"], width=22, bg=CARD).grid(row=i+1, column=2)


# =========================================================
# 4) VIEW GRADES
# sp_Student_ViewGrades(@CurrentUsername)
# =========================================================
def view_grades():
    win = tk.Toplevel()
    win.title("My Grades")
    win.geometry("650x420")
    win.configure(bg=BG)

    tk.Label(win, text="My Grades", font=("Arial", 16, "bold"), bg=BG).pack(pady=15)

    frame = tk.Frame(win, bg=BG)
    frame.pack()

    headers = ["CourseName", "Grade", "DateEntered"]
    for i, h in enumerate(headers):
        tk.Label(frame, text=h, width=22, bg=ACCENT, fg="white").grid(row=0, column=i)

    try:
        grades = call_sp_rows(
            "sp_Student_ViewGrades",
            (Session.username,)
        )
    except DbError as e:
        messagebox.showerror("Error", str(e))
        return

    for i, g in enumerate(grades):
        tk.Label(frame, text=g["CourseName"], width=22, bg=CARD).grid(row=i+1, column=0)
        tk.Label(frame, text=g["Grade"], width=22, bg=CARD).grid(row=i+1, column=1)
        tk.Label(frame, text=g["DateEntered"], width=22, bg=CARD).grid(row=i+1, column=2)


# =========================================================
# 5) VIEW ATTENDANCE
# sp_Student_ViewAttendance(@CurrentUsername)
# =========================================================
def view_attendance():
    win = tk.Toplevel()
    win.title("My Attendance")
    win.geometry("650x420")
    win.configure(bg=BG)

    tk.Label(win, text="My Attendance", font=("Arial", 16, "bold"), bg=BG).pack(pady=15)

    frame = tk.Frame(win, bg=BG)
    frame.pack()

    headers = ["CourseName", "Status", "DateRecorded"]
    for i, h in enumerate(headers):
        tk.Label(frame, text=h, width=22, bg=ACCENT, fg="white").grid(row=0, column=i)

    try:
        rows = call_sp_rows(
            "sp_Student_ViewAttendance",
            (Session.username,)
        )
    except DbError as e:
        messagebox.showerror("Error", str(e))
        return

    for i, a in enumerate(rows):
        tk.Label(frame, text=a["CourseName"], width=22, bg=CARD).grid(row=i+1, column=0)
        tk.Label(frame, text=a["StatusText"], width=22, bg=CARD).grid(row=i+1, column=1)
        tk.Label(frame, text=a["DateRecorded"], width=22, bg=CARD).grid(row=i+1, column=2)


# =========================================================
# 6) REQUEST ROLE UPGRADE
# sp_RoleRequest_Submit(@Username, @RequestedRole, @Reason, @Comments)
# =========================================================
def request_role():
    win = tk.Toplevel()
    win.title("Role Upgrade Request")
    win.geometry("420x380")
    win.configure(bg=BG)

    tk.Label(win, text="Request Role Upgrade", font=("Arial", 16, "bold"), bg=BG).pack(pady=15)

    tk.Label(win, text="Requested Role", bg=BG).pack()
    role_entry = tk.Entry(win, width=40)
    role_entry.pack(pady=5)

    tk.Label(win, text="Reason", bg=BG).pack()
    reason_entry = tk.Entry(win, width=40)
    reason_entry.pack(pady=5)

    tk.Label(win, text="Comments (optional)", bg=BG).pack()
    comments_entry = tk.Entry(win, width=40)
    comments_entry.pack(pady=5)

    def submit():
        role = role_entry.get().strip()
        reason = reason_entry.get().strip()
        comments = comments_entry.get().strip()

        if not role or not reason:
            messagebox.showerror("Error", "Role and reason are required")
            return

        try:
            call_sp_non_query(
                "sp_RoleRequest_Submit",
                (Session.username, role, reason, comments)
            )
            messagebox.showinfo("Success", "Role request submitted")
            win.destroy()
        except DbError as e:
            messagebox.showerror("Error", str(e))

    tk.Button(win, text="Submit", bg=ACCENT, fg="white", relief="flat", command=submit).pack(pady=20)
