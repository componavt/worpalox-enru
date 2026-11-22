# D1/D2 — согласованный блок строк 196–232 для внешней проверки (2026-11-22)

Один корпусный блок — все файлы анализа, отфильтрованные на ОДНИ И ТЕ ЖЕ
строки (196–232), чтобы проверяющий мог сверить согласованность между
pass2_triage, аудит-снимком, пилотом, сценами, ловушками и картой уровней.

Блок выбран как самый насыщенный: сцена S0001 «Ракетное лето» (уровень
101 = строка 205, ловушка T0001), строки Брэдбери (200–202), открытие
«Джейн Эйр» (211–217), творчество Типа (218), «Грозовой перевал»
(219–232), решения всех четырёх типов (puzzle/context/check/reject).

Полные файлы (все 881 строк) лежат в tool/d1/ — здесь их фрагменты.
Отчёты 008 и 009 описывают весь корпус; их числа проверяются по
audit_summary.json (pass 1).

---

## 008-locking-apk4.md

```markdown
# 008 locking apk4
Статус: open · Начат: 2026-11-22
Итерация по ревью GPT к 007 (замечания владельца: мерцание drag,
зелёные неподвижные фишки, запятые в карточке, бедная сцена, брак
звуков). Предназначен для передачи GPT. Пара к 007.

## Итог
Реализованы все пункты ревью: гистерезис drag (8 логических пикселей) +
зарезервированные слоты маркеров (чипы больше не меняют размер при
наведении — источник мерцания); зелёная фиксация вариант-1 «вставка в
свободную последовательность» на уровне модели PuzzleState; запятые
приклеиваются в карточке результата (display only); Sound Lab итерация
(Drop 003 — контрольный, 5 новых кандидатов, resolvePlacementSoundId);
импортёр — provenance talp_import + манифест + очистка уровней,
удалённых из APPROVED. Analyze 0, тесты 64/64, регресс-тесты импортёра
11/11. APK 4 (55,0 МБ) установлен 2026-11-22 23:27, приложение запущено.

---
## 2026-11-22 — 1. Мерцание drag: две причины, обе устранены

- **Резерв маркеров.** Маркеры вставки рисовались условно → чип менял
  ширину при наведении → Wrap пересчитывался во время жеста → цели
  двигались под пальцем. Теперь оба маркерных слота присутствуют всегда
  (прозрачные в покое) — ширина чипа постоянна до, во время и после
  наведения (WordToken).
- **Гистерезис 8 логических пикселей.** Каждая цель фишки получила
  GlobalKey; onWillAccept соседа возвращает false, пока указатель внутри
  предыдущих границ, раздутых на 8 px. Коммит всегда идёт той цели,
  которую показывает маркер (Flutter держит предыдущую активной, пока
  сосед отклонён). За пределами полосы — переключение мгновенное;
  переход на другую строку — сразу (проверка пересечения строк).
- Уровень детализации по GPT: диагностика координат не понадобилась —
  обе механики устранены в коде; регрессия покрыта существующими
  кросс-строчными тестами концевой зоны.

---
## 2026-11-22 — 2. Зелёная фиксация (вариант 1 GPT — «вставка в свободную последовательность»)

- PuzzleState: lockingEnabled, _lockedSlots, newlyLockedSlot; moveToken в
  locking-режиме переупорядочивает только свободные слоты (подвижный ряд
  «перепрыгивает» через зелёные), затем фиксирует целевой слот, если
  текст совпал с ответом (text-based, дубликаты честны).
- Фиксируется ТОЛЬКО фишка, которую игрок поставил сам; соседи, случайно
  вставшие правильно, и удачно перемешанные — не фиксируются (по GPT).
- Фишки в locked-слотах: зелёные (WordTokenState.locked, тот же стиль,
  что на финише), без drag-источника, без цели, тап игнорируется. Дроп
  на зелёную фишку — отмена без хода (молча перенаправлять запрещено).
- Концевая зона вставляет в **последний свободный слот** (PuzzleState
  .lastFreeSlot), а не в последний слот предложения; зелёная фишка в
  конце не может быть сдвинута этим ходом.
- Shuffle: перемешивает через существующий механизм; locked-слоты
  сохраняются.
- Очки: placement-награды считаются как раньше; efficiencyBonus (Perfect)
  в locking-режиме обнулён через ScoringService(lockingMode) — n−LCS
  больше не «лучший возможный» при фиксациях (замечание GPT).
- Результат: MoveResult-объект пока не вводился — PuzzleState
  .newlyLockedSlot покрывает потребности обоих экранов; полноценный
  MoveResult отложен до появления альтернативных порядков.

---
## 2026-11-22 — 3. Запятые в карточке результата (display only)

formatResultSentence расширен: пробел перед запятыми склеивается вместе с
терминальным знаком. Тесты: «Oh , yes ...» → «Oh, yes...»; «Сиди там ,
пока тебя не сменят .» → «Сиди там, пока тебя не сменят.»; уже
склеенные строки не меняются; внутренние токены данных и индексы линзы
не трогаются; русский Wrap подсказки (линза) не проходит через
форматирование.

---
## 2026-11-22 — 4. Sound Lab итерация (Drop 003 + новые кандидаты)

- Каталог: Drop 003 (контрольный, владелец не забраковал) + Soft Tap
  (impactGeneric_light_000), Wood Tap (impactWood_medium_003), Glass Tick
  (impactGlass_light_000) из Kenney Impact Sounds (CC0, скачано
  браузером в assets/sounds/) + Soft Pop и Two-note Soft (сгенерированы
  локально, ~110 мс, мягкое затухание). Семь забракованных звуков
  удалены из assets/audio/lab и каталога.
- resolvePlacementSoundId: сохранённый ID, отсутствующий в каталоге,
  откатывается на Off (правка loadPreference). Off по умолчанию.
- Gate: busy сбрасывается onPlayerComplete/stop/ошибкой (не только
  таймером) — новый игровой звук не прерывает играющий; в лаборатории
  preview останавливает предыдущий образец.
- Звуки слушает и утверждает владелец (поправка учтена); агент отвечает
  только за файлы, меню и происхождение.

---
## 2026-11-22 — 5. Импортёр: provenance, манифест, очистка (вопрос GPT п.6)

- Каждая экспортированная связь помечена source: talp_import (будущее
  ручное выравнивание уровня 104 будет отличимо от генерированного).
- managed_levels.json: манифест уровней, управляемых последним
  запуском. Уровни из манифеста, удалённые из APPROVED, очищаются при
  следующем импорте (регресс-тест: удалённый из APPROVED уровень
  теряет alignment; ручные alignment'ы не трогаются).
- Импорт-тесты: 11/11 PASS (обновлены под strict/relaxed и манифест).

## Числа

- analyze 0; тесты 64/64 (63 + locking-обновления); импорт-тесты 11/11.
- APK 4: 55,0 МБ, собран и установлен 2026-11-22 23:27
  (устройство 0C141FDD4001A9, авторизовано).
- Сборка потребовала compileSdk 36 (цепочка audioplayers → androidx.window
  → jni → shared_preferences_android) + override для плагинов — детали в
  007, правки в android/app/build.gradle.kts и android/build.gradle.kts.
- Известный флак: services_test (delete-profile) ~1 из 3 запусков файла —
  существовал до этой вехи, вынесен отдельным заданием.

## Дальше

- Живая проверка владельцем: мерцание на границе, зелёная фиксация
  (перепрыгивание через зелёные), запятые в карточке, Sound Lab
  (выбор звука → ход → сброс → другой звук).
- Чистая сборка из checkout 96bfcfa (воспроизводимость pushed main) —
  по запросу GPT, отдельным шагом.
- Проход 1 по всем 881 строкам (аудит-снимок) и редакторский отбор —
  по схеме трёх проходов GPT; глубокая разметка и автоэкспорт — после
  живой проверки двух механик (линза/сцена).
```

