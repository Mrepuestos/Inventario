"""
odoo_client.py
Conexion de SOLO LECTURA a Odoo 17 via XML-RPC para Cell Center 4620.

IMPORTANTE: este archivo NUNCA escribe, ajusta ni modifica nada en Odoo.
Solo lee inventario. No tiene ninguna funcion de escritura.
"""

import os
import xmlrpc.client

# La configuracion se lee desde variables de entorno (se cargan en Render).
ODOO_URL = os.environ.get("ODOO_URL", "").rstrip("/")
ODOO_DB = os.environ.get("ODOO_DB", "")
ODOO_USERNAME = os.environ.get("ODOO_USERNAME", "")
ODOO_API_KEY = os.environ.get("ODOO_API_KEY", "")

# Nombres exactos de las categorias en tu Odoo.
CAT_CELULARES = "CELULAR"
CAT_PANTALLAS = "REPUESTOS"


def _conectar():
    """Autentica contra Odoo y devuelve (uid, proxy de modelos)."""
    if not all([ODOO_URL, ODOO_DB, ODOO_USERNAME, ODOO_API_KEY]):
        raise RuntimeError(
            "Faltan variables de entorno de Odoo "
            "(ODOO_URL, ODOO_DB, ODOO_USERNAME, ODOO_API_KEY)."
        )
    common = xmlrpc.client.ServerProxy(f"{ODOO_URL}/xmlrpc/2/common")
    uid = common.authenticate(ODOO_DB, ODOO_USERNAME, ODOO_API_KEY, {})
    if not uid:
        raise RuntimeError("Odoo rechazo las credenciales (uid vacio).")
    models = xmlrpc.client.ServerProxy(f"{ODOO_URL}/xmlrpc/2/object")
    return uid, models


def _ejecutar(uid, models, modelo, metodo, args, kwargs=None):
    """Atajo para execute_kw. Solo se usa con metodos de lectura."""
    return models.execute_kw(
        ODOO_DB, uid, ODOO_API_KEY, modelo, metodo, args, kwargs or {}
    )


def _id_categoria(uid, models, nombre):
    """Devuelve el id de una categoria de producto por nombre, o None."""
    ids = _ejecutar(
        uid, models, "product.category", "search",
        [[["name", "=", nombre]]],
    )
    return ids[0] if ids else None


def leer_pantallas():
    """
    Lee las pantallas (categoria REPUESTOS) con la cantidad que Odoo
    tiene en stock. Conteo por CANTIDAD.
    Devuelve lista de dicts: codigo, nombre, cantidad_odoo, barcode.
    """
    uid, models = _conectar()
    cat_id = _id_categoria(uid, models, CAT_PANTALLAS)
    if cat_id is None:
        raise RuntimeError(f"No existe la categoria '{CAT_PANTALLAS}' en Odoo.")

    productos = _ejecutar(
        uid, models, "product.product", "search_read",
        [[["categ_id", "child_of", cat_id]]],
        {"fields": ["name", "default_code", "qty_available", "barcode"]},
    )
    resultado = []
    for p in productos:
        resultado.append({
            "codigo": p.get("default_code") or "",
            "nombre": p.get("name") or "",
            "cantidad_odoo": p.get("qty_available") or 0,
            "barcode": p.get("barcode") or "",
        })
    resultado.sort(key=lambda x: x["nombre"].lower())
    return resultado


def leer_celulares():
    """
    Lee los celulares (categoria CELULAR) en stock, unidad por unidad
    usando el numero de serie / IMEI. Conteo por SERIAL.
    Devuelve lista de dicts: imei, modelo, ubicacion.
    """
    uid, models = _conectar()
    cat_id = _id_categoria(uid, models, CAT_CELULARES)
    if cat_id is None:
        raise RuntimeError(f"No existe la categoria '{CAT_CELULARES}' en Odoo.")

    # Productos de la categoria CELULAR.
    prod_ids = _ejecutar(
        uid, models, "product.product", "search",
        [[["categ_id", "child_of", cat_id]]],
    )
    if not prod_ids:
        return []

    # Stock real por serie: quants con lote, en ubicacion interna, cantidad > 0.
    quants = _ejecutar(
        uid, models, "stock.quant", "search_read",
        [[
            ["product_id", "in", prod_ids],
            ["location_id.usage", "=", "internal"],
            ["lot_id", "!=", False],
            ["quantity", ">", 0],
        ]],
        {"fields": ["lot_id", "product_id", "location_id", "quantity"]},
    )
    resultado = []
    for q in quants:
        lote = q.get("lot_id")
        producto = q.get("product_id")
        ubicacion = q.get("location_id")
        resultado.append({
            "imei": lote[1] if lote else "",
            "modelo": producto[1] if producto else "",
            "ubicacion": ubicacion[1] if ubicacion else "",
        })
    resultado.sort(key=lambda x: x["modelo"].lower())
    return resultado


def probar_conexion():
    """
    Prueba la conexion y devuelve un resumen para verificar que todo
    lee bien antes de construir el conteo.
    """
    celulares = leer_celulares()
    pantallas = leer_pantallas()
    return {
        "ok": True,
        "celulares_total": len(celulares),
        "pantallas_total": len(pantallas),
        "celulares_muestra": celulares[:5],
        "pantallas_muestra": pantallas[:5],
    }
