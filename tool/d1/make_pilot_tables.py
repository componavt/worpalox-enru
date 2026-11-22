#!/usr/bin/env python3
"""Builds pilot scene, trap and alignment-audit CSVs for the D1 package.
Editorial verdicts by the agent (2026-11-22); link data from assets/corpus.
"""

import csv
import re
from pathlib import Path

OUT = Path(__file__).resolve().parent
ROOT = OUT.parent.parent
CORPUS = ROOT / "assets" / "corpus"

src = (CORPUS / "enru.src").read_text(encoding="utf-8").splitlines()
tgt = (CORPUS / "enru.tgt").read_text(encoding="utf-8").splitlines()
talp = (CORPUS / "enru.talp").read_text(encoding="utf-8").splitlines()
LINK = re.compile(r"^(\d+)([p-])(\d+)$")


def line_links(n):
    en = src[n - 1].split()
    ru = tgt[n - 1].split()
    out = []
    for tok in talp[n - 1].split():
        m = LINK.match(tok)
        if m:
            a, s, b = m.groups()
            out.append((int(a), en[int(a) - 1], int(b), ru[int(b) - 1], s == "-"))
    return out


# ------------------------------------------------------------- scenes
scene_lines = [
    # line_id, role, source_guess, source_conf, translation_ok,
    # prev_story_line, link, link_codes, quote_prev, quote_this,
    # start_reason, confidence, note
    (199, "HEADING", "The Martian Chronicles", "high", "ok", "", "START",
     "", "", "", "HEADING", "high", "January 1999: ROCKET SUMMER"),
    (203, "BODY", "The Martian Chronicles", "high", "ok", "", "START",
     "", "", "The heat pulsed", "SCENE_START", "high", ""),
    (204, "BODY", "The Martian Chronicles", "high", "ok", 203, "STRONG",
     "TIME|SETTING", "The heat pulsed", "The icicles dropped", "", "high", ""),
    (205, "BODY", "The Martian Chronicles", "high", "ok", 204, "STRONG",
     "CAUSE|TIME", "dropped", "flew open", "", "high", ""),
    (148, "BODY", "Dorothy and the Wizard in Oz", "high", "ok", "", "START",
     "", "", "", "SCENE_START", "high", "chapter opening"),
    (149, "BODY", "Dorothy and the Wizard in Oz", "high", "ok", 148, "STRONG",
     "ENT|TIME", "Frisco", "Hugson", "", "high", "same train"),
    (150, "BODY", "Dorothy and the Wizard in Oz", "high", "ok", 149, "STRONG",
     "ENT|TIME", "train", "conductor", "", "high", ""),
    (151, "DIALOGUE", "Dorothy and the Wizard in Oz", "high", "ok", 150, "STRONG",
     "DIAL", "called out", "Hugson ' s Siding", "", "high", "conductor call"),
    (346, "BODY", "The Murder of Roger Ackroyd", "high", "loose", "", "START",
     "", "", "", "SCENE_START", "high", "chapter opening"),
    (348, "BODY", "The Murder of Roger Ackroyd", "high", "ok", 346, "STRONG",
     "TIME", "next few weeks", "16th 17th September", "", "high", "dates"),
    (349, "BODY", "The Murder of Roger Ackroyd", "high", "ok", 348, "STRONG",
     "TIME", "September", "Friday the 17th", "", "high", "dates continue"),
    (350, "BODY", "The Murder of Roger Ackroyd", "high", "loose", 349, "STRONG",
     "CAUSE|TIME", "sent for", "nothing to be done", "", "high", ""),
    (351, "BODY", "The Murder of Roger Ackroyd", "high", "ok", 350, "STRONG",
     "CAUSE|TIME", "done", "dead some hours", "", "high", ""),
    (386, "BODY", "", "low", "ok", "", "START", "", "", "", "SCENE_START",
     "high", "park scene opener"),
    (387, "BODY", "", "low", "ok", 386, "STRONG", "COREF|ENT", "LOOKED UP",
     "I noticed", "", "high", "same narrator"),
    (393, "BODY", "", "low", "ok", 392, "STRONG", "COREF", "these long haired girls",
     "Like royalty in exile", "", "high", "metaphor about the girls"),
]
with (OUT / "scene_lines.csv").open("w", encoding="utf-8", newline="") as f:
    w = csv.writer(f)
    w.writerow(["line_id", "role", "source_guess", "source_conf",
                "translation_ok", "prev_story_line", "link", "link_codes",
                "quote_prev", "quote_this", "start_reason", "confidence",
                "note"])
    w.writerows(scene_lines)

