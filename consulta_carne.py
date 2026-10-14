import sys
import json
from playwright.sync_api import sync_playwright, TimeoutError as PlaywrightTimeoutError

URL = "https://chaira.uniamazonia.edu.co/Administrativo/Vistas/Publico/General/VerificaCarne.aspx"

def consultar_estudiante(documento: str, headless: bool = True) -> dict:
    resultado = {
        "success": False,
        "documento_consultado": documento,
        "nombre": None,
        "cedula": None,
        "programa": None,
        "tipo_usuario": None,
        "error": None
    }

    with sync_playwright() as p:
        browser = p.chromium.launch(headless=headless)
        page = browser.new_page()

        try:
            # 1. Cargar la página
            page.goto(URL, wait_until="networkidle", timeout=30000)

            # 2. Escribir el documento
            input_selector = "#TBusqueda-inputEl"
            page.wait_for_selector(input_selector, state="visible", timeout=10000)
            page.fill(input_selector, documento)

            # 3. Hacer clic, capturar la respuesta y revisar encabezados
            boton_selector = "#BBuscarPersona, #BBuscarPersona-btnInnerEl"
            
            # Usamos 'as response_info' para capturar el objeto de respuesta
            with page.expect_response(
                lambda r: "VerificaCarne.aspx" in r.url and r.request.method == "POST",
                timeout=15000
            ) as response_info:
                page.locator(boton_selector).first.click()

            # <-- AQUÍ SE INSPECCIONAN LOS ENCABEZADOS -->
            response = response_info.value
            print(f"\n[HTTP Status]: {response.status}")
            
            headers = response.headers
            print("--- Encabezados de Respuesta Relevantes ---")
            encontrados = False
            for k, v in headers.items():
                # Si deseas ver todos los encabezados del servidor, quita esta condición if:
                if any(palabra in k.lower() for palabra in ["rate", "limit", "retry", "server", "cache"]):
                    print(f"  {k}: {v}")
                    encontrados = True
            
            if not encontrados:
                print("  (No se encontraron encabezados estándar de rate-limiting en la respuesta)")

            # 4. Esperar a que los datos reales reemplacen los textos de plantilla
            page.wait_for_function(
                """() => {
                    const nombreEl = document.querySelector('#DFNombre-textEl');
                    const tipoEl = document.querySelector('#LTipoUsuario-textEl');
                    const msgBox = document.querySelector('.x-message-box');

                    if (nombreEl) {
                        const txt = nombreEl.innerText.trim();
                        if (txt !== 'NOMBRE' && txt !== '') {
                            return true;
                        }
                    }
                    if (tipoEl && tipoEl.innerText.trim() !== '') {
                        return true;
                    }

                    if (msgBox && msgBox.innerText.trim().length > 0) {
                        return true;
                    }

                    return false;
                }""",
                timeout=10000
            )

            page.wait_for_timeout(500)

            # 5. Extraer los datos
            def get_text(selector: str) -> str:
                elem = page.query_selector(selector)
                return elem.inner_text().strip() if elem else ""

            nombre = get_text("#DFNombre-textEl")
            cedula = get_text("#DFCedula-textEl")
            programa = get_text("#DFPrograma-textEl")
            tipo_usuario = get_text("#LTipoUsuario-textEl")

            if nombre == "NOMBRE" or not nombre:
                msg_box = page.query_selector(".x-message-box")
                if msg_box:
                    resultado["error"] = msg_box.inner_text().strip()
                else:
                    resultado["error"] = "No se encontraron registros para el documento proporcionado."
            else:
                resultado["nombre"] = nombre
                resultado["cedula"] = cedula
                resultado["programa"] = programa
                resultado["tipo_usuario"] = tipo_usuario
                resultado["success"] = True

        except PlaywrightTimeoutError:
            msg_box = page.query_selector(".x-message-box")
            if msg_box:
                resultado["error"] = msg_box.inner_text().strip()
            else:
                resultado["error"] = "Tiempo de espera agotado al consultar el servidor."
        except Exception as e:
            resultado["error"] = str(e)
        finally:
            browser.close()

    return resultado


if __name__ == "__main__":
    doc = sys.argv[1].strip() if len(sys.argv) > 1 else input("Ingrese documento: ").strip()

    if not doc:
        print("Documento vacío.")
        sys.exit(1)

    print(f"\nConsultando documento: {doc}...")
    datos = consultar_estudiante(doc, headless=True)

    print("\n--- Resultado JSON ---")
    print(json.dumps(datos, indent=2, ensure_ascii=False))