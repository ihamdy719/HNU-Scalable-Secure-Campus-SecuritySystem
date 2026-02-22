# =========================================================
# Admin Dashboard
# =========================================================
# Role: Admin only
# Uses ONLY:
#   - Stored Procedures (CRUD, Assignments, Role Requests)
#   - Read-only Admin Views
# =========================================================

import tkinter as tk
from tkinter import messagebox, ttk

from session import Session
from db import call_sp_rows, call_sp_non_query, execute_query, DbError

# ---------------------------------------------------------
# UI Colors
# ---------------------------------------------------------
BG = "#f5f6fa"
CARD = "#ffffff"
PRIMARY = "#2f3640"
ACCENT = "#487eb0"


# =========================================================
# Main Admin Window
# =========================================================
def open():
    if not Session.is_logged_in() or Session.role != "Admin":
        messagebox.showerror("Access Denied", "Admin only.")
        return

    win = tk.Tk()
    win.title("Admin Dashboard")
    win.geometry("760x560")
    win.configure(bg=BG)
    win.resizable(False, False)

    tk.Label(
        win,
        text=f"Admin Dashboard – {Session.username}",
        font=("Arial", 20, "bold"),
        bg=ACCENT,
        fg="white"
    ).pack(fill="x")

    card = tk.Frame(win, bg=CARD)
    card.place(relx=0.5, rely=0.55, anchor="center", width=640, height=460)

    btn = dict(width=35, height=2, bg=ACCENT, fg="white", relief="flat")

    tk.Button(card, text="Manage Users", command=open_manage_users, **btn).pack(pady=6)
    tk.Button(card, text="Role Requests", command=open_role_requests, **btn).pack(pady=6)
    tk.Button(card, text="Manage Courses", command=open_manage_courses, **btn).pack(pady=6)
    tk.Button(card, text="Assignments (Instructor / TA / Student)", command=open_assignments, **btn).pack(pady=6)
    tk.Button(card, text="View Logs (Read Only)", command=open_logs, **btn).pack(pady=6)

    tk.Button(
        win, text="Logout",
        bg="#e84118", fg="white", width=12, relief="flat",
        command=lambda: (Session.clear(), win.destroy(), __import__("login"))
    ).place(x=630, y=10)

    win.mainloop()


# =========================================================
# USERS
# =========================================================
def open_manage_users():
    win = tk.Toplevel()
    win.title("Users")
    win.geometry("700x420")
    win.configure(bg=BG)

    tk.Label(
        win,
        text="System Users",
        font=("Arial", 16, "bold"),
        bg=BG
    ).pack(pady=10)

    try:
        users = call_sp_rows("sp_User_GetAll", (Session.username,))
    except DbError as e:
        messagebox.showerror("Error", str(e))
        return

    # ===== Scrollable Area =====
    canvas = tk.Canvas(win, bg=BG, highlightthickness=0)
    scrollbar = tk.Scrollbar(win, orient="vertical", command=canvas.yview)

    scrollable_frame = tk.Frame(canvas, bg=BG)

    scrollable_frame.bind(
        "<Configure>",
        lambda e: canvas.configure(scrollregion=canvas.bbox("all"))
    )

    canvas.create_window((0, 0), window=scrollable_frame, anchor="nw")
    canvas.configure(yscrollcommand=scrollbar.set)

    canvas.pack(side="left", fill="both", expand=True)
    scrollbar.pack(side="right", fill="y")

    frame = scrollable_frame
    # ==========================

    headers = ["Username", "Role", "ClearanceLevel"]
    for i, h in enumerate(headers):
        tk.Label(
            frame,
            text=h,
            width=20,
            bg=ACCENT,
            fg="white"
        ).grid(row=0, column=i)

    for r, u in enumerate(users, start=1):
        tk.Label(frame, text=u["Username"], width=20, bg=CARD).grid(row=r, column=0)
        tk.Label(frame, text=u["Role"], width=20, bg=CARD).grid(row=r, column=1)
        tk.Label(frame, text=u["ClearanceLevel"], width=20, bg=CARD).grid(row=r, column=2)

    tk.Button(win, text="Add User", bg=ACCENT, fg="white", command=open_add_user).pack(pady=5)
    tk.Button(win, text="Change User Role", bg=ACCENT, fg="white", command=open_edit_user).pack(pady=5)
    tk.Button(win, text="Delete User", bg=ACCENT, fg="white", command=open_delete_user).pack(pady=5)