---

## 009-triage-881.md

```markdown
# 009 triage 881
Статус: open · Начат: 2026-11-22
Проходы 1–2 схемы GPT по всем 881 строкам корпуса: машинный аудит-снимок
(pass 1) и редакторский триаж (pass 2). Глубокая разметка сильных
кандидатов (pass 3) и экспорт — после проверки GPT. Пара к 008.

## Итог

- **Pass 1 (аудит, все 881):** 863 ok, 13 дубликатов, 3 без связей,
  2 за границей индексов; контрольные суммы enru.src/.tgt/.talp и
  levels.json зафиксированы в audit_summary.json; флаги границ источников:
  31 CAPS, 158 без терминального знака, 2 с малой буквы, 41 с непарной
  кавычкой. Инструмент: tool/talp_audit.py (расширен).
- **Pass 2 (редакторский триаж, все 881):** puzzle_candidate **101**,
  context_candidate **492**, needs_source_check **50**, reject **238**.
  Файл: tool/d1/pass2_triage.csv (line_id, source, decision, reason).
  300 строк — решения из пилота (pilot_lines.csv), 581 — свежее чтение
  агента (triage_pack.txt, 169 КБ).
- Оценка масштаба: пул пазлов ≈ 101 строка (13% — совпадает с долей
  пилота 13%); контекстный слой ≈ 492 строки — достаточен для 10–20 сцен.
- APK 4 (55,0 МБ) установлен 23:27, приложение запущено — телефон готов
  к проверке фиксации/линзы/звука параллельно с триажем.

## Pass 1 — что вошло в снимок

- Контрольные суммы: enru.src ed8b3633…, enru.tgt, enru.talp, levels.json
  (полные SHA-256 в audit_summary.json) — фиксация ревизии корпуса.
- Стабильный ключ строки: номер строки 1–881 (как в D1).
- Диапазоны индексов talp против токенов: 2 выхода за границу (602, 612)
  — остаются заблокированными для импорта.
- Строки без связей: 3 (137, 234, 257).
- Дубликаты: 13 пар точных повторов EN.
- Признаки границ источников: 31 строка CAPS, 158 без терминального
  знака, 2 с малой буквы, 41 с непарной кавычкой — вход в причины
  reject/needs_source_check на pass 2.
- Вердикт проверки есть у каждой строки (ok / duplicate / no_links /
  out_of_bounds) — audit_lines.csv, колонка verdict.

## Pass 2 — результаты триажа

- Источники решений: 300 строк из пилота (pilot: PLAY→puzzle_candidate,
  CONTEXT→context_candidate, SKIP→reject, mismatch→needs_source_check) +
  581 строка свежего чтения (pass2_hand). Пересечений нет: 300 + 581 = 881.
- **puzzle_candidate 101** — белый список для будущих уровней: короткие
  фразы с чистым переводом и 3–9 подвижными токенами. Внутри — все
  игровые уровни-источники (101–131) и ~70 новых кандидатов.
- **context_candidate 492** — контекстный слой для сцен (в т.ч. окна
  Оз/Баум 121–153, Кристи 346–354, Джордан 386–395, Дойл 407–466,
  Брэдбери 175–204).
- **needs_source_check 50** — несоответствия переводов, битые апострофы
  (backticks), RU-плейсхолдеры, инлайн-сноски, typo (Сначалo, caughts,
  suppouse, oppotyunity, усоршенствованное) — в issues-список, в игру не
  попадают до проверки.
- **reject 238** — заголовки, авторы, посвящения, номера страниц,
  инструкции, рецепты, научные абзацы, взрослый контент (295, 298, 756,
  793), оскорбительная историческая лексика (341, 333).

## Ограничения (честно)

- Триаж — редакторское суждение агента по одному чтению; уверенность не
  проставлялась построчно (в отличие от пилота) — спорные строки
  помечены needs_source_check, а не угаданы.
- Пересчёт «доли PLAY на весь корпус» по-прежнему некорректен (выборка
  пристрастна), но теперь пул кандидатов известен ПОИМЁННО — доля больше
  не нужна.
- Pass 3 (глубокая разметка: acceptable_orders, ловушки, эмодзи-словарь)
  — только для строк, которые GPT утвердит по триажу.

## Дальше

- Передать pass2_triage.csv + 008/009 GPT на проверку решений.
- После вердикта: глубокая разметка утверждённых puzzle_candidate
  (батчи по 20–30), сборка новых уровней через импортёр, сцены по
  критериям GPT (начало/новая информация/связь/конец/источник).
- Отдельно: чистая сборка 96bfcfa (воспроизводимость), фикс флака
  services_test, включение locking-режима в ScoringService-тесты.
```

