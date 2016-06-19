CREATE TABLE IF NOT EXISTS role (
  id_role SERIAL NOT NULL PRIMARY KEY,
  title VARCHAR(255) NOT NULL,
  description TEXT,
  "type" VARCHAR(10)
);

CREATE TABLE IF NOT EXISTS "user" (
  id_user SERIAL NOT NULL PRIMARY KEY,
  nickname VARCHAR(32) NOT NULL,
  e_mail VARCHAR(128) NOT NULL,
  password VARCHAR(64) NOT NULL,
  date_of_registration TIMESTAMPTZ NOT NULL,
  id_role INTEGER NOT NULL,

--   Внешний ключ на роли. Связь 1 к 1. При удалении или изменении не делать ничего.
  CONSTRAINT id_user_id_role_fk FOREIGN KEY (id_role) REFERENCES role(id_role) ON DELETE NO ACTION ON UPDATE NO ACTION,
--   Простая проверка корректности почты. Основная проверка обычно проверяется отправкой письма.
  CONSTRAINT check_email CHECK (e_mail ~* '^[A-Za-z0-9._%-]+@[A-Za-z0-9.-]+[.][A-Za-z]+$')
);

CREATE TABLE user_info (
  id_user_info SERIAL NOT NULL PRIMARY KEY,
  id_user INTEGER NOT NULL,
  rate INTEGER NOT NULL DEFAULT 0,
  num_message INTEGER NOT NULL DEFAULT 0,
  date_last_visit TIMESTAMPTZ NOT NULL,
  is_banned BOOLEAN DEFAULT FALSE,
--   Соответствие пользователю, удаляем и изменяет соответственно
  CONSTRAINT id_user_id_user_fk FOREIGN KEY (id_user) REFERENCES "user"(id_user) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT check_num_message CHECK (num_message >= 0)
);

CREATE TABLE IF NOT EXISTS category (
  id_category SERIAL NOT NULL PRIMARY KEY,
  title VARCHAR(255) NOT NULL
);

CREATE TABLE IF NOT EXISTS forum (
  id_forum SERIAL NOT NULL PRIMARY KEY,
  id_category INTEGER NOT NULL,
  title VARCHAR(255) NOT NULL,
  description TEXT,
  CONSTRAINT id_category_forum_id_category_fk FOREIGN KEY (id_category) REFERENCES category(id_category) ON DELETE NO ACTION ON UPDATE NO ACTION
);

CREATE TABLE IF NOT EXISTS forum_info (
  id_forum_info SERIAL NOT NULL PRIMARY KEY,
  id_forum INTEGER NOT NULL,
  num_posts INTEGER NOT NULL DEFAULT 0,
  last_post_id INTEGER,
  last_post_author_id INTEGER,
  last_post_timestamp TIMESTAMPTZ,
  CONSTRAINT id_forum_info_id_forum_fk FOREIGN KEY (id_forum) REFERENCES forum(id_forum) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT check_num_posts CHECK (num_posts >= 0)
);

CREATE TABLE IF NOT EXISTS topic (
  id_topic SERIAL NOT NULL PRIMARY KEY,
  id_author INTEGER NOT NULL,
  title VARCHAR(255) NOT NULL,
  text TEXT NOT NULL,
  is_important BOOLEAN NOT NULL DEFAULT FALSE,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  is_approved BOOLEAN NOT NULL DEFAULT FALSE,
  date_of_creation TIMESTAMPTZ,
  CONSTRAINT topic_id_author_id_user_fk FOREIGN KEY (id_author) REFERENCES "user"(id_user) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE IF NOT EXISTS topic_info (
  id_topic_info SERIAL NOT NULL PRIMARY KEY,
  id_topic INTEGER NOT NULL,
  rate INTEGER NOT NULL DEFAULT 0,
  num_posts INTEGER NOT NULL DEFAULT 0,
  last_post_author_id INTEGER,
  last_post_timestamp TIMESTAMPTZ,
--   Соответствие топику
  CONSTRAINT id_topic_id_topic_fk FOREIGN KEY (id_topic) REFERENCES topic(id_topic) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT check_num_posts CHECK (num_posts >= 0)
);

-- Меняется редко, поэтому нет отдельной таблички.
CREATE TABLE IF NOT EXISTS post (
  id_post SERIAL NOT NULL PRIMARY KEY,
  id_author INTEGER NOT NULL,
  title VARCHAR(255),
  text TEXT NOT NULL,
  subtext TEXT DEFAULT '',
  date_of_creation TIMESTAMPTZ,
  date_last_edit TIMESTAMPTZ,
  rate INTEGER NOT NULL DEFAULT 0,
  CONSTRAINT post_id_author_id_user_fk FOREIGN KEY (id_author) REFERENCES "user"(id_user) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE IF NOT EXISTS forum_topic (
  id_forum INTEGER NOT NULL,
  id_topic INTEGER NOT NULL,
  CONSTRAINT forum_topic_id_forum_fk FOREIGN KEY (id_forum) REFERENCES forum(id_forum) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT forum_topic_id_topic_fk FOREIGN KEY (id_topic) REFERENCES topic(id_topic) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE IF NOT EXISTS topic_post (
  id_topic INTEGER NOT NULL,
  id_post INTEGER NOT NULL,
  CONSTRAINT topic_post_id_topic_fk FOREIGN KEY (id_topic) REFERENCES topic(id_topic) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT topic_post_id_post_fk FOREIGN KEY (id_post) REFERENCES post(id_post) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE IF NOT EXISTS moderator_forum (
  id_forum INTEGER NOT NULL,
  id_user INTEGER NOT NULL,
  CONSTRAINT moderator_forum_id_forum_fk FOREIGN KEY (id_forum) REFERENCES forum(id_forum),
  CONSTRAINT moderator_forum_id_user_fk FOREIGN KEY (id_user) REFERENCES "user"(id_user)
);