def open_add_user():
    win = tk.Toplevel()
    win.title("Add User")
    win.geometry("450x520")
    win.configure(bg=BG)

    tk.Label(
        win,
        text="Register User",
        font=("Arial", 16, "bold"),
        bg=BG
    ).pack(pady=10)

    # =========================
    # Common Fields
    # =========================
    tk.Label(win, text="Username", bg=BG).pack()
    e_username = tk.Entry(win, width=35)
    e_username.pack(pady=3)

    tk.Label(win, text="Password", bg=BG).pack()
    e_password = tk.Entry(win, width=35, show="*")
    e_password.pack(pady=3)

    # =========================
    # Role Dropdown
    # =========================
    tk.Label(win, text="Role", bg=BG).pack()
    role_var = tk.StringVar()
    cb_role = ttk.Combobox(
        win,
        textvariable=role_var,
        state="readonly",
        values=["Admin", "Instructor", "TA", "Student", "Guestrole"],
        width=32
    )
    cb_role.pack(pady=4)

    # =========================
    # Extra Fields Frame
    # =========================
    extra_frame = tk.Frame(win, bg=BG)
    extra_frame.pack(pady=10, fill="x")

    def clear_extra():
        for w in extra_frame.winfo_children():
            w.destroy()

    # =========================
    # Dynamic Fields by Role
    # =========================
    def on_role_change(event=None):
        clear_extra()
        role = role_var.get()

        if role in ("Student", "Instructor", "TA"):
            tk.Label(extra_frame, text="Full Name", bg=BG).pack()
            e_fullname = tk.Entry(extra_frame, width=35)
            e_fullname.pack(pady=3)

            tk.Label(extra_frame, text="Email", bg=BG).pack()
            e_email = tk.Entry(extra_frame, width=35)
            e_email.pack(pady=3)

            if role == "Student":
                tk.Label(extra_frame, text="Phone", bg=BG).pack()
                e_phone = tk.Entry(extra_frame, width=35)
                e_phone.pack(pady=3)

                tk.Label(extra_frame, text="Date of Birth (YYYY-MM-DD)", bg=BG).pack()
                e_dob = tk.Entry(extra_frame, width=35)
                e_dob.pack(pady=3)

                tk.Label(extra_frame, text="Department", bg=BG).pack()
                e_dept = tk.Entry(extra_frame, width=35)
                e_dept.pack(pady=3)

                extra_frame.entries = {
                    "FullName": e_fullname,
                    "Email": e_email,
                    "Phone": e_phone,
                    "DOB": e_dob,
                    "Department": e_dept
                }
            else:
                extra_frame.entries = {
                    "FullName": e_fullname,
                    "Email": e_email
                }
        else:
            extra_frame.entries = {}

    cb_role.bind("<<ComboboxSelected>>", on_role_change)

    # =========================
    # Register Logic
    # =========================
    def register():
        try:
            role = role_var.get()

            if not role:
                messagebox.showerror("Error", "Please select a role")
                return

            # -------------------------
            # Admin → sp_Admin_CreateUser
            # -------------------------
            if role == "Admin":
                call_sp_non_query(
                    "sp_Admin_CreateUser",
                    (
                        Session.username,
                        e_username.get().strip(),
                        e_password.get().strip(),
                        role
                    )
                )

            # -------------------------
            # Others → sp_User_Register
            # -------------------------
            else:
                data = extra_frame.entries

                call_sp_non_query(
                    "sp_User_Register",
                    (
                        e_username.get().strip(),
                        e_password.get().strip(),
                        role,
                        data.get("FullName").get().strip() if "FullName" in data else None,
                        data.get("Email").get().strip() if "Email" in data else None,
                        data.get("Phone").get().strip() if "Phone" in data else None,
                        data.get("DOB").get().strip() if "DOB" in data else None,
                        data.get("Department").get().strip() if "Department" in data else None,
                    )
                )

            messagebox.showinfo("Success", "User created successfully")
            win.destroy()

        except DbError as e:
            messagebox.showerror("Error", str(e))

    tk.Button(
        win,
        text="Create User",
        bg=ACCENT,
        fg="white",
        width=20,
        command=register
    ).pack(pady=15)
