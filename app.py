"""
Timetable Generator — Web Interface with Firebase Authentication
================================================================
A Flask web application with role-based access control:
  - ADMIN: Full dashboard, all data, faculty PDF downloads
  - FACULTY: Personal timetable only + PDF download

Uses Firebase Authentication for login and session management.

Usage:
    python app.py
    # Then open http://localhost:5001 in your browser
"""

import os
import io
import sys
import zipfile
from datetime import time as dt_time
from functools import wraps

from flask import (Flask, render_template_string, request, jsonify,
                   redirect, url_for, session, make_response, send_file)

# Import our modules
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from db_manager import DBManager
from faculty_pdf import generate_faculty_pdf

# Firebase Admin SDK (server-side token verification)
try:
    import firebase_admin
    from firebase_admin import credentials, auth as firebase_auth
    FIREBASE_AVAILABLE = True
except ImportError:
    FIREBASE_AVAILABLE = False
    print("WARNING: firebase-admin not installed. Auth will be disabled.")

try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    pass

app = Flask(__name__)
app.secret_key = os.getenv('FLASK_SECRET_KEY', 'dev-secret-key-change-me')

# ---------------------------------------------------------------------------
# Firebase Initialization
# ---------------------------------------------------------------------------
def init_firebase():
    """Initialize Firebase Admin SDK if not already initialized."""
    if not FIREBASE_AVAILABLE:
        return False
    if firebase_admin._apps:
        return True  # Already initialized

    sa_path = os.getenv('FIREBASE_SERVICE_ACCOUNT_PATH',
                        './firebase-service-account.json')
    if not os.path.exists(sa_path):
        print(f"  WARNING: Firebase service account not found at {sa_path}")
        print("  Auth features will be disabled. Set up Firebase to enable.")
        return False

    try:
        cred = credentials.Certificate(sa_path)
        firebase_admin.initialize_app(cred)
        print("  ✓ Firebase Admin SDK initialized")
        return True
    except Exception as e:
        print(f"  WARNING: Firebase init failed: {e}")
        return False


FIREBASE_INITIALIZED = init_firebase()

# Firebase Web SDK config (for client-side login page)
FIREBASE_WEB_CONFIG = {
    'apiKey': os.getenv('FIREBASE_API_KEY', ''),
    'authDomain': os.getenv('FIREBASE_AUTH_DOMAIN', ''),
    'projectId': os.getenv('FIREBASE_PROJECT_ID', ''),
}


# ---------------------------------------------------------------------------
# Auth Helpers
# ---------------------------------------------------------------------------
# Password policy constants
PASSWORD_RULES = {
    'min_length': 8,
    'require_uppercase': True,
    'require_lowercase': True,
    'require_digit': True,
    'require_special': True,
}


def validate_password(password):
    """Check password against policy rules. Returns (ok, error_message)."""
    if len(password) < PASSWORD_RULES['min_length']:
        return False, f'Password must be at least {PASSWORD_RULES["min_length"]} characters'
    if PASSWORD_RULES['require_uppercase'] and not any(c.isupper() for c in password):
        return False, 'Password must contain at least one uppercase letter'
    if PASSWORD_RULES['require_lowercase'] and not any(c.islower() for c in password):
        return False, 'Password must contain at least one lowercase letter'
    if PASSWORD_RULES['require_digit'] and not any(c.isdigit() for c in password):
        return False, 'Password must contain at least one digit'
    if PASSWORD_RULES['require_special'] and not any(c in '!@#$%^&*()_+-=[]{}|;:,.<>?/~`' for c in password):
        return False, 'Password must contain at least one special character (!@#$%^&*...)'
    return True, ''


def get_current_user():
    """
    Get the currently logged-in user from session.
    Returns dict with uid, email, role, faculty_short_name, password_changed or None.
    """
    if 'user_uid' not in session:
        return None
    return {
        'uid': session.get('user_uid'),
        'email': session.get('user_email'),
        'role': session.get('user_role'),
        'faculty_short_name': session.get('faculty_short_name'),
        'password_changed': session.get('password_changed', False),
    }


def login_required(f):
    """Decorator: requires authenticated user who has changed their password."""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        user = get_current_user()
        if not user:
            return redirect(url_for('login'))
        # Force password change for first-time faculty logins
        if not user.get('password_changed', False) and user['role'] != 'ADMIN':
            return redirect(url_for('change_password'))
        return f(*args, **kwargs)
    return decorated_function


def admin_required(f):
    """Decorator: requires ADMIN role."""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        user = get_current_user()
        if not user:
            return redirect(url_for('login'))
        if user['role'] != 'ADMIN':
            return redirect(url_for('faculty_dashboard'))
        return f(*args, **kwargs)
    return decorated_function


