#!/usr/bin/env python3

import json
import os
import secrets
import sqlite3
import string
import sys
import uuid
from enum import Enum
from typing import Optional

import bcrypt
import jwt


class UserType(Enum):
    ADMIN = "admin"
    OPERATOR = "operator"
    USER = "user"


class KeysStorage:
    def __init__(self, db_connection) -> None:
        self.db_connection = db_connection
        cursor = db_connection.cursor()
        cursor.execute("CREATE TABLE IF NOT EXISTS keys (key TEXT NOT NULL)")
        db_connection.commit()

    def make_key(self) -> str:
        alphabet = string.ascii_letters + string.digits + string.punctuation
        key = "".join(secrets.choice(alphabet) for _ in range(32))
        return key

    def store_key(self, key: str) -> None:
        cursor = self.db_connection.cursor()
        cursor.execute("INSERT INTO keys (key) VALUES (?)", (key,))
        self.db_connection.commit()

    def get_key(self) -> str:
        cursor = self.db_connection.cursor()
        cursor.execute("SELECT key FROM keys")
        result = cursor.fetchone()
        if result is not None:
            return result[0]
        key = self.make_key()
        self.store_key(key)
        return key

    def get_key_for_signing(self) -> str:
        return self.get_key()

    def get_key_for_verifying(self) -> str:
        return self.get_key()


class UsersStorage:
    def __init__(self, db_connection):
        self.db_connection = db_connection
        cursor = db_connection.cursor()
        cursor.execute(
            "CREATE TABLE IF NOT EXISTS users (user_id TEXT PRIMARY KEY NOT NULL, login TEXT NOT NULL, pwd_hash TEXT NOT NULL, type TEXT NOT NULL)"
        )
        db_connection.commit()
        self.keys_storage = KeysStorage(db_connection)

    def set_password(self, user_type: UserType, user_login: str, password: str) -> bool:
        cursor = self.db_connection.cursor()
        cursor.execute("SELECT type FROM users WHERE login=?", (user_login,))
        result = cursor.fetchone()
        if result is not None and result[0] != user_type.value:
            return False
        cursor.execute("DELETE FROM users WHERE type=?", (user_type.value,))
        password_hash = bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")
        cursor.execute(
            "INSERT INTO users (user_id, login, pwd_hash, type) VALUES (?, ?, ?, ?)",
            (str(uuid.uuid4()), user_login, password_hash, user_type.value),
        )
        self.db_connection.commit()
        return True

    def password_is_set(self, user_type: UserType) -> bool:
        cursor = self.db_connection.cursor()
        cursor.execute("SELECT COUNT(*) FROM users WHERE type=?", (user_type.value,))
        return cursor.fetchone()[0] > 0

    def has_users(self) -> bool:
        cursor = self.db_connection.cursor()
        cursor.execute("SELECT COUNT(*) FROM users")
        return cursor.fetchone()[0] > 0

    def get_user_type_by_login_and_password(self, user_login: str, password: str) -> Optional[UserType]:
        cursor = self.db_connection.cursor()
        cursor.execute("SELECT pwd_hash, type FROM users WHERE login=?", (user_login,))
        result = cursor.fetchone()
        if result is not None:
            if bcrypt.checkpw(password.encode("utf-8"), result[0].encode("utf-8")):
                return UserType(result[1])
        return None

    def get_user_type_by_cookie(self, cookie: str) -> Optional[UserType]:
        try:
            decoded = jwt.decode(cookie, self.keys_storage.get_key_for_verifying(), algorithms=["HS256"])
            user_id = decoded.get("id")
            cursor = self.db_connection.cursor()
            cursor.execute("SELECT type FROM users WHERE user_id=?", (user_id,))
            result = cursor.fetchone()
            if result is not None:
                return UserType(result[0])
        except Exception:
            pass
        return None

    def make_cookie(self, user_type: UserType) -> Optional[str]:
        cursor = self.db_connection.cursor()
        cursor.execute("SELECT user_id FROM users WHERE type=?", (user_type.value,))
        result = cursor.fetchone()
        if result is not None:
            return jwt.encode(
                {"id": result[0]}, self.keys_storage.get_key_for_signing(), algorithm="HS256"
            ).decode("utf-8")
        return None


def return_200(header: str = None, body: str = None) -> None:
    sys.stdout.write(f"Status: 200 Ok\r\n{header}\r\n\r\n{body}")
    sys.exit(0)


def return_400(msg: str) -> None:
    sys.stdout.write(f"Status: 400 Bad Request\r\n\r\nBad Request: {msg}")
    sys.exit(0)


def return_401() -> None:
    sys.stdout.write("Status: 401 Unauthorized\r\n\r\n")
    sys.exit(0)


def return_403() -> None:
    sys.stdout.write("Status: 403 Forbidden\r\n\r\n")
    sys.exit(0)