def open_edit_user():
    win = tk.Toplevel()
    win.title("Change Role")
    win.geometry("350x260")
    win.configure(bg=BG)

    tk.Label(
        win,
        text="Change User Role",
        font=("Arial", 14, "bold"),
        bg=BG
    ).pack(pady=10)

    tk.Label(win, text="Username", bg=BG).pack()
    e_user = tk.Entry(win, width=30)
    e_user.pack()

    tk.Label(win, text="New Role", bg=BG).pack()
    e_role = tk.Entry(win, width=30)
    e_role.pack()

    def update():
        try:
            call_sp_non_query(
                "sp_User_UpdateRole",
                (Session.username, e_user.get().strip(), e_role.get().strip())
            )
            messagebox.showinfo("Success", "Role updated successfully")
            win.destroy()
        except DbError as e:
            messagebox.showerror("Error", str(e))

    tk.Button(
        win,
        text="Update",
        bg=ACCENT,
        fg="white",
        command=update
    ).pack(pady=15)
def open_delete_user():
    win = tk.Toplevel()
    win.title("Delete User")
    win.geometry("300x200")
    win.configure(bg=BG)

    tk.Label(
        win,
        text="Delete User",
        font=("Arial", 14, "bold"),
        bg=BG
    ).pack(pady=10)

    entry_user = tk.Entry(win, width=30)
    entry_user.pack(pady=5)

    def delete():
        try:
            call_sp_non_query(
                "sp_User_Delete",
                (Session.username, entry_user.get().strip())
            )
            messagebox.showinfo("Deleted", "User removed successfully")
            win.destroy()
        except DbError as err:
            messagebox.showerror("Error", str(err))

    tk.Button(
        win,
        text="Delete",
        bg="#e84118",
        fg="white",
        command=delete
    ).pack(pady=15)

# =========================================================
# MANAGE COURSES (ADMIN) – BUTTONS INSIDE
# =========================================================
def open_manage_courses():
    win = tk.Toplevel()
    win.title("Manage Courses")
    win.geometry("1050x520")
    win.configure(bg=BG)

    tk.Label(win, text="Manage Courses", font=("Arial", 16, "bold"), bg=BG)\
        .pack(pady=10)

    selected_course = {}

    # ===============================
    # Table + Scrollbar
    # ===============================
    table_frame = tk.Frame(win, bg=BG)
    table_frame.pack(fill="both", expand=True, padx=10)

    canvas = tk.Canvas(table_frame, bg=BG)
    scrollbar = tk.Scrollbar(table_frame, orient="vertical", command=canvas.yview)
    scrollable = tk.Frame(canvas, bg=BG)

    scrollable.bind(
        "<Configure>",
        lambda e: canvas.configure(scrollregion=canvas.bbox("all"))
    )

    canvas.create_window((0, 0), window=scrollable, anchor="nw")
    canvas.configure(yscrollcommand=scrollbar.set)

    canvas.pack(side="left", fill="both", expand=True)
    scrollbar.pack(side="right", fill="y")

    headers = [
        "CourseID", "CourseName", "Description",
        "PublicInfo", "ClearanceLevel", "IsDeleted"
    ]

    def load_courses():
        for w in scrollable.winfo_children():
            w.destroy()

        for c, h in enumerate(headers):
            tk.Label(scrollable, text=h, width=18, bg=ACCENT, fg="white")\
                .grid(row=0, column=c)

        courses = call_sp_rows("sp_Admin_GetCourses", (Session.username,))

        for r, course in enumerate(courses, start=1):
            for c, key in enumerate(headers):
                lbl = tk.Label(
                    scrollable,
                    text=course[key],
                    width=18,
                    bg=CARD
                )
                lbl.grid(row=r, column=c)

                lbl.bind(
                    "<Button-1>",
                    lambda e, cr=course: select_course(cr)
                )

    def select_course(course):
        selected_course.clear()
        selected_course.update(course)
        info_label.config(
            text=f"Selected Course: {course['CourseID']} - {course['CourseName']}"
        )

    load_courses()

    info_label = tk.Label(
        win,
        text="No course selected",
        bg=BG,
        fg="black",
        font=("Arial", 10, "italic")
    )
    info_label.pack(pady=5)
    # ===============================
    # Buttons (INSIDE SAME SCREEN)
    # ===============================
    btn_frame = tk.Frame(win, bg=BG)
    btn_frame.pack(pady=15)

    tk.Button(
        btn_frame,
        text="Add Course",
        width=18,
        bg=ACCENT,
        fg="white",
        command=lambda: add_course(load_courses)
    ).grid(row=0, column=0, padx=8)

    tk.Button(
        btn_frame,
        text="Edit Selected",
        width=18,
        bg=ACCENT,
        fg="white",
        command=lambda: edit_selected_course(selected_course, load_courses)
    ).grid(row=0, column=1, padx=8)

    tk.Button(
        btn_frame,
        text="Delete Selected",
        width=18,
        bg="#e84118",
        fg="white",
        command=lambda: delete_selected_course(selected_course, load_courses)
    ).grid(row=0, column=2, padx=8)
    
    
    
    
    
