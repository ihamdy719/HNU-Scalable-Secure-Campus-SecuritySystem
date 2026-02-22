# =========================================================
# SRMS - Main Entry Point
# =========================================================
# This file launches the login screen.
# Importing the login module automatically starts the UI.
# =========================================================

def main():
    """
    Entry point of the SRMS system.
    Importing the login module triggers the Tkinter login UI.
    """
    try:
        import login   # The login module contains the Tkinter mainloop
    except Exception as e:
        print(f"Failed to launch SRMS Login UI: {e}")


if __name__ == "__main__":
    main()