---

## pass2_triage.csv — решения триажа для строк 196–232

```csv

line_id,source,decision,reason
196,pass2_hand,reject,dedication
197,pass2_hand,needs_source_check,RU broken dash mid-line
198,pass2_hand,needs_source_check,RU broken quote
199,pass2_hand,context_candidate,scene S0001 heading
200,pass2_hand,context_candidate,"ok, mov 43"
201,pass2_hand,context_candidate,"loose, sentence continues into 202"
202,pass2_hand,context_candidate,"loose, sentence continues from 201"
203,pass2_pilot,reject,"pilot: BODY, translation ok, medium confidence"
204,pass2_pilot,puzzle_candidate,"pilot: BODY, translation ok, high confidence"
205,pass2_pilot,puzzle_candidate,"pilot: BODY, translation ok, high confidence"
206,pass2_pilot,reject,"pilot: TITLE_AUTHOR, translation ok, high confidence"
207,pass2_pilot,reject,"pilot: TITLE_AUTHOR, translation ok, high confidence"
208,pass2_hand,context_candidate,"ok, mov 13"
209,pass2_hand,needs_source_check,RU merges two sentences
210,pass2_hand,context_candidate,"ok, mov 23"
211,pass2_hand,reject,heading
212,pass2_hand,context_candidate,"famous opening, mov 10"
213,pass2_hand,context_candidate,"ok, mov 64"
214,pass2_hand,context_candidate,"ok, mov 65"
215,pass2_hand,context_candidate,"ok, mov 48"
216,pass2_hand,context_candidate,"ok, mov 94, quote"
217,pass2_hand,context_candidate,"dialogue, mov 11, quote"
218,pass2_pilot,context_candidate,"pilot: DIALOGUE, translation ok, medium confidence"
219,pass2_hand,reject,title
220,pass2_pilot,reject,"pilot: TITLE_AUTHOR, translation ok, high confidence"
221,pass2_pilot,reject,"pilot: DIALOGUE, translation loose, medium confidence"
222,pass2_pilot,puzzle_candidate,"pilot: BODY, translation loose, high confidence"
223,pass2_pilot,reject,"pilot: DIALOGUE, translation ok, medium confidence"
224,pass2_pilot,context_candidate,"pilot: BODY, translation ok, medium confidence"
225,pass2_hand,reject,heading
226,pass2_pilot,reject,"pilot: NOTE, translation ok, high confidence"
227,pass2_pilot,context_candidate,"pilot: BODY, translation ok, medium confidence"
228,pass2_pilot,reject,"pilot: BODY, translation loose, medium confidence"
229,pass2_pilot,context_candidate,"pilot: BODY, translation loose, medium confidence"
230,pass2_pilot,context_candidate,"pilot: BODY, translation ok, medium confidence"
231,pass2_pilot,puzzle_candidate,"pilot: DIALOGUE, translation ok, medium confidence"
232,pass2_pilot,context_candidate,"pilot: BODY, translation ok, medium confidence"

```