def add_course(refresh):
    win = tk.Toplevel()
    win.title("Add Course")
    win.geometry("420x350")
    win.configure(bg=BG)

    tk.Label(win, text="Add Course", font=("Arial", 14, "bold"), bg=BG).pack(pady=10)

    fields = {}
    for lbl in ["Course Name", "Description", "Public Info"]:
        tk.Label(win, text=lbl, bg=BG).pack()
        e = tk.Entry(win, width=40)
        e.pack(pady=5)
        fields[lbl] = e

    def save():
        call_sp_non_query(
            "sp_Admin_CreateCourse",
            (
                Session.username,
                fields["Course Name"].get().strip(),
                fields["Description"].get().strip() or None,
                fields["Public Info"].get().strip() or None
            )
        )
        messagebox.showinfo("Success", "Course added successfully")
        win.destroy()
        refresh()

    tk.Button(win, text="Save", bg=ACCENT, fg="white", command=save)\
        .pack(pady=15)
def edit_selected_course(course, refresh):
    if not course:
        messagebox.showwarning("Select Course", "Please select a course first.")
        return

    win = tk.Toplevel()
    win.title("Edit Course")
    win.geometry("420x360")
    win.configure(bg=BG)

    tk.Label(win, text="Edit Course", font=("Arial", 14, "bold"), bg=BG).pack(pady=10)

    e_name = tk.Entry(win, width=40)
    e_name.insert(0, course["CourseName"])
    e_name.pack(pady=5)

    e_desc = tk.Entry(win, width=40)
    e_desc.insert(0, course["Description"] or "")
    e_desc.pack(pady=5)

    e_info = tk.Entry(win, width=40)
    e_info.insert(0, course["PublicInfo"] or "")
    e_info.pack(pady=5)

    def update():
        call_sp_non_query(
            "sp_Admin_UpdateCourse",
            (
                Session.username,
                course["CourseID"],
                e_name.get().strip(),
                e_desc.get().strip() or None,
                e_info.get().strip() or None
            )
        )
        messagebox.showinfo("Success", "Course updated successfully")
        win.destroy()
        refresh()

    tk.Button(win, text="Update", bg=ACCENT, fg="white", command=update)\
        .pack(pady=15)
def delete_selected_course(course, refresh):
    if not course:
        messagebox.showwarning("Select Course", "Please select a course first.")
        return

    if not messagebox.askyesno(
        "Confirm Delete",
        f"Delete course '{course['CourseName']}'?"
    ):
        return

    call_sp_non_query(
        "sp_Admin_DeleteCourse",
        (
            Session.username,
            course["CourseID"]
        )
    )

    messagebox.showinfo("Deleted", "Course deleted successfully")
    refresh()

# =========================================================
# ASSIGNMENTS
# =========================================================
import tkinter as tk
from tkinter import ttk, messagebox

