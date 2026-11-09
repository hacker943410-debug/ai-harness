"""Synthetic-only profile/build/fidelity regression; never requires company data."""
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest
import zipfile

SCRIPT = Path(__file__).resolve().parents[1]/'skills/jh-company-word/scripts/company_word.py'
spec = importlib.util.spec_from_file_location('company_word', SCRIPT)
cw = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cw)
W = cw.W


def p(value, size=20, extra=''):
    return f'<w:p><w:pPr>{extra}</w:pPr><w:r><w:rPr><w:sz w:val="{size}"/></w:rPr><w:t>{value}</w:t></w:r></w:p>'


SECT = '<w:sectPr><w:pgSz w:w="11906" w:h="16838"/><w:pgMar w:top="1701" w:left="1440" w:right="1440" w:bottom="1440"/></w:sectPr>'
CELL = '<w:tc><w:tcPr><w:tcW w:w="4000" w:type="dxa"/></w:tcPr>'+p('Synthetic cell', 18)+'</w:tc>'
TABLE = '<w:tbl><w:tblPr><w:tblW w:w="8000" w:type="dxa"/></w:tblPr><w:tblGrid><w:gridCol w:w="4000"/><w:gridCol w:w="4000"/></w:tblGrid><w:tr>'+CELL*2+'</w:tr><w:tr>'+CELL*2+'</w:tr></w:tbl>'


def fixture(path, modifications=None):
    body = p('Original cover')+p('Original subtitle', extra=SECT)+p('Original heading', 24)+p('Old synthetic body')+p('Old bullet')+TABLE+SECT
    data = {
        '[Content_Types].xml': b'<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"/>',
        '_rels/.rels': (f'<Relationships xmlns="{cw.R}"><Relationship Id="r1" Type="document" Target="word/document.xml"/></Relationships>').encode(),
        'word/document.xml': (f'<w:document xmlns:w="{W}"><w:body>{body}</w:body></w:document>').encode(),
        'word/styles.xml': (f'<w:styles xmlns:w="{W}"/>').encode(),
        'word/numbering.xml': (f'<w:numbering xmlns:w="{W}"/>').encode(),
        'word/header1.xml': (f'<w:hdr xmlns:w="{W}">'+p('Old subject | CONFIDENTIAL')+'</w:hdr>').encode(),
        'word/footer1.xml': (f'<w:ftr xmlns:w="{W}">'+p(' / 12')+'</w:ftr>').encode(),
        'word/settings.xml': (f'<w:settings xmlns:w="{W}"/>').encode(),
        'word/media/synthetic.bin': b'synthetic inert bytes, not a real company asset',
    }
    data.update(modifications or {})
    with zipfile.ZipFile(path, 'w') as archive:
        for name, value in data.items():
            archive.writestr(name, value)
    return data


class CompanyWordTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='company-word-test-')
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.source = self.root/'source.docx'
        self.parts = fixture(self.source)
        self.profile = self.root/'private-profile'
        self.selection = {'prototypes': {'heading1': 2, 'body': 3, 'bullet': 4, 'table': 5},
                          'body_section': 1, 'cover_section': 0, 'cover': [0, 1],
                          'cover_slots': {'title': 0, 'subtitle': 1},
                          'running_text': {'Old subject | CONFIDENTIAL': '{{running_title}} | CONFIDENTIAL'}}
        self.content = {'title': 'New report', 'subtitle': 'Synthetic validation', 'sections': [
            {'heading': 'Purpose', 'paragraphs': ['Only the requested new content.'],
             'tables': [{'headers': ['Name', 'Result', 'Evidence'], 'rows': [['A', 'PASS', 'Observed']]}]}]}
        self.output = self.root/'output.docx'

    def capture(self):
        return cw.capture(self.source, self.profile, self.selection)

    def build(self):
        self.capture()
        return cw.build(self.profile, self.content, self.output)

    def rewrite_output(self, changes):
        parts = cw.package(self.output)
        parts.update(changes)
        with zipfile.ZipFile(self.output, 'w') as archive:
            for name, value in parts.items():
                archive.writestr(name, value)

    def test_capture_retains_exact_reference_and_measured_rules(self):
        before = self.source.read_bytes()
        self.capture()
        self.assertEqual(before, (self.profile/'reference.docx').read_bytes())
        self.assertEqual(before, self.source.read_bytes())
        profile = cw.load_json(self.profile/'profile.json')
        self.assertEqual(profile['page_system'][0]['pgSz']['w'], '11906')
        self.assertEqual(profile['typography']['body']['sizes_half_points'], ['20'])
        self.assertEqual(profile['slots']['title']['operation'], 'replace_source_text')

    def test_profile_capture_refuses_overwrite(self):
        self.capture()
        with self.assertRaisesRegex(ValueError, 'PROFILE_EXISTS'):
            self.capture()

    def test_build_preserves_opaque_parts_and_replaces_prose(self):
        self.build()
        data = cw.package(self.output)
        for name in ('word/styles.xml', 'word/numbering.xml', 'word/media/synthetic.bin'):
            self.assertEqual(data[name], self.parts[name])
        body = cw.text(cw.xml(data['word/document.xml']))
        self.assertIn('Only the requested new content.', body)
        self.assertNotIn('Old synthetic body', body)
        self.assertNotIn('Original cover', body)
        self.assertIn('New report | CONFIDENTIAL', cw.text(cw.xml(data['word/header1.xml'])))
        self.assertNotIn('12', cw.text(cw.xml(data['word/footer1.xml'])))
        self.assertEqual(cw.verify(self.profile, self.output)['status'], 'STRUCTURAL_PASS_VISUAL_REQUIRED')
        self.assertIsNone(cw.verify(self.profile, self.output)['score'])

    def test_short_memo_omits_cover(self):
        self.content['include_cover'] = False
        self.build()
        doc = cw.xml(cw.package(self.output)['word/document.xml'])
        self.assertEqual(len(cw.descendants(doc, 'sectPr')), 1)

    def test_running_title_change_retains_styled_confidentiality_suffix(self):
        header = f'<w:hdr xmlns:w="{W}"><w:p><w:r><w:t>Old subject | </w:t></w:r><w:r><w:rPr><w:color w:val="FF0000"/></w:rPr><w:t>CONFIDENTIAL</w:t></w:r></w:p></w:hdr>'
        fixture(self.source, {'word/header1.xml': header.encode()})
        self.build()
        parsed = cw.xml(cw.package(self.output)['word/header1.xml'])
        red = cw.descendants(parsed, 'color')[0]
        self.assertEqual(cw.text(red.parentNode.parentNode), 'CONFIDENTIAL')

    def test_split_static_footer_total_becomes_a_section_page_field(self):
        footer = f'<w:ftr xmlns:w="{W}"><w:p><w:r><w:t>1</w:t></w:r><w:r><w:t> / </w:t></w:r><w:r><w:t>46</w:t></w:r></w:p></w:ftr>'
        fixture(self.source, {'word/footer1.xml': footer.encode()})
        self.build()
        parsed = cw.xml(cw.package(self.output)['word/footer1.xml'])
        self.assertNotIn('46', cw.text(parsed))
        self.assertIn('SECTIONPAGES', cw.descendants(parsed, 'fldSimple')[0].getAttributeNS(W, 'instr'))

    def test_each_digit_of_static_footer_total_may_be_a_separate_run(self):
        footer = f'<w:ftr xmlns:w="{W}"><w:p><w:r><w:t>1</w:t></w:r><w:r><w:t> / </w:t></w:r><w:r><w:t>4</w:t></w:r><w:r><w:t>6</w:t></w:r></w:p></w:ftr>'
        fixture(self.source, {'word/footer1.xml': footer.encode()})
        self.build()
        parsed = cw.xml(cw.package(self.output)['word/footer1.xml'])
        self.assertNotIn('4', cw.text(parsed))
        self.assertNotIn('6', cw.text(parsed))
        self.assertEqual(len(cw.descendants(parsed, 'fldSimple')), 1)

    def test_new_column_count_retains_printable_width_and_repeat_header(self):
        self.build()
        document = cw.xml(cw.package(self.output)['word/document.xml'])
        table = cw.descendants(document, 'tbl')[0]
        widths = cw.descendants(table, 'gridCol')
        self.assertEqual(len(widths), 3)
        self.assertEqual(sum(int(n.getAttributeNS(W, 'w')) for n in widths), 8000)
        self.assertEqual(len(cw.descendants(table, 'tblHeader')), 1)

    def test_source_hash_drift_is_blocked(self):
        self.capture()
        (self.profile/'reference.docx').write_bytes(b'changed')
        with self.assertRaisesRegex(ValueError, 'REFERENCE_HASH'):
            cw.build(self.profile, self.content, self.output)
        self.assertFalse(self.output.exists())

    def test_existing_output_is_preserved(self):
        self.capture()
        self.output.write_bytes(b'owned by user')
        with self.assertRaisesRegex(ValueError, 'OUTPUT_EXISTS'):
            cw.build(self.profile, self.content, self.output)
        self.assertEqual(self.output.read_bytes(), b'owned by user')

    def test_existing_receipt_is_preserved_before_output_creation(self):
        self.capture()
        Path(str(self.output)+'.build.json').write_text('user receipt')
        with self.assertRaisesRegex(ValueError, 'RECEIPT_EXISTS'):
            cw.build(self.profile, self.content, self.output)
        self.assertFalse(self.output.exists())

    def test_nonrectangular_table_fails_before_writing(self):
        self.capture()
        self.content['sections'][0]['tables'][0]['rows'][0].pop()
        with self.assertRaisesRegex(ValueError, 'TABLE_SHAPE'):
            cw.build(self.profile, self.content, self.output)
        self.assertFalse(self.output.exists())

    def test_invalid_title_and_text_control_fail(self):
        for value in ('', 'x'*81, 'bad\x01text', 'bad\ufffetext', 'bad\ud800text'):
            self.content['title'] = value
            with self.assertRaises(ValueError):
                cw.validate_content(self.content)

    def test_string_collection_is_not_silently_split_into_characters(self):
        self.content['sections'][0]['paragraphs'] = 'PRIVATE FACT'
        with self.assertRaisesRegex(ValueError, 'COLLECTION_MUST_BE_LIST'):
            cw.validate_content(self.content)

    def test_unsupported_requested_component_is_not_silently_dropped(self):
        self.content['toc'] = True
        with self.assertRaisesRegex(ValueError, 'UNSUPPORTED_CONTENT_COMPONENT'):
            cw.validate_content(self.content)

    def test_unslotted_cover_drawing_does_not_retain_source_prose(self):
        parts = dict(self.parts)
        document = cw.xml(parts['word/document.xml'])
        body = cw.descendants(document, 'body')[0]
        body.insertBefore(cw.xml(f'<w:p xmlns:w="{W}"><w:r><w:drawing/><w:t>Old private approval</w:t></w:r></w:p>').documentElement, body.firstChild)
        fixture(self.source, {'word/document.xml': document.toxml(encoding='utf-8')})
        self.selection['cover'] = [0, 1, 2]
        self.selection['cover_slots'] = {'title': 1, 'subtitle': 2}
        self.selection['prototypes'] = {key: value+1 for key, value in self.selection['prototypes'].items()}
        self.build()
        built = cw.xml(cw.package(self.output)['word/document.xml'])
        self.assertNotIn('Old private approval', cw.text(built))
        self.assertEqual(len(cw.descendants(built, 'drawing')), 1)

    def test_cover_and_body_may_use_distinct_source_geometry(self):
        document = cw.xml(self.parts['word/document.xml'])
        cw.descendants(document, 'pgMar')[0].setAttributeNS(W, 'w:top', '1200')
        fixture(self.source, {'word/document.xml': document.toxml(encoding='utf-8')})
        self.build()
        self.assertEqual(cw.verify(self.profile, self.output)['status'], 'STRUCTURAL_PASS_VISUAL_REQUIRED')

    def test_wrong_component_locator_is_blocked(self):
        self.selection['prototypes']['body'] = 5
        with self.assertRaisesRegex(ValueError, 'COMPONENT_TYPE'):
            self.capture()
        self.assertFalse(self.profile.exists())

    def test_required_component_missing_is_blocked(self):
        del self.selection['prototypes']['table']
        with self.assertRaisesRegex(ValueError, 'REQUIRED_PROTOTYPE'):
            self.capture()

    def test_unsafe_zip_path_is_blocked(self):
        fixture(self.source, {'../outside.xml': b'<x/>'})
        with self.assertRaisesRegex(ValueError, 'UNSAFE_PACKAGE'):
            self.capture()

    def test_active_content_is_blocked(self):
        fixture(self.source, {'word/vbaProject.bin': b'not executed'})
        with self.assertRaisesRegex(ValueError, 'ACTIVE_CONTENT'):
            self.capture()

    def test_renamed_active_payload_content_type_is_blocked(self):
        fixture(self.source, {'word/payload.bin': b'inert', '[Content_Types].xml': b'<Types><Override PartName="/word/payload.bin" ContentType="application/vnd.ms-office.vbaProject"/></Types>'})
        with self.assertRaisesRegex(ValueError, 'ACTIVE_CONTENT_TYPE'):
            self.capture()

    def test_renamed_active_relationship_is_blocked(self):
        fixture(self.source, {'word/payload.bin': b'inert', 'word/_rels/document.xml.rels': f'<Relationships xmlns="{cw.R}"><Relationship Id="a" Type="http://schemas.microsoft.com/office/2006/relationships/vbaProject" Target="payload.bin"/></Relationships>'.encode()})
        with self.assertRaisesRegex(ValueError, 'ACTIVE_RELATIONSHIP'):
            self.capture()

    def test_hidden_comment_is_blocked(self):
        fixture(self.source, {'word/comments.xml': f'<w:comments xmlns:w="{W}">'+p('Old private approval')+'</w:comments>'})
        with self.assertRaisesRegex(ValueError, 'HIDDEN_SOURCE_TEXT'):
            self.capture()

    def test_unmapped_unused_header_prose_is_blocked(self):
        fixture(self.source, {'word/header99.xml': (f'<w:hdr xmlns:w="{W}">'+p('Old private approval')+'</w:hdr>').encode()})
        with self.assertRaisesRegex(ValueError, 'UNREVIEWED_HEADER'):
            self.capture()

    def test_deliberately_unused_header_text_is_cleared_in_derivative(self):
        fixture(self.source, {'word/header99.xml': (f'<w:hdr xmlns:w="{W}">'+p('Old private approval')+'</w:hdr>').encode()})
        self.selection['clear_text_parts'] = ['word/header99.xml']
        self.build()
        self.assertEqual(cw.text(cw.xml(cw.package(self.output)['word/header99.xml'])), '')
        self.assertEqual(cw.verify(self.profile, self.output)['status'], 'STRUCTURAL_PASS_VISUAL_REQUIRED')

    def test_selected_section_header_cannot_be_cleared(self):
        document = cw.xml(self.parts['word/document.xml'])
        header = document.createElementNS(W, 'w:headerReference')
        header.setAttributeNS('http://schemas.openxmlformats.org/officeDocument/2006/relationships', 'r:id', 'h1')
        document.documentElement.setAttribute('xmlns:r', 'http://schemas.openxmlformats.org/officeDocument/2006/relationships')
        cw.descendants(document, 'sectPr')[-1].appendChild(header)
        self.selection['clear_text_parts'] = ['word/header1.xml']
        for target in ('header1.xml', '/word/header1.xml', 'header%31.xml'):
            with self.subTest(target=target):
                fixture(self.source, {'word/document.xml': document.toxml(encoding='utf-8'),
                    'word/_rels/document.xml.rels': f'<Relationships xmlns="{cw.R}"><Relationship Id="h1" Type="header" Target="{target}"/></Relationships>'.encode()})
                with self.assertRaisesRegex(ValueError, 'ACTIVE_RUNNING_PART'):
                    self.capture()

    def test_inherited_header_is_materialized_and_cannot_be_cleared(self):
        document = cw.xml(self.parts['word/document.xml'])
        header = document.createElementNS(W, 'w:headerReference')
        header.setAttributeNS('http://schemas.openxmlformats.org/officeDocument/2006/relationships', 'r:id', 'h1')
        document.documentElement.setAttribute('xmlns:r', 'http://schemas.openxmlformats.org/officeDocument/2006/relationships')
        sections = cw.descendants(document, 'sectPr')
        sections[0].appendChild(header)
        effective = cw.effective_section(sections, 1)
        self.assertEqual(len(cw.children(effective, 'headerReference')), 1)
        fixture(self.source, {'word/document.xml': document.toxml(encoding='utf-8'),
            'word/_rels/document.xml.rels': f'<Relationships xmlns="{cw.R}"><Relationship Id="h1" Type="header" Target="header1.xml"/></Relationships>'.encode()})
        self.selection['clear_text_parts'] = ['word/header1.xml']
        with self.assertRaisesRegex(ValueError, 'ACTIVE_RUNNING_PART'):
            self.capture()

    def test_external_relationship_is_blocked(self):
        fixture(self.source, {'word/_rels/document.xml.rels': f'<Relationships xmlns="{cw.R}"><Relationship Id="x" Target="https://example.invalid/remote" TargetMode="External"/></Relationships>'.encode()})
        with self.assertRaisesRegex(ValueError, 'EXTERNAL_RELATIONSHIP'):
            self.capture()

    def test_broken_relationship_is_blocked(self):
        fixture(self.source, {'word/_rels/document.xml.rels': f'<Relationships xmlns="{cw.R}"><Relationship Id="x" Target="missing.xml"/></Relationships>'.encode()})
        with self.assertRaisesRegex(ValueError, 'RELATIONSHIP_TARGET'):
            self.capture()

    def test_xml_entity_declaration_is_blocked(self):
        fixture(self.source, {'word/styles.xml': b'<!DOCTYPE x [<!ENTITY e "bad">]><x>&e;</x>'})
        with self.assertRaisesRegex(ValueError, 'XML_DECLARATION'):
            self.capture()

    def test_output_tampering_is_detected(self):
        self.build()
        self.rewrite_output({'word/styles.xml': f'<w:styles xmlns:w="{W}"><w:style/></w:styles>'.encode()})
        with self.assertRaisesRegex(ValueError, 'RECEIPT_HASH'):
            cw.verify(self.profile, self.output)

    def test_preserve_only_change_is_detected_even_with_updated_local_hash(self):
        self.build()
        self.rewrite_output({'word/styles.xml': f'<w:styles xmlns:w="{W}"><w:style/></w:styles>'.encode()})
        receipt_path = Path(str(self.output)+'.build.json')
        receipt = cw.load_json(receipt_path)
        receipt['output_sha256'] = cw.digest(self.output.read_bytes())
        receipt['changed_parts'].append('word/styles.xml')
        receipt_path.write_bytes(cw.json_bytes(receipt))
        with self.assertRaisesRegex(ValueError, 'PRESERVE_ONLY'):
            cw.verify(self.profile, self.output)


if __name__ == '__main__':
    unittest.main()
