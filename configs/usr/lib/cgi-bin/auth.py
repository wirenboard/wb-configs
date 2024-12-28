#!/usr/bin/env python3

import json
import os
import secrets
import sqlite3
import string
import sys
import uuid
from dataclasses import dataclass
from enum import Enum
from typing import Optional

import bcrypt
import jwt


class UserType(Enum):
    ADMIN = "admin"
    OPERATOR = "operator"
    USER = "user"


@dataclass
class User:
    user_id: str
    login: str
    pwd_hash: str
    type: UserType


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


def make_cookie_value(user_id: str, keys_storage: KeysStorage) -> str:
    return jwt.encode({"id": user_id}, keys_storage.get_key(), algorithm="HS256").decode("utf-8")


def decode_cookie_value(cookie: str, keys_storage: KeysStorage) -> Optional[str]:
    try:
        decoded = jwt.decode(cookie, keys_storage.get_key(), algorithms=["HS256"])
        return decoded.get("id")
    except Exception:
        return None


def make_password_hash(password: str) -> str:
    return bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")


def check_password(password: str, password_hash: str) -> bool:
    return bcrypt.checkpw(password.encode("utf-8"), password_hash.encode("utf-8"))


class UsersStorage:
    def __init__(self, db_connection):
        self.db_connection = db_connection
        cursor = db_connection.cursor()
        cursor.execute(
            "CREATE TABLE IF NOT EXISTS users (user_id TEXT PRIMARY KEY NOT NULL, login TEXT UNIQUE NOT NULL, pwd_hash TEXT NOT NULL, type TEXT NOT NULL)"
        )
        db_connection.commit()

    def add_user(self, user: User) -> None:
        cursor = self.db_connection.cursor()
        user_uuid = str(uuid.uuid4())
        cursor.execute(
            "INSERT INTO users (user_id, login, pwd_hash, type) VALUES (?, ?, ?, ?)",
            (user_uuid, user.login, user.pwd_hash, user.type.value),
        )
        self.db_connection.commit()
        user.user_id = user_uuid

    def delete_user(self, user_id: str) -> None:
        cursor = self.db_connection.cursor()
        cursor.execute("DELETE FROM users WHERE user_id=?", (user_id,))
        self.db_connection.commit()

    def update_user(self, user: User) -> None:
        cursor = self.db_connection.cursor()
        cursor.execute(
            "UPDATE users SET login=?, pwd_hash=?, type=? WHERE user_id=?",
            (user.login, user.pwd_hash, user.type.value, user.user_id),
        )
        self.db_connection.commit()

    def has_users(self) -> bool:
        cursor = self.db_connection.cursor()
        cursor.execute("SELECT EXISTS (SELECT 1 FROM users)")
        return cursor.fetchone()[0] == 1

    def get_user_by_login(self, user_login: str) -> Optional[User]:
        if user_login is None:
            return None
        cursor = self.db_connection.cursor()
        cursor.execute("SELECT user_id, pwd_hash, type FROM users WHERE login=?", (user_login,))
        result = cursor.fetchone()
        if result is not None:
            return User(result[0], user_login, result[1], UserType(result[2]))
        return None

    def get_user_by_id(self, user_id: str) -> Optional[User]:
        if user_id is None:
            return None
        cursor = self.db_connection.cursor()
        cursor.execute("SELECT login, pwd_hash, type FROM users WHERE user_id=?", (user_id,))
        result = cursor.fetchone()
        if result is not None:
            return User(user_id, result[0], result[1], UserType(result[2]))
        return None

    def count_users_by_type(self, user_type: UserType) -> int:
        cursor = self.db_connection.cursor()
        cursor.execute("SELECT COUNT(*) FROM users WHERE type=?", (user_type.value,))
        return cursor.fetchone()[0]

    def get_users(self):
        cursor = self.db_connection.cursor()
        cursor.execute("SELECT user_id, login, type FROM users")
        return [User(user_id, login, "", UserType(type)) for user_id, login, type in cursor.fetchall()]


def response_200(header: str = None, body: str = None) -> str:
    return f"Status: 200 Ok\r\n{header}\r\n\r\n{body}"


def response_400(msg: str) -> str:
    return f"Status: 400 Bad Request\r\n\r\nBad Request: {msg}"


def response_401() -> str:
    return "Status: 401 Unauthorized\r\n\r\n"


def response_403() -> str:
    return "Status: 403 Forbidden\r\n\r\n"


def response_404() -> str:
    return "Status: 404 Not Found\r\n\r\n"


def response_500(error: str) -> str:
    return f"Status: 500 Internal Server Error\r\n\r\nInternal Server Error: {error}"


def make_set_cookie_header(user_id: str) -> str:
    return f"Set-Cookie: id={user_id}; HttpOnly; SameSite=Lax;\r\n"


def get_cookie_params_dict(params: str) -> dict:
    if params is None:
        return {}
    return {part.split("=")[0].strip(): part.split("=")[1].strip() for part in params.split(";")}


def get_current_user(users_storage: UsersStorage, keys_storage: KeysStorage) -> Optional[User]:
    user_id = get_cookie_params_dict(os.environ.get("HTTP_COOKIE")).get("id")
    return users_storage.get_user_by_id(decode_cookie_value(user_id, keys_storage))


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


def validate_add_user_request(request: dict) -> None:
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


