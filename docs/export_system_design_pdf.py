#!/usr/bin/env python3
"""Export SYSTEM_DESIGN.md to PDF using local Google Chrome and Python stdlib."""

from __future__ import annotations

import base64
import argparse
import html
import mimetypes
import re
import shutil
import subprocess
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parent
REPO_ROOT = ROOT.parent
SOURCE = ROOT / "SYSTEM_DESIGN.md"
OUTPUT = ROOT / "SYSTEM_DESIGN.pdf"
CHROME_CANDIDATES = (
    shutil.which("google-chrome"),
    shutil.which("chromium"),
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
)


def inline(text: str) -> str:
    escaped = html.escape(text, quote=False)
    escaped = re.sub(r"`([^`]+)`", r"<code>\1</code>", escaped)
    escaped = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", escaped)
    escaped = re.sub(r"\*([^*]+)\*", r"<em>\1</em>", escaped)
    escaped = re.sub(
        r"\[([^\]]+)\]\(([^)]+)\)",
        lambda match: (
            f'<a href="{html.escape(match.group(2), quote=True)}">'
            f"{match.group(1)}</a>"
        ),
        escaped,
    )
    return escaped


def table_row(line: str) -> list[str]:
    return [cell.strip() for cell in line.strip().strip("|").split("|")]


def svg_data_uri(path: Path) -> str:
    source = path.read_text(encoding="utf-8")
    reference_pattern = re.compile(r'((?:href|xlink:href)=["\'])([^"\']+)(["\'])')

    def embed_reference(match: re.Match[str]) -> str:
        reference = match.group(2)
        if reference.startswith(("data:", "http://", "https://", "#")):
            return match.group(0)
        image_path = (path.parent / reference).resolve()
        if not image_path.is_relative_to(REPO_ROOT) or not image_path.is_file():
            return match.group(0)
        return (
            f"{match.group(1)}{image_data_uri(image_path)}{match.group(3)}"
        )

    source = reference_pattern.sub(embed_reference, source)
    encoded = base64.b64encode(source.encode("utf-8")).decode("ascii")
    return f"data:image/svg+xml;base64,{encoded}"


def image_data_uri(path: Path) -> str:
    mime_type = mimetypes.guess_type(path.name)[0] or "application/octet-stream"
    encoded = base64.b64encode(path.read_bytes()).decode("ascii")
    return f"data:{mime_type};base64,{encoded}"