---

## audit_lines.csv — аудит-снимок (pass 1) для строк 196–232

```csv

line_id,en,ru,en_tokens,ru_tokens,movable_tokens,links,reliable,probable,en_unpaired,ru_unpaired,m2o_groups,o2m_groups,calque_inversions,inversion_pairs,length_ratio,duplicate_of,flag_all_caps,flag_no_terminal,flag_lowercase_start,flag_unclosed_quote,verdict
196,For my wife MARGUERITE with all my love,МОЕЙ ЖЕНЕ МАРГАРЕТ С ИСКРЕННЕЙ ЛЮБОВЬЮ,8,6,8,8,4,4,0,0,0,2,0,,1.33,,0,1,0,0,ok
197,"“ It is good to renew one ’ s wonder ,” said the philosopher .",""" Великое дело – способность удивляться , – сказал философ . -",15,12,14,12,3,9,6,4,3,2,0,,1.25,,0,0,0,0,ok
198,“ Space travel has again made children of us all .”,"Космические полеты снова сделали всех нас детьми "".",11,8,11,10,6,4,1,0,0,2,2,5<4 10<9,1.38,,0,1,0,0,ok
199,January 1999 : ROCKET SUMMER,Январь 1999 . Ракетное лето,5,5,5,5,4,1,0,0,0,0,0,,1.0,,0,1,0,0,ok
200,"One minute it was Ohio winter , with doors closed , windows locked , the panes blind with frost , icicles fringing every roof , children skiing on slopes , housewives lumbering like great black bears in their furs along the icy streets .","Только что была огайская зима : двери заперты , окна закрыты , стекла незрячие от изморози , все крыши оторочены сосульками , дети мчатся с горок на лыжах , женщины в шубах черными медведицами бредут по гололедным улицам .",44,39,43,41,21,20,7,0,3,2,2,37<35 39<35,1.13,,0,0,0,0,ok
201,And then a long wave of warmth crossed the small town .,"И вдруг могучая волна тепла прокатилась по городку ,",12,9,11,11,4,7,2,0,1,2,0,,1.33,,0,0,0,0,ok
202,A flooding sea of hot air ; it seemed as if someone had left a bakery door open .,"вал горячего воздуха захлестнул его , будто нечаянно оставили открытой дверь пекарни .",19,13,18,17,6,11,2,3,0,3,3,17<16 18<16 18<17,1.46,,0,0,0,0,ok
203,The heat pulsed among the cottages and bushes and children .,"Зной омывал дома , кусты , детей .",11,8,10,9,3,6,2,0,0,1,0,,1.38,,0,0,0,0,ok
204,"The icicles dropped , shattering , to melt .","Сосульки срывались с крыш , разбивались и таяли .",9,9,8,10,5,5,1,0,1,1,0,,1.0,,0,0,0,0,ok
205,The doors flew open .,Двери распахнулись .,5,3,4,4,4,0,1,0,0,1,0,,1.67,,0,0,0,0,ok
206,CHARLOTTE BRONTE,Шарлотта Бронте,2,2,2,2,2,0,0,0,0,0,0,,1.0,,1,1,0,0,ok
207,JANE EYRE,ДЖЕН ЭЙР,2,2,2,2,1,1,0,0,0,0,0,,1.0,,1,1,0,0,ok
208,"Be seated somewhere ; and until you can speak pleasantly , remain silent .","Сядь где - нибудь и , пока не научишься быть вежливой , молчи .",14,14,13,13,8,5,3,2,1,1,0,,1.0,,0,0,0,0,ok
209,"A breakfast - room adjoined the drawing - room , I slipped in there .","Рядом с гостиной находилась небольшая столовая , где обычно завтракали Я тихонько шмыгнула туда .",15,15,14,26,6,20,3,2,4,7,0,,1.0,,0,0,0,0,ok
210,"It contained a bookcase : I soon possessed myself of a volume , taking care that it should be one stored with pictures .","Там стоял книжный шкаф ; я выбрала себе книжку , предварительно убедившись , что в ней много картинок .",24,19,23,20,7,13,8,4,4,3,0,,1.26,,0,0,0,0,ok
211,CHAPTER I,Глава I,2,2,2,2,2,0,0,0,0,0,0,,1.0,,1,1,0,0,ok
212,There was no possibility of taking a walk that day .,В этот день нечего было и думать о прогулке .,11,10,10,27,4,23,1,0,5,6,0,,1.1,,0,0,0,0,ok
213,"We had been wandering , indeed , in the leafless shrubbery an hour in the morning ; but since dinner ( Mrs . Reed , when there was no company , dined early ) the cold winter wind had brought with it clouds so sombre , and a rain so penetrating , that further out - door exercise was now out of the question .","Правда , утром мы еще побродили часок по дорожкам облетевшего сада , но после обеда ( когда не было гостей , миссис Рид кушала рано ) холодный зимний ветер нагнал угрюмые тучи и полил такой пронизывающий дождь , что и речи не могло быть ни о какой попытке выйти еще раз .",65,52,64,81,60,21,9,7,7,10,30,7<1 14<1 15<1 16<1 7<2 14<2 15<2 16<2 7<3 14<3 15<3 16<3 7<4 14<4 15<4 16<4 14<13 15<13 16<13 26<22 28<22 29<22 31<22 26<24 28<24 29<24 31<24 29<28 50<49 51<49,1.25,,0,0,0,0,ok
214,"I was glad of it : I never liked long walks , especially on chilly afternoons : dreadful to me was the coming home in the raw twilight , with nipped fingers and toes , and a heart saddened by the chidings of Bessie , the nurse , and humbled by the consciousness of my physical inferiority to Eliza , John , and Georgiana Reed .","Что же , тем лучше : я вообще не любила подолгу гулять зимой , особенно под вечер . Мне казалось просто ужасным возвращаться домой в зябких сумерках , когда пальцы на руках и ногах немеют от стужи , а сердце сжимается тоской от вечной воркотни Бесси , нашей няньки , и от унизительного сознания физического превосходства надо мной Элизы , Джона и Джоржианы Рид .",66,65,65,65,32,33,10,11,8,5,1,20<18,1.02,,0,0,0,0,ok
215,"The said Eliza , John , and Georgiana were now clustered round their mama in the drawing - room : she lay reclined on a sofa by the fireside , and with her darlings about her ( for the time neither quarrelling nor crying ) looked perfectly happy .","Вышеупомянутые Элиза , Джон и Джорджиана собрались теперь в гостиной возле своей мамы : она полулежала на диване перед камином , окруженная своими дорогими детками ( в данную минуту они не ссорились и не ревели ), и , очевидно , была безмятежно счастлива .",49,44,48,52,17,35,5,6,5,8,1,15<13,1.11,,0,0,0,0,ok
216,"Me , she had dispensed from joining the group ; saying , “ She regretted to be under the necessity of keeping me at a distance ; but that until she heard from Bessie , and could discover by her own observation , that I was endeavouring in good earnest to acquire a more sociable and childlike disposition , a more attractive and sprightly manner — something lighter , franker , more natural , as it were — she really must exclude me from privileges intended only for contented , happy , little children .","Я была освобождена от участия в этой семейной группе ; как заявила мне миссис Рид , она весьма сожалеет , но приходится отделить меня от остальных детей , по крайней мере до тех пор , пока Бесси не сообщит ей , да и она сама не увидит , что я действительно прилагаю все усилия , чтобы стать более приветливой и ласковой девочкой , более уживчивой и кроткой , пока она не заметит во мне что - то более светлое , доброе и чистосердечное ; а тем временем она вынуждена лишить меня всех радостей , которые предназначены для скромных , почтительных деток .",95,102,94,102,34,68,16,27,17,18,1,34<31,0.93,,0,0,0,1,ok
217,“ What does Bessie say I have done ?” I asked .,— А что Бесси сказала ? Что я сделала ?,12,10,11,7,5,2,5,4,0,1,0,,1.2,,0,0,0,0,ok
218,"“ Jane , I don ’ t like cavillers or questioners ; besides , there is something truly forbidding in a child taking up her elders in that manner .","— Джен , я не выношу придирок и допросов ; это просто возмутительно , когда ребенок так разговаривает со старшими .",30,21,29,24,5,19,6,3,0,4,0,,1.43,,0,0,0,1,ok
219,Wuthering Heights,Грозовой перевал,2,2,2,2,2,0,0,0,0,0,0,,1.0,,0,1,0,0,ok
220,Emily Bronte,Эмилия Бронте,2,2,2,2,2,0,0,0,0,0,0,,1.0,,0,1,0,0,ok
221,' Mr . Heathcliff ?' I said .,- Мистер Хитклиф ?- спросил я .,8,7,7,8,4,4,0,0,0,1,0,,1.14,,0,0,0,0,ok
222,A nod was the answer .,В ответ он молча кивнул .,6,6,5,3,2,1,3,3,0,0,0,,1.0,,0,0,0,0,ok
223,"' Mr . Lockwood , your new tenant , sir .","- Мистер Локвуд , ваш новый жилец , сэр .",11,10,10,11,9,2,0,0,0,1,0,,1.1,,0,0,0,0,ok
224,"I do myself the honour of calling as soon as possible after my arrival , to express the hope that I have not inconvenienced you by my perseverance in soliciting the occupation of Thrushcross Grange : I heard yesterday you had had some thoughts ...","Почел за честь тотчас же по приезде выразить вам свою надежду , что я не причинил вам беспокойства , так настойчиво добиваясь позволения поселиться на Мысе Скворцов : я слышал вчера , что у вас были некоторые колебания ...",45,39,45,37,15,22,13,9,5,5,0,,1.15,,0,1,0,0,ok
225,CHAPTER I,Глава 1,2,2,2,2,1,1,0,0,0,0,0,,1.0,211,1,1,0,0,duplicate
226,1801 .,1801 .,2,2,1,2,2,0,0,0,0,0,0,,1.0,,0,0,0,0,ok
227,I have just returned from a visit to my landlord -- the solitary neighbour that I shall be troubled with .,"Я только что вернулся от своего хозяина -- единственного соседа , который будет мне здесь докучать .",21,17,20,18,12,6,4,2,1,3,1,3<2,1.24,,0,0,0,0,ok
228,This is certainly a beautiful country !,Место поистине прекрасное !,7,4,6,4,2,2,3,0,0,0,0,,1.75,,0,0,0,0,ok
229,"In all England , I do not believe that I could have fixed on a situation so completely removed from the stir of society .","Во всей Англии едва ли я сыскал бы уголок , так идеально удаленный от светской суеты .",25,17,24,27,11,16,3,1,5,4,2,24<22 24<23,1.47,,0,0,0,0,ok
230,A perfect misanthropist ' s heaven : and Mr . Heathcliff and I are such a suitable pair to divide the desolation between us .,"Совершенный рай для мизантропа ; а мистер Хитклиф и я -- оба мы прямо созданы для того , чтобы делить между собой уединение .",25,24,24,24,12,12,4,3,1,3,2,6<3 23<22,1.04,,0,0,0,0,ok
231,A capital fellow !,Превосходный человек !,4,3,3,3,1,2,1,0,0,0,0,,1.33,,0,0,0,0,ok
232,"He little imagined how my heart warmed towards him when I beheld his black eyes withdraw so suspiciously under their brows , as I rode up , and when his fingers sheltered themselves , with a jealous resolution , still further in his waistcoat , as I announced my name .","Он и не представляет себе , какую теплоту я почувствовал в сердце , увидав , что его черные глаза так недоверчиво ушли под брови , когда я подъехал на коне , и что он с настороженной решимостью еще глубже засунул пальцы за жилет , когда я назвал свое имя .",51,50,50,51,34,17,8,4,5,5,11,17<16 18<16 35<31 38<31 40<31 41<31 35<34 38<34 40<34 41<34 44<34,1.02,,0,0,0,0,ok

```

