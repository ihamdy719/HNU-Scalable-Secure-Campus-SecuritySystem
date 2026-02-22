import tkinter as tk
from tkinter import messagebox, ttk

from session import Session
from db import call_sp_rows, call_sp_non_query, DbError

# ---------------------------------------------------------
# UI Colors
# ---------------------------------------------------------
BG = "#f5f6fa"
CARD = "#ffffff"
PRIMARY = "#2f3640"
ACCENT = "#487eb0"


# =========================================================
# Helpers
# =========================================================
def _safe_int(value: str):
    value = (value or "").strip()
    if value == "":
        return None
    return int(value)


def _safe_float(value: str):
    value = (value or "").strip()
    if value == "":
        return None
    return float(value)


def get_my_courses_basic():
    """
    Returns list of dicts: [{CourseID, CourseName}, ...]
    Uses sp_Instructor_ViewCourses (already exists) and extracts needed columns.
    If you create a dedicated SP like sp_Instructor_GetMyCourses, you can swap it here.
    """
    rows = call_sp_rows("sp_Instructor_ViewCourses", (Session.username,))
    courses = []
    for r in rows:
        courses.append({
            "CourseID": r.get("CourseID"),
            "CourseName": r.get("CourseName")
        })
    # sort by name
    courses.sort(key=lambda x: (x["CourseName"] or ""))
    return courses


def build_treeview(parent, columns, widths=None):
    """
    columns: list of (key, title)
    widths:  list of ints same length
    """
    frame = tk.Frame(parent, bg=BG)
    frame.pack(fill="both", expand=True, padx=10, pady=10)

    tree = ttk.Treeview(frame, columns=[c[0] for c in columns], show="headings", height=14)
    vsb = ttk.Scrollbar(frame, orient="vertical", command=tree.yview)
    tree.configure(yscrollcommand=vsb.set)

    tree.grid(row=0, column=0, sticky="nsew")
    vsb.grid(row=0, column=1, sticky="ns")

    frame.grid_rowconfigure(0, weight=1)
    frame.grid_columnconfigure(0, weight=1)

    for idx, (key, title) in enumerate(columns):
        tree.heading(key, text=title)
        w = widths[idx] if widths and idx < len(widths) else 140
        tree.column(key, width=w, anchor="center")

    return tree


def fill_treeview(tree, rows, keys):
    tree.delete(*tree.get_children())
    for r in rows:
        values = [r.get(k, "") for k in keys]
        tree.insert("", "end", values=values)


# =========================================================
# Main Dashboard
# =========================================================
def open():
    if not Session.is_logged_in() or Session.role != "Instructor":
        messagebox.showerror("Access Denied", "Only Instructors can access this dashboard.")
        return

    win = tk.Tk()
    win.title("Instructor Dashboard")
    win.geometry("640x600")
    win.configure(bg=BG)

    card = tk.Frame(win, bg=CARD)
    card.place(relx=0.5, rely=0.5, anchor="center", width=520, height=520)

    tk.Label(
        card,
        text=f"Instructor Dashboard - {Session.username}",
        font=("Arial", 16, "bold"),
        bg=CARD,
        fg=PRIMARY
    ).pack(pady=18)

    btn = dict(width=32, height=2, bg=ACCENT, fg="white", relief="flat")

    tk.Button(card, text="View My Courses", command=open_courses, **btn).pack(pady=6)
    tk.Button(card, text="View Students by Course", command=open_students, **btn).pack(pady=6)
    tk.Button(card, text="Manage Grades", command=open_grades, **btn).pack(pady=6)
    tk.Button(card, text="View Attendance", command=open_attendance, **btn).pack(pady=6)
    tk.Button(card, text="View Avg Grade (Safe)", command=open_avg_grade, **btn).pack(pady=6)

    tk.Button(
        card,
        text="Logout",
        bg="#e84118",
        fg="white",
        width=32,
        height=2,
        relief="flat",
        command=lambda: logout(win)
    ).pack(pady=16)

    win.mainloop()


def logout(win):
    Session.clear()
    win.destroy()
    import login  # noqa