# ---------------------------------------------------------------------------
# CSS Styles (shared across all pages)
# ---------------------------------------------------------------------------
SHARED_STYLES = """
:root {
    --bg-primary: #0f0f1a;
    --bg-secondary: #1a1a2e;
    --bg-card: #16213e;
    --bg-card-hover: #1a2745;
    --text-primary: #e8e8f0;
    --text-secondary: #8888a8;
    --text-muted: #5a5a7a;
    --accent-blue: #4f8fff;
    --accent-purple: #8b5cf6;
    --accent-green: #10b981;
    --accent-amber: #f59e0b;
    --accent-red: #ef4444;
    --accent-cyan: #06b6d4;
    --border-color: #2a2a4a;
    --gradient-1: linear-gradient(135deg, #4f8fff, #8b5cf6);
    --gradient-2: linear-gradient(135deg, #10b981, #06b6d4);
    --shadow-glow: 0 0 30px rgba(79, 143, 255, 0.15);
}

* { margin: 0; padding: 0; box-sizing: border-box; }

body {
    font-family: 'Inter', -apple-system, sans-serif;
    background: var(--bg-primary);
    color: var(--text-primary);
    min-height: 100vh;
    line-height: 1.6;
}

nav {
    background: var(--bg-secondary);
    border-bottom: 1px solid var(--border-color);
    padding: 0 2rem;
    position: sticky;
    top: 0;
    z-index: 100;
    backdrop-filter: blur(12px);
}

.nav-inner {
    max-width: 1400px;
    margin: 0 auto;
    display: flex;
    align-items: center;
    gap: 2rem;
    height: 64px;
}

.nav-brand {
    font-weight: 700;
    font-size: 1.1rem;
    background: var(--gradient-1);
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
    white-space: nowrap;
}

.nav-links {
    display: flex;
    gap: 0.15rem;
    list-style: none;
    overflow-x: auto;
    flex: 1;
    scrollbar-width: none;  /* Firefox */
    -ms-overflow-style: none;  /* IE/Edge */
}
.nav-links::-webkit-scrollbar {
    display: none;  /* Chrome/Safari */
}

.nav-links a {
    text-decoration: none;
    color: var(--text-secondary);
    padding: 0.4rem 0.7rem;
    border-radius: 8px;
    font-size: 0.8rem;
    font-weight: 500;
    transition: all 0.2s;
    white-space: nowrap;
}

.nav-links a:hover, .nav-links a.active {
    color: var(--text-primary);
    background: rgba(79, 143, 255, 0.1);
}

.nav-links a.active {
    background: rgba(79, 143, 255, 0.2);
    color: var(--accent-blue);
}

.nav-user {
    display: flex;
    align-items: center;
    gap: 1rem;
    white-space: nowrap;
}

.nav-user .user-email {
    font-size: 0.8rem;
    color: var(--text-secondary);
}

.nav-user .user-role {
    font-size: 0.7rem;
    padding: 0.15rem 0.6rem;
    border-radius: 20px;
    font-weight: 600;
}

.role-admin {
    background: rgba(139, 92, 246, 0.2);
    color: var(--accent-purple);
    border: 1px solid rgba(139, 92, 246, 0.3);
}

.role-faculty {
    background: rgba(16, 185, 129, 0.2);
    color: var(--accent-green);
    border: 1px solid rgba(16, 185, 129, 0.3);
}

.btn-logout {
    background: rgba(239, 68, 68, 0.1);
    color: var(--accent-red);
    border: 1px solid rgba(239, 68, 68, 0.3);
    padding: 0.4rem 1rem;
    border-radius: 8px;
    font-size: 0.8rem;
    cursor: pointer;
    text-decoration: none;
    transition: all 0.2s;
}

.btn-logout:hover {
    background: rgba(239, 68, 68, 0.2);
}

main {
    max-width: 1400px;
    margin: 0 auto;
    padding: 2rem;
}

h1 {
    font-size: 1.8rem;
    font-weight: 700;
    margin-bottom: 0.5rem;
}

h1 .icon { margin-right: 0.5rem; }

.subtitle {
    color: var(--text-secondary);
    font-size: 0.9rem;
    margin-bottom: 2rem;
}

.stats-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
    gap: 1rem;
    margin-bottom: 2rem;
}

.stat-card {
    background: var(--bg-card);
    border: 1px solid var(--border-color);
    border-radius: 12px;
    padding: 1.25rem;
    transition: all 0.3s;
}

.stat-card:hover {
    transform: translateY(-2px);
    box-shadow: var(--shadow-glow);
    border-color: var(--accent-blue);
}

.stat-value {
    font-size: 2rem;
    font-weight: 700;
    background: var(--gradient-1);
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
}

.stat-label {
    font-size: 0.8rem;
    color: var(--text-secondary);
    text-transform: uppercase;
    letter-spacing: 0.05em;
    margin-top: 0.25rem;
}

.filters {
    display: flex;
    gap: 0.75rem;
    margin-bottom: 1.5rem;
    flex-wrap: wrap;
}

.filter-group {
    display: flex;
    flex-direction: column;
    gap: 0.25rem;
}

.filter-group label {
    font-size: 0.7rem;
    color: var(--text-muted);
    text-transform: uppercase;
    letter-spacing: 0.05em;
}

select, input[type="text"] {
    background: var(--bg-card);
    border: 1px solid var(--border-color);
    color: var(--text-primary);
    padding: 0.5rem 1rem;
    border-radius: 8px;
    font-size: 0.85rem;
    font-family: 'Inter', sans-serif;
    min-width: 160px;
    transition: border-color 0.2s;
}

select:focus, input[type="text"]:focus {
    outline: none;
    border-color: var(--accent-blue);
}

.btn {
    background: var(--gradient-1);
    color: white;
    border: none;
    padding: 0.5rem 1.5rem;
    border-radius: 8px;
    font-size: 0.85rem;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.2s;
    align-self: flex-end;
    text-decoration: none;
    display: inline-block;
}

.btn:hover {
    transform: translateY(-1px);
    box-shadow: 0 4px 15px rgba(79, 143, 255, 0.3);
}

.btn-sm {
    padding: 0.35rem 0.9rem;
    font-size: 0.75rem;
}

.btn-green {
    background: var(--gradient-2);
}

.table-container {
    background: var(--bg-card);
    border: 1px solid var(--border-color);
    border-radius: 12px;
    overflow: hidden;
    margin-bottom: 2rem;
}

.table-header {
    padding: 1rem 1.5rem;
    border-bottom: 1px solid var(--border-color);
    display: flex;
    justify-content: space-between;
    align-items: center;
}

.table-header h2 {
    font-size: 1rem;
    font-weight: 600;
}

.table-count {
    font-size: 0.8rem;
    color: var(--text-muted);
    background: var(--bg-secondary);
    padding: 0.25rem 0.75rem;
    border-radius: 20px;
}

.table-scroll { overflow-x: auto; }

table {
    width: 100%;
    border-collapse: collapse;
    font-size: 0.82rem;
}

th {
    background: var(--bg-secondary);
    color: var(--text-secondary);
    font-weight: 600;
    text-transform: uppercase;
    font-size: 0.7rem;
    letter-spacing: 0.05em;
    padding: 0.75rem 1rem;
    text-align: left;
    white-space: nowrap;
    position: sticky;
    top: 0;
}

td {
    padding: 0.65rem 1rem;
    border-top: 1px solid rgba(42, 42, 74, 0.5);
    vertical-align: top;
}

tr:hover td { background: var(--bg-card-hover); }

.badge {
    display: inline-block;
    padding: 0.15rem 0.6rem;
    border-radius: 20px;
    font-size: 0.7rem;
    font-weight: 600;
    letter-spacing: 0.03em;
}

.badge-hard {
    background: rgba(239, 68, 68, 0.15);
    color: var(--accent-red);
    border: 1px solid rgba(239, 68, 68, 0.3);
}

.badge-soft {
    background: rgba(245, 158, 11, 0.15);
    color: var(--accent-amber);
    border: 1px solid rgba(245, 158, 11, 0.3);
}

.badge-db {
    background: rgba(79, 143, 255, 0.15);
    color: var(--accent-blue);
    border: 1px solid rgba(79, 143, 255, 0.3);
}

.badge-app {
    background: rgba(139, 92, 246, 0.15);
    color: var(--accent-purple);
    border: 1px solid rgba(139, 92, 246, 0.3);
}

.badge-both {
    background: rgba(16, 185, 129, 0.15);
    color: var(--accent-green);
    border: 1px solid rgba(16, 185, 129, 0.3);
}

.badge-active {
    background: rgba(16, 185, 129, 0.15);
    color: var(--accent-green);
}

.badge-inactive {
    background: rgba(239, 68, 68, 0.15);
    color: var(--accent-red);
}

.btn-delete {
    background: rgba(239, 68, 68, 0.1);
    color: var(--accent-red);
    border: 1px solid rgba(239, 68, 68, 0.3);
    padding: 0.25rem 0.6rem;
    border-radius: 6px;
    font-size: 0.75rem;
    cursor: pointer;
    transition: all 0.2s;
    font-family: 'Inter', sans-serif;
}
.btn-delete:hover {
    background: rgba(239, 68, 68, 0.3);
    border-color: var(--accent-red);
}

.badge-core {
    background: rgba(6, 182, 212, 0.15);
    color: var(--accent-cyan);
    border: 1px solid rgba(6, 182, 212, 0.3);
}

.badge-elective {
    background: rgba(245, 158, 11, 0.15);
    color: var(--accent-amber);
    border: 1px solid rgba(245, 158, 11, 0.3);
}

.badge-moved {
    background: rgba(245, 158, 11, 0.15);
    color: var(--accent-amber);
}

.util-bar-bg {
    background: var(--bg-secondary);
    border-radius: 6px;
    height: 8px;
    width: 100px;
    overflow: hidden;
}

.util-bar {
    height: 100%;
    border-radius: 6px;
    transition: width 0.5s ease;
}

.util-low { background: var(--accent-green); }
.util-med { background: var(--accent-amber); }
.util-high { background: var(--accent-red); }

.empty-state {
    text-align: center;
    padding: 4rem 2rem;
    color: var(--text-muted);
}

.empty-state .icon {
    font-size: 3rem;
    margin-bottom: 1rem;
}

/* Faculty PDF list */
.faculty-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(250px, 1fr));
    gap: 1rem;
    margin-top: 1rem;
}

.faculty-card {
    background: var(--bg-card);
    border: 1px solid var(--border-color);
    border-radius: 10px;
    padding: 1rem 1.25rem;
    display: flex;
    justify-content: space-between;
    align-items: center;
    transition: all 0.2s;
}

.faculty-card:hover {
    border-color: var(--accent-blue);
    transform: translateY(-1px);
}

.faculty-card .name {
    font-weight: 600;
    font-size: 0.9rem;
}

.faculty-card .classes {
    font-size: 0.75rem;
    color: var(--text-muted);
}

/* Schedule grid for faculty */
.schedule-grid {
    display: grid;
    grid-template-columns: 100px repeat(5, 1fr);
    gap: 2px;
    margin-bottom: 2rem;
}

.schedule-cell {
    background: var(--bg-card);
    border: 1px solid var(--border-color);
    padding: 0.75rem;
    min-height: 80px;
    font-size: 0.78rem;
}

.schedule-cell.header {
    background: var(--bg-secondary);
    font-weight: 600;
    text-align: center;
    min-height: auto;
    padding: 0.5rem;
    font-size: 0.75rem;
    color: var(--text-secondary);
    text-transform: uppercase;
}

.schedule-cell.time-label {
    background: var(--bg-secondary);
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 0.72rem;
    color: var(--text-secondary);
    min-height: auto;
}

.schedule-cell .course-code {
    font-weight: 700;
    color: var(--accent-blue);
    font-size: 0.85rem;
}

.schedule-cell .room {
    color: var(--accent-green);
    font-size: 0.72rem;
}

.schedule-cell .batch {
    color: var(--text-muted);
    font-size: 0.7rem;
}

.schedule-cell.empty {
    display: flex;
    align-items: center;
    justify-content: center;
    color: var(--text-muted);
    font-size: 1.2rem;
}

@media (max-width: 768px) {
    nav { padding: 0 1rem; }
    main { padding: 1rem; }
    .stats-grid { grid-template-columns: repeat(2, 1fr); }
    .filters { flex-direction: column; }
    .filter-group { width: 100%; }
    select, input[type="text"] { width: 100%; }
    .schedule-grid { grid-template-columns: 80px repeat(5, 1fr); }
}
"""


# ---------------------------------------------------------------------------
# Navigation builder
# ---------------------------------------------------------------------------
def build_nav(user, active_page=''):
    """Build the navigation bar HTML based on user role."""
    if not user:
        return ''

    links = ''
    if user['role'] == 'ADMIN':
        pages = [
            ('admin_dashboard', 'dashboard', 'Dashboard'),
            ('admin_timetable', 'timetable', 'Master Timetable'),
            ('admin_faculty', 'faculty', 'Faculty Schedule'),
            ('admin_rooms', 'rooms', 'Room Utilization'),
            ('admin_constraints', 'constraints', 'Constraints'),
            ('admin_violations', 'violations', 'Violation Log'),
            ('admin_faculty_pdfs', 'pdfs', 'Faculty PDFs'),
            ('admin_manage_users', 'users', 'Manage Users'),
        ]
    else:
        pages = [
            ('faculty_dashboard', 'dashboard', 'My Schedule'),
        ]

    for endpoint, page_id, label in pages:
        active = 'active' if page_id == active_page else ''
        links += f'<li><a href="{url_for(endpoint)}" class="{active}">{label}</a></li>'

    role_class = 'role-admin' if user['role'] == 'ADMIN' else 'role-faculty'
    role_label = user['role']

    return f'''
    <nav>
        <div class="nav-inner">
            <div class="nav-brand">📅 Timetable Generator</div>
            <ul class="nav-links">{links}</ul>
            <div class="nav-user">
                <span class="user-email">{user["email"]}</span>
                <span class="user-role {role_class}">{role_label}</span>
                <a href="{url_for("logout")}" class="btn-logout">Logout</a>
            </div>
        </div>
    </nav>
    '''


