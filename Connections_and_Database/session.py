# =========================================================
# Session Manager
# =========================================================
# Stores the current logged-in user's information.
# All GUI screens import this file to enforce RBAC + MLS.
# =========================================================

class Session:
    """
    Global session manager for the logged-in user.
    Stores:
        - username
        - role
        - clearance level
    Used by all GUI screens to enforce RBAC + MLS.
    """

    username: str = None
    role: str = None
    clearance: int = None

    # -----------------------------------------------------
    # Set current user session
    # -----------------------------------------------------
    @staticmethod
    def set_user(username: str, role: str, clearance: int):
        """
        Stores the logged-in user's identity and permissions.
        """
        Session.username = username
        Session.role = role
        Session.clearance = clearance

    # -----------------------------------------------------
    # Clear session (logout)
    # -----------------------------------------------------
    @staticmethod
    def clear():
        """
        Clears all session data.
        """
        Session.username = None
        Session.role = None
        Session.clearance = None

    # -----------------------------------------------------
    # Check login state
    # -----------------------------------------------------
    @staticmethod
    def is_logged_in() -> bool:
        """
        Returns True if a user is currently logged in.
        """
        return Session.username is not None

    # -----------------------------------------------------
    # Get session as dict
    # -----------------------------------------------------
    @staticmethod
    def get_user() -> dict:
        """
        Returns a dictionary containing the current session info.
        """
        return {
            "username": Session.username,
            "role": Session.role,
            "clearance": Session.clearance
        }

    # -----------------------------------------------------
    # RBAC: Check role
    # -----------------------------------------------------
    @staticmethod
    def has_role(required_role: str) -> bool:
        """
        Returns True if the logged-in user has the required role.
        """
        if Session.role is None:
            return False
        return Session.role == required_role

    # -----------------------------------------------------
    # MLS: Check clearance
    # -----------------------------------------------------
    @staticmethod
    def has_clearance(required_level: int) -> bool:
        """
        Returns True if the user's clearance level is >= required level.
        """
        if Session.clearance is None:
            return False
        return Session.clearance >= required_level