---

## pilot_lines.csv — пилотные решения для строк 196–232

```csv

line_id,selection,en,ru,en_tokens,movable_tokens,role,translation_ok,use,confidence,reason
203,around,The heat pulsed among the cottages and bushes and children .,"Зной омывал дома , кусты , детей .",11,10,BODY,ok,SKIP,medium,"mov 10, just above window"
204,around,"The icicles dropped , shattering , to melt .","Сосульки срывались с крыш , разбивались и таяли .",9,8,BODY,ok,PLAY,high,"mov 8, Rocket Summer scene"
205,around,The doors flew open .,Двери распахнулись .,5,4,BODY,ok,PLAY,high,"mov 4, game level 101"
206,around,CHARLOTTE BRONTE,Шарлотта Бронте,2,2,TITLE_AUTHOR,ok,SKIP,high,"author, CAPS"
207,around,JANE EYRE,ДЖЕН ЭЙР,2,2,TITLE_AUTHOR,ok,SKIP,high,"title, CAPS"
218,random,"“ Jane , I don ’ t like cavillers or questioners ; besides , there is something truly forbidding in a child taking up her elders in that manner .","— Джен , я не выношу придирок и допросов ; это просто возмутительно , когда ребенок так разговаривает со старшими .",30,29,DIALOGUE,ok,CONTEXT,medium,mov 29
220,around,Emily Bronte,Эмилия Бронте,2,2,TITLE_AUTHOR,ok,SKIP,high,author
221,around,' Mr . Heathcliff ?' I said .,- Мистер Хитклиф ?- спросил я .,8,7,DIALOGUE,loose,SKIP,medium,"!mov 7, RU broken dash"
222,around,A nod was the answer .,В ответ он молча кивнул .,6,5,BODY,loose,PLAY,high,"mov 5, game level 103, RU adds молча"
223,around,"' Mr . Lockwood , your new tenant , sir .","- Мистер Локвуд , ваш новый жилец , сэр .",11,10,DIALOGUE,ok,SKIP,medium,mov 10
224,around,"I do myself the honour of calling as soon as possible after my arrival , to express the hope that I have not inconvenienced you by my perseverance in soliciting the occupation of Thrushcross Grange : I heard yesterday you had had some thoughts ...","Почел за честь тотчас же по приезде выразить вам свою надежду , что я не причинил вам беспокойства , так настойчиво добиваясь позволения поселиться на Мысе Скворцов : я слышал вчера , что у вас были некоторые колебания ...",45,45,BODY,ok,CONTEXT,medium,mov 45
226,around,1801 .,1801 .,2,1,NOTE,ok,SKIP,high,date line
227,around,I have just returned from a visit to my landlord -- the solitary neighbour that I shall be troubled with .,"Я только что вернулся от своего хозяина -- единственного соседа , который будет мне здесь докучать .",21,20,BODY,ok,CONTEXT,medium,mov 20
228,around,This is certainly a beautiful country !,Место поистине прекрасное !,7,6,BODY,loose,SKIP,medium,"mov 6, RU condensed"
229,around,"In all England , I do not believe that I could have fixed on a situation so completely removed from the stir of society .","Во всей Англии едва ли я сыскал бы уголок , так идеально удаленный от светской суеты .",25,24,BODY,loose,CONTEXT,medium,mov 24
230,around,A perfect misanthropist ' s heaven : and Mr . Heathcliff and I are such a suitable pair to divide the desolation between us .,"Совершенный рай для мизантропа ; а мистер Хитклиф и я -- оба мы прямо созданы для того , чтобы делить между собой уединение .",25,24,BODY,ok,CONTEXT,medium,mov 24
231,around,A capital fellow !,Превосходный человек !,4,3,DIALOGUE,ok,PLAY,medium,"mov 3, exclamation fragment"
232,around,"He little imagined how my heart warmed towards him when I beheld his black eyes withdraw so suspiciously under their brows , as I rode up , and when his fingers sheltered themselves , with a jealous resolution , still further in his waistcoat , as I announced my name .","Он и не представляет себе , какую теплоту я почувствовал в сердце , увидав , что его черные глаза так недоверчиво ушли под брови , когда я подъехал на коне , и что он с настороженной решимостью еще глубже засунул пальцы за жилет , когда я назвал свое имя .",51,50,BODY,ok,CONTEXT,medium,mov 50

```