def page_shell(title, user, active_page, content):
    """Wrap content in the full page HTML shell."""
    nav_html = build_nav(user, active_page)
    return f'''<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{title} — Timetable Generator</title>
    <meta name="description" content="University Timetable Generator - View schedules, room utilization, and constraint enforcement">
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap" rel="stylesheet">
    <style>{SHARED_STYLES}</style>
</head>
<body>
    {nav_html}
    <main>{content}</main>
</body>
</html>'''


# ---------------------------------------------------------------------------
# Helper: format time objects for display
# ---------------------------------------------------------------------------
def format_entries(entries):
    """Convert time objects to strings for Jinja rendering."""
    for entry in entries:
        for key, val in entry.items():
            if isinstance(val, dt_time):
                entry[key] = val.strftime('%H:%M')
            elif hasattr(val, 'strftime'):
                entry[key] = val.strftime('%Y-%m-%d %H:%M')
    return entries


# ---------------------------------------------------------------------------
# LOGIN / LOGOUT ROUTES
# ---------------------------------------------------------------------------

LOGIN_TEMPLATE = '''<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Login — Timetable Generator</title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap" rel="stylesheet">
    <style>
        ''' + SHARED_STYLES + '''
        .login-container {
            display: flex;
            align-items: center;
            justify-content: center;
            min-height: 100vh;
            padding: 2rem;
        }
        .login-card {
            background: var(--bg-card);
            border: 1px solid var(--border-color);
            border-radius: 16px;
            padding: 3rem;
            width: 100%;
            max-width: 420px;
            box-shadow: var(--shadow-glow);
        }
        .login-card h1 {
            text-align: center;
            margin-bottom: 0.5rem;
            font-size: 1.5rem;
        }
        .login-card .subtitle {
            text-align: center;
            margin-bottom: 2rem;
        }
        .form-group {
            margin-bottom: 1.25rem;
        }
        .form-group label {
            display: block;
            font-size: 0.8rem;
            color: var(--text-secondary);
            margin-bottom: 0.4rem;
            text-transform: uppercase;
            letter-spacing: 0.05em;
        }
        .form-group input {
            width: 100%;
            background: var(--bg-secondary);
            border: 1px solid var(--border-color);
            color: var(--text-primary);
            padding: 0.75rem 1rem;
            border-radius: 8px;
            font-size: 0.9rem;
            font-family: 'Inter', sans-serif;
            transition: border-color 0.2s;
        }
        .form-group input:focus {
            outline: none;
            border-color: var(--accent-blue);
        }
        .login-btn {
            width: 100%;
            background: var(--gradient-1);
            color: white;
            border: none;
            padding: 0.85rem;
            border-radius: 8px;
            font-size: 1rem;
            font-weight: 600;
            cursor: pointer;
            transition: all 0.2s;
            margin-top: 0.5rem;
        }
        .login-btn:hover {
            transform: translateY(-1px);
            box-shadow: 0 4px 20px rgba(79, 143, 255, 0.4);
        }
        .login-btn:disabled {
            opacity: 0.6;
            cursor: not-allowed;
            transform: none;
        }
        .error-msg {
            background: rgba(239, 68, 68, 0.1);
            border: 1px solid rgba(239, 68, 68, 0.3);
            color: var(--accent-red);
            padding: 0.75rem 1rem;
            border-radius: 8px;
            font-size: 0.85rem;
            margin-bottom: 1rem;
            display: none;
        }
        .brand-header {
            text-align: center;
            margin-bottom: 2rem;
        }
        .brand-header .logo {
            font-size: 2.5rem;
            margin-bottom: 0.5rem;
        }
    </style>
</head>
<body>
    <div class="login-container">
        <div class="login-card">
            <div class="brand-header">
                <div class="logo">📅</div>
                <h1>Timetable Generator</h1>
                <p class="subtitle">Sign in to access your schedule</p>
            </div>

            <div id="error-msg" class="error-msg"></div>

            <form id="login-form" onsubmit="handleLogin(event)">
                <div class="form-group">
                    <label>Email</label>
                    <input type="email" id="email" placeholder="yourname@daiict.ac.in" required autocomplete="email">
                </div>
                <div class="form-group">
                    <label>Password</label>
                    <input type="password" id="password" placeholder="Enter your password" required autocomplete="current-password">
                </div>
                <button type="submit" class="login-btn" id="login-btn">Sign In</button>
            </form>
            <div id="reset-msg" style="display:none;padding:0.75rem 1rem;border-radius:8px;font-size:0.85rem;margin-top:1rem;background:rgba(16,185,129,0.1);border:1px solid rgba(16,185,129,0.3);color:#10b981;"></div>
            <div style="text-align:center;margin-top:1rem;">
                <a href="#" onclick="handleForgotPassword(event)" style="color:#8888a8;font-size:0.85rem;text-decoration:none;" onmouseover="this.style.color='#4f8fff'" onmouseout="this.style.color='#8888a8'">Forgot Password?</a>
            </div>
        </div>
    </div>

    <!-- Firebase JS SDK -->
    <script src="https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js"></script>
    <script src="https://www.gstatic.com/firebasejs/10.12.0/firebase-auth-compat.js"></script>
    <script>
        // Initialize Firebase
        const firebaseConfig = {{ firebase_config | tojson }};
        firebase.initializeApp(firebaseConfig);

        async function handleLogin(e) {
            e.preventDefault();
            const btn = document.getElementById('login-btn');
            const errorDiv = document.getElementById('error-msg');
            const email = document.getElementById('email').value;
            const password = document.getElementById('password').value;

            btn.disabled = true;
            btn.textContent = 'Signing in...';
            errorDiv.style.display = 'none';

            try {
                // Authenticate with Firebase client SDK
                const userCredential = await firebase.auth()
                    .signInWithEmailAndPassword(email, password);

                // Get the ID token
                const idToken = await userCredential.user.getIdToken();

                // Send to our Flask backend to create session
                const response = await fetch('/api/session-login', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ id_token: idToken })
                });

                const data = await response.json();

                if (data.success) {
                    window.location.href = data.redirect;
                } else {
                    errorDiv.textContent = data.error || 'Login failed';
                    errorDiv.style.display = 'block';
                }
            } catch (err) {
                let msg = 'Authentication failed';
                if (err.code === 'auth/wrong-password' || err.code === 'auth/invalid-credential') {
                    msg = 'Invalid email or password';
                } else if (err.code === 'auth/user-not-found') {
                    msg = 'No account found with this email';
                } else if (err.code === 'auth/too-many-requests') {
                    msg = 'Too many attempts. Please try again later.';
                }
                errorDiv.textContent = msg;
                errorDiv.style.display = 'block';
            } finally {
                btn.disabled = false;
                btn.textContent = 'Sign In';
            }
        }

        async function handleForgotPassword(e) {
            e.preventDefault();
            const email = document.getElementById('email').value;
            const errorDiv = document.getElementById('error-msg');
            const resetMsg = document.getElementById('reset-msg');
            errorDiv.style.display = 'none';
            resetMsg.style.display = 'none';

            if (!email) {
                errorDiv.textContent = 'Please enter your email address first';
                errorDiv.style.display = 'block';
                return;
            }

            try {
                await firebase.auth().sendPasswordResetEmail(email);
                resetMsg.textContent = '✓ Password reset email sent! Check your inbox.';
                resetMsg.style.display = 'block';
            } catch (err) {
                let msg = 'Failed to send reset email';
                if (err.code === 'auth/user-not-found') {
                    msg = 'No account found with this email';
                } else if (err.code === 'auth/too-many-requests') {
                    msg = 'Too many requests. Please try again later.';
                }
                errorDiv.textContent = msg;
                errorDiv.style.display = 'block';
            }
        }
    </script>
</body>
</html>'''


@app.route('/login')
def login():
    user = get_current_user()
    if user:
        if user['role'] == 'ADMIN':
            return redirect(url_for('admin_dashboard'))
        return redirect(url_for('faculty_dashboard'))

    return render_template_string(
        LOGIN_TEMPLATE,
        firebase_config=FIREBASE_WEB_CONFIG,
    )


@app.route('/api/session-login', methods=['POST'])
def session_login():
    """Verify Firebase ID token and create a Flask session."""
    data = request.get_json()
    id_token = data.get('id_token', '')

    if not id_token:
        return jsonify({'success': False, 'error': 'No token provided'}), 400

    if not FIREBASE_INITIALIZED:
        return jsonify({'success': False,
                        'error': 'Firebase not configured on server'}), 500

    try:
        # Verify the ID token with Firebase Admin SDK
        decoded_token = firebase_auth.verify_id_token(id_token)
        uid = decoded_token['uid']
        email = decoded_token.get('email', '')

        # Look up user role in our database
        db = DBManager(quiet=True)
        try:
            db.cur.execute(
                """SELECT ur.role, f.short_name, ur.password_changed
                   FROM user_role ur
                   LEFT JOIN faculty f ON ur.faculty_id = f.faculty_id
                   WHERE ur.uid = %s""",
                (uid,)
            )
            row = db.cur.fetchone()
        finally:
            db.close()

        if not row:
            return jsonify({
                'success': False,
                'error': 'Account not authorized. Contact admin.'
            }), 403

        role, faculty_short_name, password_changed = row

        # Store in Flask session
        session['user_uid'] = uid
        session['user_email'] = email
        session['user_role'] = role
        session['faculty_short_name'] = faculty_short_name or ''
        session['password_changed'] = password_changed

        # Determine redirect
        if role == 'ADMIN':
            redirect_url = url_for('admin_dashboard')
        elif not password_changed:
            # Force password change on first login
            redirect_url = url_for('change_password')
        else:
            redirect_url = url_for('faculty_dashboard')

        return jsonify({'success': True, 'redirect': redirect_url})

    except firebase_admin.exceptions.InvalidArgumentError:
        return jsonify({'success': False, 'error': 'Invalid token'}), 401
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500


