from pathlib import Path
import os
import sys

sys.path.insert(0, "/private/tmp/pondera_pdf_deps")

from reportlab.lib import colors
from reportlab.lib.enums import TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.platypus import (
    Image,
    ListFlowable,
    ListItem,
    PageBreak,
    Paragraph,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)


ROOT = Path(__file__).resolve().parent.parent
OUTPUT_DIR = ROOT / "output" / "pdf"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
PDF_PATH = OUTPUT_DIR / "pondera_manual_usuario.pdf"
LOGO_PATH = ROOT / "assets" / "branding" / "pondera_logo.png"


def build_styles():
    styles = getSampleStyleSheet()
    styles.add(
        ParagraphStyle(
            name="TitleLarge",
            parent=styles["Title"],
            fontName="Helvetica-Bold",
            fontSize=22,
            leading=26,
            textColor=colors.HexColor("#143B63"),
            spaceAfter=12,
            alignment=TA_LEFT,
        )
    )
    styles.add(
        ParagraphStyle(
            name="SectionTitle",
            parent=styles["Heading2"],
            fontName="Helvetica-Bold",
            fontSize=14,
            leading=18,
            textColor=colors.HexColor("#145DA0"),
            spaceBefore=10,
            spaceAfter=8,
        )
    )
    styles.add(
        ParagraphStyle(
            name="BodySmall",
            parent=styles["BodyText"],
            fontName="Helvetica",
            fontSize=10.5,
            leading=14,
            textColor=colors.HexColor("#263238"),
            spaceAfter=6,
        )
    )
    styles.add(
        ParagraphStyle(
            name="Callout",
            parent=styles["BodyText"],
            fontName="Helvetica-Bold",
            fontSize=10.5,
            leading=14,
            textColor=colors.HexColor("#143B63"),
            backColor=colors.HexColor("#EAF3FB"),
            borderPadding=8,
            borderRadius=6,
            spaceBefore=6,
            spaceAfter=8,
        )
    )
    return styles


def bullet_list(items, style):
    return ListFlowable(
        [
            ListItem(Paragraph(item, style), leftIndent=6)
            for item in items
        ],
        bulletType="bullet",
        start="circle",
        leftIndent=14,
        bulletFontName="Helvetica",
        bulletFontSize=8,
    )


def section(story, title, paragraphs, bullets, styles):
    story.append(Paragraph(title, styles["SectionTitle"]))
    for text in paragraphs:
        story.append(Paragraph(text, styles["BodySmall"]))
    if bullets:
        story.append(bullet_list(bullets, styles["BodySmall"]))
        story.append(Spacer(1, 4))


