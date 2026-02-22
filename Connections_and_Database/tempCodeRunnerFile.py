import tkinter as tk
from tkinter import messagebox

from db import call_sp_single_row, DbError
from session import Session


# =========================================================
# Open Dashboard Based on Role
# =========================================================
def open_dashboard(role):
    try:
        if role == "Admin":
            import dashboard_admin as dash
        elif role == "Instructor":
            import dashboard_instructor as dash
        elif role == "TA":
            import dashboard_ta as dash
        elif role == "Student":
            import dashboard_student as dash
        elif role == "Guestrole":
            import dashboard_guest as dash
        else:
            messagebox.showerror("Error", f"Unknown role: {role}")
            return

        dash.open()

    except Exception as e:
        messagebox.showerror(
            "Error",
            f"Failed to open dashboard:\n{str(e)}"
        )


# =========================================================
# Login Logic (FINAL – SQL handles authentication)
# =========================================================
def login():
    username = entry_username.get().strip()
    password = entry_password.get().strip()

    if not username or not password:
        messagebox.showerror("Error", "Please enter username and password")
        return

    try:
        # ✅ SQL does hashing + validation internally
        row = call_sp_single_row(
            "sp_User_Login",
            (username, password)
        )

        if row is None:
            messagebox.showerror("Error", "Invalid username or password")
            return

        role = row["Role"]
        clearance = row["ClearanceLevel"]

        # ✅ Save session
        Session.set_user(username, role, clearance)

        messagebox.showinfo(
            "Success",
            f"Welcome {username}\nRole: {role}"
        )

        root.destroy()
        open_dashboard(role)

    except DbError as db_err:
        messagebox.showerror("Database Error", str(db_err))

    except Exception as e:
        messagebox.showerror("Error", f"Login failed:\n{str(e)}")


# =========================================================
# Tkinter Login UI
# =========================================================
root = tk.Tk()
root.title("SRMS Login")
root.geometry("380x300")
root.resizable(False, False)

BG = "#f5f6fa"
CARD = "#ffffff"
PRIMARY = "#2f3640"
ACCENT = "#487eb0"

root.configure(bg=BG)

card = tk.Frame(root, bg=CARD)
card.place(relx=0.5, rely=0.5, anchor="center", width=300, height=260)

tk.Label(
    card,
    text="Secure SRMS Login",
    font=("Arial", 16, "bold"),
    bg=CARD,
    fg=PRIMARY
).pack(pady=15)

tk.Label(card, text="Username", bg=CARD, fg=PRIMARY)\
    .pack(anchor="w", padx=20)
entry_username = tk.Entry(card)
entry_username.pack(pady=5, padx=20, fill="x")

tk.Label(card, text="Password", bg=CARD, fg=PRIMARY)\
    .pack(anchor="w", padx=20)
entry_password = tk.Entry(card, show="*")
entry_password.pack(pady=5, padx=20, fill="x")

tk.Button(
    card,
    text="Login",
    bg=ACCENT,
    fg="white",
    command=login
).pack(pady=20)

root.mainloop()
