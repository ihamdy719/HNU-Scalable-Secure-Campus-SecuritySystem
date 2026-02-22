import tkinter as tk
from tkinter import messagebox, ttk

from session import Session
from db import call_sp_rows, call_sp_non_query, DbError

# =========================================================
# UI Colors
# =========================================================
BG = "#f5f6fa"
CARD = "#ffffff"
PRIMARY = "#2f3640"
ACCENT = "#487eb0"


# =========================================================
# TA Dashboard
# =========================================================
def open():
    if not Session.is_logged_in() or Session.role != "TA":
        messagebox.showerror("Access Denied", "Only TAs can access this dashboard.")
        return

    win = tk.Tk()
    win.title("TA Dashboard")
    win.geometry("560x460")
    win.resizable(False, False)
    win.configure(bg=BG)

    card = tk.Frame(win, bg=CARD)
    card.place(relx=0.5, rely=0.5, anchor="center", width=440, height=380)

    tk.Label(
        card,
        text=f"TA Dashboard - {Session.username}",
        font=("Arial", 16, "bold"),
        bg=CARD,
        fg=PRIMARY
    ).pack(pady=20)

    btn_style = dict(width=28, height=2, bg=ACCENT, fg="white", relief="flat")

    tk.Button(card, text="View My Courses", command=open_view_courses, **btn_style).pack(pady=8)
    tk.Button(card, text="View Students by Course", command=open_view_students, **btn_style).pack(pady=8)
    tk.Button(card, text="Manage Attendance", command=open_manage_attendance, **btn_style).pack(pady=8)

    def logout():
        Session.clear()
        win.destroy()
        import login  # noqa

    tk.Button(
        card,
        text="Logout",
        bg="#e84118",
        fg="white",
        width=28,
        height=2,
        relief="flat",
        command=logout
    ).pack(pady=12)

    win.mainloop()


# =========================================================
# 1) View Courses (sp_TA_ViewCourses)
# =========================================================
def open_view_courses():
    win = tk.Toplevel()
    win.title("My Courses")
    win.geometry("700x420")
    win.configure(bg=BG)

    tk.Label(win, text="Courses Assigned to Me", font=("Arial", 16, "bold"),
             bg=BG, fg=PRIMARY).pack(pady=15)

    try:
        courses = call_sp_rows("sp_TA_ViewCourses", (Session.username,))
    except DbError as e:
        messagebox.showerror("Error", str(e))
        return

    frame = tk.Frame(win, bg=BG)
    frame.pack()

    headers = ["CourseID", "CourseName"]
    for i, h in enumerate(headers):
        tk.Label(frame, text=h, width=30, bg=ACCENT, fg="white").grid(row=0, column=i)

    for i, c in enumerate(courses):
        tk.Label(frame, text=c["CourseID"], width=30, bg=CARD).grid(row=i+1, column=0)
        tk.Label(frame, text=c["CourseName"], width=30, bg=CARD).grid(row=i+1, column=1)


