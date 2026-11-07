from __future__ import annotations

import base64
import hashlib
import hmac
import os
import secrets

from contextlib import contextmanager
from dataclasses import dataclass
from typing import Any, Iterator, Mapping, Sequence

import mysql.connector
from mysql.connector import Error, MySQLConnection

@dataclass(frozen=True)
class DatabaseConfig:

    host: str = "localhost"
    port: int = 3306
    user: str = "root"
    password: str = ""
    database: str = "farmacia_db"

    @classmethod
    def from_environment(cls) -> "DatabaseConfig":

        return cls(
            host=os.getenv("FARMACIA_DB_HOST", "localhost"),
            port=int(os.getenv("FARMACIA_DB_PORT", "3306")),
            user=os.getenv("FARMACIA_DB_USER", "root"),
            password=os.getenv("FARMACIA_DB_PASSWORD", ""),
            database=os.getenv("FARMACIA_DB_NAME", "farmacia_db"),
        )

class Database:
    def __init__(self, config: DatabaseConfig | None = None):
        self.config = config or DatabaseConfig.from_environment()

    def connect(self) -> MySQLConnection:

        try:
            return mysql.connector.connect(
                host=self.config.host,
                port=self.config.port,
                user=self.config.user,
                password=self.config.password,
                database=self.config.database,
                charset="utf8mb4",
                collation="utf8mb4_general_ci",
                autocommit=False,
                connection_timeout=10,
                use_pure=True
            )

        except Error as exc:

            raise RuntimeError(
                "No fue posible conectar con MySQL. "
                "Verifica el servidor, las credenciales "
                f"y la base de datos. Detalle: {exc}"
            ) from exc

    def test_connection(self) -> bool:
        connection = self.connect()

        try:
            cursor = connection.cursor()
            cursor.execute("SELECT 1")
            result = cursor.fetchone()
            cursor.close()
            return bool(result and result[0] == 1)

        finally:
            connection.close()

    @contextmanager
    def transaction(self) -> Iterator[Any]:
        connection = self.connect()
        cursor = connection.cursor(dictionary=True)

        try:
            yield cursor
            connection.commit()

        except Exception:
            connection.rollback()
            raise

        finally:
            cursor.close()
            connection.close()

    def execute(self,query: str,params: Sequence[Any] | Mapping[str, Any] | None = None,) -> int:
        connection = self.connect()
        cursor = connection.cursor()

        try:
            cursor.execute(query, params or ())
            connection.commit()
            return int(cursor.lastrowid or 0)

        except Exception:
            connection.rollback()
            raise

        finally:
            cursor.close()
            connection.close()

    def fetch_one(self,query: str,params: Sequence[Any] | Mapping[str, Any] | None = None,) -> dict[str, Any] | None:
        connection = self.connect()
        cursor = connection.cursor(dictionary=True)

        try:
            cursor.execute(query, params or ())
            return cursor.fetchone()

        finally:
            cursor.close()
            connection.close()

    def fetch_all(self,query: str,params: Sequence[Any] | Mapping[str, Any] | None = None,) -> list[dict[str, Any]]:
        connection = self.connect()
        cursor = connection.cursor(dictionary=True)

        try:
            cursor.execute(query, params or ())
            return cursor.fetchall()

        finally:
            cursor.close()
            connection.close()

_SCRYPT_N = 2**14
_SCRYPT_R = 8
_SCRYPT_P = 1
_SCRYPT_SALT_BYTES = 16
_SCRYPT_KEY_BYTES = 32