@app.route('/logout')
def logout():
    session.clear()
    return redirect(url_for('login'))


@app.route('/')
def index():
    user = get_current_user()
    if user:
        if user['role'] == 'ADMIN':
            return redirect(url_for('admin_dashboard'))
        return redirect(url_for('faculty_dashboard'))
    return redirect(url_for('login'))


# ---------------------------------------------------------------------------
# FACULTY ROUTES
# ---------------------------------------------------------------------------

@app.route('/faculty/dashboard')
@login_required
def faculty_dashboard():
    user = get_current_user()
    faculty_name = user.get('faculty_short_name', '')

    db = DBManager(quiet=True)
    try:
        entries = db.get_faculty_schedule(faculty_name) if faculty_name else []
        entries = format_entries(entries)
    finally:
        db.close()

    # Build schedule grid data
    days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday']
    periods = ['08:00', '09:00', '10:00', '11:00', '12:00']
    period_labels = ['8:00 – 8:50', '9:00 – 9:50', '10:00 – 10:50',
                     '11:00 – 11:50', '12:00 – 12:50']

    schedule = {}
    for e in entries:
        day = e.get('day_of_week', '')
        start = str(e.get('start_time', ''))[:5]
        key = (day, start)
        if key not in schedule:
            schedule[key] = []
        schedule[key].append(e)

    # Build grid HTML
    grid_html = '<div class="schedule-grid">'
    # Header row
    grid_html += '<div class="schedule-cell header"></div>'
    for day in days:
        grid_html += f'<div class="schedule-cell header">{day}</div>'

    # Data rows
    for p_idx, period in enumerate(periods):
        grid_html += f'<div class="schedule-cell time-label">{period_labels[p_idx]}</div>'
        for day in days:
            cell_entries = schedule.get((day, period), [])
            if cell_entries:
                cell_html = ''
                for e in cell_entries:
                    code = e.get('course_code', '?')
                    room = e.get('room_number', '-') or '-'
                    batch = e.get('sub_batch', '')
                    sec = e.get('section', '')
                    cell_html += f'''
                        <div class="course-code">{code}</div>
                        <div class="room">📍 {room}</div>
                        <div class="batch">{batch} {sec}</div>
                    '''
                grid_html += f'<div class="schedule-cell">{cell_html}</div>'
            else:
                grid_html += '<div class="schedule-cell empty">—</div>'

    grid_html += '</div>'

    content = f'''
    <h1><span class="icon">👨‍🏫</span>Welcome, Prof. {faculty_name}</h1>
    <p class="subtitle">Your personal teaching schedule for this semester</p>

    <div style="margin-bottom: 1.5rem;">
        <a href="{url_for('faculty_download_pdf')}" class="btn btn-green">
            📄 Download My Timetable (PDF)
        </a>
    </div>

    {grid_html}

    <div class="table-container">
        <div class="table-header">
            <h2>Detailed Schedule</h2>
            <span class="table-count">{len(entries)} sessions</span>
        </div>
        <div class="table-scroll">
            <table>
                <thead>
                    <tr>
                        <th>Day</th>
                        <th>Time</th>
                        <th>Course Code</th>
                        <th>Course Name</th>
                        <th>Batch</th>
                        <th>Section</th>
                        <th>Room</th>
                    </tr>
                </thead>
                <tbody>
    '''

    for e in entries:
        content += f'''
            <tr>
                <td>{e.get("day_of_week", "")}</td>
                <td>{e.get("start_time", "")}</td>
                <td><strong>{e.get("course_code", "")}</strong></td>
                <td>{e.get("course_name", "")}</td>
                <td>{e.get("sub_batch", "")}</td>
                <td>{e.get("section", "")}</td>
                <td>{e.get("room_number", "-") or "-"}</td>
            </tr>
        '''

    content += '''
                </tbody>
            </table>
        </div>
    </div>
    '''

    return page_shell(f'Schedule — {faculty_name}', user, 'dashboard', content)


@app.route('/faculty/download-pdf')
@login_required
def faculty_download_pdf():
    """Faculty downloads their own timetable as PDF."""
    user = get_current_user()
    faculty_name = user.get('faculty_short_name', '')
    if not faculty_name:
        return "No faculty profile linked", 400

    db = DBManager(quiet=True)
    try:
        pdf_bytes = generate_faculty_pdf(db, faculty_name)
    finally:
        db.close()

    response = make_response(pdf_bytes)
    response.headers['Content-Type'] = 'application/pdf'
    response.headers['Content-Disposition'] = \
        f'attachment; filename=Timetable_{faculty_name}.pdf'
    return response


# ---------------------------------------------------------------------------
# ADMIN ROUTES
# ---------------------------------------------------------------------------

@app.route('/admin/')
@admin_required
def admin_dashboard():
    db = DBManager(quiet=True)
    try:
        stats = db.get_stats()
        constraints = db.get_constraints()
        constraints = format_entries(constraints)
    finally:
        db.close()

    # Stats grid
    stats_html = '<div class="stats-grid">'
    for key, val in stats.items():
        label = key.replace('_', ' ')
        stats_html += f'''
        <div class="stat-card">
            <div class="stat-value">{val}</div>
            <div class="stat-label">{label}</div>
        </div>'''
    stats_html += '</div>'

    # Constraints table
    constraints_html = '''
    <div class="table-container">
        <div class="table-header">
            <h2>🔒 Active Scheduling Constraints</h2>
            <span class="table-count">''' + str(len(constraints)) + ''' rules</span>
        </div>
        <div class="table-scroll">
            <table>
                <thead>
                    <tr>
                        <th>ID</th><th>Name</th><th>Type</th>
                        <th>Scope</th><th>Enforced By</th><th>Status</th>
                    </tr>
                </thead>
                <tbody>'''

    for c in constraints:
        ctype = c.get('constraint_type', '').lower()
        enforcement = c.get('enforcement_level', '').lower()
        is_active = c.get('is_active', False)
        active_class = 'active' if is_active else 'inactive'
        active_label = 'ACTIVE' if is_active else 'OFF'
        constraints_html += f'''
            <tr>
                <td>{c.get("constraint_id", "")}</td>
                <td>{c.get("constraint_name", "")}</td>
                <td><span class="badge badge-{ctype}">{c.get("constraint_type", "")}</span></td>
                <td>{c.get("scope", "")}</td>
                <td><span class="badge badge-{enforcement}">{c.get("enforcement_level", "")}</span></td>
                <td><span class="badge badge-{active_class}">{active_label}</span></td>
            </tr>'''

    constraints_html += '</tbody></table></div></div>'

    content = f'''
    <h1><span class="icon">📊</span>Dashboard</h1>
    <p class="subtitle">University Timetable Generator — Database Overview</p>
    {stats_html}
    {constraints_html}
    '''

    return page_shell('Dashboard', get_current_user(), 'dashboard', content)