scenes = [
    ("S0001", "The Martian Chronicles", 203, 205, 3, 2,
     "Ракетное лето", "Зимой в городке вдруг наступает волна тепла; двери распахиваются",
     "", 1, 1, "STORY_MODE", "B", "approved"),
    ("S0002", "Dorothy and the Wizard in Oz", 148, 153, 6, 2,
     "Поезд из Фриско", "Ночной поезд сильно опаздывает; пассажирка выходит у тупика",
     "conductor, little girl", 1, 0, "STORY_MODE", "B", "needs_source_check"),
    ("S0003", "The Murder of Roger Ackroyd", 346, 354, 8, 2,
     "Смерть миссис Феррарс", "Доктор Шеппард узнаёт о смерти миссис Феррарс",
     "Dr Sheppard, Mrs Ferrars", 1, 1, "STORY_MODE", "A", "approved"),
    ("S0004", "", 386, 395, 10, 3,
     "Девочки в парке", "Рассказчик замечает трёх необычных девочек на пикнике",
     "narrator, three girls", 1, 0, "STORY_MODE", "B", "approved"),
    ("S0005", "appliance manual", 8, 10, 3, 0,
     "(rejected)", "Упаковка и утилизация — rejected candidate",
     "", 0, 0, "", "C", "rejected"),
]
with (OUT / "scenes.csv").open("w", encoding="utf-8", newline="") as f:
    w = csv.writer(f)
    w.writerow(["scene_id", "source_guess", "line_first", "line_last",
                "n_lines", "n_play", "title_ru", "summary_ru", "characters",
                "self_contained", "orderable", "best_use", "grade",
                "review_status"])
    w.writerows(scenes)

members = [
    ("S0001", 1, 203, "SETUP", "CONTEXT", 0),
    ("S0001", 2, 204, "DEVELOP", "PLAY", 1),
    ("S0001", 3, 205, "PAYOFF", "PLAY", 1),
    ("S0002", 1, 148, "SETUP", "PLAY", 0),
    ("S0002", 2, 149, "DEVELOP", "CONTEXT", 1),
    ("S0002", 3, 150, "DEVELOP", "CONTEXT", 1),
    ("S0002", 4, 151, "PAYOFF", "PLAY", 1),
    ("S0002", 5, 152, "DEVELOP", "CONTEXT", 1),
    ("S0002", 6, 153, "DEVELOP", "CONTEXT", 1),
    ("S0003", 1, 346, "SETUP", "CONTEXT", 0),
    ("S0003", 2, 348, "DEVELOP", "CONTEXT", 1),
    ("S0003", 3, 349, "DEVELOP", "CONTEXT", 1),
    ("S0003", 4, 350, "DEVELOP", "PLAY", 1),
    ("S0003", 5, 351, "PAYOFF", "PLAY", 1),
    ("S0003", 6, 352, "DEVELOP", "CONTEXT", 1),
    ("S0003", 7, 353, "DEVELOP", "CONTEXT", 1),
    ("S0003", 8, 354, "DEVELOP", "SKIP", 1),
    ("S0004", 1, 386, "SETUP", "CONTEXT", 0),
    ("S0004", 2, 387, "DEVELOP", "PLAY", 1),
    ("S0004", 3, 388, "DEVELOP", "SKIP", 1),
    ("S0004", 4, 389, "DEVELOP", "CONTEXT", 1),
    ("S0004", 5, 390, "DEVELOP", "CONTEXT", 1),
    ("S0004", 6, 391, "DEVELOP", "CONTEXT", 1),
    ("S0004", 7, 392, "DEVELOP", "CONTEXT", 1),
    ("S0004", 8, 393, "PAYOFF", "PLAY", 1),
    ("S0004", 9, 394, "DEVELOP", "CONTEXT", 1),
    ("S0004", 10, 395, "DEVELOP", "CONTEXT", 1),
]
with (OUT / "scene_members.csv").open("w", encoding="utf-8", newline="") as f:
    w = csv.writer(f)
    w.writerow(["scene_id", "story_pos", "line_id", "role_in_scene", "use",
                "needs_prev"])
    w.writerows(members)