def make_set_cookie_header(cookie: str) -> str:
    return f"Set-Cookie: id={cookie}; HttpOnly; SameSite=Lax;\r\n"


def get_cookie_params_dict(params: str) -> dict:
    if params is None:
        return {}
    return {part.split("=")[0].strip(): part.split("=")[1].strip() for part in params.split(";")}


def get_id_from_cookie(header: str) -> Optional[str]:
    if header is None:
        return None
    return get_cookie_params_dict(header).get("id")


def is_admin_uri(uri: str) -> bool:
    uri_prefixes = ["/fwupdate"]
    return any(uri.startswith(prefix) for prefix in uri_prefixes)


def validate_login_request(form: dict) -> None:
    if "password" not in form.keys():
        raise TypeError("No password field in POST arguments")

    if not isinstance(form.get("password"), str) or not form.get("password"):
        raise TypeError("Invalid password field in POST arguments")

    if "login" not in form.keys():
        raise TypeError("No login field in POST arguments")

    if not isinstance(form.get("login"), str) or not form.get("login"):
        raise TypeError("Invalid login field in POST arguments")


def validate_auth_setup_request(request: dict) -> None:
    if request.get("type") not in [e.value for e in UserType]:
        raise TypeError("Invalid type field in POST arguments")

    if "password" not in request.keys():
        raise TypeError("No password field in POST arguments")

    if not isinstance(request.get("password"), str) or not request.get("password"):
        raise TypeError("Invalid password field in POST arguments")

    if "login" not in request.keys():
        raise TypeError("No login field in POST arguments")

    if not isinstance(request.get("login"), str) or not request.get("login"):
        raise TypeError("Invalid login field in POST arguments")


def check_auth(db_connection) -> None:
    uri = os.environ.get("REQUEST_URI")
    users_storage = UsersStorage(db_connection)

    user_type = users_storage.get_user_type_by_cookie(get_id_from_cookie(os.environ.get("HTTP_COOKIE")))
    if (user_type == UserType.ADMIN) or (
        not is_admin_uri(uri)
        and ((user_type is not None) or (user_type is None and not users_storage.has_users()))
    ):
        homeui_header = ""
        if user_type is not None:
            homeui_header = f"Homeui-User: {user_type.value}"
        return_200(header=homeui_header)

    return_401()


def login(db_connection) -> None:
    try:
        form = json.loads(sys.stdin.read())
        validate_login_request(form)
    except Exception as e:
        return_400(str(e))

    users_storage = UsersStorage(db_connection)
    user_type = users_storage.get_user_type_by_login_and_password(form.get("login"), form.get("password"))
    if user_type is None:
        return_401()
    return_200(header=make_set_cookie_header(users_storage.make_cookie(user_type)))


def allow_to_setup_user(user_type: UserType, user_type_to_set: UserType, users_storage: UsersStorage) -> bool:
    if user_type == UserType.ADMIN:
        return True
    if user_type_to_set != UserType.ADMIN:
        return False
    if user_type is None:
        return not users_storage.has_users()
    return not users_storage.password_is_set(UserType.ADMIN)


def auth_setup(db_connection) -> None:
    try:
        request = json.loads(sys.stdin.read())
        validate_auth_setup_request(request)
    except Exception as e:
        return_400(str(e))

    users_storage = UsersStorage(db_connection)
    user_type_to_set = UserType(request.get("type"))
    user_type = users_storage.get_user_type_by_cookie(get_id_from_cookie(os.environ.get("HTTP_COOKIE")))
    if allow_to_setup_user(user_type, user_type_to_set, users_storage):
        if users_storage.set_password(user_type_to_set, request.get("login"), request.get("password")):
            return_200()
        return_400("Login already exists")
    return_403()


def not_configured_users(db_connection) -> None:
    users_storage = UsersStorage(db_connection)
    user_type = users_storage.get_user_type_by_cookie(get_id_from_cookie(os.environ.get("HTTP_COOKIE")))
    if user_type is None:
        if users_storage.has_users():
            return_403()
        return_200("Content-type: text/plain", UserType.ADMIN.value)

    if user_type in [UserType.USER, UserType.OPERATOR] and not users_storage.password_is_set(UserType.ADMIN):
        return_200("Content-type: text/plain", UserType.ADMIN.value)
    not_set = [user_type.value for user_type in UserType if not users_storage.password_is_set(user_type)]
    return_200("Content-type: text/plain", ",".join(not_set))


def main():
    action_methods = {
        "check_auth": check_auth,
        "login": login,
        "auth_setup": auth_setup,
        "not_configured_users": not_configured_users,
    }
    action = os.environ.get("ACTION")
    if action not in action_methods:
        raise ValueError("Invalid action")
    con = sqlite3.connect("/var/wb-webui.conf.d/users.db")
    action_methods[action](con)


try:
    main()
except Exception as e:
    sys.stdout.write(f"Status: 500 Internal Server Error\r\n\r\nInternal Server Error: {e}")
    sys.exit(1)