# =========================================================
# 0) Instructor Profile (NEW)
# Depends on:
#   sp_Instructor_ViewProfile(@CurrentUsername)
#   sp_Instructor_UpdateProfile(@CurrentUsername, @FullName, @Email)
# =========================================================
def open_profile():
    win = tk.Toplevel()
    win.title("My Profile")
    win.geometry("520x360")
    win.configure(bg=BG)

    tk.Label(win, text="My Profile", font=("Arial", 16, "bold"), bg=BG, fg=PRIMARY).pack(pady=10)

    form = tk.Frame(win, bg=BG)
    form.pack(pady=10)

    tk.Label(form, text="Full Name", bg=BG).grid(row=0, column=0, sticky="w", padx=6, pady=6)
    entry_name = tk.Entry(form, width=40)
    entry_name.grid(row=0, column=1, padx=6, pady=6)

    tk.Label(form, text="Email", bg=BG).grid(row=1, column=0, sticky="w", padx=6, pady=6)
    entry_email = tk.Entry(form, width=40)
    entry_email.grid(row=1, column=1, padx=6, pady=6)

    info = tk.Label(win, text="", bg=BG, fg=PRIMARY)
    info.pack(pady=5)

    def load():
        try:
            rows = call_sp_rows("dbo.sp_Instructor_ViewProfile", (Session.username,))
            if not rows:
                messagebox.showerror("Error", "Profile not found.")
                return

            r = rows[0]
            entry_name.delete(0, tk.END)
            entry_email.delete(0, tk.END)
            entry_name.insert(0, r.get("FullName", "") or "")
            entry_email.insert(0, r.get("Email", "") or "")

            info.config(text=f"InstructorID: {r.get('InstructorID', '')}")
        except DbError as e:
            messagebox.showerror("Error", str(e))

    def update():
        fullname = entry_name.get().strip()
        email = entry_email.get().strip()

        if fullname == "" or email == "":
            messagebox.showerror("Error", "Full Name and Email are required.")
            return

        try:
            call_sp_non_query("sp_Instructor_UpdateProfile", (Session.username, fullname, email))
            messagebox.showinfo("Success", "Profile updated successfully.")
            load()
        except DbError as e:
            messagebox.showerror("Error", str(e))

    btn_row = tk.Frame(win, bg=BG)
    btn_row.pack(pady=10)

    tk.Button(btn_row, text="Load Profile", bg=ACCENT, fg="white", width=16, command=load).grid(row=0, column=0, padx=6)
    tk.Button(btn_row, text="Update Profile", bg=ACCENT, fg="white", width=16, command=update).grid(row=0, column=1, padx=6)

    load()


# =========================================================
# 1) View Instructor Courses
# =========================================================
def open_courses():
    win = tk.Toplevel()
    win.title("My Courses")
    win.geometry("860x520")
    win.configure(bg=BG)

    tk.Label(win, text="My Courses", font=("Arial", 16, "bold"), bg=BG, fg=PRIMARY).pack(pady=10)

    tree = build_treeview(
        win,
        columns=[
            ("CourseID", "CourseID"),
            ("CourseName", "Course Name"),
            ("Description", "Description"),
            ("PublicInfo", "Public Info"),
        ],
        widths=[90, 200, 260, 260]
    )

    def load():
        try:
            rows = call_sp_rows("sp_Instructor_ViewCourses", (Session.username,))
            fill_treeview(tree, rows, ["CourseID", "CourseName", "Description", "PublicInfo"])
        except DbError as e:
            messagebox.showerror("Error", str(e))

    tk.Button(win, text="Refresh", bg=ACCENT, fg="white", command=load).pack(pady=6)
    load()


# =========================================================
# 2) View Students By Course (Combobox)
# =========================================================
def open_students():
    win = tk.Toplevel()
    win.title("Students By Course")
    win.geometry("860x560")
    win.configure(bg=BG)

    tk.Label(win, text="Students By Course", font=("Arial", 16, "bold"), bg=BG, fg=PRIMARY).pack(pady=10)

    top = tk.Frame(win, bg=BG)
    top.pack(pady=6)

    tk.Label(top, text="Select Course", bg=BG).grid(row=0, column=0, padx=6, pady=6, sticky="w")

    course_cb = ttk.Combobox(top, width=40, state="readonly")
    course_cb.grid(row=0, column=1, padx=6, pady=6)

    tree = build_treeview(
        win,
        columns=[
            ("StudentID", "StudentID"),
            ("FullName", "Full Name"),
            ("Email", "Email"),
            ("Department", "Department"),
        ],
        widths=[90, 220, 280, 160]
    )

    courses = []
    try:
        courses = get_my_courses_basic()
        course_cb["values"] = [f'{c["CourseID"]} - {c["CourseName"]}' for c in courses]
        if courses:
            course_cb.current(0)
    except DbError as e:
        messagebox.showerror("Error", str(e))

    def load():
        if not courses or course_cb.current() < 0:
            messagebox.showerror("Error", "No courses available.")
            return

        cid = courses[course_cb.current()]["CourseID"]

        try:
            rows = call_sp_rows("sp_Instructor_ViewStudentsByCourse", (Session.username, cid))
            fill_treeview(tree, rows, ["StudentID", "FullName", "Email", "Department"])
        except DbError as e:
            messagebox.showerror("Error", str(e))

    tk.Button(top, text="Load", bg=ACCENT, fg="white", width=12, command=load).grid(row=0, column=2, padx=6)
    load()