@app.route('/admin/timetable')
@admin_required
def admin_timetable():
    selected_day = request.args.get('day', '')
    selected_batch = request.args.get('batch', '')
    selected_faculty = request.args.get('faculty', '')

    filters = {}
    if selected_day:
        filters['day_of_week'] = selected_day
    if selected_batch:
        filters['sub_batch'] = selected_batch
    if selected_faculty:
        filters['faculty'] = selected_faculty

    db = DBManager(quiet=True)
    try:
        entries = db.get_master_timetable(filters if filters else None)
        entries = format_entries(entries)
        all_entries = db.get_master_timetable()
        all_entries = format_entries(all_entries)
        batches = sorted(set(e['sub_batch'] for e in all_entries if e.get('sub_batch')))
        faculties = sorted(set(e['faculty_short_name'] for e in all_entries if e.get('faculty_short_name')))
    finally:
        db.close()

    days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday']

    # Build filter form
    day_options = '<option value="">All Days</option>'
    for d in days:
        sel = 'selected' if d == selected_day else ''
        day_options += f'<option value="{d}" {sel}>{d}</option>'

    batch_options = '<option value="">All Batches</option>'
    for b in batches:
        sel = 'selected' if b == selected_batch else ''
        batch_options += f'<option value="{b}" {sel}>{b}</option>'

    fac_options = '<option value="">All Faculty</option>'
    for f in faculties:
        sel = 'selected' if f == selected_faculty else ''
        fac_options += f'<option value="{f}" {sel}>{f}</option>'

    # Build table rows
    rows_html = ''
    for e in entries:
        course_type = e.get('course_type', '') or ''
        type_class = 'core' if 'core' in course_type.lower() else 'elective'
        moved_badge = '<span class="badge badge-moved">MOVED</span>' if e.get('is_moved') else '-'
        rows_html += f'''
            <tr>
                <td>{e.get("day_of_week", "")}</td>
                <td>{e.get("start_time", "")}</td>
                <td>{e.get("slot_group", "")}</td>
                <td><strong>{e.get("course_code", "")}</strong></td>
                <td>{e.get("course_name", "")}</td>
                <td><span class="badge badge-{type_class}">{course_type}</span></td>
                <td>{e.get("faculty_short_name", "")}</td>
                <td>{e.get("sub_batch", "")}</td>
                <td>{e.get("section", "")}</td>
                <td>{e.get("room_number", "") or "-"}</td>
                <td>{moved_badge}</td>
            </tr>'''

    if not entries:
        rows_html = '''<tr><td colspan="11" class="empty-state">
            <div class="icon">📭</div>
            <p>No timetable entries found. Run the generator with --use-db first.</p>
        </td></tr>'''

    content = f'''
    <h1><span class="icon">📅</span>Master Timetable</h1>
    <p class="subtitle">Complete schedule with batch, faculty, and room details</p>

    <form class="filters" method="GET" action="{url_for("admin_timetable")}">
        <div class="filter-group"><label>Day</label><select name="day">{day_options}</select></div>
        <div class="filter-group"><label>Batch</label><select name="batch">{batch_options}</select></div>
        <div class="filter-group"><label>Faculty</label><select name="faculty">{fac_options}</select></div>
        <button type="submit" class="btn">Filter</button>
    </form>

    <div class="table-container">
        <div class="table-header">
            <h2>Schedule</h2>
            <span class="table-count">{len(entries)} entries</span>
        </div>
        <div class="table-scroll">
            <table>
                <thead>
                    <tr>
                        <th>Day</th><th>Time</th><th>Slot</th>
                        <th>Course Code</th><th>Course Name</th><th>Type</th>
                        <th>Faculty</th><th>Batch</th><th>Section</th>
                        <th>Room</th><th>Moved?</th>
                    </tr>
                </thead>
                <tbody>{rows_html}</tbody>
            </table>
        </div>
    </div>
    '''

    return page_shell('Master Timetable', get_current_user(), 'timetable', content)


@app.route('/admin/faculty')
@admin_required
def admin_faculty():
    selected_faculty = request.args.get('faculty', '')

    db = DBManager(quiet=True)
    try:
        if selected_faculty:
            entries = db.get_faculty_schedule(selected_faculty)
        else:
            entries = db.get_faculty_schedule()
        entries = format_entries(entries)
        all_entries = db.get_faculty_schedule()
        faculties = sorted(set(e['faculty'] for e in all_entries if e.get('faculty')))
    finally:
        db.close()

    fac_options = '<option value="">All Faculty</option>'
    for f in faculties:
        sel = 'selected' if f == selected_faculty else ''
        fac_options += f'<option value="{f}" {sel}>{f}</option>'

    rows_html = ''
    for e in entries:
        rows_html += f'''
            <tr>
                <td><strong>{e.get("faculty", "")}</strong></td>
                <td>{e.get("day_of_week", "")}</td>
                <td>{e.get("start_time", "")}</td>
                <td>{e.get("course_code", "")}</td>
                <td>{e.get("course_name", "")}</td>
                <td>{e.get("sub_batch", "")}</td>
                <td>{e.get("section", "")}</td>
                <td>{e.get("room_number", "") or "-"}</td>
            </tr>'''

    if not entries:
        rows_html = '''<tr><td colspan="8" class="empty-state">
            <div class="icon">📭</div><p>No schedule data.</p>
        </td></tr>'''

    content = f'''
    <h1><span class="icon">👨‍🏫</span>Faculty Schedule</h1>
    <p class="subtitle">Individual teaching schedules for all faculty members</p>

    <form class="filters" method="GET" action="{url_for("admin_faculty")}">
        <div class="filter-group"><label>Faculty</label><select name="faculty">{fac_options}</select></div>
        <button type="submit" class="btn">Filter</button>
    </form>

    <div class="table-container">
        <div class="table-header">
            <h2>Teaching Schedule</h2>
            <span class="table-count">{len(entries)} sessions</span>
        </div>
        <div class="table-scroll">
            <table>
                <thead>
                    <tr>
                        <th>Faculty</th><th>Day</th><th>Time</th>
                        <th>Course Code</th><th>Course Name</th>
                        <th>Batch</th><th>Section</th><th>Room</th>
                    </tr>
                </thead>
                <tbody>{rows_html}</tbody>
            </table>
        </div>
    </div>
    '''

    return page_shell('Faculty Schedule', get_current_user(), 'faculty', content)


@app.route('/admin/rooms')
@admin_required
def admin_rooms():
    db = DBManager(quiet=True)
    try:
        entries = db.get_room_utilization()
        entries = format_entries(entries)
    finally:
        db.close()

    rows_html = ''
    for e in entries:
        pct = float(e.get('utilization_pct', 0))
        bar_class = 'util-low' if pct < 40 else ('util-med' if pct < 75 else 'util-high')
        rows_html += f'''
            <tr>
                <td><strong>{e.get("room_number", "")}</strong></td>
                <td>{e.get("room_type", "")}</td>
                <td>{e.get("capacity", "")}</td>
                <td>{e.get("total_classes", "")} / 25</td>
                <td>{pct}%</td>
                <td>
                    <div class="util-bar-bg">
                        <div class="util-bar {bar_class}" style="width: {pct}%"></div>
                    </div>
                </td>
            </tr>'''

    if not entries:
        rows_html = '''<tr><td colspan="6" class="empty-state">
            <div class="icon">📭</div><p>No room data available.</p>
        </td></tr>'''

    content = f'''
    <h1><span class="icon">🏫</span>Room Utilization</h1>
    <p class="subtitle">Classroom occupancy and utilization rates (out of 25 possible slots/week)</p>

    <div class="table-container">
        <div class="table-header">
            <h2>Utilization Report</h2>
            <span class="table-count">{len(entries)} rooms</span>
        </div>
        <div class="table-scroll">
            <table>
                <thead>
                    <tr>
                        <th>Room</th><th>Type</th><th>Capacity</th>
                        <th>Classes/Week</th><th>Utilization</th><th></th>
                    </tr>
                </thead>
                <tbody>{rows_html}</tbody>
            </table>
        </div>
    </div>
    '''

    return page_shell('Room Utilization', get_current_user(), 'rooms', content)


@app.route('/admin/constraints')
@admin_required
def admin_constraints():
    db = DBManager(quiet=True)
    try:
        entries = db.get_constraints()
        entries = format_entries(entries)
    finally:
        db.close()

    rows_html = ''
    for e in entries:
        ctype = e.get('constraint_type', '').lower()
        enforcement = e.get('enforcement_level', '').lower()
        is_active = e.get('is_active', False)
        active_class = 'active' if is_active else 'inactive'
        active_label = 'ACTIVE' if is_active else 'OFF'
        rows_html += f'''
            <tr>
                <td>{e.get("constraint_id", "")}</td>
                <td><strong>{e.get("constraint_name", "")}</strong></td>
                <td><span class="badge badge-{ctype}">{e.get("constraint_type", "")}</span></td>
                <td>{e.get("scope", "")}</td>
                <td style="max-width:400px;font-size:0.78rem;color:var(--text-secondary);">{e.get("rule_description", "")}</td>
                <td><span class="badge badge-{enforcement}">{e.get("enforcement_level", "")}</span></td>
                <td><span class="badge badge-{active_class}">{active_label}</span></td>
            </tr>'''

    content = f'''
    <h1><span class="icon">🔒</span>Scheduling Constraints</h1>
    <p class="subtitle">All scheduling rules — stored as queryable, toggleable database rows</p>

    <div class="table-container">
        <div class="table-header">
            <h2>Constraint Rules</h2>
            <span class="table-count">{len(entries)} rules</span>
        </div>
        <div class="table-scroll">
            <table>
                <thead>
                    <tr>
                        <th>ID</th><th>Name</th><th>Type</th><th>Scope</th>
                        <th>Description</th><th>Enforced By</th><th>Status</th>
                    </tr>
                </thead>
                <tbody>{rows_html}</tbody>
            </table>
        </div>
    </div>
    '''

    return page_shell('Constraints', get_current_user(), 'constraints', content)


@app.route('/admin/violations')
@admin_required
def admin_violations():
    db = DBManager(quiet=True)
    try:
        entries = db.get_violations()
        entries = format_entries(entries)
    finally:
        db.close()

    rows_html = ''
    if entries:
        for e in entries:
            severity = e.get('severity', '')
            sev_class = 'hard' if severity in ('ERROR', 'CRITICAL') else 'soft'
            rows_html += f'''
                <tr>
                    <td>{e.get("violation_id", "")}</td>
                    <td>{e.get("constraint_name", "N/A")}</td>
                    <td>{e.get("constraint_type", "-")}</td>
                    <td><span class="badge badge-{sev_class}">{severity}</span></td>
                    <td style="max-width:500px;font-size:0.78rem;color:var(--text-secondary);">{e.get("violation_detail", "")}</td>
                    <td>{e.get("detected_at", "")}</td>
                </tr>'''
    else:
        rows_html = '''<tr><td colspan="6" class="empty-state">
            <div class="icon">✅</div>
            <p>No violations detected — all constraints satisfied!</p>
        </td></tr>'''

    content = f'''
    <h1><span class="icon">⚠️</span>Constraint Violation Log</h1>
    <p class="subtitle">Audit trail of all violations detected during timetable generation</p>

    <div class="table-container">
        <div class="table-header">
            <h2>Violations</h2>
            <span class="table-count">{len(entries)} entries</span>
        </div>
        <div class="table-scroll">
            <table>
                <thead>
                    <tr>
                        <th>ID</th><th>Constraint</th><th>Type</th>
                        <th>Severity</th><th>Detail</th><th>Detected At</th>
                    </tr>
                </thead>
                <tbody>{rows_html}</tbody>
            </table>
        </div>
    </div>
    '''

    return page_shell('Violation Log', get_current_user(), 'violations', content)


