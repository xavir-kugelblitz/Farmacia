import customtkinter as ctk
from database import Database, authenticate_user
from usuarios import UsuariosFrame


class FarmaciaApp(ctk.CTk):

    def __init__(self):
        super().__init__()

        self.title("Sistema de Gestión de Farmacia")
        self.geometry("1100x700")
        self.minsize(850, 550)

        ctk.set_appearance_mode("system")
        ctk.set_default_color_theme("blue")

        self.db = Database()
        self.usuario_actual = None

        self.modulos_por_rol = {
            "Admin": [
                "Inicio", "Usuarios", "Medicamentos", "Clientes",
                "Ventas", "Compras", "Pedidos", "Reportes"
            ],
            "Gerente": [
                "Inicio", "Usuarios", "Medicamentos", "Clientes",
                "Ventas", "Compras", "Pedidos", "Reportes"
            ],
            "Encargado": [
                "Inicio", "Medicamentos", "Clientes", "Ventas"
            ]
        }

        self.mostrar_login()

    # --------------------------------------------------
    # INICIO DE SESIÓN
    # --------------------------------------------------

    def limpiar_ventana(self):
        for widget in self.winfo_children():
            widget.destroy()

    def mostrar_login(self):
        self.limpiar_ventana()

        contenedor = ctk.CTkFrame(self, width=420)
        contenedor.place(relx=0.5, rely=0.5, anchor="center")

        ctk.CTkLabel(
            contenedor,
            text="Sistema de Gestión de Farmacia",
            font=ctk.CTkFont(size=24, weight="bold")
        ).pack(padx=30, pady=(35, 10))

        ctk.CTkLabel(
            contenedor,
            text="Inicio de sesión",
            font=ctk.CTkFont(size=16)
        ).pack(pady=(0, 25))

        self.entrada_usuario = ctk.CTkEntry(
            contenedor,
            width=300,
            height=40,
            placeholder_text="Nombre de usuario"
        )
        self.entrada_usuario.pack(pady=10)

        self.entrada_contrasena = ctk.CTkEntry(
            contenedor,
            width=300,
            height=40,
            placeholder_text="Contraseña",
            show="*"
        )
        self.entrada_contrasena.pack(pady=10)

        self.mostrar_contrasena = ctk.BooleanVar(value=False)

        ctk.CTkCheckBox(
            contenedor,
            text="Mostrar contraseña",
            variable=self.mostrar_contrasena,
            command=self.alternar_contrasena
        ).pack(pady=8)

        self.mensaje = ctk.CTkLabel(
            contenedor,
            text="",
            text_color=("red", "#ff5555")
        )
        self.mensaje.pack(pady=8)

        self.boton_login = ctk.CTkButton(
            contenedor,
            text="Iniciar sesión",
            width=300,
            height=40,
            command=self.iniciar_sesion
        )
        self.boton_login.pack(pady=(10, 35))

        self.entrada_usuario.focus()
        self.bind("<Return>", self.evento_enter)

    def alternar_contrasena(self):
        if self.mostrar_contrasena.get():
            self.entrada_contrasena.configure(show="")
        else:
            self.entrada_contrasena.configure(show="*")

    def evento_enter(self, evento=None):
        self.iniciar_sesion()

    def iniciar_sesion(self):
        usuario = self.entrada_usuario.get().strip()
        contrasena = self.entrada_contrasena.get()

        if not usuario or not contrasena:
            self.mensaje.configure(text="Ingresa tu usuario y contraseña.")
            return

        self.boton_login.configure(state="disabled", text="Verificando...")
        self.update_idletasks()

        try:
            resultado = authenticate_user(
                db=self.db,
                nombre_usuario=usuario,
                password=contrasena
            )

            if resultado is None:
                self.mensaje.configure(
                    text="Usuario o contraseña incorrectos."
                )
                self.entrada_contrasena.delete(0, "end")
                self.entrada_contrasena.focus()
                return

            self.usuario_actual = resultado
            self.mostrar_ventana_principal()

        except Exception as error:
            self.mensaje.configure(text=f"Error de conexión: {error}")

        finally:
            # La pantalla de login puede haber sido destruida tras autenticar.
            try:
                if self.boton_login.winfo_exists():
                    self.boton_login.configure(
                        state="normal",
                        text="Iniciar sesión"
                    )
            except Exception:
                pass

    # --------------------------------------------------
    # VENTANA PRINCIPAL
    # --------------------------------------------------

    def mostrar_ventana_principal(self):
        self.unbind("<Return>")
        self.limpiar_ventana()

        barra_superior = ctk.CTkFrame(
            self,
            height=65,
            corner_radius=0
        )
        barra_superior.pack(fill="x")
        barra_superior.pack_propagate(False)

        ctk.CTkLabel(
            barra_superior,
            text="FARMACIA",
            font=ctk.CTkFont(size=22, weight="bold")
        ).pack(side="left", padx=25)

        modulos = self.modulos_por_rol.get(
            self.usuario_actual["rol"], ["Inicio"]
        )

        self.menu_modulos = ctk.CTkOptionMenu(
            barra_superior,
            values=modulos,
            width=180,
            command=self.mostrar_modulo
        )
        self.menu_modulos.pack(side="left", padx=20)

        ctk.CTkLabel(
            barra_superior,
            text=(
                f"{self.usuario_actual['nombre_completo']} "
                f"({self.usuario_actual['rol']})"
            ),
            font=ctk.CTkFont(size=13)
        ).pack(side="right", padx=20)

        self.area_contenido = ctk.CTkFrame(
            self,
            corner_radius=0
        )
        self.area_contenido.pack(
            fill="both",
            expand=True,
            padx=15,
            pady=15
        )

        self.mostrar_modulo("Inicio")

    # --------------------------------------------------
    # NAVEGACIÓN ENTRE MÓDULOS
    # --------------------------------------------------

    def mostrar_modulo(self, modulo):
        rol = self.usuario_actual["rol"]
        modulos_permitidos = self.modulos_por_rol.get(rol, ["Inicio"])

        if modulo not in modulos_permitidos:
            modulo = "Inicio"

        for widget in self.area_contenido.winfo_children():
            widget.destroy()

        if modulo == "Inicio":
            self.mostrar_inicio()

        elif modulo == "Usuarios":
            self.mostrar_usuarios()

        else:
            self.mostrar_modulo_provisional(modulo)

    def mostrar_usuarios(self):
        try:
            pantalla = UsuariosFrame(
                self.area_contenido,
                self.db,
                self.usuario_actual
            )
            pantalla.pack(fill="both", expand=True)
        except Exception as error:
            ctk.CTkLabel(
                self.area_contenido,
                text=f"No fue posible abrir Administración de usuarios:\n{error}",
                text_color=("red", "#ff5555"),
                wraplength=750
            ).pack(padx=30, pady=50)

    # --------------------------------------------------
    # PANTALLA DE INICIO
    # --------------------------------------------------

    def mostrar_inicio(self):
        ctk.CTkLabel(
            self.area_contenido,
            text="Panel principal",
            font=ctk.CTkFont(size=28, weight="bold")
        ).pack(anchor="w", padx=30, pady=(35, 10))

        ctk.CTkLabel(
            self.area_contenido,
            text=f"Bienvenido, {self.usuario_actual['nombre_completo']}",
            font=ctk.CTkFont(size=20)
        ).pack(anchor="w", padx=30, pady=10)

        ctk.CTkLabel(
            self.area_contenido,
            text=f"Rol de usuario: {self.usuario_actual['rol']}",
            font=ctk.CTkFont(size=16)
        ).pack(anchor="w", padx=30, pady=5)

        ctk.CTkLabel(
            self.area_contenido,
            text="Selecciona un módulo en el menú superior para comenzar.",
            font=ctk.CTkFont(size=15)
        ).pack(anchor="w", padx=30, pady=20)

        ctk.CTkButton(
            self.area_contenido,
            text="Cerrar sesión",
            width=160,
            command=self.cerrar_sesion
        ).pack(anchor="w", padx=30, pady=25)

    # --------------------------------------------------
    # PANTALLAS PROVISIONALES
    # --------------------------------------------------

    def mostrar_modulo_provisional(self, modulo):
        ctk.CTkLabel(
            self.area_contenido,
            text=modulo,
            font=ctk.CTkFont(size=28, weight="bold")
        ).pack(pady=(100, 15))

        ctk.CTkLabel(
            self.area_contenido,
            text="Este módulo todavía no ha sido desarrollado.",
            font=ctk.CTkFont(size=16)
        ).pack(pady=10)

        ctk.CTkLabel(
            self.area_contenido,
            text="Su funcionalidad se incorporará en una siguiente etapa.",
            font=ctk.CTkFont(size=14)
        ).pack(pady=5)

    # --------------------------------------------------
    # CIERRE DE SESIÓN
    # --------------------------------------------------

    def cerrar_sesion(self):
        self.usuario_actual = None
        self.unbind("<Return>")
        self.mostrar_login()


if __name__ == "__main__":
    app = FarmaciaApp()
    app.mainloop()