# =========================================================
# ASSIGNMENTS (MAIN WINDOW)
# =========================================================
def open_assignments():
    win = tk.Toplevel()
    win.title("Assignments")
    win.geometry("520x260")
    win.configure(bg=BG)

    tk.Label(
        win, text="Assignments Management",
        font=("Arial", 16, "bold"), bg=BG
    ).pack(pady=15)

    btn_frame = tk.Frame(win, bg=BG)
    btn_frame.pack(pady=10)

    tk.Button(
        btn_frame, text="Assign / Unassign Instructor",
        width=30, bg=ACCENT, fg="white",
        command=open_instructor_assignments
    ).grid(row=0, column=0, padx=10, pady=8)

    tk.Button(
        btn_frame, text="Assign / Unassign TA",
        width=30, bg=ACCENT, fg="white",
        command=open_ta_assignments
    ).grid(row=1, column=0, padx=10, pady=8)

    tk.Button(
        btn_frame, text="Enroll / Remove Student",
        width=30, bg=ACCENT, fg="white",
        command=open_enrollment_management
    ).grid(row=2, column=0, padx=10, pady=8)


# -----------------------------
# Helpers
# -----------------------------
def _friendly_db_error(e: Exception) -> str:
    """
    يحاول يطلع message واضح من DbError بدل الشكل الطويل.
    """
    msg = str(e)
    # غالباً DbError بيكون: "Non-query failed: (... SQL Server]MESSAGE (50000) ...)"
    # هنحاول نطلع الجزء اللي قبل (50000) لو موجود
    if "]" in msg:
        # خدي آخر جزء بعد آخر ]
        msg2 = msg.split("]")[-1].strip()
        if msg2:
            msg = msg2
    return msg


def _load_courses():
    rows = call_sp_rows("sp_Admin_GetCourses", (Session.username,))
    # E7 بيرجع CourseID, CourseName
    return [(r["CourseID"], r["CourseName"]) for r in rows]


def _load_instructors():
    rows = call_sp_rows("sp_Admin_GetInstructors", (Session.username,))
    # E9 بيرجع InstructorID, FullName
    return [(r["InstructorID"], r["FullName"]) for r in rows]


def _load_tas():
    rows = call_sp_rows("sp_Admin_GetTAs", (Session.username,))
    # E10 بيرجع Username
    return [r["Username"] for r in rows]


def _load_students():
    rows = call_sp_rows("sp_Admin_GetStudents", (Session.username,))
    # E8 بيرجع StudentID, FullName
    return [(r["StudentID"], r["FullName"]) for r in rows]


def _combo_set_values(combo: ttk.Combobox, values):
    combo["values"] = values
    if values:
        combo.current(0)