---

## scene_lines.csv — строки сцен в блоке

```csv

line_id,role,source_guess,source_conf,translation_ok,prev_story_line,link,link_codes,quote_prev,quote_this,start_reason,confidence,note
199,HEADING,The Martian Chronicles,high,ok,,START,,,,HEADING,high,January 1999: ROCKET SUMMER
203,BODY,The Martian Chronicles,high,ok,,START,,,The heat pulsed,SCENE_START,high,
204,BODY,The Martian Chronicles,high,ok,203,STRONG,TIME|SETTING,The heat pulsed,The icicles dropped,,high,
205,BODY,The Martian Chronicles,high,ok,204,STRONG,CAUSE|TIME,dropped,flew open,,high,

```

---

## scenes.csv — карточка сцены S0001

```csv

scene_id,source_guess,line_first,line_last,n_lines,n_play,title_ru,summary_ru,characters,self_contained,orderable,best_use,grade,review_status
S0001,The Martian Chronicles,203,205,3,2,Ракетное лето,Зимой в городке вдруг наступает волна тепла; двери распахиваются,,1,1,STORY_MODE,B,approved

```

---

## scene_members.csv — члены сцены S0001

```csv

scene_id,story_pos,line_id,role_in_scene,use,needs_prev
S0001,1,203,SETUP,CONTEXT,0
S0001,2,204,DEVELOP,PLAY,1
S0001,3,205,PAYOFF,PLAY,1

```