# ------------------------------------------------------------- traps
trap_rules = [
    ("PREFIX_VS_PARTICLE", "Приставка и частица",
     "приставка стоит перед корнем", "частица стоит после глагола", "yes",
     "A2", "phrasal_verb", "205"),
    ("SVO_RIGID", "Твёрдый порядок слов",
     "порядок слов относительно свободен", "SVO порядок обязателен", "yes",
     "A1", "word_order", ""),
    ("ADV_PLACEMENT", "Место наречия",
     "наречие часто идёт до или после свободно",
     "частотное наречие стоит после вспомогательного глагола", "yes",
     "A2", "adverbs", "357,848,816"),
    ("QUESTION_ORDER", "Порядок в вопросе",
     "порядок как в утверждении", "инверсия со вспомогательным глаголом",
     "yes", "A1", "questions", "483,842"),
    ("GEN_VS_POSS", "Родительный падеж",
     "принадлежность через родительный падеж после главного слова",
     "притяжательная форма или of перед главным словом", "yes",
     "A2", "possessives", "844"),
    ("AUX_PERFECT", "Вспомогательный в перфекте",
     "перфект без вспомогательного: причастие/наречие раньше",
     "have/has/had стоит перед причастием", "yes",
     "A2", "perfect", "351,754,628"),
    ("NEG_PLACEMENT", "Место отрицания", "не перед глаголом",
     "not после вспомогательного", "yes", "A1", "negation", ""),
    ("LOC_FIRST_EXISTENTIAL", "Обстоятельство в начале",
     "В комнате стоит стол", "There is a table in the room", "yes",
     "A2", "existentials", ""),
    ("ADJ_ORDER", "Порядок прилагательных", "порядок прилагательных свободен",
     "opinion-size-age-colour", "yes", "B1", "adjectives", ""),
    ("ARTICLE", "Артикль", "артиклей нет", "нужен артикль", "no", "A1",
     "articles", ""),
    ("AUX_DO", "Вспомогательный do", "вспомогательный глагол не нужен",
     "do/does/did обязателен", "no", "A1", "questions", ""),
]
with (OUT / "trap_rules.csv").open("w", encoding="utf-8", newline="") as f:
    w = csv.writer(f)
    w.writerow(["rule_code", "name_ru", "ru_pattern_ru", "en_pattern_ru",
                "order_playable", "cefr", "skill_code", "exemplar_line_ids"])
    w.writerows(trap_rules)