def build_story():
    styles = build_styles()
    story = []
    table_cell_style = ParagraphStyle(
        "TableCell",
        parent=styles["BodySmall"],
        fontName="Helvetica",
        fontSize=9,
        leading=11,
        spaceAfter=0,
    )

    if LOGO_PATH.exists():
        story.append(Image(str(LOGO_PATH), width=30 * mm, height=30 * mm))
        story.append(Spacer(1, 6))

    story.append(Paragraph("Pondera - Manual breve de usuario", styles["TitleLarge"]))
    story.append(
        Paragraph(
            "Guía operativa para capturar lecturas de balanza, configurar conexiones, "
            "usar recetas de lectura y administrar la licencia demo u offline.",
            styles["BodySmall"],
        )
    )
    story.append(
        Paragraph(
            "Versión preparada para clientes de prueba. La demo se bloquea 15 días "
            "después del primer uso en cada instalación.",
            styles["Callout"],
        )
    )

    section(
        story,
        "1. Qué hace Pondera",
        [
            "Pondera es una aplicación de escritorio para recibir datos desde una balanza o indicador por Ethernet/TCP o por RS-232.",
            "Una vez interpretada la trama, la aplicación muestra el peso actual y puede escribir el valor en el campo activo del sistema usando comandos de teclado configurables.",
        ],
        [
            "Puede trabajar con recetas de lectura basadas en expresiones regulares.",
            "Puede pedir ayuda a n8n para generar o actualizar la receta a partir de una trama real.",
            "Puede operar con licencia demo o con licencia offline de activación.",
        ],
        styles,
    )

    section(
        story,
        "2. Flujo recomendado de primer uso",
        [
            "Al abrir la aplicación por primera vez, revise el estado de licencia y luego configure el enlace con la balanza.",
            "Después de validar la comunicación, capture una trama real y cree la receta de lectura con n8n o cargue una receta existente.",
        ],
        [
            "Elegir tipo de conexión.",
            "Guardar parámetros de red o RS-232.",
            "Conectar y verificar recepción.",
            "Crear receta.",
            "Revisar unidades y comandos de teclado.",
        ],
        styles,
    )

    section(
        story,
        "3. Panel de peso actual",
        [
            "En la parte superior se muestra el peso limpio que Pondera logró interpretar.",
            "Si todavía no existe receta, la aplicación mostrará 'Sin receta'. Si la licencia está vencida, verás el mensaje de bloqueo correspondiente.",
        ],
        [
            "Use este panel como referencia rápida para el operador.",
            "Si el dato no cambia, revise la receta, la conexión y el log de tramas.",
        ],
        styles,
    )

    section(
        story,
        "4. Estado de conexión",
        [
            "Este panel resume si la aplicación está conectada o desconectada, y permite abrir o cerrar el enlace con la balanza.",
            "Si la demo o la licencia están bloqueadas, Pondera no abrirá una nueva conexión.",
        ],
        [
            "Conectado: hay enlace operativo.",
            "Desconectado: no hay enlace activo.",
            "Bloqueado: la licencia o demo no permiten continuar.",
        ],
        styles,
    )

    section(
        story,
        "5. Última trama recibida",
        [
            "Muestra la última trama capturada desde la balanza y permite desplegar las anteriores recientes.",
            "Este panel es útil para diagnosticar si la balanza sí está enviando datos aunque la receta todavía no los interprete bien.",
        ],
        [
            "Si no hay datos, primero verifique la conexión.",
            "Si hay datos pero no peso limpio, revise o regenere la receta.",
        ],
        styles,
    )

    section(
        story,
        "6. Diagnóstico avanzado",
        [
            "Entrega mensajes técnicos de red o del puerto serial, además de contadores básicos de recepción.",
            "Úselo para confirmar si el socket TCP abre, si el puerto serial escucha o si hay errores de lectura.",
        ],
        [
            "Ayuda a soporte técnico a entender desconexiones o puertos inválidos.",
            "No modifica la operación: es solo diagnóstico.",
        ],
        styles,
    )

    story.append(PageBreak())

    section(
        story,
        "7. Licencia",
        [
            "Pondera puede operar en demo o con licencia offline. La demo vence 15 días después del primer uso por instalación.",
            "Cuando la demo o la licencia vencen, la aplicación bloquea el uso y elimina la receta guardada para obligar a pasar nuevamente por el flujo controlado.",
        ],
        [
            "Generar solicitud de activación: crea el archivo para pedir una licencia.",
            "Importar licencia: carga el archivo firmado entregado por soporte.",
            "Restablecer demo: solo aparece en desarrollo.",
        ],
        styles,
    )

    section(
        story,
        "8. Configuración del enlace con la balanza",
        [
            "Aquí se elige el tipo de conexión y sus parámetros. Guarde siempre los cambios antes de conectar.",
        ],
        [],
        styles,
    )

    connection_table = Table(
        [
            [
                Paragraph("Modo", table_cell_style),
                Paragraph("Parámetros principales", table_cell_style),
                Paragraph("Uso recomendado", table_cell_style),
            ],
            [
                Paragraph("Ethernet/TCP", table_cell_style),
                Paragraph("IP y puerto TCP", table_cell_style),
                Paragraph("Equipos en red", table_cell_style),
            ],
            [
                Paragraph("RS-232", table_cell_style),
                Paragraph(
                    "Puerto, baud, data bits, paridad, stop bits y flujo",
                    table_cell_style,
                ),
                Paragraph(
                    "Equipos por cable serial",
                    table_cell_style,
                ),
            ],
        ],
        colWidths=[34 * mm, 74 * mm, 50 * mm],
    )
    connection_table.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#145DA0")),
                ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
                ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
                ("FONTSIZE", (0, 0), (-1, -1), 9),
                ("LEADING", (0, 0), (-1, -1), 11),
                ("GRID", (0, 0), (-1, -1), 0.4, colors.HexColor("#B7C6D6")),
                ("BACKGROUND", (0, 1), (-1, -1), colors.HexColor("#F8FBFE")),
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("LEFTPADDING", (0, 0), (-1, -1), 6),
                ("RIGHTPADDING", (0, 0), (-1, -1), 6),
                ("TOPPADDING", (0, 0), (-1, -1), 6),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
            ]
        )
    )
    story.append(connection_table)
    story.append(Spacer(1, 10))

    section(
        story,
        "9. Receta de lectura",
        [
            "La receta define cómo extraer el peso útil desde la trama cruda. Puede ser creada o actualizada con ayuda de n8n.",
            "Cuando se pulsa 'Crear receta' o 'Actualizar receta', la app envía la última trama y el valor esperado a n8n junto con metadatos de instalación y licencia.",
        ],
        [
            "Use un peso real y conocido al cargar el valor esperado.",
            "Si cambia el formato de salida de la balanza, regenere la receta.",
            "Si se elimina la receta, Pondera deja de interpretar tramas hasta crear una nueva.",
        ],
        styles,
    )

    section(
        story,
        "10. Unidades de medida",
        [
            "Permite definir la unidad de entrada que entrega la balanza y la unidad de salida que deseas mostrar o inyectar.",
            "La conversión se aplica después de interpretar correctamente la lectura.",
        ],
        [
            "Ejemplo: entrada en kg y salida en g.",
            "Si el peso visual no coincide, revise la unidad configurada por la balanza.",
        ],
        styles,
    )

    section(
        story,
        "11. Comandos de teclado",
        [
            "Pondera puede escribir el peso limpio en el campo activo del sistema.",
            "Los campos de prefijo y sufijo permiten agregar teclas antes o después del valor, por ejemplo tabulaciones o confirmaciones.",
        ],
        [
            "Pruebe primero en un bloc de notas o campo de prueba.",
            "Evite usar comandos agresivos si el foco del cursor no está controlado.",
        ],
        styles,
    )

    section(
        story,
        "12. Resolución rápida de problemas",
        [
            "Si no llegan datos, revise cableado, IP, puerto o configuración serial.",
            "Si llegan tramas pero no hay peso útil, regenere la receta con una muestra real.",
            "Si la aplicación quedó bloqueada, revise el estado de licencia y solicite activación si ya terminó la demo.",
        ],
        [
            "TCP: comprobar IP, puerto y conectividad.",
            "RS-232: revisar baud rate, data bits, paridad, stop bits y control de flujo.",
            "n8n: revisar conectividad HTTPS y respuesta del webhook.",
        ],
        styles,
    )

    return story


def add_page_number(canvas, doc):
    canvas.saveState()
    canvas.setFont("Helvetica", 9)
    canvas.setFillColor(colors.HexColor("#607D8B"))
    canvas.drawRightString(doc.pagesize[0] - 18 * mm, 12 * mm, f"Página {doc.page}")
    canvas.restoreState()


def main():
    doc = SimpleDocTemplate(
        str(PDF_PATH),
        pagesize=A4,
        leftMargin=18 * mm,
        rightMargin=18 * mm,
        topMargin=18 * mm,
        bottomMargin=18 * mm,
        title="Pondera - Manual breve de usuario",
        author="Codex",
    )
    story = build_story()
    doc.build(story, onFirstPage=add_page_number, onLaterPages=add_page_number)
    print(PDF_PATH)


if __name__ == "__main__":
    main()