---

## pilot_traps.csv — ловушки в блоке

```csv

trap_id,line_id,kind,rule_code,verdict,pairs,full_order,trigger_tokens,source,likelihood,severity,explanation_ru,wrong_example_en,confidence,review_status
T0001,205,ORDER,PREFIX_VS_PARTICLE,TRAP,4<3,,4|3,BOTH,2,2,"Русская приставка стоит перед корнем, английская частица — после глагола: flew open.",The doors open flew .,high,approved
A0002,222,ORDER,SVO_RIGID,ACCEPTABLE,,4<1 5<2 4<3 5<3,the answer was a nod,,LLM,0,1,«Ответом был кивок» — The answer was a nod — законная альтернатива.,The answer was a nod .,high

```

---

## level_mapping.csv — уровни, чьи корпусные строки в блоке

```csv

level_id,corpus_line,match,import_allowed,english
101,205,en,yes,The doors flew open .
103,222,en,yes,A nod was the answer .
116,231,en,yes,A capital fellow !
117,228,en,yes,This is certainly a beautiful country !
140,204,en,yes,"The icicles dropped , shattering , to melt ."

```

---

## audit_summary.json — сводка pass 1 (полный файл)

```json

{
  "source_checksums": {
    "enru.src.sha256": "ed8b363353e39a57ff324359294ea8067b897e59c312eafcb8a9bb381309c545",
    "enru.tgt.sha256": "d515044434312d30d0d02f17c18eac3c267003c69fbb660051b81a43dd5e9bcd",
    "enru.talp.sha256": "3120cb872f5c05804578170f0b661ce3611b859ee4b58fbc2a0ec22d1a481ace",
    "levels.json.sha256": "a57f3ef2feed19406d31aa400af6e537e987da3a03b5643314f1649903ab1536"
  },
  "total_lines": 881,
  "files_in_sync": true,
  "talp_base": "1-based (verified on line 205: 2-1 3-2 4-2 5-3)",
  "total_links": 17281,
  "reliable_links": 9175,
  "probable_links": 8106,
  "lines_without_links": 3,
  "lines_without_links_ids": [
    137,
    234,
    257
  ],
  "out_of_bounds_count": 2,
  "out_of_bounds_sample": [
    {
      "line": 602,
      "kind": "en",
      "index": 40
    },
    {
      "line": 612,
      "kind": "ru",
      "index": 34
    }
  ],
  "bad_talp_tokens": [],
  "links_per_line_min": 0,
  "links_per_line_max": 161,
  "links_per_line_mean": 19.6,
  "links_distribution": {
    "0": 3,
    "1": 15,
    "2": 49,
    "3": 43,
    "4": 41,
    "5": 41,
    "6": 29,
    "7": 31,
    "8": 42,
    "9": 26,
    "10": 34,
    "11": 19,
    "12": 29,
    "13": 18,
    "14": 24,
    "15": 18,
    "16": 33,
    "17": 16,
    "18": 16,
    "19": 24,
    "20": 22,
    "21": 23,
    "22": 9,
    "23": 12,
    "24": 19,
    "25": 14,
    "26": 13,
    "27": 15,
    "28": 13,
    "29": 17,
    "30": 8,
    "31": 6,
    "32": 12,
    "33": 7,
    "34": 4,
    "35": 9,
    "36": 5,
    "37": 8,
    "38": 8,
    "39": 4,
    "40": 8,
    "41": 2,
    "42": 4,
    "43": 8,
    "44": 2,
    "45": 6,
    "46": 3,
    "47": 5,
    "48": 4,
    "49": 4,
    "50": 3,
    "51": 2,
    "52": 1,
    "53": 2,
    "54": 1,
    "55": 1,
    "56": 3,
    "57": 2,
    "58": 1,
    "59": 1,
    "60": 1,
    "61": 3,
    "62": 1,
    "63": 1,
    "64": 3,
    "65": 2,
    "66": 1,
    "67": 1,
    "70": 2,
    "72": 1,
    "74": 2,
    "75": 2,
    "76": 1,
    "78": 1,
    "81": 2,
    "86": 1,
    "87": 1,
    "91": 1,
    "92": 1,
    "93": 2,
    "96": 1,
    "97": 1,
    "102": 1,
    "104": 1,
    "106": 1,
    "122": 1,
    "132": 1,
    "135": 1,
    "161": 1
  },
  "en_unpaired_token_share": 0.256,
  "en_unpaired_top": [
    [
      "the",
      894
    ],
    [
      ",",
      492
    ],
    [
      "a",
      327
    ],
    [
      "of",
      176
    ],
    [
      "and",
      144
    ],
    [
      "to",
      143
    ],
    [
      "it",
      94
    ],
    [
      "\"",
      92
    ],
    [
      "was",
      74
    ],
    [
      "his",
      72
    ],
    [
      "that",
      70
    ],
    [
      "in",
      61
    ],
    [
      "-",
      60
    ],
    [
      "i",
      55
    ],
    [
      "is",
      54
    ]
  ],
  "m2o_groups_total": 1612,
  "o2m_groups_total": 2286,
  "duplicate_en_lines": [
    [
      72,
      71
    ],
    [
      94,
      81
    ],
    [
      98,
      86
    ],
    [
      112,
      76
    ],
    [
      132,
      123
    ],
    [
      142,
      119
    ],
    [
      146,
      123
    ],
    [
      154,
      119
    ],
    [
      225,
      211
    ],
    [
      376,
      211
    ],
    [
      547,
      447
    ],
    [
      552,
      267
    ],
    [
      570,
      76
    ]
  ],
  "length_ratio_min": 0.31,
  "length_ratio_max": 14.0,
  "length_ratio_outliers_15": 147,
  "levels_found": 32,
  "levels_total": 32,
  "pass1_verdicts": {
    "ok": 863,
    "duplicate": 13,
    "no_links": 3,
    "out_of_bounds": 2
  },
  "boundary_flags": {
    "all_caps": 31,
    "no_terminal": 158,
    "lowercase_start": 2,
    "unclosed_quote": 41
  }
}

```

---

## issues.csv — issues в блоке

```csv

line_id,kind,note
221,content,"mov 7, RU broken dash"

```