traps = [
    ("T0001", 205, "ORDER", "PREFIX_VS_PARTICLE", "TRAP", "4<3", "",
     "4|3", "BOTH", 2, 2,
     "Русская приставка стоит перед корнем, английская частица — после глагола: flew open.",
     "The doors open flew .", "high", "approved"),
    ("T0002", 350, "ORDER", "SVO_RIGID", "TRAP", "3<2", "", "3|2", "LLM", 2,
     2, "В русском «ничего было нельзя» подлежащее-слово идёт раньше; в английском was идёт раньше nothing.",
     "There nothing was to be done .", "medium", "draft"),
    ("T0003", 351, "ORDER", "AUX_PERFECT", "TRAP", "4<3", "", "4|3", "BOTH",
     2, 2, "В русском «была мертва» причастие раньше; в английском had стоит перед been/dead.",
     "She dead been some hours .", "high", "approved"),
    ("T0004", 357, "ORDER", "ADV_PLACEMENT", "TRAP", "4<3", "", "4|3", "BOTH",
     2, 2, "«Уже расположились» — already тянется в начало; в английском already идёт после were.",
     "Most people already were seated .", "high", "approved"),
    ("T0005", 359, "ORDER", "ADV_PLACEMENT", "TRAP", "6<5", "", "6|5", "LLM",
     2, 2, "«Слегка искривились» — слегка хочется поставить раньше глагола.",
     "Jane ' s lips slightly twisted .", "medium", "draft"),
    ("T0006", 483, "ORDER", "QUESTION_ORDER", "TRAP", "3<2", "", "3|2", "LLM",
     3, 2, "Русский вопрос без инверсии: How you knew — пропущен и смещён did.",
     "How you did know what I was doing ?", "high", "approved"),
    ("T0007", 628, "ORDER", "AUX_PERFECT", "TRAP", "3<2", "", "3|2", "LLM",
     2, 2, "«Там не бывал» — there раньше been; в английском been идёт раньше there.",
     "Never there been myself .", "medium", "draft"),
    ("T0008", 842, "ORDER", "QUESTION_ORDER", "TRAP", "3<2", "", "3|2", "LLM",
     2, 2, "Когда он придет — When he coming, вспомогательный 's теряет позицию.",
     "When he 's coming ?", "high", "approved"),
    ("T0009", 844, "ORDER", "GEN_VS_POSS", "TRAP", "9<7", "", "9|7", "LLM",
     2, 2, "«Призрак Ленина» — главное слово раньше; в английском Lenin 's стоит раньше ghost.",
     "That question haunts Red Square like ghost Lenin 's .", "medium", "draft"),
    ("T0010", 848, "ORDER", "ADV_PLACEMENT", "TRAP", "4<3", "", "4|3", "LLM",
     2, 2, "«Без малого семьдесят» — nearly хочется раньше was.",
     "Mr. Wilkes nearly was seventy .", "medium", "draft"),
    ("T0011", 816, "ORDER", "ADV_PLACEMENT", "TRAP", "4<3", "", "4|3", "LLM",
     2, 2, "«Они там до сих пор» — there раньше still.",
     "They are there still in warehouses in Liverpool .", "medium", "draft"),
    ("T0012", 754, "ORDER", "AUX_PERFECT", "TRAP", "5<4", "", "5|4", "LLM",
     2, 2, "«Долгие годы любил» — loved раньше have.",
     "For years I loved have her .", "high", "approved"),
    ("T0013", 837, "ORDER", "SVO_RIGID", "TRAP", "2<1", "", "2|1", "LLM", 1,
     2, "«Пока тебя не сменят — сиди» — until раньше stay.",
     "Until you are relieved stay .", "low", "draft"),
    ("T0014", 263, "ORDER", "SVO_RIGID", "TRAP", "5<3", "", "5|3", "LLM", 2,
     2, "«Вернуться она не могла» — turn раньше she.",
     "Unfortunately turn she , couldn ' t back .", "medium", "draft"),
    ("T0015", 360, "ORDER", "SVO_RIGID", "TRAP", "8<2", "", "8|2", "LLM", 1,
     2, "«Хорошо знакомы» — so well раньше knew.",
     "She so well knew that particular type of voice .", "low", "draft"),
    ("A0001", 387, "ORDER", "ADV_PLACEMENT", "ACCEPTABLE", "", "5<1 5<2",
     "", "LLM", 0, 1, "«Сначала я заметила» — First, I noticed... звучит естественно.",
     "First I noticed their hair , long and uncombed .", "high", "approved"),
    ("A0002", 222, "ORDER", "SVO_RIGID", "ACCEPTABLE", "", "4<1 5<2 4<3 5<3",
     "the answer was a nod", "", "LLM", 0, 1,
     "«Ответом был кивок» — The answer was a nod — законная альтернатива.",
     "The answer was a nod .", "high", "approved"),
]
with (OUT / "pilot_traps.csv").open("w", encoding="utf-8", newline="") as f:
    w = csv.writer(f)
    w.writerow(["trap_id", "line_id", "kind", "rule_code", "verdict",
                "pairs", "full_order", "trigger_tokens", "source",
                "likelihood", "severity", "explanation_ru", "wrong_example_en",
                "confidence", "review_status"])
    w.writerows(traps)