# =========================================================
# 2) View Students by Course (sp_TA_ViewStudentsByCourse)
# =========================================================
def open_view_students():
    win = tk.Toplevel()
    win.title("Students by Course")
    win.geometry("820x520")
    win.configure(bg=BG)

    tk.Label(
        win,
        text="Students in My Courses",
        font=("Arial", 16, "bold"),
        bg=BG,
        fg=PRIMARY
    ).pack(pady=15)

    # ===============================
    # Load courses for this TA
    # ===============================
    try:
        courses = call_sp_rows("sp_TA_ViewCourses", (Session.username,))
    except DbError as e:
        messagebox.showerror("Error", str(e))
        return

    if not courses:
        messagebox.showinfo("Info", "No courses assigned to you.")
        win.destroy()
        return

    course_map = {
        f"{c['CourseName']} (ID {c['CourseID']})": c["CourseID"]
        for c in courses
    }

    tk.Label(win, text="Select Course", bg=BG).pack()
    course_cb = ttk.Combobox(
        win,
        values=list(course_map.keys()),
        state="readonly",
        width=40
    )
    course_cb.pack(pady=5)

    frame = tk.Frame(win, bg=BG)
    frame.pack(pady=10)

    def load_students():
        for w in frame.winfo_children():
            w.destroy()

        if not course_cb.get():
            messagebox.showerror("Error", "Please select a course")
            return

        course_id = course_map[course_cb.get()]

        try:
            students = call_sp_rows(
                "sp_TA_ViewStudentsByCourse",
                (Session.username, course_id)
            )
        except DbError as e:
            messagebox.showerror("Error", str(e))
            return

        headers = ["StudentID", "FullName", "Email", "Department"]
        for i, h in enumerate(headers):
            tk.Label(
                frame,
                text=h,
                width=20,
                bg=ACCENT,
                fg="white"
            ).grid(row=0, column=i)

        for i, s in enumerate(students, start=1):
            tk.Label(frame, text=s["StudentID"], width=20, bg=CARD).grid(row=i, column=0)
            tk.Label(frame, text=s["FullName"], width=20, bg=CARD).grid(row=i, column=1)
            tk.Label(frame, text=s["Email"], width=20, bg=CARD).grid(row=i, column=2)
            tk.Label(frame, text=s["Department"], width=20, bg=CARD).grid(row=i, column=3)

    tk.Button(
        win,
        text="Load Students",
        bg=ACCENT,
        fg="white",
        width=20,
        command=load_students
    ).pack(pady=10)

# =========================================================
# 3) Manage Attendance
#    Insert / Update / Delete
# =========================================================
def open_manage_attendance():
    win = tk.Toplevel()
    win.title("Manage Attendance")
    win.geometry("850x520")
    win.configure(bg=BG)

    tk.Label(win, text="Attendance Records", font=("Arial", 16, "bold"),
             bg=BG, fg=PRIMARY).pack(pady=15)

    frame = tk.Frame(win, bg=BG)
    frame.pack()

    headers = ["AttendanceID", "StudentID", "CourseName", "Status", "DateRecorded"]
    for i, h in enumerate(headers):
        tk.Label(frame, text=h, width=18, bg=ACCENT, fg="white").grid(row=0, column=i)

    def load_attendance():
        for w in frame.grid_slaves():
            if int(w.grid_info()["row"]) > 0:
                w.destroy()

        try:
            rows = call_sp_rows("sp_TA_ViewAttendance", (Session.username,))
        except DbError as e:
            messagebox.showerror("Error", str(e))
            return

        for i, a in enumerate(rows):
            tk.Label(frame, text=a["AttendanceID"], width=18, bg=CARD).grid(row=i+1, column=0)
            tk.Label(frame, text=a["StudentID"], width=18, bg=CARD).grid(row=i+1, column=1)
            tk.Label(frame, text=a["CourseName"], width=18, bg=CARD).grid(row=i+1, column=2)
            tk.Label(frame, text=a["StatusText"], width=18, bg=CARD).grid(row=i+1, column=3)
            tk.Label(frame, text=a["DateRecorded"], width=18, bg=CARD).grid(row=i+1, column=4)

    load_attendance()

    btn_frame = tk.Frame(win, bg=BG)
    btn_frame.pack(pady=12)

    btn_style = dict(bg=ACCENT, fg="white", relief="flat", width=20)

    tk.Button(btn_frame, text="Refresh", command=load_attendance, **btn_style).grid(row=0, column=0, padx=5)
    tk.Button(btn_frame, text="Add Attendance",
              command=lambda: open_add_attendance(load_attendance),
              **btn_style).grid(row=0, column=1, padx=5)
    tk.Button(btn_frame, text="Update Attendance",
              command=lambda: open_update_attendance(load_attendance),
              **btn_style).grid(row=0, column=2, padx=5)
    tk.Button(btn_frame, text="Delete Attendance",
              command=lambda: open_delete_attendance(load_attendance),
              **btn_style).grid(row=0, column=3, padx=5)


