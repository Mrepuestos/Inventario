"""
app.py
App de inventario Cell Center 4620 - Fase 1 (verificacion de lectura Odoo).
Web/PWA en Flask. SOLO LECTURA contra Odoo: no escribe nada.

Rutas:
  /          -> pagina de verificacion (estado de conexion + muestra)
  /api/test  -> el mismo resumen en JSON
"""

import os
from flask import Flask, jsonify, render_template_string

import odoo_client

app = Flask(__name__)


STATUS_HTML = """<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>Inventario - Cell Center 4620</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Outfit:wght@400;500;600;800&family=IBM+Plex+Mono:wght@400;600&display=swap" rel="stylesheet">
<style>
  :root{
    --bg:#0c0d11; --panel:#15171e; --line:#262a36;
    --text:#eef0f5; --muted:#8a8f9e;
    --amber:#ffb020; --green:#34d399; --red:#f87171;
  }
  *{box-sizing:border-box;margin:0;padding:0}
  body{
    background:var(--bg);color:var(--text);
    font-family:'Outfit',sans-serif;-webkit-font-smoothing:antialiased;
    padding:30px 18px 60px;min-height:100vh;
  }
  .wrap{max-width:520px;margin:0 auto}
  .brand{display:flex;align-items:center;gap:10px;margin-bottom:4px}
  .dot{width:10px;height:10px;border-radius:50%;background:var(--amber);box-shadow:0 0 14px var(--amber)}
  .brand h1{font-size:16px;font-weight:600;letter-spacing:.2px}
  .sub{color:var(--muted);font-size:13px;margin-bottom:22px}
  .status{
    display:inline-flex;align-items:center;gap:9px;
    padding:9px 16px;border-radius:999px;
    font-size:12.5px;font-weight:600;letter-spacing:.5px;
    border:1px solid var(--line);margin-bottom:24px;
  }
  .status.ok{color:var(--green);border-color:rgba(52,211,153,.35);background:rgba(52,211,153,.08)}
  .status.bad{color:var(--red);border-color:rgba(248,113,113,.35);background:rgba(248,113,113,.08)}
  .pulse{width:8px;height:8px;border-radius:50%;background:currentColor}
  .cards{display:grid;gap:14px}
  .card{background:var(--panel);border:1px solid var(--line);border-radius:18px;padding:20px}
  .card .tag{font-size:11px;letter-spacing:1.4px;font-weight:600;color:var(--amber);text-transform:uppercase}
  .card .num{font-size:46px;font-weight:800;line-height:1.05;margin:6px 0 2px}
  .card .desc{color:var(--muted);font-size:13.5px;margin-bottom:16px}
  .sample{border-top:1px solid var(--line);padding-top:14px;display:grid;gap:9px}
  .sample .row{display:flex;justify-content:space-between;gap:12px;font-size:13px;align-items:baseline}
  .sample .k{font-family:'IBM Plex Mono',monospace;color:var(--text);overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
  .sample .v{font-family:'IBM Plex Mono',monospace;color:var(--muted);flex:none}
  .empty{color:var(--muted);font-size:13px;font-style:italic}
  .err{background:rgba(248,113,113,.06);border:1px solid rgba(248,113,113,.3);border-radius:16px;padding:18px}
  .err h3{color:var(--red);font-size:15px;margin-bottom:8px}
  .err code{font-family:'IBM Plex Mono',monospace;font-size:12.5px;color:#ffc9c9;display:block;background:#000;padding:12px;border-radius:10px;margin-top:10px;word-break:break-word}
  .foot{margin-top:26px;text-align:center;color:var(--muted);font-size:12px;letter-spacing:.3px}
  .foot b{color:var(--green);font-weight:600}
</style>
</head>
<body>
<div class="wrap">
  <div class="brand"><span class="dot"></span><h1>Inventario - Cell Center 4620</h1></div>
  <div class="sub">Verificacion de conexion - Fase 1</div>

  {% if resumen %}
    <div class="status ok"><span class="pulse"></span>CONECTADO A ODOO</div>
    <div class="cards">
      <div class="card">
        <div class="tag">CELULAR - por IMEI</div>
        <div class="num">{{ resumen.celulares_total }}</div>
        <div class="desc">celulares en stock (unidades con serie)</div>
        <div class="sample">
          {% for c in resumen.celulares_muestra %}
            <div class="row"><span class="k">{{ c.imei }}</span><span class="v">{{ c.modelo[:18] }}</span></div>
          {% else %}
            <div class="empty">Sin unidades en stock.</div>
          {% endfor %}
        </div>
      </div>
      <div class="card">
        <div class="tag">REPUESTOS - por cantidad</div>
        <div class="num">{{ resumen.pantallas_total }}</div>
        <div class="desc">modelos de pantalla en catalogo</div>
        <div class="sample">
          {% for p in resumen.pantallas_muestra %}
            <div class="row"><span class="k">{{ p.nombre[:26] }}</span><span class="v">{{ p.cantidad_odoo }} u</span></div>
          {% else %}
            <div class="empty">Sin pantallas en la categoria.</div>
          {% endfor %}
        </div>
      </div>
    </div>
  {% else %}
    <div class="status bad"><span class="pulse"></span>SIN CONEXION</div>
    <div class="err">
      <h3>No se pudo leer Odoo</h3>
      <div class="desc" style="color:var(--muted)">Revisa las variables de entorno en Render y vuelve a cargar.</div>
      <code>{{ error }}</code>
    </div>
  {% endif %}

  <div class="foot"><b>Solo lectura</b> - esta app nunca modifica tu Odoo</div>
</div>
</body>
</html>"""


@app.route("/")
def inicio():
    try:
        resumen = odoo_client.probar_conexion()
        error = None
    except Exception as e:
        resumen = None
        error = str(e)
    return render_template_string(STATUS_HTML, resumen=resumen, error=error)


@app.route("/api/test")
def api_test():
    try:
        return jsonify(odoo_client.probar_conexion())
    except Exception as e:
        return jsonify({"ok": False, "error": str(e)}), 500


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5000))
    app.run(host="0.0.0.0", port=port)