def render_markdown(source: str) -> str:
    lines = source.splitlines()
    output: list[str] = []
    paragraphs: list[str] = []
    index = 0

    def flush_paragraph() -> None:
        if paragraphs:
            output.append(f"<p>{inline(' '.join(paragraphs))}</p>")
            paragraphs.clear()

    while index < len(lines):
        line = lines[index]
        stripped = line.strip()
        if not stripped:
            flush_paragraph()
            index += 1
            continue

        if stripped.startswith("```"):
            flush_paragraph()
            language = stripped[3:].strip()
            code_lines: list[str] = []
            index += 1
            while index < len(lines) and not lines[index].strip().startswith("```"):
                code_lines.append(lines[index])
                index += 1
            output.append(
                f"<pre><code>{html.escape(chr(10).join(code_lines))}</code></pre>"
            )
            index += 1
            continue

        if stripped.startswith("|") and index + 1 < len(lines):
            separator = lines[index + 1].strip()
            if separator.startswith("|") and re.fullmatch(
                r"[\s|:-]+", separator
            ):
                flush_paragraph()
                header = table_row(stripped)
                index += 2
                rows: list[list[str]] = []
                while index < len(lines) and lines[index].strip().startswith("|"):
                    rows.append(table_row(lines[index].strip()))
                    index += 1
                output.append("<table><thead><tr>")
                output.extend(f"<th>{inline(cell)}</th>" for cell in header)
                output.append("</tr></thead><tbody>")
                for row in rows:
                    output.append("<tr>")
                    output.extend(f"<td>{inline(cell)}</td>" for cell in row)
                    output.append("</tr>")
                output.append("</tbody></table>")
                continue

        heading = re.match(r"^(#{1,6})\s+(.+)$", stripped)
        if heading:
            flush_paragraph()
            level = len(heading.group(1))
            output.append(f"<h{level}>{inline(heading.group(2))}</h{level}>")
            index += 1
            continue

        image = re.match(r"^!\[([^\]]*)\]\(([^)]+)\)$", stripped)
        if image:
            flush_paragraph()
            alt, relative_path = image.groups()
            image_path = (ROOT / relative_path).resolve()
            if not image_path.is_relative_to(REPO_ROOT) or not image_path.is_file():
                raise FileNotFoundError(f"Wireframe not found: {relative_path}")
            if image_path.name == "architecture.svg":
                figure_class = "architecture"
            elif image_path.name == "gropanda_logo.png":
                figure_class = "logo"
            else:
                figure_class = "wireframe"
            image_uri = (
                svg_data_uri(image_path)
                if image_path.suffix.lower() == ".svg"
                else image_data_uri(image_path)
            )
            output.append(
                f'<figure class="{figure_class}">'
                f'<img src="{image_uri}" alt="{html.escape(alt)}">'
                f"<figcaption>{html.escape(alt)}</figcaption></figure>"
            )
            index += 1
            continue

        if re.match(r"^\d+\.\s+", stripped):
            flush_paragraph()
            items: list[str] = []
            while index < len(lines) and re.match(
                r"^\s*\d+\.\s+", lines[index]
            ):
                item = re.sub(r"^\s*\d+\.\s+", "", lines[index]).strip()
                items.append(f"<li>{inline(item)}</li>")
                index += 1
            output.append(f"<ol>{''.join(items)}</ol>")
            continue

        if stripped.startswith("- "):
            flush_paragraph()
            items = []
            while index < len(lines) and lines[index].strip().startswith("- "):
                items.append(f"<li>{inline(lines[index].strip()[2:])}</li>")
                index += 1
            output.append(f"<ul>{''.join(items)}</ul>")
            continue

        if stripped == "---":
            flush_paragraph()
            output.append("<hr>")
            index += 1
            continue

        paragraphs.append(stripped)
        index += 1

    flush_paragraph()
    return "\n".join(output)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", nargs="?", type=Path, default=SOURCE)
    parser.add_argument("output", nargs="?", type=Path, default=OUTPUT)
    args = parser.parse_args()
    source_path = args.source.resolve()
    output_path = args.output.resolve()
    chrome = next((candidate for candidate in CHROME_CANDIDATES if candidate and Path(candidate).is_file()), None)
    if chrome is None:
        raise SystemExit(
            "Google Chrome or Chromium is required. Install a Chromium-based "
            "browser, then run this script again."
        )
    if not source_path.is_file():
        raise SystemExit(f"Design document not found: {source_path}")

    title = source_path.stem.replace("_", " ").title()
    body = render_markdown(source_path.read_text(encoding="utf-8"))
    document = f"""<!doctype html>
<html><head><meta charset="utf-8"><title>{html.escape(title)}</title>
<style>
@page {{ size: A4; margin: 18mm 16mm 20mm;
  @bottom-right {{ content: "GroPanda · " counter(page); color: #788078;
    font: 9pt Arial, sans-serif; }} }}
@page architecture {{ size: A4 landscape; margin: 14mm 15mm 16mm;
  @bottom-right {{ content: "GroPanda · " counter(page); color: #788078;
    font: 9pt Arial, sans-serif; }} }}
* {{ box-sizing: border-box; }}
body {{ color: #303a32; font: 10pt/1.48 Arial, sans-serif; }}
h1, h2, h3, h4 {{ color: #285b43; page-break-after: avoid; }}
h1 {{ font-size: 25pt; border-bottom: 3px solid #a8e6a1; padding-bottom: 8px; }}
h2 {{ font-size: 17pt; margin-top: 25px; border-bottom: 1px solid #dce8d7;
  padding-bottom: 5px; }}
h3 {{ font-size: 12pt; margin-top: 18px; }}
p {{ margin: 7px 0 10px; }}
a {{ color: #285b43; }}
code {{ background: #f2f4ed; padding: 1px 3px; border-radius: 3px;
  font: 8.5pt Menlo, monospace; overflow-wrap: anywhere; }}
pre {{ white-space: pre-wrap; background: #f2f4ed; padding: 10px;
  border-radius: 7px; font: 8pt/1.4 Menlo, monospace; }}
table {{ width: 100%; border-collapse: collapse; margin: 9px 0 15px;
  font-size: 8.1pt; page-break-inside: auto; }}
thead {{ display: table-header-group; }}
th {{ background: #eaf4e8; color: #285b43; text-align: left; }}
th, td {{ border: 1px solid #dce8d7; padding: 5px 6px; vertical-align: top; }}
tr {{ page-break-inside: avoid; }}
ul, ol {{ padding-left: 22px; }}
li {{ margin: 3px 0; }}
figure {{ text-align: center; margin: 14px 0 20px; page-break-inside: avoid; }}
figure.wireframe img {{ height: 208mm; max-width: 100%; object-fit: contain; }}
figure.logo {{ margin: 0 auto 8px; }}
figure.logo img {{ display: block; width: auto; height: 28mm; margin: auto; }}
figure.logo figcaption {{ display: none; }}
figure.architecture {{ page: architecture; page-break-before: always;
  page-break-after: always; }}
figure.architecture img {{ display: block; width: 100%; height: auto; }}
figcaption {{ color: #788078; font-size: 8.5pt; margin-top: 5px; }}
hr {{ border: 0; border-top: 1px solid #dce8d7; }}
</style></head><body>{body}</body></html>"""

    with tempfile.TemporaryDirectory(prefix="gropanda-pdf-") as temp_dir:
        html_path = Path(temp_dir) / f"{source_path.stem}.html"
        html_path.write_text(document, encoding="utf-8")
        result = subprocess.run(
            [
                chrome,
                "--headless",
                "--disable-gpu",
                "--no-sandbox",
                "--disable-dev-shm-usage",
                "--no-pdf-header-footer",
                f"--user-data-dir={temp_dir}/chrome-profile",
                f"--print-to-pdf={output_path}",
                html_path.as_uri(),
            ],
            capture_output=True,
            text=True,
            check=False,
        )
        if result.returncode != 0 or not output_path.is_file():
            raise SystemExit(
                "Chrome could not export the PDF.\n"
                f"{result.stderr.strip() or result.stdout.strip()}"
            )
    print(f"Created {output_path} ({output_path.stat().st_size:,} bytes)")


if __name__ == "__main__":
    main()