# =========================================================
# Instructor Assignments Window
# =========================================================
def open_instructor_assignments():
    win = tk.Toplevel()
    win.title("Instructor Assignments")
    win.geometry("760x520")
    win.configure(bg=BG)

    tk.Label(win, text="Assign / Unassign Instructor", font=("Arial", 16, "bold"), bg=BG).pack(pady=10)

    # Top form
    top = tk.Frame(win, bg=BG)
    top.pack(fill="x", padx=12, pady=6)

    tk.Label(top, text="Instructor", bg=BG).grid(row=0, column=0, sticky="w")
    cb_instructor = ttk.Combobox(top, state="readonly", width=35)
    cb_instructor.grid(row=1, column=0, padx=(0, 14), pady=4)

    tk.Label(top, text="Course", bg=BG).grid(row=0, column=1, sticky="w")
    cb_course = ttk.Combobox(top, state="readonly", width=35)
    cb_course.grid(row=1, column=1, pady=4)

    # Table
    table_frame = tk.Frame(win, bg=BG)
    table_frame.pack(fill="both", expand=True, padx=12, pady=10)

    cols = ("InstructorID", "InstructorName", "CourseID", "CourseName")
    tree = ttk.Treeview(table_frame, columns=cols, show="headings", height=12)

    for c in cols:
        tree.heading(c, text=c)
        tree.column(c, width=160 if c in ("InstructorName", "CourseName") else 110, anchor="center")

    vsb = ttk.Scrollbar(table_frame, orient="vertical", command=tree.yview)
    tree.configure(yscrollcommand=vsb.set)

    tree.grid(row=0, column=0, sticky="nsew")
    vsb.grid(row=0, column=1, sticky="ns")

    table_frame.grid_rowconfigure(0, weight=1)
    table_frame.grid_columnconfigure(0, weight=1)

    # Buttons
    btns = tk.Frame(win, bg=BG)
    btns.pack(pady=8)

    def refresh():
        # Load dropdowns
        try:
            instructors = _load_instructors()
            courses = _load_courses()

            _combo_set_values(cb_instructor, [f"{iid} - {name}" for iid, name in instructors])
            _combo_set_values(cb_course, [f"{cid} - {cname}" for cid, cname in courses])

            # Load table
            for item in tree.get_children():
                tree.delete(item)

            assignments = call_sp_rows("sp_Admin_GetInstructorAssignments", (Session.username,))
            for a in assignments:
                tree.insert(
                    "", "end",
                    values=(a["InstructorID"], a["InstructorName"], a["CourseID"], a["CourseName"])
                )

        except DbError as e:
            messagebox.showerror("Error", _friendly_db_error(e))

    def assign():
        try:
            if not cb_instructor.get() or not cb_course.get():
                messagebox.showerror("Error", "Please select instructor and course.")
                return

            instructor_id = int(cb_instructor.get().split("-")[0].strip())
            course_id = int(cb_course.get().split("-")[0].strip())

            call_sp_non_query(
                "sp_Admin_AssignInstructorToCourse",
                (Session.username, instructor_id, course_id)
            )
            messagebox.showinfo("Success", "Instructor assigned successfully.")
            refresh()

        except DbError as e:
            # هنا بالذات لو already assigned هتظهر كرسالة بدل crash
            messagebox.showerror("Error", _friendly_db_error(e))
        except ValueError:
            messagebox.showerror("Error", "Invalid selection values.")

    def unassign_selected():
        try:
            sel = tree.selection()
            if not sel:
                messagebox.showerror("Error", "Select an assignment row first.")
                return

            vals = tree.item(sel[0], "values")
            instructor_id = int(vals[0])
            course_id = int(vals[2])

            call_sp_non_query(
                "sp_Admin_UnassignInstructorFromCourse",
                (Session.username, instructor_id, course_id)
            )
            messagebox.showinfo("Success", "Instructor unassigned successfully.")
            refresh()

        except DbError as e:
            messagebox.showerror("Error", _friendly_db_error(e))
        except Exception as e:
            messagebox.showerror("Error", str(e))

    tk.Button(btns, text="Assign", bg=ACCENT, fg="white", width=16, command=assign).grid(row=0, column=0, padx=8)
    tk.Button(btns, text="Unassign (Selected)", bg="#e84118", fg="white", width=16, command=unassign_selected).grid(row=0, column=1, padx=8)
    tk.Button(btns, text="Refresh", bg="#353b48", fg="white", width=16, command=refresh).grid(row=0, column=2, padx=8)

    refresh()


