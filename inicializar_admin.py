from database import Database, create_initial_admin
from getpass import getpass

try:
    db = Database()

    print("=== CREACIÓN DEL ADMINISTRADOR ===")

    nombre = input("Nombre completo: ")
    usuario = input("Nombre de usuario: ")
    correo = input("Correo electrónico (opcional): ")

    contrasena = getpass("Contraseña: ")
    confirmar = getpass("Confirmar contraseña: ")

    if contrasena != confirmar:
        raise ValueError("Las contraseñas no coinciden.")

    id_admin = create_initial_admin(
        db=db,
        nombre_completo=nombre,
        nombre_usuario=usuario,
        password=contrasena,
        correo=correo or None
    )

    print("\nAdministrador creado correctamente.")
    print("ID asignado:", id_admin)

except Exception as error:
    print("\nNo fue posible crear el administrador.")
    print("Detalle:", error)