# =========================================================
# 3) Manage Grades (Save/Update + Delete + View Grades By Course)
# =========================================================
def open_grades():
    win = tk.Toplevel()
    win.title("Manage Grades")
    win.geometry("920x640")
    win.configure(bg=BG)

    tk.Label(win, text="Manage Grades", font=("Arial", 16, "bold"), bg=BG, fg=PRIMARY).pack(pady=10)

    # Course selector
    top = tk.Frame(win, bg=BG)
    top.pack(pady=6)

    tk.Label(top, text="Select Course", bg=BG).grid(row=0, column=0, padx=6, pady=6, sticky="w")
    course_cb = ttk.Combobox(top, width=45, state="readonly")
    course_cb.grid(row=0, column=1, padx=6, pady=6)

    # Inputs
    form = tk.Frame(win, bg=BG)
    form.pack(pady=8)

    tk.Label(form, text="Student ID", bg=BG).grid(row=0, column=0, padx=6, pady=6, sticky="w")
    entry_sid = tk.Entry(form, width=24)
    entry_sid.grid(row=0, column=1, padx=6, pady=6)

    tk.Label(form, text="Grade", bg=BG).grid(row=0, column=2, padx=6, pady=6, sticky="w")
    entry_grade = tk.Entry(form, width=24)
    entry_grade.grid(row=0, column=3, padx=6, pady=6)

    # Tree (grades list)
    tree = build_treeview(
        win,
        columns=[
            ("GradeID", "GradeID"),
            ("StudentID", "StudentID"),
            ("FullName", "Student Name"),
            ("Grade", "Grade"),
            ("DateEntered", "Date Entered"),
        ],
        widths=[80, 90, 220, 90, 200]
    )

    courses = []
    try:
        courses = get_my_courses_basic()
        course_cb["values"] = [f'{c["CourseID"]} - {c["CourseName"]}' for c in courses]
        if courses:
            course_cb.current(0)
    except DbError as e:
        messagebox.showerror("Error", str(e))

    def selected_course_id():
        if not courses or course_cb.current() < 0:
            return None
        return courses[course_cb.current()]["CourseID"]

    def load_grades():
        cid = selected_course_id()
        if cid is None:
            messagebox.showerror("Error", "No course selected.")
            return
        try:
            rows = call_sp_rows("sp_Instructor_ViewGradesByCourse", (Session.username, cid))
            fill_treeview(tree, rows, ["GradeID", "StudentID", "FullName", "Grade", "DateEntered"])
        except DbError as e:
            messagebox.showerror("Error", str(e))

    def save_update():
        cid = selected_course_id()
        if cid is None:
            messagebox.showerror("Error", "No course selected.")
            return

        try:
            sid = _safe_int(entry_sid.get())
            grade = _safe_float(entry_grade.get())
        except ValueError:
            messagebox.showerror("Error", "StudentID must be integer, Grade must be numeric.")
            return

        if sid is None or grade is None:
            messagebox.showerror("Error", "StudentID and Grade are required.")
            return

        try:
            call_sp_non_query("sp_Instructor_SaveGrade", (Session.username, sid, cid, grade))
            messagebox.showinfo("Success", "Grade saved/updated successfully.")
            load_grades()
        except DbError as e:
            messagebox.showerror("Error", str(e))

    def delete_grade():
        cid = selected_course_id()
        if cid is None:
            messagebox.showerror("Error", "No course selected.")
            return

        try:
            sid = _safe_int(entry_sid.get())
        except ValueError:
            messagebox.showerror("Error", "StudentID must be integer.")
            return

        if sid is None:
            messagebox.showerror("Error", "StudentID is required.")
            return

        try:
            call_sp_non_query("sp_Instructor_DeleteGrade", (Session.username, sid, cid))
            messagebox.showinfo("Success", "Grade deleted (soft delete).")
            load_grades()
        except DbError as e:
            messagebox.showerror("Error", str(e))

    # Click row -> fill StudentID + Grade
    def on_tree_select(_event):
        sel = tree.selection()
        if not sel:
            return
        vals = tree.item(sel[0], "values")
        # columns: GradeID, StudentID, FullName, Grade, DateEntered
        if len(vals) >= 4:
            entry_sid.delete(0, tk.END)
            entry_grade.delete(0, tk.END)
            entry_sid.insert(0, vals[1])
            entry_grade.insert(0, vals[3])

    tree.bind("<<TreeviewSelect>>", on_tree_select)

    btns = tk.Frame(win, bg=BG)
    btns.pack(pady=8)

    tk.Button(btns, text="Refresh Course Grades", bg=ACCENT, fg="white", width=20, command=load_grades).grid(row=0, column=0, padx=6)
    tk.Button(btns, text="Save / Update", bg=ACCENT, fg="white", width=16, command=save_update).grid(row=0, column=1, padx=6)
    tk.Button(btns, text="Delete Grade", bg="#e84118", fg="white", width=16, command=delete_grade).grid(row=0, column=2, padx=6)

    # Load initial
    load_grades()