@app.route('/admin/faculty-pdfs')
@admin_required
def admin_faculty_pdfs():
    db = DBManager(quiet=True)
    try:
        all_entries = db.get_faculty_schedule()
        all_entries = format_entries(all_entries)
    finally:
        db.close()

    # Count classes per faculty
    faculty_classes = {}
    for e in all_entries:
        f = e.get('faculty', '')
        if f:
            faculty_classes[f] = faculty_classes.get(f, 0) + 1

    sorted_faculty = sorted(faculty_classes.keys())

    cards_html = ''
    for f in sorted_faculty:
        count = faculty_classes[f]
        cards_html += f'''
        <div class="faculty-card">
            <div>
                <div class="name">👨‍🏫 {f}</div>
                <div class="classes">{count} sessions/week</div>
            </div>
            <a href="{url_for("admin_download_faculty_pdf", short_name=f)}"
               class="btn btn-sm btn-green">📄 PDF</a>
        </div>'''

    content = f'''
    <h1><span class="icon">📄</span>Faculty PDFs</h1>
    <p class="subtitle">Download individual timetable PDFs for each faculty member</p>

    <div style="margin-bottom: 1.5rem;">
        <a href="{url_for("admin_download_all_pdfs")}" class="btn">
            📦 Download All Faculty PDFs (ZIP)
        </a>
    </div>

    <div class="faculty-grid">
        {cards_html}
    </div>
    '''

    return page_shell('Faculty PDFs', get_current_user(), 'pdfs', content)


@app.route('/admin/download-faculty-pdf/<short_name>')
@admin_required
def admin_download_faculty_pdf(short_name):
    """Admin downloads a specific faculty member's PDF."""
    db = DBManager(quiet=True)
    try:
        pdf_bytes = generate_faculty_pdf(db, short_name)
    finally:
        db.close()

    response = make_response(pdf_bytes)
    response.headers['Content-Type'] = 'application/pdf'
    response.headers['Content-Disposition'] = \
        f'attachment; filename=Timetable_{short_name}.pdf'
    return response


@app.route('/admin/download-all-pdfs')
@admin_required
def admin_download_all_pdfs():
    """Admin downloads a ZIP file containing all faculty PDFs."""
    db = DBManager(quiet=True)
    try:
        all_entries = db.get_faculty_schedule()
        faculties = sorted(set(e['faculty'] for e in all_entries if e.get('faculty')))

        zip_buffer = io.BytesIO()
        with zipfile.ZipFile(zip_buffer, 'w', zipfile.ZIP_DEFLATED) as zf:
            for f in faculties:
                pdf_bytes = generate_faculty_pdf(db, f)
                zf.writestr(f'Timetable_{f}.pdf', pdf_bytes)
    finally:
        db.close()

    zip_buffer.seek(0)
    return send_file(
        zip_buffer,
        mimetype='application/zip',
        as_attachment=True,
        download_name='All_Faculty_Timetables.zip'
    )


# ---------------------------------------------------------------------------
# CHANGE PASSWORD (Forced on first login for faculty)
# ---------------------------------------------------------------------------

CHANGE_PASSWORD_TEMPLATE = '''<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Change Password — Timetable Generator</title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap" rel="stylesheet">
    <style>
        ''' + SHARED_STYLES + '''
        .change-pw-container {
            display: flex;
            align-items: center;
            justify-content: center;
            min-height: 100vh;
            padding: 2rem;
        }
        .change-pw-card {
            background: var(--bg-card);
            border: 1px solid var(--border-color);
            border-radius: 16px;
            padding: 3rem;
            width: 100%;
            max-width: 480px;
            box-shadow: var(--shadow-glow);
        }
        .change-pw-card h1 {
            text-align: center;
            margin-bottom: 0.5rem;
            font-size: 1.4rem;
        }
        .change-pw-card .subtitle {
            text-align: center;
            margin-bottom: 1.5rem;
        }
        .form-group {
            margin-bottom: 1.25rem;
        }
        .form-group label {
            display: block;
            font-size: 0.8rem;
            color: var(--text-secondary);
            margin-bottom: 0.4rem;
            text-transform: uppercase;
            letter-spacing: 0.05em;
        }
        .form-group input {
            width: 100%;
            background: var(--bg-secondary);
            border: 1px solid var(--border-color);
            color: var(--text-primary);
            padding: 0.75rem 1rem;
            border-radius: 8px;
            font-size: 0.9rem;
            font-family: 'Inter', sans-serif;
            transition: border-color 0.2s;
        }
        .form-group input:focus {
            outline: none;
            border-color: var(--accent-blue);
        }
        .submit-btn {
            width: 100%;
            background: var(--gradient-2);
            color: white;
            border: none;
            padding: 0.85rem;
            border-radius: 8px;
            font-size: 1rem;
            font-weight: 600;
            cursor: pointer;
            transition: all 0.2s;
            margin-top: 0.5rem;
        }
        .submit-btn:hover {
            transform: translateY(-1px);
            box-shadow: 0 4px 20px rgba(16, 185, 129, 0.4);
        }
        .submit-btn:disabled {
            opacity: 0.6;
            cursor: not-allowed;
            transform: none;
        }
        .error-msg, .success-msg {
            padding: 0.75rem 1rem;
            border-radius: 8px;
            font-size: 0.85rem;
            margin-bottom: 1rem;
            display: none;
        }
        .error-msg {
            background: rgba(239, 68, 68, 0.1);
            border: 1px solid rgba(239, 68, 68, 0.3);
            color: var(--accent-red);
        }
        .success-msg {
            background: rgba(16, 185, 129, 0.1);
            border: 1px solid rgba(16, 185, 129, 0.3);
            color: var(--accent-green);
        }
        .policy-box {
            background: var(--bg-secondary);
            border: 1px solid var(--border-color);
            border-radius: 10px;
            padding: 1rem 1.25rem;
            margin-bottom: 1.5rem;
        }
        .policy-box h3 {
            font-size: 0.8rem;
            color: var(--text-secondary);
            text-transform: uppercase;
            margin-bottom: 0.5rem;
        }
        .policy-item {
            display: flex;
            align-items: center;
            gap: 0.5rem;
            font-size: 0.82rem;
            color: var(--text-muted);
            padding: 0.15rem 0;
        }
        .policy-item.pass { color: var(--accent-green); }
        .policy-item.fail { color: var(--accent-red); }
        .policy-icon { font-size: 0.9rem; }
        .warning-banner {
            background: rgba(245, 158, 11, 0.1);
            border: 1px solid rgba(245, 158, 11, 0.3);
            color: var(--accent-amber);
            padding: 0.75rem 1rem;
            border-radius: 8px;
            font-size: 0.85rem;
            margin-bottom: 1.5rem;
            text-align: center;
        }
    </style>
</head>
<body>
    <div class="change-pw-container">
        <div class="change-pw-card">
            <h1>🔐 Change Your Password</h1>
            <p class="subtitle">{{ subtitle }}</p>

            {% if is_forced %}
            <div class="warning-banner">
                ⚠️ You must change your temporary password before accessing the system.
            </div>
            {% endif %}

            <div id="error-msg" class="error-msg"></div>
            <div id="success-msg" class="success-msg"></div>

            <div class="policy-box">
                <h3>Password Requirements</h3>
                <div class="policy-item" id="pol-length">
                    <span class="policy-icon">○</span> At least 8 characters
                </div>
                <div class="policy-item" id="pol-upper">
                    <span class="policy-icon">○</span> One uppercase letter (A-Z)
                </div>
                <div class="policy-item" id="pol-lower">
                    <span class="policy-icon">○</span> One lowercase letter (a-z)
                </div>
                <div class="policy-item" id="pol-digit">
                    <span class="policy-icon">○</span> One digit (0-9)
                </div>
                <div class="policy-item" id="pol-special">
                    <span class="policy-icon">○</span> One special character (!@#$%^&*...)
                </div>
            </div>

            <form id="change-pw-form" onsubmit="handleChangePassword(event)">
                <div class="form-group">
                    <label>New Password</label>
                    <input type="password" id="new-password" placeholder="Enter new password"
                           required oninput="checkPolicy()" autocomplete="new-password">
                </div>
                <div class="form-group">
                    <label>Confirm Password</label>
                    <input type="password" id="confirm-password" placeholder="Confirm new password"
                           required autocomplete="new-password">
                </div>
                <button type="submit" class="submit-btn" id="submit-btn">Change Password</button>
            </form>

            {% if not is_forced %}
            <div style="text-align: center; margin-top: 1rem;">
                <a href="{{ back_url }}" style="color: var(--text-muted); font-size: 0.85rem;">← Back to Dashboard</a>
            </div>
            {% endif %}
        </div>
    </div>

    <script src="https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js"></script>
    <script src="https://www.gstatic.com/firebasejs/10.12.0/firebase-auth-compat.js"></script>
    <script>
        const firebaseConfig = {{ firebase_config | tojson }};
        firebase.initializeApp(firebaseConfig);

        function checkPolicy() {
            const pw = document.getElementById('new-password').value;
            const checks = [
                { id: 'pol-length',  pass: pw.length >= 8 },
                { id: 'pol-upper',   pass: /[A-Z]/.test(pw) },
                { id: 'pol-lower',   pass: /[a-z]/.test(pw) },
                { id: 'pol-digit',   pass: /[0-9]/.test(pw) },
                { id: 'pol-special', pass: /[!@#$%^&*()_+\\-=\\[\\]{}|;:,.<>?/~`]/.test(pw) },
            ];
            checks.forEach(c => {
                const el = document.getElementById(c.id);
                el.className = 'policy-item ' + (c.pass ? 'pass' : 'fail');
                el.querySelector('.policy-icon').textContent = c.pass ? '✓' : '✗';
            });
        }

        async function handleChangePassword(e) {
            e.preventDefault();
            const btn = document.getElementById('submit-btn');
            const errorDiv = document.getElementById('error-msg');
            const successDiv = document.getElementById('success-msg');
            const newPw = document.getElementById('new-password').value;
            const confirmPw = document.getElementById('confirm-password').value;

            errorDiv.style.display = 'none';
            successDiv.style.display = 'none';

            if (newPw !== confirmPw) {
                errorDiv.textContent = 'Passwords do not match';
                errorDiv.style.display = 'block';
                return;
            }

            // Client-side policy check
            const checks = [
                newPw.length >= 8,
                /[A-Z]/.test(newPw),
                /[a-z]/.test(newPw),
                /[0-9]/.test(newPw),
                /[!@#$%^&*()_+\\-=\\[\\]{}|;:,.<>?/~`]/.test(newPw),
            ];
            if (!checks.every(Boolean)) {
                errorDiv.textContent = 'Password does not meet all requirements';
                errorDiv.style.display = 'block';
                return;
            }

            btn.disabled = true;
            btn.textContent = 'Updating...';

            try {
                // Update password in Firebase client SDK
                const user = firebase.auth().currentUser;
                if (!user) {
                    // Re-auth needed — use the session email
                    errorDiv.textContent = 'Session expired. Please log in again.';
                    errorDiv.style.display = 'block';
                    btn.disabled = false;
                    btn.textContent = 'Change Password';
                    return;
                }
                await user.updatePassword(newPw);

                // Notify our backend to update the flag
                const response = await fetch('/api/password-changed', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ success: true })
                });
                const data = await response.json();

                if (data.success) {
                    successDiv.textContent = 'Password changed successfully! Redirecting...';
                    successDiv.style.display = 'block';
                    setTimeout(() => { window.location.href = data.redirect; }, 1500);
                } else {
                    errorDiv.textContent = data.error || 'Failed to update';
                    errorDiv.style.display = 'block';
                }
            } catch (err) {
                let msg = 'Failed to change password';
                if (err.code === 'auth/requires-recent-login') {
                    msg = 'Session expired. Please log out and log in again, then change your password.';
                } else if (err.code === 'auth/weak-password') {
                    msg = 'Firebase rejected: password too weak';
                }
                errorDiv.textContent = msg;
                errorDiv.style.display = 'block';
            } finally {
                btn.disabled = false;
                btn.textContent = 'Change Password';
            }
        }
    </script>
</body>
</html>'''


