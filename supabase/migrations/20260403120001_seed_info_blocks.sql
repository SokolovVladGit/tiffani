-- ============================================================
-- Seed data for info_blocks
-- ============================================================

-- 1. HERO
INSERT INTO info_blocks (block_type, sort_order, title, subtitle, image_url)
VALUES (
  'hero',
  1,
  'Доставка и обслуживание',
  'Быстро, удобно и с заботой о вашем выборе',
  'https://plus.unsplash.com/premium_photo-1661394793076-ac3a20f9bb9b?w=500&auto=format&fit=crop&q=60&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxzZWFyY2h8MTQyfHxkZWxpdmVyeSUyMG1hbnxlbnwwfHwwfHx8MA%3D%3D'
);

-- 2. DELIVERY
INSERT INTO info_blocks (block_type, sort_order, title, items_json)
VALUES (
  'delivery',
  2,
  'Доставка',
  '{
    "regions": [
      {
        "region": "Приднестровье",
        "price_lines": [
          "Доставка курьером по Тирасполю — 50 руб",
          "Доставка курьером по Бендерам — 40 руб",
          "Доставка Экспресс-почтой по НС Приднестровья — 40 руб"
        ],
        "free_delivery_note": "Есть бесплатная доставка при заказе от 1000 руб",
        "disclaimer": "Более точные условия уточняет менеджер после оформления заказа в зависимости от направления",
        "timing_lines": [
          "Тирасполь и Бендеры: как правило доставка осуществляется в течение 1–2 дней с момента оформления заказа",
          "Исключения составляют только выходные и праздничные дни, детали оговариваются менеджером индивидуально после оформления заказа",
          "Все остальные пункты ПМР: в течение 2–3 рабочих дней"
        ],
        "payment_note": "Наложенного платежа нет. Отправление заказа осуществляется только после полной его оплаты. Детали уточняйте у вашего менеджера."
      },
      {
        "region": "Молдова / Гагаузия",
        "price_lines": [
          "Почтой Молдовы (в зависимости от объема) — от 30 лей"
        ],
        "free_delivery_note": "Есть бесплатная доставка при заказе от 1000 лей",
        "disclaimer": "Более точные условия уточняет менеджер после оформления заказа в зависимости от направления",
        "timing_lines": [
          "Молдова и Гагаузия: в течение 2–3 рабочих дней",
          "Исключения составляют праздничные и выходные дни"
        ],
        "payment_note": "Наложенного платежа нет. Отправление заказа осуществляется только после полной его оплаты. Детали уточняйте у вашего менеджера."
      }
    ]
  }'::jsonb
);

-- 3. STORES
INSERT INTO info_blocks (block_type, sort_order, title, subtitle, items_json)
VALUES (
  'stores',
  3,
  'Наши магазины',
  'Консультация и подбор в уютной атмосфере',
  '{
    "stores": [
      {
        "name": "Центральный магазин",
        "city": "Тирасполь",
        "address": "ул. 25 Октября 94",
        "phone": "+373 779 76 364",
        "working_hours": "с 9:00 до 20:00 без выходных",
        "image_url": "https://images.unsplash.com/photo-1736236279745-b2c000357470?w=500&auto=format&fit=crop&q=60&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxzZWFyY2h8OHx8YmVhdXR5JTIwc3RvcmV8ZW58MHx8MHx8fDA%3D"
      },
      {
        "name": "Магазин на Балке",
        "city": "Тирасполь",
        "address": "ул. Юности 18/1",
        "phone": "+373 778 76 364",
        "working_hours": "с 9:00 до 20:00 без выходных",
        "image_url": "https://images.unsplash.com/photo-1568386453619-84c3ff4b43c5?w=500&auto=format&fit=crop&q=60&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxzZWFyY2h8M3x8YmVhdXR5JTIwc3RvcmV8ZW58MHx8MHx8fDA%3D"
      },
      {
        "name": "Магазин в Бендерах",
        "city": "Бендеры",
        "address": "ул. Ленина 15, ТЦ «Пассаж» бутик №14",
        "phone": "+373 777 80 997",
        "working_hours": "с 9:00 до 20:00 без выходных",
        "image_url": "https://media.istockphoto.com/id/1536715711/photo/woman-making-photo-of-cream-on-her-smartphone.webp?a=1&b=1&s=612x612&w=0&k=20&c=ICvl385T8jgGEXoJdHNkqaEua-qLJgoPVlNdzdISJcM="
      }
    ]
  }'::jsonb
);

-- 4. GALLERY
INSERT INTO info_blocks (block_type, sort_order, title, items_json)
VALUES (
  'gallery',
  4,
  'Галерея',
  '{
    "images": [
      {
        "image_url": "https://static.tildacdn.one/tild3666-3832-4737-a361-633563643862/IMG_0993.JPG",
        "sort_order": 1
      },
      {
        "image_url": "https://static.tildacdn.one/tild3866-6237-4131-a135-303134613636/348464551_5766572712.jpg",
        "sort_order": 2
      },
      {
        "image_url": "https://static.tildacdn.one/tild3863-3463-4534-a463-636466326630/348876073_9485986896.jpg",
        "sort_order": 3
      }
    ]
  }'::jsonb
);

-- 5. CTA
INSERT INTO info_blocks (block_type, sort_order, title, subtitle, items_json)
VALUES (
  'cta',
  5,
  'Поможем подобрать уход',
  'Оставьте заявку, и мы поможем подобрать продукты под ваш запрос',
  '{
    "button_label": "Оставить заявку",
    "fields": ["name", "phone"],
    "note": null
  }'::jsonb
);
