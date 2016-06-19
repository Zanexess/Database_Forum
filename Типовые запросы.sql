-- Отобразить все форумы в какой-то категории
SELECT * FROM forum as f JOIN forum_info as fi ON f.id_forum = fi.id_forum WHERE id_category = 1;

-- Отобразить все топики в форуме, отображая сначала все важные
SELECT t.id_topic, id_author, title, text, is_important, is_active, is_approved, date_of_creation
  FROM forum_topic as ft JOIN topic as t ON ft.id_topic = t.id_topic
  WHERE id_forum = 3 ORDER BY is_important DESC;

-- Отобразить все посты из топика.
SELECT id_author, title, text, subtext, date_of_creation, date_last_edit, rate FROM post as p JOIN topic_post as tp ON (p.id_post = tp.id_post)
  WHERE id_topic = 5
  ORDER BY p.id_post;

-- Отобразить топик и все посты после по времени создания
SELECT * FROM (
  SELECT id_author, title, text, null, date_of_creation as dc, date_of_creation, NULL FROM topic WHERE id_topic = 5
    UNION
  SELECT id_author, title, text, subtext, date_of_creation as dc, date_last_edit, rate
    FROM post as p JOIN topic_post as tp ON (p.id_post = tp.id_post)
    WHERE id_topic = 5) as l ORDER BY dc;
