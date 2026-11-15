-- TIFFANI editorial article recovery.
-- Sources: the five public tpost pages on https://tiffani.md, fetched 2026-11-14.
-- Drafts only. is_published stays false until a human reviews the copy.
--
-- Idempotent against public.articles.slug and public.article_blocks.id.
-- An existing slug is not updated.
-- Blocks are inserted only when the article has no blocks outside this file.
-- No DELETE. No UPDATE. No other tables.
--
-- Mapping:
--   h2/h3 and Tilda preface blockquotes -> heading
--   t-redactor__quote -> quote
--   t-redactor__text, split on blank lines -> paragraph
--   figure data-src -> image
--   hr separators are omitted; they are not content
--
-- Editorial review before publication:
--   akne: diet, dairy, alcohol and stress claimed as acne causes
--   5-opasnih-ingredientov-dlya-beremennih: pregnancy and breastfeeding claims
--   mikrobiom: aging and probiotic claims
--   mifi-ob-spf: UV and HEV claims
-- The original wording is preserved, including the source typo in the microbiome heading.

BEGIN;

INSERT INTO public.articles (
  id, slug, title, excerpt, cover_image_url, is_published, published_at
)
VALUES
  ('b7d19138-6873-52af-8c0f-e1767047e15c'::uuid, $slug_mikrobiom$mikrobiom$slug_mikrobiom$, $title_mikrobiom$Микробиом$title_mikrobiom$, $excerpt_mikrobiom$Микробиом кожи.$excerpt_mikrobiom$, $cover_mikrobiom$https://static.tildacdn.com/tild3864-3666-4732-a364-623461316262/beautiful-asian-woma.jpg$cover_mikrobiom$, false, '2023-08-27T18:00:00+03:00'::timestamptz),
  ('970b2b9b-422b-50db-8d6e-63d9ee05d1b3'::uuid, $slug_top_5_oshibok_pri_vibore_kosmetiki$top-5-oshibok-pri-vibore-kosmetiki$slug_top_5_oshibok_pri_vibore_kosmetiki$, $title_top_5_oshibok_pri_vibore_kosmetiki$ТОП 5 ОШИБОК ПРИ ВЫБОРЕ КОСМЕТИКИ$title_top_5_oshibok_pri_vibore_kosmetiki$, $excerpt_top_5_oshibok_pri_vibore_kosmetiki$За 3 года ежедневного подбора ухода наша команда сталкивалась с самыми разными запросами и ошибками при покупке косметики.$excerpt_top_5_oshibok_pri_vibore_kosmetiki$, $cover_top_5_oshibok_pri_vibore_kosmetiki$https://static.tildacdn.com/tild3334-3866-4063-a633-353362363937/close-up-portrait-wo.jpg$cover_top_5_oshibok_pri_vibore_kosmetiki$, false, '2022-10-07T18:00:00+03:00'::timestamptz),
  ('4c882120-d214-5721-9482-ef74c894843d'::uuid, $slug_akne$akne$slug_akne$, $title_akne$АКНЕ$title_akne$, $excerpt_akne$1. Первое, куда стоит обратить внимание — еда. Печеньки, картошечка фри, колбаска и прочее сладкое, жирное, жареное. Если это основа питания — ничего удивительного, что прыщи. Кожа спасает организм от гадости, как может — выводит лишнее наружу. Решение очевидно — отказаться от вот этого всего. Кофе тоже. Я когда не пью - лицо чище.$excerpt_akne$, $cover_akne$https://static.tildacdn.com/tild3535-3661-4562-b434-336633643762/portrait-beautiful-w.png$cover_akne$, false, '2021-09-24T18:00:00+03:00'::timestamptz),
  ('70f44b68-e96d-5d63-b046-d6046e9f10e9'::uuid, $slug_5_opasnih_ingredientov_dlya_beremennih$5-opasnih-ingredientov-dlya-beremennih$slug_5_opasnih_ingredientov_dlya_beremennih$, $title_5_opasnih_ingredientov_dlya_beremennih$5 ОПАСНЫХ ИНГРЕДИЕНТОВ ДЛЯ БЕРЕМЕННЫХ$title_5_opasnih_ingredientov_dlya_beremennih$, $excerpt_5_opasnih_ingredientov_dlya_beremennih$(витамин А, ретинол)$excerpt_5_opasnih_ingredientov_dlya_beremennih$, $cover_5_opasnih_ingredientov_dlya_beremennih$https://static.tildacdn.com/tild3265-3031-4331-b366-636361633834/pregnant-woman-poses.jpg$cover_5_opasnih_ingredientov_dlya_beremennih$, false, '2023-10-02T18:00:00+03:00'::timestamptz),
  ('9c4a8701-c5eb-5f7e-b125-e59e49f45a32'::uuid, $slug_mifi_ob_spf$mifi-ob-spf$slug_mifi_ob_spf$, $title_mifi_ob_spf$МИФЫ ОБ SPF$title_mifi_ob_spf$, $excerpt_mifi_ob_spf$SPF нужен только летом и на пляже.$excerpt_mifi_ob_spf$, $cover_mifi_ob_spf$https://static.tildacdn.com/tild3832-6461-4035-b536-626561613466/photo.JPG$cover_mifi_ob_spf$, false, '2025-08-09T18:24:00+03:00'::timestamptz)
ON CONFLICT (slug) DO NOTHING;

-- Микробиом  https://tiffani.md/tpost/89av6uetg1-mikrobiom
INSERT INTO public.article_blocks (
  id, article_id, block_type, text_content, image_url, sort_order
)
SELECT v.id, a.id, v.block_type, v.text_content, v.image_url, v.sort_order
FROM (VALUES
  ('97fdbf67-2231-5e52-8a91-2cc2935b5128'::uuid, 'heading', $b_mikrobiom_1$Микробиом. Какой у тебя? Богатый или бедны?$b_mikrobiom_1$, NULL::text, 1),
  ('56b30de0-962a-53f4-91f3-278eb5e277a1'::uuid, 'paragraph', $b_mikrobiom_2$Микробиом кожи.$b_mikrobiom_2$, NULL::text, 2),
  ('7904f8a6-fe28-5de3-a382-44cbd859a235'::uuid, 'paragraph', $b_mikrobiom_3$Это все микроорганизмы, которые живут на твоей (моей, нашей, соседа дяди Толи) коже. И это верхняя часть её защитного барьера (→ там картинки).$b_mikrobiom_3$, NULL::text, 3),
  ('31ab6033-0273-5ee6-9fd8-00b9af2694ac'::uuid, 'paragraph', $b_mikrobiom_4$Если плохо бактериям на коже, то плохо и самой коже. А когда коже плохо, она всегда быстрее СТАРЕЕТ.$b_mikrobiom_4$, NULL::text, 4),
  ('49de152b-c027-521f-8ea7-ccbf36176882'::uuid, 'image', NULL::text, $b_mikrobiom_5$https://static.tildacdn.com/tild3164-3664-4265-a165-373136333165/____________________.jpg$b_mikrobiom_5$, 5),
  ('3fbbb4fd-7c33-51a3-a535-95cc18be8369'::uuid, 'image', NULL::text, $b_mikrobiom_6$https://static.tildacdn.com/tild3335-6432-4138-b936-333363346438/____________________.jpg$b_mikrobiom_6$, 6),
  ('69a67499-7397-5327-b8fe-e9c25405c09f'::uuid, 'heading', $b_mikrobiom_7$Как узнать, что твоим бактериям плохо?$b_mikrobiom_7$, NULL::text, 7),
  ('f98c04cb-0c14-53ec-966b-a4001f83778d'::uuid, 'paragraph', $b_mikrobiom_8$→ Твоя кожа патологически сухая и/или шелушится.$b_mikrobiom_8$, NULL::text, 8),
  ('7517aad0-7fe6-5250-8418-1bf52f9383db'::uuid, 'paragraph', $b_mikrobiom_9$→ Твоя кожа краснеет и раздражается от дождя, ветра, косметики, недоброго взгляда.$b_mikrobiom_9$, NULL::text, 9),
  ('b1eae0ea-ef46-574c-af91-b7b3f35409e2'::uuid, 'paragraph', $b_mikrobiom_10$→ Твоя кожа аномально выделяет жир и подпорчена акне.$b_mikrobiom_10$, NULL::text, 10),
  ('84bc9420-d341-54f3-bd0b-3911fd3d27ab'::uuid, 'paragraph', $b_mikrobiom_11$→ У тебя чувствительная кожа, атопический дерматит, себорея, псориаз, розацеа и прочие приключения кожи. (Тут ещё и генетика, конечно, «помогает»).$b_mikrobiom_11$, NULL::text, 11),
  ('be8aab89-65c2-5941-ba6c-22773a67454d'::uuid, 'paragraph', $b_mikrobiom_12$Чаще всего - первый пункт: ибо чем беднее микробиом, тем она суше.
На самых сухих участках тебя (меня, нас, соседа дяди Толи) ползает меньше всего микроорганизмов. (Это тыльная сторона кисти, внутренняя сторона голени, предплечья)$b_mikrobiom_12$, NULL::text, 12),
  ('0f8c23f2-2fb4-5f7e-a38c-9d677d850edd'::uuid, 'quote', $b_mikrobiom_13$ВЫВОД: богатый микробиом - здоровая кожа. И «долгомолодая» кожа.$b_mikrobiom_13$, NULL::text, 13),
  ('77bc531b-87f9-550c-aa35-a194a8bd79fe'::uuid, 'heading', $b_mikrobiom_14$Как ты могла повредить микробиом?$b_mikrobiom_14$, NULL::text, 14),
  ('d143e6cd-83d4-5624-98e8-da3ee356af02'::uuid, 'image', NULL::text, $b_mikrobiom_15$https://static.tildacdn.com/tild6133-3339-4030-b733-643834323637/____________________.jpg$b_mikrobiom_15$, 15),
  ('acbc745b-8516-56d8-93c5-ef5dc10a4309'::uuid, 'heading', $b_mikrobiom_16$Что делать то?$b_mikrobiom_16$, NULL::text, 16),
  ('c3d6315b-f8f9-5b37-ba6e-ba2351716282'::uuid, 'paragraph', $b_mikrobiom_17$Убрать все причины и глядеть в сторону косметики с ПРОБИОТИКАМИ! Они ремонтируют микробиом и замещают бактерии, выбывшие из строя.$b_mikrobiom_17$, NULL::text, 17),
  ('b74b960e-a078-5a61-b863-4db5e8303161'::uuid, 'heading', $b_mikrobiom_18$Кому больше других надобна косметика с пробиотиками?$b_mikrobiom_18$, NULL::text, 18),
  ('dbc27d22-d746-56ec-8f7d-b66ac92ba2a4'::uuid, 'paragraph', $b_mikrobiom_19$→ тебе, если у тебя подозрительно сухая кожа.$b_mikrobiom_19$, NULL::text, 19),
  ('d8c37577-2d38-52eb-ad44-9031dcbab54b'::uuid, 'paragraph', $b_mikrobiom_20$→ тебе, если надо восстановить кожу после загара, пилингов, лазерной шлифовки.$b_mikrobiom_20$, NULL::text, 20),
  ('85b1164b-76e5-5436-9b5b-590106d4ec10'::uuid, 'paragraph', $b_mikrobiom_21$→ тебе, если ты применяла мази с антибиотиками, и возможно, если принимала из вовнутрь.$b_mikrobiom_21$, NULL::text, 21),
  ('2ed03f30-79fb-5f35-ae89-5e38a8c47976'::uuid, 'paragraph', $b_mikrobiom_22$→ если ты живешь в загрязнённом городе, куришь и часто стрессуешь.$b_mikrobiom_22$, NULL::text, 22),
  ('8e0af3f7-2338-5a82-a0a3-1eb7d817df00'::uuid, 'paragraph', $b_mikrobiom_23$→ тебе, если тебе 25+, и ты не хочешь в миг состариться.$b_mikrobiom_23$, NULL::text, 23),
  ('f5ec4b84-c874-51d0-bdad-aafe28cebb9b'::uuid, 'paragraph', $b_mikrobiom_24$А с возрастом, плачь-не плачь, микробиом становится беднее.$b_mikrobiom_24$, NULL::text, 24),
  ('2f3dfb15-85ef-58bd-8f3d-c8793638bad5'::uuid, 'image', NULL::text, $b_mikrobiom_25$https://static.tildacdn.com/tild6561-3735-4864-a133-373937633330/____________________.jpg$b_mikrobiom_25$, 25),
  ('54e0cc08-1045-553a-9231-3cbda25fc092'::uuid, 'heading', $b_mikrobiom_26$Ну что, кому из вас уже пора закупаться литрами средств с пробиотиками?$b_mikrobiom_26$, NULL::text, 26)
) AS v(id, block_type, text_content, image_url, sort_order)
JOIN public.articles a
  ON a.slug = $join_mikrobiom$mikrobiom$join_mikrobiom$
WHERE NOT EXISTS (
  SELECT 1
  FROM public.article_blocks b
  WHERE b.article_id = a.id
    AND b.id <> ALL (ARRAY['97fdbf67-2231-5e52-8a91-2cc2935b5128'::uuid, '56b30de0-962a-53f4-91f3-278eb5e277a1'::uuid, '7904f8a6-fe28-5de3-a382-44cbd859a235'::uuid, '31ab6033-0273-5ee6-9fd8-00b9af2694ac'::uuid, '49de152b-c027-521f-8ea7-ccbf36176882'::uuid, '3fbbb4fd-7c33-51a3-a535-95cc18be8369'::uuid, '69a67499-7397-5327-b8fe-e9c25405c09f'::uuid, 'f98c04cb-0c14-53ec-966b-a4001f83778d'::uuid, '7517aad0-7fe6-5250-8418-1bf52f9383db'::uuid, 'b1eae0ea-ef46-574c-af91-b7b3f35409e2'::uuid, '84bc9420-d341-54f3-bd0b-3911fd3d27ab'::uuid, 'be8aab89-65c2-5941-ba6c-22773a67454d'::uuid, '0f8c23f2-2fb4-5f7e-a38c-9d677d850edd'::uuid, '77bc531b-87f9-550c-aa35-a194a8bd79fe'::uuid, 'd143e6cd-83d4-5624-98e8-da3ee356af02'::uuid, 'acbc745b-8516-56d8-93c5-ef5dc10a4309'::uuid, 'c3d6315b-f8f9-5b37-ba6e-ba2351716282'::uuid, 'b74b960e-a078-5a61-b863-4db5e8303161'::uuid, 'dbc27d22-d746-56ec-8f7d-b66ac92ba2a4'::uuid, 'd8c37577-2d38-52eb-ad44-9031dcbab54b'::uuid, '85b1164b-76e5-5436-9b5b-590106d4ec10'::uuid, '2ed03f30-79fb-5f35-ae89-5e38a8c47976'::uuid, '8e0af3f7-2338-5a82-a0a3-1eb7d817df00'::uuid, 'f5ec4b84-c874-51d0-bdad-aafe28cebb9b'::uuid, '2f3dfb15-85ef-58bd-8f3d-c8793638bad5'::uuid, '54e0cc08-1045-553a-9231-3cbda25fc092'::uuid])
)
ON CONFLICT (id) DO NOTHING;

-- ТОП 5 ОШИБОК ПРИ ВЫБОРЕ КОСМЕТИКИ  https://tiffani.md/tpost/1sjnvcroo1-top-5-oshibok-pri-vibore-kosmetiki
INSERT INTO public.article_blocks (
  id, article_id, block_type, text_content, image_url, sort_order
)
SELECT v.id, a.id, v.block_type, v.text_content, v.image_url, v.sort_order
FROM (VALUES
  ('a82adc68-433d-56eb-b809-43b04720970c'::uuid, 'paragraph', $b_top_5_oshibok_pri_vibore_kosmetiki_1$За 3 года ежедневного подбора ухода наша команда сталкивалась с самыми разными запросами и ошибками при покупке косметики.$b_top_5_oshibok_pri_vibore_kosmetiki_1$, NULL::text, 1),
  ('e12ce5d9-a134-50d8-b4ed-118e5315a5e4'::uuid, 'heading', $b_top_5_oshibok_pri_vibore_kosmetiki_2$Вот 5 ключевых:$b_top_5_oshibok_pri_vibore_kosmetiki_2$, NULL::text, 2),
  ('693ccd61-dcb1-5a69-96d0-6ee13dd0df52'::uuid, 'paragraph', $b_top_5_oshibok_pri_vibore_kosmetiki_3$❌Не учитывать тип кожи и ее потребности
✅Тип кожи и ее состояние - основа правильно подобранного, работающего ухода. Часто тип кожи определяется неверно. К примеру, кожу с нарушенными функциями защитного барьера путают с сухой, потому что чувствуют стянутость, видят шелушения и шероховатость. При этом такая кожа вполне может быть жирной, но требующей восстановления защитных функций.$b_top_5_oshibok_pri_vibore_kosmetiki_3$, NULL::text, 3),
  ('1b68b394-d2ae-5e95-8e03-399b6f5e6c90'::uuid, 'paragraph', $b_top_5_oshibok_pri_vibore_kosmetiki_4$❌Скупать всё без системы
✅Системность - вторая составляющая успешного ухода. Базовый уход состоит из 4х шагов:
- 1 Очищение
- 2 Отшелушивание
- 3 Увлажнение
- 4 Защита от солнца.$b_top_5_oshibok_pri_vibore_kosmetiki_4$, NULL::text, 4),
  ('cac5c666-ed48-5d1b-89ac-ff7d009fd0d8'::uuid, 'paragraph', $b_top_5_oshibok_pri_vibore_kosmetiki_5$Не нужно покупать 3 крема и прыгать с одного средства на другое. Дай своему уходу раскрыться. Будь последовательна.$b_top_5_oshibok_pri_vibore_kosmetiki_5$, NULL::text, 5),
  ('96eda0d3-7305-5fe3-9ac0-dc918dcfc2cb'::uuid, 'paragraph', $b_top_5_oshibok_pri_vibore_kosmetiki_6$❌Покупать все то же, что у подруги/блогера
✅Подруга хвалит свой уход и говорит, что тебе тоже стоит его попробовать? Соблазн велик, но делать так стоит, только если у тебя и подруги/блогера одинаковый тип, возраст, состояние, потребности кожи и образ жизни. При выборе косметики всегда отталкивайся только от СВОЕЙ кожи!$b_top_5_oshibok_pri_vibore_kosmetiki_6$, NULL::text, 6),
  ('558c8617-24ad-536f-b2e8-154bad385e3e'::uuid, 'paragraph', $b_top_5_oshibok_pri_vibore_kosmetiki_7$❌Ограничиваться одной линейкой/брендом
✅Не бойся сочетать в одном уходе косметику из разных стран, разных линеек и производителей. Главное, чтобы не было конфликтов активных компонентов и уход отвечал потребностям кожи.$b_top_5_oshibok_pri_vibore_kosmetiki_7$, NULL::text, 7),
  ('9d31a71f-51dd-5a01-9be3-c379cb168d64'::uuid, 'paragraph', $b_top_5_oshibok_pri_vibore_kosmetiki_8$❌Считать, что уход не может быть бюджетным
✅Качественный базовый уход не стоит баснословных денег. Корейская косметика предлагает вполне доступные пенки, тонеры и кремы. Функциональный уход за счет запатентованных формул, активов и особенностей производства стоит дороже. При этом в твоем уходе может быть всего одно такое средство, которого хватит на 3-4 месяца или его вообще может и не быть, если в этом нет нужды.→ Твоя кожа патологически сухая и/или шелушится.$b_top_5_oshibok_pri_vibore_kosmetiki_8$, NULL::text, 8),
  ('29be91ab-b5cd-51f2-b38b-9dd6a67808c5'::uuid, 'heading', $b_top_5_oshibok_pri_vibore_kosmetiki_9$Как не запутаться в тонкостях и подобрать эффективный уход?$b_top_5_oshibok_pri_vibore_kosmetiki_9$, NULL::text, 9),
  ('4f623c97-36c9-5383-9f9a-a30e08b7bcfa'::uuid, 'paragraph', $b_top_5_oshibok_pri_vibore_kosmetiki_10$→ Команда Тиффани к твоим услугам! Приходи в наши магазины (адреса в шапке профиля, работаем без выходных с 9 до 20) либо напиши нам в Директ. Мы подберем уход с нуля, разберем имеющийся, выстроим систему и будем вместе радоваться результатам. Работает доставка и онлайн консультация ❤$b_top_5_oshibok_pri_vibore_kosmetiki_10$, NULL::text, 10)
) AS v(id, block_type, text_content, image_url, sort_order)
JOIN public.articles a
  ON a.slug = $join_top_5_oshibok_pri_vibore_kosmetiki$top-5-oshibok-pri-vibore-kosmetiki$join_top_5_oshibok_pri_vibore_kosmetiki$
WHERE NOT EXISTS (
  SELECT 1
  FROM public.article_blocks b
  WHERE b.article_id = a.id
    AND b.id <> ALL (ARRAY['a82adc68-433d-56eb-b809-43b04720970c'::uuid, 'e12ce5d9-a134-50d8-b4ed-118e5315a5e4'::uuid, '693ccd61-dcb1-5a69-96d0-6ee13dd0df52'::uuid, '1b68b394-d2ae-5e95-8e03-399b6f5e6c90'::uuid, 'cac5c666-ed48-5d1b-89ac-ff7d009fd0d8'::uuid, '96eda0d3-7305-5fe3-9ac0-dc918dcfc2cb'::uuid, '558c8617-24ad-536f-b2e8-154bad385e3e'::uuid, '9d31a71f-51dd-5a01-9be3-c379cb168d64'::uuid, '29be91ab-b5cd-51f2-b38b-9dd6a67808c5'::uuid, '4f623c97-36c9-5383-9f9a-a30e08b7bcfa'::uuid])
)
ON CONFLICT (id) DO NOTHING;

-- АКНЕ  https://tiffani.md/tpost/vaim3p2661-akne
INSERT INTO public.article_blocks (
  id, article_id, block_type, text_content, image_url, sort_order
)
SELECT v.id, a.id, v.block_type, v.text_content, v.image_url, v.sort_order
FROM (VALUES
  ('d9bca800-d734-5108-8ed2-e085fc793435'::uuid, 'heading', $b_akne_1$Что можно сделать самостоятельно?$b_akne_1$, NULL::text, 1),
  ('9fea1db9-5b5f-5754-9442-1776bece31a7'::uuid, 'paragraph', $b_akne_2$1. Первое, куда стоит обратить внимание — еда. Печеньки, картошечка фри, колбаска и прочее сладкое, жирное, жареное. Если это основа питания — ничего удивительного, что прыщи. Кожа спасает организм от гадости, как может — выводит лишнее наружу. Решение очевидно — отказаться от вот этого всего. Кофе тоже. Я когда не пью - лицо чище.$b_akne_2$, NULL::text, 2),
  ('f2c2b747-a865-5a63-9c75-2516f44973c0'::uuid, 'paragraph', $b_akne_3$Сделать, конечно, труднее, чем сказать. Начать — так вообще самое сложное. А вы не отказывайтесь от всего сразу. Это прямая дорога в стресс. Начните с малого — установите лимит на количество конфет в неделю. А дальше наращивайте обороты.$b_akne_3$, NULL::text, 3),
  ('7f2b08b8-29eb-5995-8ef6-9778dcc4f683'::uuid, 'paragraph', $b_akne_4$Что касается молочки. Мнений много - разные. Доказывать вред или пользу молока не имею права. Но отказаться, чтобы проследить - всегда можно. На своём опыте скажу - когда молочки нет, либо минимум - не появляются подкожники, это те, что самые болючие. Поняли какие?$b_akne_4$, NULL::text, 4),
  ('6e9324b4-a740-5dbc-b573-625c255dc590'::uuid, 'paragraph', $b_akne_5$2. Алкоголь, сигареты, кальян, электронки тоже ничего хорошего коже не сулят. Принцип такой же, как с едой. Организм переполнен токсинами — кожа спешит на помощь: лови прыщи. Смекайте.$b_akne_5$, NULL::text, 5),
  ('a43aa8ab-be31-5a34-97b9-f5f65b03c5dd'::uuid, 'paragraph', $b_akne_6$3. Избегать стресса советовать не буду. Потому что сама не знаю, как🙃 Но если уж случилось, освободите себя от кортизола — гормона стресса. Бег, танцы, вышивание крестиком. Что там у вас в качестве антидепрессанта. Плюс работа только на работе, нормальные выходные и сон не меньше 7-8 часов.$b_akne_6$, NULL::text, 6),
  ('90339a0a-4def-5719-9867-cc8c0e9b89bb'::uuid, 'paragraph', $b_akne_7$4. Выстроить уход — задача тоже посильная. Тут уже мы есть! Для начала не трите воспалённую кожу скрабами, не сушите спиртовыми лосьонами, забудьте о спонжиках и щёточках. Повторяю, как мантру: качественное ежедневное двухэтапное очищение (это то самое масло гидрофильное и пенка), тонер, крем, мягкое отшелушивание и работа с порами. Это основа.$b_akne_7$, NULL::text, 7)
) AS v(id, block_type, text_content, image_url, sort_order)
JOIN public.articles a
  ON a.slug = $join_akne$akne$join_akne$
WHERE NOT EXISTS (
  SELECT 1
  FROM public.article_blocks b
  WHERE b.article_id = a.id
    AND b.id <> ALL (ARRAY['d9bca800-d734-5108-8ed2-e085fc793435'::uuid, '9fea1db9-5b5f-5754-9442-1776bece31a7'::uuid, 'f2c2b747-a865-5a63-9c75-2516f44973c0'::uuid, '7f2b08b8-29eb-5995-8ef6-9778dcc4f683'::uuid, '6e9324b4-a740-5dbc-b573-625c255dc590'::uuid, 'a43aa8ab-be31-5a34-97b9-f5f65b03c5dd'::uuid, '90339a0a-4def-5719-9867-cc8c0e9b89bb'::uuid])
)
ON CONFLICT (id) DO NOTHING;

-- 5 ОПАСНЫХ ИНГРЕДИЕНТОВ ДЛЯ БЕРЕМЕННЫХ  https://tiffani.md/tpost/hiea719p61-5-opasnih-ingredientov-dlya-beremennih
INSERT INTO public.article_blocks (
  id, article_id, block_type, text_content, image_url, sort_order
)
SELECT v.id, a.id, v.block_type, v.text_content, v.image_url, v.sort_order
FROM (VALUES
  ('ac232c82-e1e9-55b3-92ea-3fe38599ef43'::uuid, 'heading', $b_5_opasnih_ingredientov_dlya_beremennih_1$РЕТИНОИДЫ$b_5_opasnih_ingredientov_dlya_beremennih_1$, NULL::text, 1),
  ('4d3aff4c-83f0-58f7-a4b0-0a76e1a25e29'::uuid, 'paragraph', $b_5_opasnih_ingredientov_dlya_beremennih_2$(витамин А, ретинол)$b_5_opasnih_ingredientov_dlya_beremennih_2$, NULL::text, 2),
  ('e87a0c7e-c349-5c88-858c-e6177eb4873d'::uuid, 'paragraph', $b_5_opasnih_ingredientov_dlya_beremennih_3$Да, витамин А важен для развития плода, НО его высокая концентрация может вызвать серьезные врожденные дефекты и у плода.
Все ретиноиды - низкомолекулярные -легко преодолевают кожный барьер и влияют на клетки организма.$b_5_opasnih_ingredientov_dlya_beremennih_3$, NULL::text, 3),
  ('0dc16032-32a9-581e-80e3-0f68de7a1aa3'::uuid, 'paragraph', $b_5_opasnih_ingredientov_dlya_beremennih_4$Планировать беременность можно только через несколько недель после окончания курса косметики/препаратов с ретиноидами.
Ретиноиды противопоказаны и в период кормления грудью.$b_5_opasnih_ingredientov_dlya_beremennih_4$, NULL::text, 4),
  ('5e87646e-a265-55f6-ae15-42f3ddcae6b8'::uuid, 'heading', $b_5_opasnih_ingredientov_dlya_beremennih_5$ОТБЕЛИВАЮЩИЕ ИНГРЕДИЕНТЫ$b_5_opasnih_ingredientov_dlya_beremennih_5$, NULL::text, 5),
  ('fd87507c-b736-5c34-9a6f-41eacfadd2a3'::uuid, 'paragraph', $b_5_opasnih_ingredientov_dlya_beremennih_6$(арбутин, гидрохинон, ниацинамид, койевая кислота)$b_5_opasnih_ingredientov_dlya_beremennih_6$, NULL::text, 6),
  ('f0c6ff0c-e572-521b-9d23-52a6bcb7ed9a'::uuid, 'paragraph', $b_5_opasnih_ingredientov_dlya_beremennih_7$Они нарушают естественный процесс производства меланина, что опасно во время беременности.
На лице могут образоваться белые пятна, которые потом не будут загорать.$b_5_opasnih_ingredientov_dlya_beremennih_7$, NULL::text, 7),
  ('efb13078-a30f-585e-9781-8f33294a7b41'::uuid, 'heading', $b_5_opasnih_ingredientov_dlya_beremennih_8$ЭФИРНЫЕ МАСЛА$b_5_opasnih_ingredientov_dlya_beremennih_8$, NULL::text, 8),
  ('883cdee4-05c7-507a-a7c7-e3bfb5db5c52'::uuid, 'paragraph', $b_5_opasnih_ingredientov_dlya_beremennih_9$Их молекулы способны проникать в кровеносную систему. Некоторые масла могут провоцировать возникновение тонуса матки во II и III триместре беременности. Так, лучше не использовать эфир мяты в этом период. Эфирные масла часто добавляют в противоотечные средства, поэтому внимательно читайте состав средства от отёков.$b_5_opasnih_ingredientov_dlya_beremennih_9$, NULL::text, 9),
  ('ec5c060e-3fe1-5172-b572-676c74572ddd'::uuid, 'heading', $b_5_opasnih_ingredientov_dlya_beremennih_10$ФРУКТОВЫЕ КИСЛОТЫ$b_5_opasnih_ingredientov_dlya_beremennih_10$, NULL::text, 10),
  ('f44887f9-6f3b-58a4-bd52-4d50dbe32977'::uuid, 'paragraph', $b_5_opasnih_ingredientov_dlya_beremennih_11$(AHA и BHA)$b_5_opasnih_ingredientov_dlya_beremennih_11$, NULL::text, 11),
  ('a6a7b70b-3d15-5dcc-ac1e-c2058eba335c'::uuid, 'paragraph', $b_5_opasnih_ingredientov_dlya_beremennih_12$Они не оказывают вредного воздействия на плод, но могут вызвать раздражение кожи, повысить чувствительность к солнцу, привести к пигментации.$b_5_opasnih_ingredientov_dlya_beremennih_12$, NULL::text, 12),
  ('bd82b193-106a-52d2-8b3e-af00e60c0d6f'::uuid, 'heading', $b_5_opasnih_ingredientov_dlya_beremennih_13$ФОРМАЛЬДЕГИДЫ$b_5_opasnih_ingredientov_dlya_beremennih_13$, NULL::text, 13),
  ('0eb7fe06-f2ad-5ac5-9ad4-e606d0f5cbf5'::uuid, 'paragraph', $b_5_opasnih_ingredientov_dlya_beremennih_14$Это токсичные вещества, которые в высокой концентрации вызывают сильнейшее раздражение кожи, могут способствовать развитию бронхиальной астмы, раздражению слизистых оболочек носоглотки и глаза.$b_5_opasnih_ingredientov_dlya_beremennih_14$, NULL::text, 14),
  ('99186570-c42e-50e9-9e86-fc0c9a73952c'::uuid, 'paragraph', $b_5_opasnih_ingredientov_dlya_beremennih_15$❌Формальдегиды запрещено включать в косметику и парфюмерию в Швеции, Японии и Корее‼️$b_5_opasnih_ingredientov_dlya_beremennih_15$, NULL::text, 15),
  ('cee4416a-c243-5d11-88ba-852206fc5156'::uuid, 'paragraph', $b_5_opasnih_ingredientov_dlya_beremennih_16$Но в США, а также странах Евросоюза они разрешены, но только в тех средствах, которые не остаются на коже. У нас их использование законодательно не регулируется никак.$b_5_opasnih_ingredientov_dlya_beremennih_16$, NULL::text, 16)
) AS v(id, block_type, text_content, image_url, sort_order)
JOIN public.articles a
  ON a.slug = $join_5_opasnih_ingredientov_dlya_beremennih$5-opasnih-ingredientov-dlya-beremennih$join_5_opasnih_ingredientov_dlya_beremennih$
WHERE NOT EXISTS (
  SELECT 1
  FROM public.article_blocks b
  WHERE b.article_id = a.id
    AND b.id <> ALL (ARRAY['ac232c82-e1e9-55b3-92ea-3fe38599ef43'::uuid, '4d3aff4c-83f0-58f7-a4b0-0a76e1a25e29'::uuid, 'e87a0c7e-c349-5c88-858c-e6177eb4873d'::uuid, '0dc16032-32a9-581e-80e3-0f68de7a1aa3'::uuid, '5e87646e-a265-55f6-ae15-42f3ddcae6b8'::uuid, 'fd87507c-b736-5c34-9a6f-41eacfadd2a3'::uuid, 'f0c6ff0c-e572-521b-9d23-52a6bcb7ed9a'::uuid, 'efb13078-a30f-585e-9781-8f33294a7b41'::uuid, '883cdee4-05c7-507a-a7c7-e3bfb5db5c52'::uuid, 'ec5c060e-3fe1-5172-b572-676c74572ddd'::uuid, 'f44887f9-6f3b-58a4-bd52-4d50dbe32977'::uuid, 'a6a7b70b-3d15-5dcc-ac1e-c2058eba335c'::uuid, 'bd82b193-106a-52d2-8b3e-af00e60c0d6f'::uuid, '0eb7fe06-f2ad-5ac5-9ad4-e606d0f5cbf5'::uuid, '99186570-c42e-50e9-9e86-fc0c9a73952c'::uuid, 'cee4416a-c243-5d11-88ba-852206fc5156'::uuid])
)
ON CONFLICT (id) DO NOTHING;

-- МИФЫ ОБ SPF  https://tiffani.md/tpost/x5ro5hd1e1-mifi-ob-spf
INSERT INTO public.article_blocks (
  id, article_id, block_type, text_content, image_url, sort_order
)
SELECT v.id, a.id, v.block_type, v.text_content, v.image_url, v.sort_order
FROM (VALUES
  ('3867dc72-055e-591d-abf7-1237d87a1d07'::uuid, 'heading', $b_mifi_ob_spf_1$МИФ №1$b_mifi_ob_spf_1$, NULL::text, 1),
  ('7655bdb0-0f62-5568-aea1-a87d34a01358'::uuid, 'paragraph', $b_mifi_ob_spf_2$SPF нужен только летом и на пляже.$b_mifi_ob_spf_2$, NULL::text, 2),
  ('0a7cd93f-9aad-5edf-ba2a-7f5baa6e6846'::uuid, 'paragraph', $b_mifi_ob_spf_3$— УФ-лучи активны круглый год.
Даже в пасмурную погоду до 80% UVA-лучей проникают через облака. А в городе мы сталкиваемся еще и с HEV-светом от гаджетов.$b_mifi_ob_spf_3$, NULL::text, 3),
  ('b375a7f9-e7fe-519b-93cb-9857961d8f2c'::uuid, 'paragraph', $b_mifi_ob_spf_4$РЕШЕНИЕ: используйте солнцезащитный крем каждый день, обновляйте его кушоном, стиком или спреем, особенно в солнечный день!$b_mifi_ob_spf_4$, NULL::text, 4),
  ('9661b347-9291-52c8-b19f-730e62c8b52f'::uuid, 'heading', $b_mifi_ob_spf_5$МИФ №2$b_mifi_ob_spf_5$, NULL::text, 5),
  ('be3e849d-0e91-5d0c-b442-d058674e7d3a'::uuid, 'paragraph', $b_mifi_ob_spf_6$Если в тональном креме есть SPF, этого достаточно.$b_mifi_ob_spf_6$, NULL::text, 6),
  ('6b8ba1bf-f77a-51b4-874b-8fe27e805fc1'::uuid, 'paragraph', $b_mifi_ob_spf_7$— Чтобы получить нужный уровень защиты, тонального крема нужно нанести в 6-7 раз больше, чем обычно, чтобы обеспечить полноценную защиту.$b_mifi_ob_spf_7$, NULL::text, 7),
  ('b629774f-3c7b-5fc0-8394-7c7e281a2706'::uuid, 'paragraph', $b_mifi_ob_spf_8$РЕШЕНИЕ: наносите отдельный солнцезащитный крем перед макияжем, например на химических фильтрах - они легкие по текстуре и могут заменить ваш дневной крем.$b_mifi_ob_spf_8$, NULL::text, 8),
  ('519c682b-c71b-52e0-a522-615badcad0db'::uuid, 'heading', $b_mifi_ob_spf_9$МИФ №3$b_mifi_ob_spf_9$, NULL::text, 9),
  ('b0d70662-40c5-516e-a7c6-0aa3707c5f26'::uuid, 'paragraph', $b_mifi_ob_spf_10$Солнцезащитные средства не нужны, это просто маркетинг.$b_mifi_ob_spf_10$, NULL::text, 10),
  ('0669f4d5-1737-53cd-8465-504eef92296e'::uuid, 'paragraph', $b_mifi_ob_spf_11$— УФ-лучи приводят к преждевременному старению кожи и гиперпигментации, увеличивает количество морщин, а также избыточное излучение вызывает солнечные ожоги.$b_mifi_ob_spf_11$, NULL::text, 11),
  ('ed656af9-1bfc-519a-9349-b45a7c488a0f'::uuid, 'paragraph', $b_mifi_ob_spf_12$ВЫВОД: SPF-крем нужен всегда и везде для сохранения здоровья и молодости кожи!$b_mifi_ob_spf_12$, NULL::text, 12)
) AS v(id, block_type, text_content, image_url, sort_order)
JOIN public.articles a
  ON a.slug = $join_mifi_ob_spf$mifi-ob-spf$join_mifi_ob_spf$
WHERE NOT EXISTS (
  SELECT 1
  FROM public.article_blocks b
  WHERE b.article_id = a.id
    AND b.id <> ALL (ARRAY['3867dc72-055e-591d-abf7-1237d87a1d07'::uuid, '7655bdb0-0f62-5568-aea1-a87d34a01358'::uuid, '0a7cd93f-9aad-5edf-ba2a-7f5baa6e6846'::uuid, 'b375a7f9-e7fe-519b-93cb-9857961d8f2c'::uuid, '9661b347-9291-52c8-b19f-730e62c8b52f'::uuid, 'be3e849d-0e91-5d0c-b442-d058674e7d3a'::uuid, '6b8ba1bf-f77a-51b4-874b-8fe27e805fc1'::uuid, 'b629774f-3c7b-5fc0-8394-7c7e281a2706'::uuid, '519c682b-c71b-52e0-a522-615badcad0db'::uuid, 'b0d70662-40c5-516e-a7c6-0aa3707c5f26'::uuid, '0669f4d5-1737-53cd-8465-504eef92296e'::uuid, 'ed656af9-1bfc-519a-9349-b45a7c488a0f'::uuid])
)
ON CONFLICT (id) DO NOTHING;

COMMIT;

-- Verification, run separately after COMMIT. Do not publish from this file.
--
-- SELECT slug, title, is_published, published_at,
--        left(excerpt, 80) AS excerpt_prefix,
--        cover_image_url
-- FROM public.articles
-- WHERE slug IN (
--   'mikrobiom',
--   'top-5-oshibok-pri-vibore-kosmetiki',
--   'akne',
--   '5-opasnih-ingredientov-dlya-beremennih',
--   'mifi-ob-spf',
-- )
-- ORDER BY published_at;
--
-- SELECT a.slug,
--        count(b.id) AS blocks,
--        count(*) FILTER (WHERE b.block_type = 'heading') AS headings,
--        count(*) FILTER (WHERE b.block_type = 'paragraph') AS paragraphs,
--        count(*) FILTER (WHERE b.block_type = 'image') AS images,
--        count(*) FILTER (WHERE b.block_type = 'quote') AS quotes
-- FROM public.articles a
-- LEFT JOIN public.article_blocks b ON b.article_id = a.id
-- WHERE a.slug IN (
--   'mikrobiom',
--   'top-5-oshibok-pri-vibore-kosmetiki',
--   'akne',
--   '5-opasnih-ingredientov-dlya-beremennih',
--   'mifi-ob-spf',
-- )
-- GROUP BY a.slug
-- ORDER BY a.slug;
--
-- SELECT count(*) AS published_drafts_leaked
-- FROM public.articles
-- WHERE slug IN (
--   'mikrobiom',
--   'top-5-oshibok-pri-vibore-kosmetiki',
--   'akne',
--   '5-opasnih-ingredientov-dlya-beremennih',
--   'mifi-ob-spf',
-- )
--   AND is_published;
