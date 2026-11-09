"""Private reference-backed Word profiles. Python 3.9+, standard library only.

No network, Office automation, model calls, or source modification. A structural
PASS is deliberately separate from Word/render/visual acceptance.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import posixpath
import re
import sys
import tempfile
import zipfile
from xml.dom import minidom as D
from xml.parsers.expat import ExpatError
from urllib.parse import unquote

W = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'
R = 'http://schemas.openxmlformats.org/package/2006/relationships'
XML = 'http://www.w3.org/XML/1998/namespace'
MAX_BYTES = 64 * 1024 * 1024


def digest(value):
    return hashlib.sha256(value).hexdigest()


def load_json(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def write_new(path, data):
    path = Path(path)
    if path.exists() or path.is_symlink():
        raise ValueError('OUTPUT_EXISTS_PRESERVED')
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open('xb') as stream:
        stream.write(data)


def json_bytes(value):
    return (json.dumps(value, ensure_ascii=False, indent=2) + '\n').encode('utf-8')


def relationship_target(part_name, target):
    base = part_name.rsplit('/_rels/', 1)[0] if '/_rels/' in part_name else ''
    target = unquote(target.split('#')[0])
    return posixpath.normpath(target.lstrip('/') if target.startswith('/') else posixpath.join(base, target))


def package(path):
    with zipfile.ZipFile(path) as archive:
        names = archive.namelist()
        if len(names) != len(set(names)):
            raise ValueError('DUPLICATE_PACKAGE_PART')
        if len(names) > 2000 or sum(i.file_size for i in archive.infolist()) > MAX_BYTES:
            raise ValueError('PACKAGE_LIMIT_EXCEEDED')
        for name in names:
            p = PurePosixPath(name)
            if p.is_absolute() or '..' in p.parts or '\\' in name:
                raise ValueError('UNSAFE_PACKAGE_PART')
            if re.search(r'vbaProject|activeX|embeddings/', name, re.I):
                raise ValueError('ACTIVE_CONTENT_NOT_SUPPORTED')
        data = {name: archive.read(name) for name in names}
    for name, value in data.items():
        if name.endswith(('.xml', '.rels')):
            xml(value)
    for required in ('[Content_Types].xml', '_rels/.rels', 'word/document.xml', 'word/styles.xml'):
        if required not in data:
            raise ValueError('REQUIRED_PART_MISSING: ' + required)
    for node in xml(data['[Content_Types].xml']).getElementsByTagName('*'):
        if re.search(r'macroenabled|vbaproject|activex|oleobject', node.getAttribute('ContentType'), re.I):
            raise ValueError('ACTIVE_CONTENT_TYPE_NOT_SUPPORTED')
    for name, value in data.items():
        if name.endswith('.rels'):
            seen = set()
            for relationship in xml(value).getElementsByTagNameNS(R, 'Relationship'):
                identity = relationship.getAttribute('Id')
                if not identity or identity in seen:
                    raise ValueError('DUPLICATE_RELATIONSHIP_ID')
                seen.add(identity)
                if re.search(r'/(?:vbaProject|oleObject|activeX|control|aFChunk)$', relationship.getAttribute('Type'), re.I):
                    raise ValueError('ACTIVE_RELATIONSHIP_NOT_SUPPORTED')
                if relationship.getAttribute('TargetMode') == 'External':
                    raise ValueError('EXTERNAL_RELATIONSHIP_REQUIRES_REVIEW')
                resolved = relationship_target(name, relationship.getAttribute('Target'))
                if resolved.startswith('../') or resolved not in data:
                    raise ValueError('RELATIONSHIP_TARGET_MISSING_OR_UNSAFE')
    return data


def xml(value):
    if isinstance(value, str):
        value = value.encode('utf-8')
    if b'\x00' in value or re.search(br'<!DOCTYPE|<!ENTITY', value, re.I):
        raise ValueError('XML_DECLARATION_NOT_SUPPORTED')
    return D.parseString(value)


def descendants(node, name):
    return list(node.getElementsByTagNameNS(W, name))


def children(node, name=None):
    return [n for n in node.childNodes if n.nodeType == n.ELEMENT_NODE
            and (name is None or (n.namespaceURI == W and n.localName == name))]


def text(node):
    return ''.join(t.firstChild.data if t.firstChild else '' for t in descendants(node, 't'))


def replace_text_in_place(node, replacement):
    """Preserve styled prefix/suffix runs, such as a red confidentiality label."""
    nodes = descendants(node, 't')
    original = text(node)
    prefix = 0
    while prefix < min(len(original), len(replacement)) and original[prefix] == replacement[prefix]:
        prefix += 1
    suffix = 0
    while suffix < min(len(original)-prefix, len(replacement)-prefix) and original[-1-suffix] == replacement[-1-suffix]:
        suffix += 1
    middle = replacement[prefix:len(replacement)-suffix if suffix else len(replacement)]
    cursor, inserted = 0, False
    for index, t in enumerate(nodes):
        value = t.firstChild.data if t.firstChild else ''
        end = cursor + len(value)
        before = value[:max(0, min(len(value), prefix-cursor))]
        after = value[max(0, len(original)-suffix-cursor):] if suffix else ''
        insertion = ''
        if not inserted and (end > prefix or index == len(nodes)-1):
            insertion, inserted = middle, True
        for child in list(t.childNodes):
            t.removeChild(child)
        t.appendChild(t.ownerDocument.createTextNode(before+insertion+after))
        t.setAttributeNS(XML, 'xml:space', 'preserve')
        cursor = end


def element(doc, name, attrs=None):
    node = doc.createElementNS(W, 'w:' + name)
    for key, value in (attrs or {}).items():
        node.setAttributeNS(W, 'w:' + key, str(value))
    return node


def attrs(node):
    return {a.localName: a.value for a in node.attributes.values() if a.namespaceURI == W}


def section_rules(section):
    return {name: attrs(nodes[0]) for name in ('pgSz', 'pgMar', 'pgNumType', 'cols')
            if (nodes := children(section, name))}


def effective_section(sections, index):
    selected = sections[index].cloneNode(True)
    inherited = {}
    for section in sections[:index+1]:
        for node in children(section):
            if node.localName in ('headerReference', 'footerReference'):
                inherited[(node.localName, node.getAttributeNS(W, 'type') or 'default')] = node
    direct = {(node.localName, node.getAttributeNS(W, 'type') or 'default') for node in children(selected)
              if node.localName in ('headerReference', 'footerReference')}
    for key, node in reversed(list(inherited.items())):
        if key not in direct:
            selected.insertBefore(node.cloneNode(True), selected.firstChild)
    return selected


def normalize_footer_fields(part):
    """Normalize existing page totals without nesting a field in cached results."""
    field_text_nodes = set()
    changed = False
    for field in descendants(part, 'fldSimple'):
        instruction = field.getAttributeNS(W, 'instr')
        replacement = re.sub(r'\bNUMPAGES\b', 'SECTIONPAGES', instruction, flags=re.I)
        if replacement != instruction:
            field.setAttributeNS(W, 'w:instr', replacement)
            changed = True
        field_text_nodes.update(id(t) for t in descendants(field, 't'))
    stack = []
    for node in part.getElementsByTagName('*'):
        if node.namespaceURI != W:
            continue
        if node.localName == 'fldChar':
            kind = node.getAttributeNS(W, 'fldCharType')
            if kind == 'begin':
                stack.append([])
            elif kind == 'end' and stack:
                codes = stack.pop()
                instruction = ''.join(n.firstChild.data if n.firstChild else '' for n in codes)
                replacement = re.sub(r'\bNUMPAGES\b', 'SECTIONPAGES', instruction, flags=re.I)
                if replacement != instruction and codes:
                    for i, code in enumerate(codes):
                        for child in list(code.childNodes):
                            code.removeChild(child)
                        code.appendChild(part.createTextNode(replacement if i == 0 else ''))
                    changed = True
        elif node.localName == 'instrText' and stack:
            stack[-1].append(node)
        elif node.localName == 't' and stack:
            field_text_nodes.add(id(node))
    return field_text_nodes, changed


def paragraph(prototype, value, *, list_item=False):
    p = prototype.cloneNode(True)
    doc = p.ownerDocument
    source_runs = descendants(p, 'r')
    best = max(source_runs, key=lambda r: len(text(r)), default=None)
    run_properties = children(best, 'rPr')[0].cloneNode(True) if best is not None and children(best, 'rPr') else None
    for child in list(p.childNodes):
        if child.nodeType != child.ELEMENT_NODE or child.localName != 'pPr':
            p.removeChild(child)
    for properties in children(p, 'pPr'):
        for child in list(children(properties)):
            if child.localName in ('sectPr', 'pageBreakBefore') or (child.localName == 'numPr' and not list_item):
                properties.removeChild(child)
    run = element(doc, 'r')
    if run_properties is not None:
        run.appendChild(run_properties)
    content = element(doc, 't')
    content.setAttributeNS(XML, 'xml:space', 'preserve')
    content.appendChild(doc.createTextNode(value))
    run.appendChild(content)
    p.appendChild(run)
    return p


def validate_content(content):
    def clean(value, maximum):
        if not isinstance(value, str) or len(value) > maximum or any(
                not (ord(c) in (9, 10, 13) or 0x20 <= ord(c) <= 0xD7FF
                     or 0xE000 <= ord(c) <= 0xFFFD or 0x10000 <= ord(c) <= 0x10FFFF)
                for c in value):
            raise ValueError('CONTENT_TYPE_OR_CAPACITY_INVALID')
    if not isinstance(content, dict):
        raise ValueError('CONTENT_OBJECT_REQUIRED')
    if set(content) - {'title', 'subject', 'subtitle', 'version', 'owner', 'running_title', 'summary', 'sections', 'include_cover'}:
        raise ValueError('UNSUPPORTED_CONTENT_COMPONENT')
    if 'include_cover' in content and not isinstance(content['include_cover'], bool):
        raise ValueError('COVER_FLAG_MUST_BE_BOOLEAN')
    clean(content.get('title'), 80)
    if not content['title'].strip():
        raise ValueError('TITLE_REQUIRED')
    for key in ('subject', 'subtitle', 'version', 'owner', 'running_title'):
        clean(content.get(key, ''), 180)
    clean(content.get('summary', ''), 500)
    sections = content.get('sections')
    if not isinstance(sections, list) or not 1 <= len(sections) <= 100:
        raise ValueError('SECTIONS_REQUIRED')
    for section in sections:
        if not isinstance(section, dict) or set(section) - {'heading', 'level', 'paragraphs', 'bullets', 'tables'}:
            raise ValueError('SECTION_OBJECT_OR_COMPONENT_INVALID')
        clean(section.get('heading'), 180)
        if section.get('level', 1) not in (1, 2, 3):
            raise ValueError('HEADING_LEVEL_INVALID')
        for key in ('paragraphs', 'bullets', 'tables'):
            if not isinstance(section.get(key, []), list):
                raise ValueError('CONTENT_COLLECTION_MUST_BE_LIST')
        for item in section.get('paragraphs', []) + section.get('bullets', []):
            clean(item, 6000)
        for table in section.get('tables', []):
            if not isinstance(table, dict) or set(table) - {'headers', 'rows'}:
                raise ValueError('TABLE_OBJECT_OR_COMPONENT_INVALID')
            headers, rows = table.get('headers'), table.get('rows')
            if not isinstance(headers, list) or not 1 <= len(headers) <= 12 or not isinstance(rows, list) or len(rows) > 1000:
                raise ValueError('TABLE_SHAPE_INVALID')
            for row in [headers] + rows:
                if not isinstance(row, list) or len(row) != len(headers):
                    raise ValueError('TABLE_SHAPE_INVALID')
                for cell in row:
                    clean(cell, 3000)


def capture(source, destination, selection):
    source, destination = Path(source), Path(destination)
    if destination.exists():
        raise ValueError('PROFILE_EXISTS_PRESERVED')
    data = package(source)
    for name, value in data.items():
        if name.startswith('word/') and name.endswith('.xml'):
            parsed = xml(value)
            if any(descendants(parsed, kind) for kind in ('ins', 'del', 'delText', 'moveFrom', 'moveTo', 'pPrChange', 'rPrChange', 'sectPrChange', 'tblPrChange', 'tcPrChange', 'trPrChange')):
                raise ValueError('REVISION_MARKUP_REQUIRES_CLEAN_REFERENCE: ' + name)
    document = xml(data['word/document.xml'])
    body = descendants(document, 'body')[0]
    nodes = children(body)
    sections = descendants(document, 'sectPr')
    if any(not isinstance(index, int) or not 0 <= index < len(sections)
           for index in (selection['body_section'], selection.get('cover_section', 0))):
        raise ValueError('SECTION_LOCATOR_INVALID')
    # Hidden source facts must not silently enter every derivative document.
    # Review only format/brand text deliberately retained by this profile.
    approved = set(selection.get('preserve_text', []))
    cleared_parts = set(selection.get('clear_text_parts', []))
    if any(name not in data or not re.fullmatch(r'word/(?:header|footer)\d+\.xml', name) for name in cleared_parts):
        raise ValueError('DISCARDED_RUNNING_PART_INVALID')
    if 'word/_rels/document.xml.rels' in data:
        relationships = {r.getAttribute('Id'): relationship_target('word/_rels/document.xml.rels', r.getAttribute('Target'))
                         for r in xml(data['word/_rels/document.xml.rels']).getElementsByTagNameNS(R, 'Relationship')}
        active_parts = set()
        for index in {selection['body_section'], selection.get('cover_section', 0)}:
            for node in children(effective_section(sections, index)):
                if node.localName in ('headerReference', 'footerReference'):
                    identity = node.getAttributeNS('http://schemas.openxmlformats.org/officeDocument/2006/relationships', 'id')
                    if identity in relationships:
                        active_parts.add(relationships[identity])
        if cleared_parts & active_parts:
            raise ValueError('ACTIVE_RUNNING_PART_CANNOT_BE_CLEARED')
    inventory = {}
    for name, value in data.items():
        if re.fullmatch(r'word/(?:header|footer)\d+\.xml', name):
            paragraphs = [p for p in descendants(xml(value), 'p') if not descendants(p, 'p')]
            inventory[name] = [text(p) for p in paragraphs if text(p).strip()]
            if name in cleared_parts:
                continue
            for p in paragraphs:
                if text(p) in selection.get('running_text', {}):
                    continue
                if re.sub(r'[\d\s/]+$', '', text(p)).strip() in approved:
                    continue
                for t in descendants(p, 't'):
                    value_text = t.firstChild.data.strip() if t.firstChild else ''
                    if value_text and value_text not in approved and not re.fullmatch(r'[\d\s/]+', value_text):
                        raise ValueError('UNREVIEWED_HEADER_FOOTER_TEXT: ' + name)
        if re.search(r'word/(?:comments|footnotes|endnotes).*\.xml$|^customXml/|^docProps/custom\.xml$', name) and name.endswith('.xml'):
            hidden = xml(value)
            leaf_text = [n.firstChild.data.strip() for n in hidden.getElementsByTagName('*')
                         if not children(n) and n.firstChild and n.firstChild.nodeType == n.TEXT_NODE and n.firstChild.data.strip()]
            if leaf_text:
                raise ValueError('HIDDEN_SOURCE_TEXT_REQUIRES_SANITIZED_WORKING_COPY: ' + name)
    if not {'heading1', 'body', 'table'} <= set(selection['prototypes']):
        raise ValueError('REQUIRED_PROTOTYPE_MISSING')
    for index in selection['prototypes'].values():
        if not isinstance(index, int) or index < 0 or index >= len(nodes):
            raise ValueError('COMPONENT_LOCATOR_INVALID')
    for name, index in selection['prototypes'].items():
        expected = 'tbl' if name == 'table' else 'p'
        if nodes[index].localName != expected:
            raise ValueError('COMPONENT_TYPE_INVALID: ' + name)
    if not 0 <= selection['body_section'] < len(sections):
        raise ValueError('SECTION_LOCATOR_INVALID')
    for index in selection.get('cover', []):
        if not isinstance(index, int) or not 0 <= index < len(nodes):
            raise ValueError('COVER_LOCATOR_INVALID')
    for index in selection.get('cover_slots', {}).values():
        if index not in selection.get('cover', []) or nodes[index].localName != 'p':
            raise ValueError('COVER_SLOT_INVALID')
    profile = {'schema_version': 1, 'name': 'company-word', 'reference': 'reference.docx',
               'source_sha256': digest(source.read_bytes()), 'selection': selection,
               'retained_running_text_inventory': inventory,
               'page_system': [section_rules(s) for s in sections],
               'parts': {name: {'sha256': digest(value), 'bytes': len(value)} for name, value in data.items()},
               'quality': {'structural_pass_is_visual_pass': False, 'word_and_all_page_visual_review_required': True,
                           'release_threshold': 90, 'critical_failures_override_score': True}}
    profile['typography'] = {}
    for name, index in selection['prototypes'].items():
        prototype = nodes[index]
        profile['typography'][name] = {
            'paragraph_properties_xml': [p.toxml() for p in descendants(prototype, 'pPr')[:2]],
            'run_properties_xml': [p.toxml() for p in descendants(prototype, 'rPr')[:2]],
            'sizes_half_points': sorted({s.getAttributeNS(W, 'val') for s in descendants(prototype, 'sz')}),
            'explicit_fonts': [attrs(f) for f in descendants(prototype, 'rFonts')[:4]]}
    profile['slots'] = {name: {'body_index': index, 'operation': 'replace_source_text',
                              'max_characters': 500 if name == 'summary' else 80 if name == 'title' else 180}
                        for name, index in selection.get('cover_slots', {}).items()}
    # Build the complete private profile in a sibling staging directory before exposing it.
    destination.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='.cw-profile-', dir=destination.parent) as temporary:
        staging = Path(temporary) / 'profile'
        staging.mkdir()
        (staging/'reference.docx').write_bytes(source.read_bytes())
        (staging/'profile.json').write_bytes(json_bytes(profile))
        (staging/'artifact.md').write_text(
            '# Company Word reference contract\n\n'
            'Use reference.docx and profile.json together. Source SHA-256: ' + profile['source_sha256'] + '\n\n'
            'The selection maps top-level body indices and paragraph/table prototypes; never copy sample business facts. '
            'Page geometry, theme, styles, numbering, drawings and logos come from the retained package. '
            'Cover fields and running titles are replaced only through documented slots. '
            'The source business content is not a mandatory outline for unrelated reports. '
            'Preserve all unmodified ZIP parts byte for byte. Word rendering and visual QA remain required.\n', encoding='utf-8')
        os.rename(staging, destination)
    return {'status': 'PROFILE_CAPTURED', 'profile': str(destination/'profile.json'), 'source_sha256': profile['source_sha256']}


def read_profile(directory):
    directory = Path(directory).resolve()
    profile = load_json(directory/'profile.json')
    if profile.get('schema_version') != 1 or profile.get('reference') != 'reference.docx':
        raise ValueError('PROFILE_SCHEMA_INVALID')
    reference = directory/'reference.docx'
    if reference.is_symlink() or digest(reference.read_bytes()) != profile['source_sha256']:
        raise ValueError('REFERENCE_HASH_MISMATCH')
    return profile, package(reference)


def table_from(prototype, headers, rows):
    table = prototype.cloneNode(True)
    doc = table.ownerDocument
    original_rows = children(table, 'tr')
    if len(original_rows) < 2:
        raise ValueError('TABLE_PROTOTYPE_REQUIRES_HEADER_AND_DATA')
    grid = children(table, 'tblGrid')[0]
    original_widths = [int(n.getAttributeNS(W, 'w')) for n in children(grid, 'gridCol')]
    total = sum(original_widths)
    width, remainder = divmod(total, len(headers))
    for node in list(grid.childNodes):
        grid.removeChild(node)
    widths = original_widths if len(original_widths) == len(headers) else [width + (i < remainder) for i in range(len(headers))]
    for size in widths:
        grid.appendChild(element(doc, 'gridCol', {'w': size}))
    for row in original_rows:
        table.removeChild(row)
    for row_index, values in enumerate([headers] + rows):
        source_row = original_rows[0 if row_index == 0 else -1]
        row = source_row.cloneNode(True)
        source_cells = children(source_row, 'tc')
        for cell in list(children(row, 'tc')):
            row.removeChild(cell)
        for column, value in enumerate(values):
            cell = source_cells[min(column, len(source_cells)-1)].cloneNode(True)
            properties = children(cell, 'tcPr')
            if properties:
                for prop in list(children(properties[0])):
                    if prop.localName in ('gridSpan', 'vMerge', 'tcW'):
                        properties[0].removeChild(prop)
                properties[0].insertBefore(element(doc, 'tcW', {'w': widths[column], 'type': 'dxa'}), properties[0].firstChild)
            source_paragraph = descendants(cell, 'p')[0]
            for node in list(cell.childNodes):
                if node.nodeType != node.ELEMENT_NODE or node.localName != 'tcPr':
                    cell.removeChild(node)
            cell.appendChild(paragraph(source_paragraph, value))
            row.appendChild(cell)
        if row_index == 0:
            properties = children(row, 'trPr')
            properties = properties[0] if properties else row.insertBefore(element(doc, 'trPr'), row.firstChild)
            if not children(properties, 'tblHeader'):
                properties.appendChild(element(doc, 'tblHeader'))
        table.appendChild(row)
    return table


def build(directory, content, output):
    validate_content(content)
    output = Path(output)
    if output.exists() or output.is_symlink():
        raise ValueError('OUTPUT_EXISTS_PRESERVED')
    if Path(str(output)+'.build.json').exists():
        raise ValueError('OUTPUT_RECEIPT_EXISTS_PRESERVED')
    profile, data = read_profile(directory)
    original = dict(data)
    selection = profile['selection']
    document = xml(data['word/document.xml'])
    body = descendants(document, 'body')[0]
    nodes, sections = children(body), descendants(document, 'sectPr')
    prototypes = {name: nodes[index].cloneNode(True) for name, index in selection['prototypes'].items()}
    body_section = effective_section(sections, selection['body_section'])
    cover_section = effective_section(sections, selection.get('cover_section', 0))
    for node in list(body.childNodes):
        body.removeChild(node)
    if content.get('include_cover', True) and selection.get('cover'):
        slots = {index: role for role, index in selection.get('cover_slots', {}).items()}
        for index in selection['cover']:
            node = nodes[index].cloneNode(True)
            if index in slots:
                role = slots[index]
                value = content.get(role, '')
                node = paragraph(node, value)
            else:
                # Do not retain undocumented source prose; keep drawing/blank furniture only.
                for text_node in descendants(node, 't'):
                    for child in list(text_node.childNodes):
                        text_node.removeChild(child)
            for properties in descendants(node, 'pPr'):
                for sect in list(children(properties, 'sectPr')):
                    properties.removeChild(sect)
            body.appendChild(node)
        paragraph_break = children(body)[-1]
        if paragraph_break.localName != 'p':
            paragraph_break = element(document, 'p')
            body.appendChild(paragraph_break)
        existing_properties = children(paragraph_break, 'pPr')
        properties = existing_properties[0] if existing_properties else paragraph_break.insertBefore(element(document, 'pPr'), paragraph_break.firstChild)
        properties.appendChild(cover_section)
    for item in content['sections']:
        role = 'heading' + str(item.get('level', 1))
        body.appendChild(paragraph(prototypes.get(role, prototypes['heading1']), item['heading']))
        for value in item.get('paragraphs', []):
            body.appendChild(paragraph(prototypes['body'], value))
        for value in item.get('bullets', []):
            body.appendChild(paragraph(prototypes.get('bullet', prototypes['body']), value, list_item=True))
        for item_table in item.get('tables', []):
            body.appendChild(table_from(prototypes['table'], item_table['headers'], item_table['rows']))
            body.appendChild(paragraph(prototypes['body'], ''))
    body.appendChild(body_section)
    data['word/document.xml'] = document.toxml(encoding='utf-8')
    running = content.get('running_title') or content['title']
    expected_running = {}
    for name, value in list(data.items()):
        if re.fullmatch(r'word/(?:header|footer)\d+\.xml', name):
            part = xml(value)
            changed = False
            if name in selection.get('clear_text_parts', []):
                for t in descendants(part, 't'):
                    for child in list(t.childNodes):
                        t.removeChild(child)
                data[name] = part.toxml(encoding='utf-8')
                continue
            paragraphs = [p for p in descendants(part, 'p') if not descendants(p, 'p')]
            for index, p in enumerate(paragraphs):
                replacements = selection.get('running_text', {})
                if text(p) in replacements:
                    replacement = replacements[text(p)].replace('{{running_title}}', running)
                    replace_text_in_place(p, replacement)
                    expected_running.setdefault(name, []).append({'paragraph': index, 'text': replacement})
                    changed = True
            if changed:
                data[name] = part.toxml(encoding='utf-8')
    # Fields retain the source's layout; refresh on open instead of preserving stale totals.
    for name, value in list(data.items()):
        if re.fullmatch(r'word/footer\d+\.xml', name):
            part = xml(value)
            field_text_nodes, changed = normalize_footer_fields(part)
            previous_text = ''
            clearing_total_digits = False
            for t in descendants(part, 't'):
                value_text = t.firstChild.data if t.firstChild else ''
                if id(t) in field_text_nodes:
                    if value_text.strip():
                        previous_text = value_text
                    continue
                if clearing_total_digits and re.fullmatch(r'\d+', value_text.strip()):
                    t.firstChild.data = ''
                    continue
                if value_text.strip():
                    clearing_total_digits = False
                combined = bool(re.fullmatch(r'\s*/\s*\d+\s*', value_text))
                split = bool(re.fullmatch(r'\d+', value_text.strip()) and previous_text.strip() == '/')
                if combined or split:
                    clearing_total_digits = True
                    t.firstChild.data = ' / ' if combined else ''
                    run = t.parentNode
                    field = element(part, 'fldSimple', {'instr': ' SECTIONPAGES '})
                    field.appendChild(element(part, 'r'))
                    properties = children(run, 'rPr')
                    if properties:
                        field.firstChild.appendChild(properties[0].cloneNode(True))
                    field.firstChild.appendChild(element(part, 't'))
                    field.firstChild.lastChild.appendChild(part.createTextNode('1'))
                    run.parentNode.insertBefore(field, run.nextSibling)
                    changed = True
                if value_text.strip():
                    previous_text = value_text
            if changed:
                data[name] = part.toxml(encoding='utf-8')
    if 'word/settings.xml' in data:
        settings = xml(data['word/settings.xml'])
        updates = descendants(settings, 'updateFields')
        if not updates:
            updates = [element(settings, 'updateFields')]
            settings.documentElement.appendChild(updates[0])
        updates[0].setAttributeNS(W, 'w:val', 'true')
        data['word/settings.xml'] = settings.toxml(encoding='utf-8')
    if 'docProps/core.xml' in data:
        core = xml(data['docProps/core.xml'])
        for node in core.getElementsByTagName('*'):
            if node.localName in ('creator', 'lastModifiedBy', 'title', 'subject', 'description', 'keywords'):
                for child in list(node.childNodes):
                    node.removeChild(child)
                node.appendChild(core.createTextNode(content['title'] if node.localName == 'title' else ''))
        data['docProps/core.xml'] = core.toxml(encoding='utf-8')
    output.parent.mkdir(parents=True, exist_ok=True)
    import io
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, 'w', zipfile.ZIP_DEFLATED) as archive:
        for name, value in data.items():
            archive.writestr(name, value)
    write_new(output, buffer.getvalue())
    receipt = {'schema_version': 1, 'source_sha256': profile['source_sha256'],
               'output_sha256': digest(output.read_bytes()), 'content_sha256': digest(json_bytes(content)),
               'changed_parts': [name for name in data if data[name] != original[name]],
               'expected_running_text': expected_running,
               'expected_sections': len(descendants(document, 'sectPr')),
               'section_sources': ([selection.get('cover_section', 0)] if content.get('include_cover', True) and selection.get('cover') else []) + [selection['body_section']],
               'expected_tables': sum(len(item.get('tables', [])) for item in content['sections']),
               'field_cache': 'REFRESH_REQUIRED_IN_WORD', 'word_validation': 'NOT_RUN', 'visual_validation': 'NOT_RUN'}
    write_new(str(output)+'.build.json', json_bytes(receipt))
    return {'status': 'BUILT_NOT_VISUALLY_VERIFIED', 'output': str(output), 'receipt': str(output)+'.build.json'}


def verify(directory, output):
    profile, source = read_profile(directory)
    actual = package(output)
    receipt = load_json(str(output)+'.build.json')
    if receipt.get('source_sha256') != profile['source_sha256'] or receipt.get('output_sha256') != digest(Path(output).read_bytes()):
        raise ValueError('BUILD_RECEIPT_HASH_MISMATCH')
    if set(actual) != set(source):
        raise ValueError('PACKAGE_PART_SET_CHANGED')
    allowed = {'word/document.xml', 'word/settings.xml', 'docProps/core.xml'} | {name for name in source if re.fullmatch(r'word/(?:header|footer)\d+\.xml', name)}
    changed = {name for name in actual if actual[name] != source[name]}
    if not changed <= allowed or changed != set(receipt['changed_parts']):
        raise ValueError('PRESERVE_ONLY_PART_CHANGED')
    document = xml(actual['word/document.xml'])
    sections = descendants(document, 'sectPr')
    if len(sections) != receipt['expected_sections'] or len(descendants(document, 'tbl')) != receipt['expected_tables']:
        raise ValueError('DOCUMENT_STRUCTURE_MISMATCH')
    expected_geometry = profile['page_system'][profile['selection']['body_section']]
    if len(receipt.get('section_sources', [])) != len(sections):
        raise ValueError('SECTION_SOURCE_MAP_MISMATCH')
    for section, source_index in zip(sections, receipt['section_sources']):
        if not isinstance(source_index, int) or not 0 <= source_index < len(profile['page_system']):
            raise ValueError('SECTION_SOURCE_MAP_INVALID')
        source_geometry = profile['page_system'][source_index]
        measured = section_rules(section)
        if measured.get('pgSz') != source_geometry.get('pgSz') or measured.get('pgMar') != source_geometry.get('pgMar'):
            raise ValueError('PAGE_GEOMETRY_CHANGED')
    page = expected_geometry['pgSz']
    margins = expected_geometry['pgMar']
    available = int(page['w']) - int(margins.get('left', 0)) - int(margins.get('right', 0))
    for table in descendants(document, 'tbl'):
        grids = children(table, 'tblGrid')
        if grids and sum(int(n.getAttributeNS(W, 'w')) for n in children(grids[0], 'gridCol')) > available:
            raise ValueError('TABLE_EXCEEDS_PRINTABLE_WIDTH')
    for name, value in actual.items():
        if re.fullmatch(r'word/(?:header|footer)\d+\.xml', name):
            if name in profile['selection'].get('clear_text_parts', []) and text(xml(value)).strip():
                raise ValueError('DISCARDED_RUNNING_PART_RETAINS_TEXT')
            paragraphs = [p for p in descendants(xml(value), 'p') if not descendants(p, 'p')]
            for expected in receipt.get('expected_running_text', {}).get(name, []):
                index = expected['paragraph']
                if not isinstance(index, int) or not 0 <= index < len(paragraphs) or text(paragraphs[index]) != expected['text']:
                    raise ValueError('RUNNING_TITLE_REPLACEMENT_MISMATCH')
    return {'status': 'STRUCTURAL_PASS_VISUAL_REQUIRED', 'source_unchanged': True,
            'checks': ['reference hash', 'output hash', 'all XML parse', 'package part set', 'preserve-only bytes', 'page geometry', 'table widths', 'source running-title removal'],
            'word_open': 'NOT_INDEPENDENTLY_OBSERVED_BY_THIS_CHECK', 'visual_review': 'REQUIRED',
            'score': None, 'production_readiness': 'NOT_ESTABLISHED'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    capture_args = commands.add_parser('capture')
    capture_args.add_argument('--source', required=True)
    capture_args.add_argument('--profile', required=True)
    capture_args.add_argument('--selection', required=True)
    for command in ('build', 'verify'):
        sub = commands.add_parser(command)
        sub.add_argument('--profile', required=True)
        sub.add_argument('--output', required=True)
        if command == 'build':
            sub.add_argument('--content', required=True)
    args = parser.parse_args()
    try:
        if args.command == 'capture':
            result = capture(args.source, args.profile, load_json(args.selection))
        elif args.command == 'build':
            result = build(args.profile, load_json(args.content), args.output)
        else:
            result = verify(args.profile, args.output)
        print(json.dumps(result, ensure_ascii=False, indent=2))
    except (ValueError, KeyError, OSError, zipfile.BadZipFile, ExpatError) as error:
        print(json.dumps({'status': 'FAIL', 'reason': str(error)}, ensure_ascii=False), file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