# =========================================================
# Add Attendance
# =========================================================
def open_add_attendance(on_success):
    win = tk.Toplevel()
    win.title("Add Attendance")
    win.geometry("420x360")
    win.configure(bg=BG)

    tk.Label(win, text="Add Attendance", font=("Arial", 16, "bold"),
             bg=BG, fg=PRIMARY).pack(pady=15)

    try:
        students = call_sp_rows("sp_TA_ViewStudentsByCourse", (Session.username,))
        courses = call_sp_rows("sp_TA_ViewCourses", (Session.username,))
    except DbError as e:
        messagebox.showerror("Error", str(e))
        win.destroy()
        return

    student_map = {f"{s['FullName']} (ID {s['StudentID']})": s["StudentID"] for s in students}
    course_map = {f"{c['CourseName']}": c["CourseID"] for c in courses}

    ttk.Label(win, text="Student").pack()
    student_cb = ttk.Combobox(win, values=list(student_map.keys()), state="readonly", width=35)
    student_cb.pack(pady=5)

    ttk.Label(win, text="Course").pack()
    course_cb = ttk.Combobox(win, values=list(course_map.keys()), state="readonly", width=35)
    course_cb.pack(pady=5)

    ttk.Label(win, text="Status").pack()
    status_cb = ttk.Combobox(win, values=["1 (Present)", "0 (Absent)"], state="readonly", width=35)
    status_cb.pack(pady=5)

    def save():
        if not student_cb.get() or not course_cb.get() or not status_cb.get():
            messagebox.showerror("Error", "All fields required")
            return

        sid = student_map[student_cb.get()]
        cid = course_map[course_cb.get()]
        status = 1 if status_cb.get().startswith("1") else 0

        try:
            call_sp_non_query("sp_TA_RecordAttendance",
                              (Session.username, sid, cid, status))
            messagebox.showinfo("Success", "Attendance recorded")
            on_success()
            win.destroy()
        except DbError as e:
            messagebox.showerror("Error", str(e))

    tk.Button(win, text="Save", bg=ACCENT, fg="white", relief="flat",
              command=save).pack(pady=20)


# =========================================================
# Update Attendance
# =========================================================
def open_update_attendance(on_success):
    _attendance_update_delete("Update Attendance",
                              "sp_TA_UpdateAttendance",
                              on_success)


# =========================================================
# Delete Attendance
# =========================================================
def open_delete_attendance(on_success):
    _attendance_update_delete("Delete Attendance",
                              "sp_TA_DeleteAttendance",
                              on_success)


def _attendance_update_delete(title, sp_name, on_success):
    win = tk.Toplevel()
    win.title(title)
    win.geometry("420x300")
    win.configure(bg=BG)

    tk.Label(win, text=title, font=("Arial", 16, "bold"),
             bg=BG, fg=PRIMARY).pack(pady=15)

    try:
        records = call_sp_rows("sp_TA_ViewAttendance", (Session.username,))
    except DbError as e:
        messagebox.showerror("Error", str(e))
        win.destroy()
        return

    if not records:
        messagebox.showinfo("Info", "No attendance records found.")
        win.destroy()
        return

    rec_map = {
        f"ID {r['AttendanceID']} - Student {r['StudentID']} - {r['CourseName']}":
            r["AttendanceID"]
        for r in records
    }

    cb = ttk.Combobox(win, values=list(rec_map.keys()), state="readonly", width=40)
    cb.pack(pady=10)

    def act():
        if not cb.get():
            messagebox.showerror("Error", "Select a record")
            return

        aid = rec_map[cb.get()]

        try:
            call_sp_non_query(sp_name, (Session.username, aid))
            messagebox.showinfo("Success", f"{title} successful")
            on_success()
            win.destroy()
        except DbError as e:
            messagebox.showerror("Error", str(e))

    tk.Button(win, text=title.split()[0], bg=ACCENT, fg="white",
              relief="flat", command=act).pack(pady=20)