@app.route('/change-password')
def change_password():
    """Password change page — forced for first-time faculty, optional otherwise."""
    user = get_current_user()
    if not user:
        return redirect(url_for('login'))

    is_forced = not user.get('password_changed', False) and user['role'] != 'ADMIN'

    if user['role'] == 'ADMIN':
        back_url = url_for('admin_dashboard')
    else:
        back_url = url_for('faculty_dashboard')

    subtitle = 'Set a secure password to continue' if is_forced else 'Update your password'

    return render_template_string(
        CHANGE_PASSWORD_TEMPLATE,
        firebase_config=FIREBASE_WEB_CONFIG,
        is_forced=is_forced,
        subtitle=subtitle,
        back_url=back_url,
    )


@app.route('/api/password-changed', methods=['POST'])
def api_password_changed():
    """Mark the current user's password as changed in the database."""
    user = get_current_user()
    if not user:
        return jsonify({'success': False, 'error': 'Not logged in'}), 401

    db = DBManager(quiet=True)
    try:
        db.cur.execute(
            "UPDATE user_role SET password_changed = TRUE WHERE uid = %s",
            (user['uid'],)
        )
        db.conn.commit()
    finally:
        db.close()

    # Update session
    session['password_changed'] = True

    if user['role'] == 'ADMIN':
        redirect_url = url_for('admin_dashboard')
    else:
        redirect_url = url_for('faculty_dashboard')

    return jsonify({'success': True, 'redirect': redirect_url})


# ---------------------------------------------------------------------------
# ADMIN: MANAGE USERS (Create faculty accounts)
# ---------------------------------------------------------------------------