# =========================================================
# TA Assignments Window
# =========================================================
def open_ta_assignments():
    win = tk.Toplevel()
    win.title("TA Assignments")
    win.geometry("720x520")
    win.configure(bg=BG)

    tk.Label(win, text="Assign / Unassign TA", font=("Arial", 16, "bold"), bg=BG).pack(pady=10)

    top = tk.Frame(win, bg=BG)
    top.pack(fill="x", padx=12, pady=6)

    tk.Label(top, text="TA Username", bg=BG).grid(row=0, column=0, sticky="w")
    cb_ta = ttk.Combobox(top, state="readonly", width=35)
    cb_ta.grid(row=1, column=0, padx=(0, 14), pady=4)

    tk.Label(top, text="Course", bg=BG).grid(row=0, column=1, sticky="w")
    cb_course = ttk.Combobox(top, state="readonly", width=35)
    cb_course.grid(row=1, column=1, pady=4)

    table_frame = tk.Frame(win, bg=BG)
    table_frame.pack(fill="both", expand=True, padx=12, pady=10)

    cols = ("TAUsername", "CourseID", "CourseName")
    tree = ttk.Treeview(table_frame, columns=cols, show="headings", height=12)
    for c in cols:
        tree.heading(c, text=c)
        tree.column(c, width=220 if c in ("TAUsername", "CourseName") else 110, anchor="center")

    vsb = ttk.Scrollbar(table_frame, orient="vertical", command=tree.yview)
    tree.configure(yscrollcommand=vsb.set)

    tree.grid(row=0, column=0, sticky="nsew")
    vsb.grid(row=0, column=1, sticky="ns")
    table_frame.grid_rowconfigure(0, weight=1)
    table_frame.grid_columnconfigure(0, weight=1)

    btns = tk.Frame(win, bg=BG)
    btns.pack(pady=8)

    def refresh():
        try:
            tas = _load_tas()
            courses = _load_courses()

            _combo_set_values(cb_ta, tas)
            _combo_set_values(cb_course, [f"{cid} - {cname}" for cid, cname in courses])

            for item in tree.get_children():
                tree.delete(item)

            assignments = call_sp_rows("sp_Admin_GetTAAssignments", (Session.username,))
            for a in assignments:
                tree.insert("", "end", values=(a["TAUsername"], a["CourseID"], a["CourseName"]))

        except DbError as e:
            messagebox.showerror("Error", _friendly_db_error(e))

    def assign():
        try:
            if not cb_ta.get() or not cb_course.get():
                messagebox.showerror("Error", "Please select TA and course.")
                return

            ta_username = cb_ta.get().strip()
            course_id = int(cb_course.get().split("-")[0].strip())

            call_sp_non_query(
                "sp_Admin_AssignTAtoCourse",
                (Session.username, ta_username, course_id)
            )
            messagebox.showinfo("Success", "TA assigned successfully.")
            refresh()

        except DbError as e:
            messagebox.showerror("Error", _friendly_db_error(e))
        except ValueError:
            messagebox.showerror("Error", "Invalid course selection.")

    def unassign_selected():
        try:
            sel = tree.selection()
            if not sel:
                messagebox.showerror("Error", "Select an assignment row first.")
                return

            vals = tree.item(sel[0], "values")
            ta_username = str(vals[0])
            course_id = int(vals[1])

            call_sp_non_query(
                "sp_Admin_UnassignTAFromCourse",
                (Session.username, ta_username, course_id)
            )
            messagebox.showinfo("Success", "TA unassigned successfully.")
            refresh()

        except DbError as e:
            messagebox.showerror("Error", _friendly_db_error(e))
        except Exception as e:
            messagebox.showerror("Error", str(e))

    tk.Button(btns, text="Assign", bg=ACCENT, fg="white", width=16, command=assign).grid(row=0, column=0, padx=8)
    tk.Button(btns, text="Unassign (Selected)", bg="#e84118", fg="white", width=16, command=unassign_selected).grid(row=0, column=1, padx=8)
    tk.Button(btns, text="Refresh", bg="#353b48", fg="white", width=16, command=refresh).grid(row=0, column=2, padx=8)

    refresh()


# =========================================================
# Enrollment Management Window (Dropdowns)
# =========================================================
def open_enrollment_management():
    win = tk.Toplevel()
    win.title("Enrollment Management")
    win.geometry("620x320")
    win.configure(bg=BG)

    tk.Label(win, text="Enroll / Remove Student", font=("Arial", 16, "bold"), bg=BG).pack(pady=10)

    box = tk.Frame(win, bg=BG)
    box.pack(padx=12, pady=10, fill="x")

    tk.Label(box, text="Student", bg=BG).grid(row=0, column=0, sticky="w")
    cb_student = ttk.Combobox(box, state="readonly", width=40)
    cb_student.grid(row=1, column=0, padx=(0, 14), pady=6)

    tk.Label(box, text="Course", bg=BG).grid(row=0, column=1, sticky="w")
    cb_course = ttk.Combobox(box, state="readonly", width=40)
    cb_course.grid(row=1, column=1, pady=6)

    btns = tk.Frame(win, bg=BG)
    btns.pack(pady=14)

    def refresh():
        try:
            students = _load_students()
            courses = _load_courses()
            _combo_set_values(cb_student, [f"{sid} - {name}" for sid, name in students])
            _combo_set_values(cb_course, [f"{cid} - {cname}" for cid, cname in courses])
        except DbError as e:
            messagebox.showerror("Error", _friendly_db_error(e))

    def enroll():
        try:
            if not cb_student.get() or not cb_course.get():
                messagebox.showerror("Error", "Please select student and course.")
                return

            student_id = int(cb_student.get().split("-")[0].strip())
            course_id = int(cb_course.get().split("-")[0].strip())

            call_sp_non_query(
                "sp_Admin_EnrollStudentInCourse",
                (Session.username, student_id, course_id)
            )
            messagebox.showinfo("Success", "Student enrolled successfully.")

        except DbError as e:
            messagebox.showerror("Error", _friendly_db_error(e))
        except ValueError:
            messagebox.showerror("Error", "Invalid selection values.")

    def remove():
        try:
            if not cb_student.get() or not cb_course.get():
                messagebox.showerror("Error", "Please select student and course.")
                return

            student_id = int(cb_student.get().split("-")[0].strip())
            course_id = int(cb_course.get().split("-")[0].strip())

            call_sp_non_query(
                "sp_Admin_RemoveEnrollment",
                (Session.username, student_id, course_id)
            )
            messagebox.showinfo("Success", "Enrollment removed successfully.")

        except DbError as e:
            messagebox.showerror("Error", _friendly_db_error(e))
        except ValueError:
            messagebox.showerror("Error", "Invalid selection values.")

    tk.Button(btns, text="Enroll", bg=ACCENT, fg="white", width=18, command=enroll).grid(row=0, column=0, padx=10)
    tk.Button(btns, text="Remove", bg="#e84118", fg="white", width=18, command=remove).grid(row=0, column=1, padx=10)
    tk.Button(btns, text="Refresh", bg="#353b48", fg="white", width=18, command=refresh).grid(row=0, column=2, padx=10)

    refresh()


