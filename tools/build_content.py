#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Конвейер контента Сидура: docx (три версии: иврит / транслит / перевод) → JSON-бандлы.

Использование:
  python3 tools/build_content.py --service mincha  path/to/Минха_три_версии.docx
  python3 tools/build_content.py --sections       path/to/Разные_молитвы_три_версии.docx
  (пути к Content и liturgy.json определяются от корня репозитория автоматически)

Формат docx (как готовит автор текстов):
  Часть 1 — иврит с огласовками, часть 2 — транслитерация, часть 3 — русский перевод.
  Размер шрифта кодирует роль абзаца:
    ≥40  — заголовок части файла (пропускается)
    30–39 — большой раздел (H)        → part службы / отдельный текст
    25–29 — подзаголовок (h)          → название благословения / блока
    23–24 — текст молитвы (b)
    ≤22  — ремарка-инструкция (r);  ремарки об условных вставках подсвечиваются

Будущие тексты: просто прогнать новый docx этим скриптом. Если json называется так же,
как id записи в liturgy.json, приложение само откроет его красивой службой (SmartRow).
"""
import sys, os, json, zipfile, argparse
from xml.etree import ElementTree as ET

NS = '{http://schemas.openxmlformats.org/wordprocessingml/2006/main}'
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONTENT = os.path.join(ROOT, 'Сидур', 'Content')

INSERT_KEYS = ['בקיץ', 'בַּקַּיִץ', 'בחורף', 'בַּחֹרֶף', 'המועד', 'הַמּוֹעֵד', 'ראש חדש',
               'ראש חודש', 'חֹדֶשׁ', 'חנוכה', 'חֲנֻכָּה', 'פורים', 'פוּרִים', 'תענית',
               'תַּעֲנִית', 'עשרת', 'עֲשֶׂרֶת', 'בסוכות', 'במועדים', 'יעלה', 'בר\'\'ח', "בר''ח"]


def cap(s):
    return s[:1].upper() + s[1:] if s else s


def read_rows(path):
    z = zipfile.ZipFile(path)
    root = ET.fromstring(z.read('word/document.xml').decode('utf-8'))
    rows = []
    for p in root.find(NS + 'body').iter(NS + 'p'):
        txt = ''.join(t.text or '' for t in p.iter(NS + 't')).strip()
        if not txt:
            continue
        rPr = next((r.find(NS + 'rPr') for r in p.iter(NS + 'r')), None)
        sz = 24
        if rPr is not None and rPr.find(NS + 'sz') is not None:
            sz = int(rPr.find(NS + 'sz').get(NS + 'val'))
        rows.append((txt, sz))
    return rows


def script_of(s):
    for ch in s:
        if '֐' <= ch <= '׿':
            return 'he'
        if 'Ѐ' <= ch <= 'ӿ':
            return 'ru'
    return '?'


def kind_of(sz):
    if sz >= 40: return 'skip'
    if sz >= 30: return 'H'
    if sz >= 25: return 'h'
    if sz <= 22: return 'r'
    return 'b'


def three_parts(rows):
    """Split rows into he / translit / ru item lists; verify exact alignment."""
    p2 = p3 = None
    for i, (t, sz) in enumerate(rows):
        if p2 is None and sz >= 40 and script_of(t) == 'ru':
            p2 = i
        if 'ЧАСТЬ 3' in t:
            p3 = i
            break
    if p2 is None:
        for i, (t, sz) in enumerate(rows):
            if sz >= 34 and script_of(t) == 'ru':
                p2 = i
                break
    def items(a, b):
        return [(kind_of(sz), t) for t, sz in rows[a:b] if kind_of(sz) != 'skip']
    he, tr, ru = items(0, p2), items(p2, p3), items(p3, len(rows))
    assert [k for k, _ in he] == [k for k, _ in tr] == [k for k, _ in ru], \
        f'Версии не выровнены: {len(he)}/{len(tr)}/{len(ru)}'
    return list(zip(he, tr, ru))


def make_block(kh, th, tt, tr_, insert):
    b = {'k': {'h': 'sub', 'r': 'rubric', 'b': 'body'}[kh],
         'he': th, 'translit': cap(tt), 'ru': cap(tr_)}
    if insert:
        b['insert'] = True
    return b


def build_service(trip, sid, single_part=False):
    """Triplets → BundledService dict. H starts a part (unless single_part)."""
    doc = {'id': sid, 'titleHe': '', 'titleRu': '', 'parts': []}
    cur = None
    insert_flag = False
    first_H = True
    for (kh, th), (kt, tt), (kr, tr_) in trip:
        if kh == 'H' and not single_part:
            if first_H:
                doc['titleHe'], doc['titleRu'] = th, cap(tr_)
                first_H = False
                continue
            cur = {'he': th, 'ru': cap(tr_), 'blocks': []}
            doc['parts'].append(cur)
            insert_flag = False
            continue
        if kh == 'H' and single_part:
            if first_H:
                doc['titleHe'], doc['titleRu'] = th, cap(tr_)
                first_H = False
            continue
        if cur is None:
            cur = {'he': doc['titleHe'] if single_part else 'פְּתִיחָה',
                   'ru': doc['titleRu'] if single_part else 'Начало', 'blocks': []}
            doc['parts'].append(cur)
        if kh == 'r':
            insert_flag = any(k in th for k in INSERT_KEYS)
            cur['blocks'].append(make_block(kh, th, tt, tr_, insert_flag))
        elif kh == 'b':
            cur['blocks'].append(make_block(kh, th, tt, tr_, insert_flag))
        else:
            insert_flag = False
            cur['blocks'].append(make_block(kh, th, tt, tr_, False))
    return doc


def save(doc, name):
    path = os.path.join(CONTENT, name + '.json')
    json.dump(doc, open(path, 'w'), ensure_ascii=False, separators=(',', ':'))
    n = sum(len(p['blocks']) for p in doc['parts'])
    print(f'  {name}.json: parts={len(doc["parts"])} blocks={n} bytes={os.path.getsize(path)}')


def cmd_service(docx, sid):
    trip = three_parts(read_rows(docx))
    save(build_service(trip, sid), sid)


# --- разные молитвы: H-разделы файла → отдельные службы + патч liturgy.json ---

SECTION_IDS = ['birkat_hashachar', 'birkat_halevana', 'bedtime',
               'birkat_hamazon', 'meein_shalosh', 'NEHENIN']
NEHENIN_ORDER = ['mezonot', 'hagefen', 'haetz', 'haadama', 'shehakol',
                 'boreh', 'smell_trees', 'smell_grasses', 'smell_other', 'shehecheyanu']


def cmd_sections(docx):
    trip = three_parts(read_rows(docx))
    # split trip by H
    sections = []
    cur = None
    for t in trip:
        if t[0][0] == 'H':
            cur = {'header': t, 'items': []}
            sections.append(cur)
        elif cur is not None:
            cur['items'].append(t)
    print(f'H-разделов: {len(sections)}')
    assert len(sections) == len(SECTION_IDS), [s['header'][2][1][:30] for s in sections]

    liturgy_path = os.path.join(CONTENT, 'liturgy.json')
    liturgy = json.load(open(liturgy_path))

    def patch(pid, he, tr, ru):
        def walk(items):
            for it in items:
                if it['id'] == pid:
                    it['textHe'], it['textTranslit'], it['textRu'] = he, cap(tr), cap(ru)
                    return True
            return False
        found = walk(liturgy.get('brachotOften', [])) or walk(liturgy.get('personal', []))
        if not found:
            for f in liturgy.get('brachotFolders', []):
                if walk(f['items']):
                    found = True
                    break
        if not found and liturgy.get('havdalah', {}).get('id') == pid:
            h = liturgy['havdalah']
            h['textHe'], h['textTranslit'], h['textRu'] = he, cap(tr), cap(ru)
            found = True
        print(f'  liturgy:{pid} {"OK" if found else "NOT FOUND"}')

    for sec, sid in zip(sections, SECTION_IDS):
        (kh, th), (kt, tt), (kr, tr_) = sec['header']
        if sid != 'NEHENIN':
            doc = build_service([sec['header']] + sec['items'], sid, single_part=False)
            # single H → everything landed in one untitled part; give it the title
            if doc['parts'] and not doc['parts'][0]['he']:
                doc['parts'][0]['he'], doc['parts'][0]['ru'] = th, cap(tr_)
            doc['titleHe'], doc['titleRu'] = th, cap(tr_)
            save(doc, sid)
            # netilat lives inside birkat_hashachar — extract it into liturgy too
            if sid == 'birkat_hashachar':
                items = sec['items']
                for i, ((k, h), (_, t2), (_, r2)) in enumerate(items):
                    if k == 'h' and 'נְטִילַת' in h:
                        for j in range(i + 1, len(items)):
                            if items[j][0][0] == 'b':
                                patch('netilat', items[j][0][1], items[j][1][1], items[j][2][1])
                                break
                        break
        else:
            # пары «подзаголовок h → первый следующий текст b» в фиксированном порядке
            items = sec['items']
            found = []
            for i, ((k, h), _, _) in enumerate(items):
                if k == 'h':
                    for j in range(i + 1, len(items)):
                        if items[j][0][0] == 'b':
                            found.append((items[j][0][1], items[j][1][1], items[j][2][1]))
                            break
                        if items[j][0][0] == 'h':
                            break
            print(f'  Неѓенин: найдено {len(found)} благословений (ожидалось {len(NEHENIN_ORDER)})')
            for (he, tr2, ru2), pid in zip(found, NEHENIN_ORDER):
                patch(pid, he, tr2, ru2)

    json.dump(liturgy, open(liturgy_path, 'w'), ensure_ascii=False, indent=2)
    print('  liturgy.json обновлён')


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('--service', help='id службы (mincha / shacharit / maariv …)')
    ap.add_argument('--sections', action='store_true', help='файл-сборник: H-разделы → отдельные тексты')
    ap.add_argument('docx')
    a = ap.parse_args()
    if a.service:
        cmd_service(a.docx, a.service)
    elif a.sections:
        cmd_sections(a.docx)
    else:
        ap.error('нужен --service ID или --sections')