@app.route('/admin/manage-users')
@admin_required
def admin_manage_users():
    """Admin page to view existing users and create new faculty accounts."""
    db = DBManager(quiet=True)
    try:
        db.cur.execute(
            """SELECT ur.uid, ur.email, ur.role, ur.password_changed, ur.created_at,
                      f.short_name
               FROM user_role ur
               LEFT JOIN faculty f ON ur.faculty_id = f.faculty_id
               ORDER BY ur.role, ur.email"""
        )
        columns = [desc[0] for desc in db.cur.description]
        users = [dict(zip(columns, row)) for row in db.cur.fetchall()]

        # Get faculty members not yet linked to accounts
        db.cur.execute(
            """SELECT f.faculty_id, f.short_name
               FROM faculty f
               WHERE f.faculty_id NOT IN (
                   SELECT faculty_id FROM user_role WHERE faculty_id IS NOT NULL
               )
               ORDER BY f.short_name"""
        )
        unlinked_faculty = db.cur.fetchall()
    finally:
        db.close()

    users = format_entries(users)

    # Users table
    users_rows = ''
    for u in users:
        role_class = 'role-admin' if u['role'] == 'ADMIN' else 'role-faculty'
        pw_badge = ('<span class="badge badge-active">Changed</span>'
                    if u['password_changed']
                    else '<span class="badge badge-inactive">Pending</span>')
        delete_btn = ''
        if u['role'] != 'ADMIN':
            uid_safe = u['uid']
            email_safe = u['email']
            delete_btn = f'<button class="btn-delete" data-uid="{uid_safe}" data-email="{email_safe}" onclick="deleteUser(this)">🗑️ Delete</button>'
        users_rows += f'''
            <tr id="row-{u['uid']}">
                <td><strong>{u.get("short_name", "—")}</strong></td>
                <td>{u["email"]}</td>
                <td><span class="user-role {role_class}" style="padding:0.15rem 0.6rem;border-radius:20px;font-size:0.7rem;">{u["role"]}</span></td>
                <td>{pw_badge}</td>
                <td>{u.get("created_at", "")}</td>
                <td>{delete_btn}</td>
            </tr>'''

    # Unlinked faculty options
    faculty_options = ''
    for fid, sname in unlinked_faculty:
        faculty_options += f'<option value="{fid}" data-short="{sname}">{sname}</option>'

    content = f'''
    <h1><span class="icon">👥</span>Manage Users</h1>
    <p class="subtitle">Create and manage faculty accounts — only admin can create accounts</p>

    <div class="table-container" style="margin-bottom: 2rem;">
        <div class="table-header">
            <h2>➕ Create Faculty Account</h2>
        </div>
        <div style="padding: 1.5rem;">
            <div id="create-error" class="error-msg" style="display:none;margin-bottom:1rem;background:rgba(239,68,68,0.1);border:1px solid rgba(239,68,68,0.3);color:var(--accent-red);padding:0.75rem 1rem;border-radius:8px;font-size:0.85rem;"></div>
            <div id="create-success" class="success-msg" style="display:none;margin-bottom:1rem;background:rgba(16,185,129,0.1);border:1px solid rgba(16,185,129,0.3);color:var(--accent-green);padding:0.75rem 1rem;border-radius:8px;font-size:0.85rem;"></div>

            {'<p style="color:var(--text-muted);font-size:0.85rem;">All faculty members already have accounts.</p>' if not unlinked_faculty else f"""
            <form id="create-user-form" onsubmit="createUser(event)" style="display:flex;gap:1rem;flex-wrap:wrap;align-items:flex-end;">
                <div class="filter-group">
                    <label>Faculty Member</label>
                    <select id="faculty-select" required onchange="updateEmail()">
                        <option value="">Select faculty...</option>
                        {faculty_options}
                    </select>
                </div>
                <div class="filter-group">
                    <label>Email (auto-generated)</label>
                    <input type="email" id="user-email" readonly style="min-width:220px;opacity:0.7;">
                </div>
                <div class="filter-group">
                    <label>Temp Password (auto-generated)</label>
                    <input type="text" id="temp-password" readonly style="min-width:200px;font-family:monospace;opacity:0.7;">
                </div>
                <button type="submit" class="btn btn-green" id="create-btn">Create Account</button>
            </form>
            """}
        </div>
    </div>

    <div class="table-container">
        <div class="table-header">
            <h2>📋 All User Accounts</h2>
            <span class="table-count">{len(users)} users</span>
        </div>
        <div class="table-scroll">
            <table>
                <thead>
                    <tr>
                        <th>Faculty</th>
                        <th>Email</th>
                        <th>Role</th>
                        <th>Password Status</th>
                        <th>Created</th>
                        <th>Actions</th>
                    </tr>
                </thead>
                <tbody>{users_rows}</tbody>
            </table>
        </div>
    </div>

    <script>
    function generatePassword() {{
        const upper = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
        const lower = 'abcdefghjkmnpqrstuvwxyz';
        const digits = '23456789';
        const special = '!@#$%&*';
        let pw = '';
        pw += upper[Math.floor(Math.random() * upper.length)];
        pw += lower[Math.floor(Math.random() * lower.length)];
        pw += digits[Math.floor(Math.random() * digits.length)];
        pw += special[Math.floor(Math.random() * special.length)];
        const all = upper + lower + digits + special;
        for (let i = 0; i < 8; i++) {{
            pw += all[Math.floor(Math.random() * all.length)];
        }}
        // Shuffle
        pw = pw.split('').sort(() => Math.random() - 0.5).join('');
        return pw;
    }}

    function updateEmail() {{
        const sel = document.getElementById('faculty-select');
        const opt = sel.options[sel.selectedIndex];
        const short = opt.getAttribute('data-short') || '';
        document.getElementById('user-email').value = short ? (short.toLowerCase() + '@daiict.ac.in') : '';
        document.getElementById('temp-password').value = short ? generatePassword() : '';
    }}

    async function createUser(e) {{
        e.preventDefault();
        const btn = document.getElementById('create-btn');
        const errorDiv = document.getElementById('create-error');
        const successDiv = document.getElementById('create-success');
        const facultyId = document.getElementById('faculty-select').value;
        const email = document.getElementById('user-email').value;
        const password = document.getElementById('temp-password').value;

        errorDiv.style.display = 'none';
        successDiv.style.display = 'none';

        if (!facultyId || !email || !password) {{
            errorDiv.textContent = 'Please select a faculty member';
            errorDiv.style.display = 'block';
            return;
        }}

        btn.disabled = true;
        btn.textContent = 'Creating...';

        try {{
            const resp = await fetch('/api/admin/create-user', {{
                method: 'POST',
                headers: {{ 'Content-Type': 'application/json' }},
                body: JSON.stringify({{ faculty_id: facultyId, email: email, password: password }})
            }});
            const data = await resp.json();

            if (data.success) {{
                successDiv.innerHTML = 'Account created!<br><strong>Email:</strong> ' + email +
                    '<br><strong>Temporary Password:</strong> <code style="background:var(--bg-secondary);padding:0.2rem 0.5rem;border-radius:4px;">' +
                    password + '</code><br><em>Share this with the faculty member. They must change it on first login.</em>';
                successDiv.style.display = 'block';
                // Remove the option from dropdown
                const sel = document.getElementById('faculty-select');
                sel.remove(sel.selectedIndex);
                document.getElementById('user-email').value = '';
                document.getElementById('temp-password').value = '';
                // Reload after a moment to update the table
                setTimeout(() => location.reload(), 3000);
            }} else {{
                errorDiv.textContent = data.error || 'Failed to create account';
                errorDiv.style.display = 'block';
            }}
        }} catch (err) {{
            errorDiv.textContent = 'Network error: ' + err.message;
            errorDiv.style.display = 'block';
        }} finally {{
            btn.disabled = false;
            btn.textContent = 'Create Account';
        }}
    }}

    async function deleteUser(btn) {{
        const uid = btn.getAttribute('data-uid');
        const email = btn.getAttribute('data-email');
        if (!confirm('Delete account for ' + email + '?\\n\\nThis will remove their Firebase account and they will need to be re-created.')) return;

        btn.disabled = true;
        btn.textContent = 'Deleting...';

        try {{
            const resp = await fetch('/api/admin/delete-user', {{
                method: 'POST',
                headers: {{ 'Content-Type': 'application/json' }},
                body: JSON.stringify({{ uid: uid }})
            }});
            const data = await resp.json();

            if (data.success) {{
                const row = document.getElementById('row-' + uid);
                if (row) {{
                    row.style.transition = 'opacity 0.4s';
                    row.style.opacity = '0';
                    window.setTimeout(function() {{
                        row.remove();
                        window.setTimeout(function() {{ location.reload(); }}, 400);
                    }}, 400);
                }} else {{
                    location.reload();
                }}
            }} else {{
                alert('Delete failed: ' + (data.error || 'Unknown error'));
                btn.disabled = false;
                btn.textContent = '🗑️ Delete';
            }}
        }} catch (err) {{
            alert('Network error: ' + err.message);
            btn.disabled = false;
            btn.textContent = '🗑️ Delete';
        }}
    }}
    </script>
    '''

    return page_shell('Manage Users', get_current_user(), 'users', content)


@app.route('/api/admin/create-user', methods=['POST'])
@admin_required
def api_admin_create_user():
    """Admin API endpoint to create a new faculty Firebase account."""
    data = request.get_json()
    faculty_id = data.get('faculty_id')
    email = data.get('email', '').strip()
    password = data.get('password', '').strip()

    if not faculty_id or not email or not password:
        return jsonify({'success': False, 'error': 'Missing required fields'}), 400

    # Validate password against policy
    ok, err_msg = validate_password(password)
    if not ok:
        return jsonify({'success': False, 'error': err_msg}), 400

    if not FIREBASE_INITIALIZED:
        return jsonify({'success': False, 'error': 'Firebase not configured'}), 500

    try:
        # Create Firebase Auth user
        user_record = firebase_auth.create_user(
            email=email,
            password=password,
            email_verified=True,
        )
        uid = user_record.uid

        # Insert into our database
        db = DBManager(quiet=True)
        try:
            db.cur.execute(
                """INSERT INTO user_role (uid, email, role, faculty_id, password_changed)
                   VALUES (%s, %s, 'FACULTY', %s, FALSE)
                   ON CONFLICT (uid) DO UPDATE
                   SET faculty_id = EXCLUDED.faculty_id, role = 'FACULTY'""",
                (uid, email, int(faculty_id))
            )
            db.conn.commit()
        finally:
            db.close()

        return jsonify({'success': True, 'uid': uid})

    except firebase_admin.exceptions.AlreadyExistsError:
        return jsonify({'success': False,
                        'error': f'Account {email} already exists in Firebase'}), 409
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500


@app.route('/api/admin/delete-user', methods=['POST'])
@admin_required
def api_admin_delete_user():
    """Admin API endpoint to delete a faculty Firebase account."""
    data = request.get_json()
    uid = data.get('uid', '').strip()

    if not uid:
        return jsonify({'success': False, 'error': 'Missing UID'}), 400

    # Prevent deleting admin accounts via API
    db = DBManager(quiet=True)
    try:
        db.cur.execute("SELECT role FROM user_role WHERE uid = %s", (uid,))
        row = db.cur.fetchone()
        if not row:
            return jsonify({'success': False, 'error': 'User not found'}), 404
        if row[0] == 'ADMIN':
            return jsonify({'success': False, 'error': 'Cannot delete admin accounts'}), 403

        # Delete from database first
        db.cur.execute("DELETE FROM user_role WHERE uid = %s", (uid,))
        db.conn.commit()
    finally:
        db.close()

    # Delete from Firebase
    if FIREBASE_INITIALIZED:
        try:
            firebase_auth.delete_user(uid)
        except Exception:
            pass  # If Firebase fails, DB record is already gone — user can be re-created

    return jsonify({'success': True})


# ---------------------------------------------------------------------------
# API Endpoints (for programmatic access — admin only)
# ---------------------------------------------------------------------------

@app.route('/api/stats')
@admin_required
def api_stats():
    db = DBManager(quiet=True)
    try:
        return jsonify(db.get_stats())
    finally:
        db.close()


@app.route('/api/timetable')
@admin_required
def api_timetable():
    filters = {}
    for key in ['day_of_week', 'sub_batch', 'faculty', 'room']:
        val = request.args.get(key)
        if val:
            filters[key] = val

    db = DBManager(quiet=True)
    try:
        entries = db.get_master_timetable(filters if filters else None)
        entries = format_entries(entries)
        return jsonify(entries)
    finally:
        db.close()


@app.route('/api/constraints')
@admin_required
def api_constraints():
    db = DBManager(quiet=True)
    try:
        entries = db.get_constraints()
        entries = format_entries(entries)
        return jsonify(entries)
    finally:
        db.close()


# ---------------------------------------------------------------------------
# Entry Point
# ---------------------------------------------------------------------------
if __name__ == '__main__':
    print("=" * 60)
    print("  Timetable Generator — Web Interface")
    print("  Open http://localhost:5001 in your browser")
    if FIREBASE_INITIALIZED:
        print("  ✓ Firebase Auth: ENABLED")
    else:
        print("  ⚠ Firebase Auth: DISABLED (service account missing)")
    print("=" * 60)
    app.run(debug=True, port=5001)