# 38 PLAY lines reviewed for traps (line_id, verdict_summary, confidence)
reviewed = [
    (115, "no convincing trap; word order matches Russian", "high"),
    (148, "no convincing trap; calque order equals correct", "high"),
    (151, "quoted station name; no order trap", "high"),
    (162, "dialogue inversion said he matches Russian pattern", "medium"),
    (163, "elliptical question; no order trap", "medium"),
    (164, "loose translation; order not teachable", "medium"),
    (204, "shattering to melt: no realistic inversion", "medium"),
    (205, "trap recorded: PREFIX_VS_PARTICLE", "high"),
    (222, "acceptable alternative recorded", "high"),
    (231, "exclamation fragment; article use, not order", "medium"),
    (239, "there-is construction matches Russian closely", "high"),
    (240, "highly unstable: adverb order matches", "high"),
    (263, "trap recorded: SVO_RIGID", "medium"),
    (329, "name frame matches Russian word order", "medium"),
    (350, "trap recorded: SVO_RIGID", "medium"),
    (351, "trap recorded: AUX_PERFECT", "high"),
    (357, "trap recorded: ADV_PLACEMENT", "high"),
    (359, "trap recorded: ADV_PLACEMENT", "medium"),
    (360, "trap recorded (weak): SVO_RIGID", "low"),
    (363, "proper noun; no order trap", "medium"),
    (387, "acceptable alternative recorded", "high"),
    (393, "in exile matches в изгнании", "high"),
    (483, "trap recorded: QUESTION_ORDER", "high"),
    (605, "quoted fragment; order matches", "medium"),
    (623, "once again she was looking: order matches", "medium"),
    (628, "trap recorded: AUX_PERFECT", "medium"),
    (630, "article trap candidate, not order", "medium"),
    (634, "no order trap; article the", "high"),
    (635, "particle up: correct order matches Russian", "medium"),
    (715, "what I know clause matches", "medium"),
    (716, "head no tail matches Russian", "high"),
    (754, "trap recorded: AUX_PERFECT", "high"),
    (785, "fragment; order matches", "medium"),
    (788, "want to watch: order matches", "high"),
    (789, "article a missing in Russian, not order", "high"),
    (790, "was n't placement matches", "high"),
    (814, "church collapses compound noun; no order trap", "medium"),
    (816, "trap recorded: ADV_PLACEMENT", "medium"),
    (817, "what you did was illegal: order matches", "medium"),
    (826, "copula is dropped in Russian, not order", "high"),
    (829, "find out particle; weak candidate rejected", "low"),
    (829, "duplicate row removed", "low"),
    (832, "moment frame; weak candidate rejected", "high"),
    (834, "I knew it: order matches", "high"),
    (837, "weak trap recorded: SVO_RIGID", "medium"),
    (842, "trap recorded: QUESTION_ORDER", "high"),
    (844, "trap recorded: GEN_VS_POSS", "medium"),
    (847, "negation form, not order", "high"),
    (848, "trap recorded: ADV_PLACEMENT", "medium"),
    (852, "be prepared: no order trap", "high"),
    (861, "began checking matches начал изучать", "high"),
]
seen = set()
review_rows = []
for line_id, verdict, conf in reviewed:
    if line_id in seen and "duplicate" in verdict:
        continue
    seen.add(line_id)
    review_rows.append((line_id, verdict, conf))
with (OUT / "pilot_trap_review.csv").open("w", encoding="utf-8", newline="") as f:
    w = csv.writer(f)
    w.writerow(["line_id", "verdict_summary", "confidence"])
    w.writerows(review_rows)
print(f"trap review rows: {len(review_rows)}; traps: {len(traps)}")

# ------------------------------------------------- alignment audit (10 levels)
audit_levels = [(101, 205), (102, 115), (103, 222), (104, 350), (105, 351),
                (106, 357), (107, 832), (108, 239), (120, 359), (122, 861)]