# =========================================================
# 4) View Attendance By Course (Combobox + StatusText Fix)
# =========================================================
def open_attendance():
    win = tk.Toplevel()
    win.title("Attendance By Course")
    win.geometry("920x560")
    win.configure(bg=BG)

    tk.Label(win, text="Attendance By Course", font=("Arial", 16, "bold"), bg=BG, fg=PRIMARY).pack(pady=10)

    top = tk.Frame(win, bg=BG)
    top.pack(pady=6)

    tk.Label(top, text="Select Course", bg=BG).grid(row=0, column=0, padx=6, pady=6, sticky="w")
    course_cb = ttk.Combobox(top, width=45, state="readonly")
    course_cb.grid(row=0, column=1, padx=6, pady=6)

    tree = build_treeview(
        win,
        columns=[
            ("AttendanceID", "AttendanceID"),
            ("StudentID", "StudentID"),
            ("FullName", "Student Name"),
            ("StatusText", "Status"),
            ("DateRecorded", "Date Recorded"),
        ],
        widths=[100, 90, 220, 110, 200]
    )

    courses = []
    try:
        courses = get_my_courses_basic()
        course_cb["values"] = [f'{c["CourseID"]} - {c["CourseName"]}' for c in courses]
        if courses:
            course_cb.current(0)
    except DbError as e:
        messagebox.showerror("Error", str(e))

    def load():
        if not courses or course_cb.current() < 0:
            messagebox.showerror("Error", "No courses available.")
            return

        cid = courses[course_cb.current()]["CourseID"]

        try:
            rows = call_sp_rows("sp_Instructor_ViewAttendanceByCourse", (Session.username, cid))

            # Your SP returns Status BIT. We generate StatusText here.
            normalized = []
            for r in rows:
                status_val = r.get("Status", 0)
                status_text = "Present" if int(status_val) == 1 else "Absent"
                normalized.append({
                    "AttendanceID": r.get("AttendanceID"),
                    "StudentID": r.get("StudentID"),
                    "FullName": r.get("FullName", ""),
                    "StatusText": status_text,
                    "DateRecorded": r.get("DateRecorded")
                })

            fill_treeview(tree, normalized, ["AttendanceID", "StudentID", "FullName", "StatusText", "DateRecorded"])
        except DbError as e:
            messagebox.showerror("Error", str(e))

    tk.Button(top, text="Load", bg=ACCENT, fg="white", width=12, command=load).grid(row=0, column=2, padx=6)
    load()


# =========================================================
# 5) Avg Grade (Inference Safe) (Combobox)
# =========================================================
def open_avg_grade():
    win = tk.Toplevel()
    win.title("Average Grade (Safe)")
    win.geometry("520x280")
    win.configure(bg=BG)

    tk.Label(win, text="Average Grade (Inference Safe)", font=("Arial", 14, "bold"), bg=BG, fg=PRIMARY).pack(pady=10)

    box = tk.Frame(win, bg=BG)
    box.pack(pady=10)

    tk.Label(box, text="Select Course", bg=BG).grid(row=0, column=0, padx=6, pady=6, sticky="w")
    course_cb = ttk.Combobox(box, width=45, state="readonly")
    course_cb.grid(row=0, column=1, padx=6, pady=6)

    result_lbl = tk.Label(win, text="", bg=BG, fg=PRIMARY, font=("Arial", 12, "bold"))
    result_lbl.pack(pady=10)

    courses = []
    try:
        courses = get_my_courses_basic()
        course_cb["values"] = [f'{c["CourseID"]} - {c["CourseName"]}' for c in courses]
        if courses:
            course_cb.current(0)
    except DbError as e:
        messagebox.showerror("Error", str(e))

    def calc():
        if not courses or course_cb.current() < 0:
            messagebox.showerror("Error", "No course selected.")
            return

        cid = courses[course_cb.current()]["CourseID"]

        try:
            rows = call_sp_rows("sp_Get_AvgGrade_Safe", (Session.username, cid))
            if not rows:
                result_lbl.config(text="No result returned.")
                return
            avg = rows[0].get("AvgGrade", None)
            if avg is None:
                result_lbl.config(text="AvgGrade is NULL.")
                return
            result_lbl.config(text=f"Average Grade = {float(avg):.2f}")
        except DbError as e:
            messagebox.showerror("Error", str(e))

    tk.Button(win, text="Calculate", bg=ACCENT, fg="white", width=18, command=calc).pack(pady=10)
    calc()


# =========================================================
# Run manually if needed:
# open()
# =========================================================
