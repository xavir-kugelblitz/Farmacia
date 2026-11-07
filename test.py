from database import Database

try:
    db = Database()

    if db.test_connection():
        print("Conexión establecida correctamente.")

        resultado = db.fetch_one(
            "SELECT DATABASE() AS base_datos, VERSION() AS version"
        )

        print("Base de datos:", resultado["base_datos"])
        print("Servidor:", resultado["version"])

except Exception as error:
    print("Error:", error)