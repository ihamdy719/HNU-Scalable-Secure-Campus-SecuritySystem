# =========================================================
# Guest Dashboard
# Role: Guestrole
# Permissions:
#   - View Public Courses only
# Uses:
#   - sp_Get_PublicCourses
# =========================================================

import tkinter as tk
from tkinter import messagebox

from session import Session
from db import call_sp_rows, DbError


# ---------------------------------------------------------
# UI Colors
# ---------------------------------------------------------
BG = "#f5f6fa"
CARD = "#ffffff"
PRIMARY = "#2f3640"
ACCENT = "#487eb0"


# ---------------------------------------------------------
# Guest Dashboard Main Window
# ---------------------------------------------------------
def open():
    if not Session.is_logged_in() or Session.role != "Guestrole":
        messagebox.showerror(
            "Access Denied",
            "Only Guests can access this dashboard."
        )
        return

    win = tk.Tk()
    win.title("Guest Dashboard")
    win.geometry("550x350")
    win.resizable(False, False)
    win.configure(bg=BG)

    # Card container
    card = tk.Frame(win, bg=CARD, bd=0)
    card.place(relx=0.5, rely=0.5, anchor="center",
               width=420, height=260)

    tk.Label(
        card,
        text=f"Guest Dashboard - {Session.username}",
        font=("Arial", 16, "bold"),
        bg=CARD,
        fg=PRIMARY
    ).pack(pady=20)

    tk.Button(
        card,
        text="View Public Courses",
        width=25,
        height=2,
        bg=ACCENT,
        fg="white",
        relief="flat",
        command=open_public_courses
    ).pack(pady=20)

    # Logout
    def logout():
        Session.clear()
        win.destroy()
        import login  # reload login screen

    tk.Button(
        card,
        text="Logout",
        width=25,
        height=2,
        bg="#e84118",
        fg="white",
        relief="flat",
        command=logout
    ).pack(pady=10)

    win.mainloop()


# ---------------------------------------------------------
# View Public Courses
# ---------------------------------------------------------
def open_public_courses():
    win = tk.Toplevel()
    win.title("Public Courses")
    win.geometry("750x450")
    win.configure(bg=BG)

    tk.Label(
        win,
        text="Public Courses",
        font=("Arial", 16, "bold"),
        bg=BG,
        fg=PRIMARY
    ).pack(pady=15)

    try:
        # ✅ FIX: Pass @CurrentUsername to SP
        courses = call_sp_rows(
            "sp_Get_PublicCourses",
            (Session.username,)
        )
    except DbError as e:
        messagebox.showerror(
            "Error",
            f"Failed to load public courses:\n{str(e)}"
        )
        return

    if not courses:
        tk.Label(
            win,
            text="No public courses available.",
            bg=BG,
            fg=PRIMARY
        ).pack(pady=20)
        return

    frame = tk.Frame(win, bg=BG)
    frame.pack()

    headers = ["CourseID", "CourseName", "Description", "PublicInfo"]

    # Header row
    for i, h in enumerate(headers):
        tk.Label(
            frame,
            text=h,
            width=20,
            bg=ACCENT,
            fg="white"
        ).grid(row=0, column=i)

    # Data rows
    for r, c in enumerate(courses, start=1):
        tk.Label(frame, text=c["CourseID"], width=20, bg=CARD)\
            .grid(row=r, column=0)
        tk.Label(frame, text=c["CourseName"], width=20, bg=CARD)\
            .grid(row=r, column=1)
        tk.Label(frame, text=c["Description"], width=20, bg=CARD)\
            .grid(row=r, column=2)
        tk.Label(frame, text=c["PublicInfo"], width=20, bg=CARD)\
            .grid(row=r, column=3)
