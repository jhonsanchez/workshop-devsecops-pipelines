from flask import request, render_template_string


def search():
    """Search page — VULNERABLE: Reflected XSS (CWE-79)"""
    query = request.args.get("q", "")

    # VULNERABLE: User input directly interpolated into HTML template
    template = f"""
    <!DOCTYPE html>
    <html>
    <head><title>Search Results</title></head>
    <body>
        <h1>Resultados de búsqueda</h1>
        <p>Búsqueda: {query}</p>
        <form method="GET" action="/search">
            <input type="text" name="q" value="{query}">
            <button type="submit">Buscar</button>
        </form>
        <div id="results">
            <p>No se encontraron resultados para: {query}</p>
        </div>
    </body>
    </html>
    """
    return render_template_string(template)