# =========================================================
# ROLE REQUESTS
# =========================================================
def open_role_requests():
    win = tk.Toplevel()
    win.title("Role Requests")
    win.geometry("720x420")
    win.configure(bg=BG)

    try:
        reqs = call_sp_rows("sp_RoleRequest_GetPending", (Session.username,))
    except DbError as e:
        messagebox.showerror("Error", str(e))
        return

    frame = tk.Frame(win, bg=BG)
    frame.pack(pady=10)

    headers = ["RequestID", "Username", "CurrentRole", "RequestedRole"]
    for i, h in enumerate(headers):
        tk.Label(
            frame,
            text=h,
            width=18,
            bg=ACCENT,
            fg="white"
        ).grid(row=0, column=i)

    # ---------------------------------------------
    # Approve / Deny handlers (NO logic change)
    # ---------------------------------------------
    def approve(request_id):
        try:
            call_sp_non_query(
                "dbo.sp_RoleRequest_Approve",
                (Session.username, request_id)
            )
            messagebox.showinfo("Success", "Request approved successfully")
            win.destroy()
            open_role_requests()   # refresh
        except DbError as e:
            messagebox.showerror("Error", str(e))

    def deny(request_id):
        try:
            call_sp_non_query(
                "sp_RoleRequest_Deny",
                (Session.username, request_id)
            )
            messagebox.showinfo("Success", "Request denied successfully")
            win.destroy()
            open_role_requests()   # refresh
        except DbError as e:
            messagebox.showerror("Error", str(e))

    # ---------------------------------------------
    # Rows
    # ---------------------------------------------
    for r, req in enumerate(reqs, start=1):
        tk.Label(frame, text=req["RequestID"], width=18, bg=CARD)\
            .grid(row=r, column=0)
        tk.Label(frame, text=req["Username"], width=18, bg=CARD)\
            .grid(row=r, column=1)
        tk.Label(frame, text=req["CurrentRole"], width=18, bg=CARD)\
            .grid(row=r, column=2)
        tk.Label(frame, text=req["RequestedRole"], width=18, bg=CARD)\
            .grid(row=r, column=3)

        tk.Button(
            frame,
            text="Approve",
            bg="#44bd32",
            fg="white",
            command=lambda i=req["RequestID"]: approve(i)
        ).grid(row=r, column=4, padx=5)

        tk.Button(
            frame,
            text="Deny",
            bg="#e84118",
            fg="white",
            command=lambda i=req["RequestID"]: deny(i)
        ).grid(row=r, column=5, padx=5)


# =========================================================
# LOGS (READ ONLY)
# =========================================================
def open_logs():
    win = tk.Toplevel()
    win.title("System Logs")
    win.geometry("900x450")
    win.configure(bg=BG)

    logs = execute_query("SELECT * FROM vw_Admin_Logs")

    frame = tk.Frame(win, bg=BG)
    frame.pack()

    headers = logs[0].keys() if logs else []
    for i, h in enumerate(headers):
        tk.Label(frame, text=h, width=18, bg=ACCENT, fg="white").grid(row=0, column=i)

    for r, log in enumerate(logs, start=1):
        for i, h in enumerate(headers):
            tk.Label(frame, text=log[h], width=18, bg=CARD).grid(row=r, column=i)