def hash_password(password: str) -> str:
    if not isinstance(password, str) or len(password) < 10:
        raise ValueError("La contraseña debe tener al menos 10 caracteres.")
    salt = secrets.token_bytes(_SCRYPT_SALT_BYTES)
    derived_key = hashlib.scrypt(
        password.encode("utf-8"),
        salt=salt,
        n=_SCRYPT_N,
        r=_SCRYPT_R,
        p=_SCRYPT_P,
        dklen=_SCRYPT_KEY_BYTES,
        maxmem=64 * 1024 * 1024,
    )

    salt_b64 = base64.urlsafe_b64encode(salt).decode("ascii")
    key_b64 = base64.urlsafe_b64encode(derived_key).decode("ascii")

    return (f"scrypt${_SCRYPT_N}${_SCRYPT_R}"f"${_SCRYPT_P}${salt_b64}${key_b64}")


def verify_password(password: str, stored_hash: str) -> bool:
    try:
        algorithm, n, r, p, salt_b64, key_b64 = stored_hash.split("$")
        if algorithm != "scrypt":
            return False
        salt = base64.urlsafe_b64decode(salt_b64.encode("ascii"))
        expected_key = base64.urlsafe_b64decode(key_b64.encode("ascii"))
        calculated_key = hashlib.scrypt(
            password.encode("utf-8"),
            salt=salt,
            n=int(n),
            r=int(r),
            p=int(p),
            dklen=len(expected_key),
            maxmem=64 * 1024 * 1024,
        )

        return hmac.compare_digest(calculated_key,expected_key)
    except (ValueError, TypeError, UnicodeError):
        return False

def create_initial_admin(
    db: Database,
    nombre_completo: str,
    nombre_usuario: str,
    password: str,
    correo: str | None = None,
) -> int:
    """
    Crea el primer administrador del sistema.

    Requiere que el rol Admin exista previamente en MySQL.
    No crea administradores duplicados.
    """

    nombre_completo = nombre_completo.strip()
    nombre_usuario = nombre_usuario.strip()

    if not nombre_completo:
        raise ValueError("El nombre completo es obligatorio.")

    if not nombre_usuario:
        raise ValueError("El nombre de usuario es obligatorio.")

    password_hash = hash_password(password)

    with db.transaction() as cursor:

        cursor.execute(
            "SELECT id_rol FROM roles WHERE nombre = %s",
            ("Admin",),
        )

        role = cursor.fetchone()

        if role is None:

            raise RuntimeError(
                "No existe el rol Admin. "
                "Ejecuta primero el script SQL."
            )

        cursor.execute(
            """
            SELECT id_usuario
            FROM usuarios
            WHERE id_rol = %s
            LIMIT 1
            """,
            (role["id_rol"],),
        )

        if cursor.fetchone() is not None:

            raise RuntimeError(
                "Ya existe un administrador. "
                "No se creó otro."
            )

        cursor.execute(
            """
            INSERT INTO usuarios (
                id_rol,
                nombre_completo,
                nombre_usuario,
                correo,
                hash_contrasena,
                activo
            )
            VALUES (%s, %s, %s, %s, %s, TRUE)
            """,
            (
                role["id_rol"],
                nombre_completo,
                nombre_usuario,
                correo.strip() if correo else None,
                password_hash,
            ),
        )

        return int(cursor.lastrowid)

def authenticate_user(db: Database,nombre_usuario: str,password: str,) -> dict[str, Any] | None:
    user = db.fetch_one(
        """
        SELECT
            u.id_usuario,
            u.nombre_completo,
            u.nombre_usuario,
            u.hash_contrasena,
            r.nombre AS rol
        FROM usuarios AS u
        INNER JOIN roles AS r
            ON r.id_rol = u.id_rol
        WHERE
            u.nombre_usuario = %s
            AND u.activo = TRUE
        LIMIT 1
        """,
        (nombre_usuario.strip(),),
    )

    if user is None:
        return None
    if not verify_password(password,user["hash_contrasena"]):
        return None
    user.pop("hash_contrasena", None)
    return user

if __name__ == "__main__":
    try:
        database = Database()
        if database.test_connection():
            print("Conexion con farmacia_db establecida correctamente.")

    except Exception as error:
        print(f"Error de conexion: {error}")