def check_auth_handler(db_connection) -> str:
    users_storage = UsersStorage(db_connection)
    keys_storage = KeysStorage(db_connection)
    user = get_current_user(users_storage, keys_storage)

    if user is None:
        return response_401() if users_storage.has_users() else response_200()

    uri = os.environ.get("REQUEST_URI")
    if (user.type == UserType.ADMIN) or not is_admin_uri(uri):
        return response_200(header=f"Homeui-User: {user.type.value}")

    return response_401()


def login_handler(db_connection) -> str:
    try:
        form = json.loads(sys.stdin.read())
        validate_login_request(form)
    except Exception as e:
        return response_400(str(e))

    users_storage = UsersStorage(db_connection)
    user = users_storage.get_user_by_login(form.get("login"))

    if user is None or not check_password(form.get("password"), user.pwd_hash):
        return response_401()

    keys_storage = KeysStorage(db_connection)
    return response_200(header=make_set_cookie_header(make_cookie_value(user.user_id, keys_storage)))


def only_for_admin(users_storage: UsersStorage, keys_storage: KeysStorage) -> bool:
    user = get_current_user(users_storage, keys_storage)
    return user is not None and user.type == UserType.ADMIN


def allow_to_add_user(current_user: Optional[User], user_to_add: User, users_storage: UsersStorage) -> bool:
    if current_user is None:
        if user_to_add.type == UserType.ADMIN:
            return not users_storage.has_users()
        return False
    return current_user.type == UserType.ADMIN


def add_user(users_storage: UsersStorage) -> str:
    if os.environ.get("REQUEST_URI") != "/auth/users":
        return response_404()

    try:
        form = json.loads(sys.stdin.read())
        validate_add_user_request(form)
    except Exception as e:
        return response_400(str(e))

    keys_storage = KeysStorage(users_storage.db_connection)
    current_user = get_current_user(users_storage, keys_storage)
    user_to_add = User("", form.get("login"), make_password_hash(form.get("password")), UserType(form.get("type")))

    if not allow_to_add_user(current_user, user_to_add, users_storage):
        return response_403()

    if users_storage.get_user_by_login(form.get("login")) is not None:
        return response_400("Login already exists")

    users_storage.add_user(user_to_add)
    return response_200(body=user_to_add.user_id)


def get_user_id_from_query() -> Optional[str]:
    query_components = os.environ.get("REQUEST_URI").split("/")
    return query_components[3] if len(query_components) == 4 else None


def update_user(users_storage: UsersStorage) -> str:
    user_id = get_user_id_from_query()
    if user_id is None:
        return response_404()

    user = users_storage.get_user_by_id(user_id)
    if user is None:
        return response_400("User not found")

    try:
        form = json.loads(sys.stdin.read())
    except Exception as e:
        return response_400(str(e))

    if form.get("login") is not None:
        user_with_the_same_login = users_storage.get_user_by_login(form.get("login"))
        if user_with_the_same_login is not None and user_with_the_same_login.user_id != user_id:
            return response_400("Login already exists")
        user.login = form.get("login")
    if form.get("password") is not None:
        user.pwd_hash = make_password_hash(form.get("password"))
    if form.get("type") is not None:
        if user.type == UserType.ADMIN and UserType(form.get("type")) != UserType.ADMIN:
            admin_count = users_storage.count_users_by_type(UserType.ADMIN)
            if admin_count == 1:
                return response_400("Can't change the last admin's type")
        user.type = UserType(form.get("type"))
    users_storage.update_user(user)
    return response_200()


def delete_user(users_storage: UsersStorage) -> str:
    user_id = get_user_id_from_query()
    if user_id is None:
        return response_404()
    user = users_storage.get_user_by_id(user_id)
    if user is None:
        return response_404()
    if user.type == UserType.ADMIN:
        admin_count = users_storage.count_users_by_type(UserType.ADMIN)
        if admin_count == 1:
            return response_400("Can't delete the last admin")
    users_storage.delete_user(user_id)
    return response_200()


def get_users(users_storage: UsersStorage) -> str:
    if os.environ.get("REQUEST_URI") != "/auth/users":
        return response_404()
    users = map(
        lambda user: {"id": user.user_id, "login": user.login, "type": user.type.value},
        users_storage.get_users(),
    )
    return response_200("Content-type: application/json", json.dumps(list(users)))


def users_handler(db_connection) -> str:
    method_handlers = {
        "GET": (get_users, only_for_admin),
        "POST": (add_user, None),
        "PUT": (update_user, only_for_admin),
        "DELETE": (delete_user, only_for_admin),
    }
    users_storage = UsersStorage(db_connection)

    handler = method_handlers.get(os.environ.get("REQUEST_METHOD"))
    if handler is None:
        return response_400("Invalid method")
    if handler[1] is None:
        return handler[0](users_storage)
    keys_storage = KeysStorage(db_connection)
    if handler[1](users_storage, keys_storage):
        return handler[0](users_storage)
    return response_403()


def check_config_handler(db_connection) -> str:
    users_storage = UsersStorage(db_connection)
    return response_404() if users_storage.has_users() else response_200()


def main():
    action_methods = {
        "check_auth": check_auth_handler,
        "login": login_handler,
        "users": users_handler,
        "check_config": check_config_handler,
    }
    action = os.environ.get("ACTION")
    if action not in action_methods:
        raise ValueError("Invalid action")
    con = sqlite3.connect("/var/wb-webui/users.db")
    sys.stdout.write(action_methods[action](con))


try:
    main()
except Exception as e:
    sys.stdout.write(response_500(str(e)))
    sys.exit(1)