verdicts = {
    (101, 205): [("2-1", "confirmed", ""), ("3-2", "confirmed", "part of idiom flew open"),
                 ("4-2", "confirmed", "part of idiom flew open"),
                 ("5-3", "confirmed", "punctuation, excluded from game")],
    (102, 115): [("1-1", "confirmed", ""), ("3-2", "confirmed", ""),
                 ("5-3", "confirmed", ""), ("6-4", "confirmed", "punctuation")],
    (103, 222): [("5-2", "rejected", "nod corresponds to кивнул, not ответ; Russian line is a paraphrase"),
                 ("6-6", "confirmed", "punctuation"),
                 ("2p5", "confirmed", "probable link is the correct one")],
    (104, 350): [("6-9", "confirmed", "EN side only"),
                 ("3-10", "confirmed", "EN side only"),
                 ("2-11", "confirmed", "EN side only"),
                 ("7p13", "rejected", "dash is non-terminal punctuation"),
                 ("4p9", "uncertain", "to be vs сделать"),
                 ("5p9", "uncertain", "to be vs сделать"),
                 ("*", "uncertain", "RU indices refer to corpus tgt line; curated level RU text is shorter, remap needed")],
    (105, 351): [("1-1", "confirmed", ""), ("3-2", "confirmed", "had been merged"),
                 ("4-3", "confirmed", ""), ("5-5", "confirmed", ""),
                 ("6-6", "confirmed", ""), ("7-7", "confirmed", "punctuation"),
                 ("2p2", "confirmed", "had merges into была")],
    (106, 357): [("4-2", "confirmed", ""), ("6-6", "confirmed", "punctuation"),
                 ("5p3", "confirmed", "seated vs расположились"),
                 ("5p5", "rejected", "seated is not креслах"),
                 ("5p4", "rejected", "seated is not в"),
                 ("2p1", "confirmed", "people vs многие, partial"),
                 ("1p1", "confirmed", "most vs многие, partial"),
                 ("3p3", "rejected", ""), ("3p4", "rejected", ""),
                 ("3p5", "rejected", "")],
    (107, 832): [("1-1", "confirmed", ""), ("5-2", "confirmed", ""),
                 ("6-4", "confirmed", "punctuation"),
                 ("3p2", "rejected", "for is not мгновение"),
                 ("2p3", "confirmed", ""), ("4p2", "rejected", "a is not мгновение")],
    (108, 239): [("1-1", "confirmed", ""), ("3-3", "confirmed", "punctuation"),
                 ("4-4", "confirmed", ""), ("5-5", "confirmed", "punctuation"),
                 ("6-6", "confirmed", ""), ("8-8", "confirmed", "punctuation"),
                 ("2p2", "confirmed", ""), ("7p7", "confirmed", "")],
    (120, 359): [("4-1", "confirmed", "possessive phrase lips"),
                 ("1-2", "confirmed", "Jane"), ("6-3", "confirmed", "slightly"),
                 ("5-4", "confirmed", "twisted"), ("7-5", "confirmed", "punctuation"),
                 ("3p2", "confirmed", "clitic s"), ("2p2", "confirmed", "clitic '")],
    (122, 861): [("3-2", "confirmed", ""), ("6-4", "confirmed", ""),
                 ("7-5", "confirmed", "punctuation"),
                 ("2p1", "confirmed", "guard vs гвардеец"),
                 ("4p3", "confirmed", "checking vs изучать, slight semantic gap")],
}
rows = []
for level_id, line in audit_levels:
    for i, en_w, j, ru_w, ok in line_links(line):
        key = f"{i}{'-' if ok else 'p'}{j}"
        kind = "reliable" if ok else "probable"
        verdict, note = "", ""
        for k, v, nt in verdicts[(level_id, line)]:
            if k == key or (level_id, line, k) == (104, 350, "*"):
                verdict, note = v, nt
                break
        rows.append((level_id, line, i, en_w, j, ru_w, kind, verdict, note))
with (OUT / "alignment_audit.csv").open("w", encoding="utf-8", newline="") as f:
    w = csv.writer(f)
    w.writerow(["level_id", "corpus_line", "en_index", "en_token",
                "ru_index", "ru_token", "talp_kind", "verdict", "note"])
    w.writerows(rows)
print(f"alignment_audit rows: {len(rows)}")
