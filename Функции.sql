-- Регистрация нового пользователя
CREATE OR REPLACE FUNCTION fn_register(nick VARCHAR(32), email VARCHAR(128), password VARCHAR(64))
	RETURNS BOOLEAN AS $$
DECLARE 
  id_new_user INTEGER;
BEGIN
	IF EXISTS (SELECT * FROM "user" WHERE nick = nickname OR email = e_mail)
	THEN
		RETURN FALSE;
	END IF;
	INSERT INTO "user" (nickname, e_mail, password, date_of_registration, id_role)
    VALUES (nick, email, password, now(), 3);

  SELECT id_user INTO id_new_user FROM "user" WHERE nick = nickname AND email = e_mail;

  INSERT INTO user_info (id_user, rate, num_message, date_last_visit, is_banned)
    VALUES (id_new_user, 0, 0, now(), FALSE);

	RETURN TRUE;
END;
$$ LANGUAGE plpgsql;
SELECT fn_register('new_user', 'new_user@mail.ru', 'password');

-- Добавить новый пост в топик
CREATE OR REPLACE FUNCTION fn_write_post(mtopic INTEGER, mauthor INTEGER, mtitle VARCHAR(255), mtext TEXT, msubtext TEXT)
	RETURNS BOOLEAN AS $$
DECLARE
	id_new_post INTEGER;
	id_new_forum INTEGER;
	time_now TIMESTAMPTZ;
	is_active_var BOOLEAN;
	is_banned_var BOOLEAN;
BEGIN
	time_now = now();
-- 	проверяем, забанен ли пользователь
	SELECT is_banned INTO is_banned_var FROM user_info WHERE id_user = mauthor;
	IF is_banned_var THEN RETURN FALSE; END IF;
-- 	узнаем, активная ли тема
	SELECT is_active INTO is_active_var FROM topic WHERE id_topic = 5;
	IF NOT is_active_var THEN RETURN FALSE; END IF;
-- 	Новый пост
	INSERT INTO post as p(id_author, title, text, subtext, date_of_creation, date_last_edit, rate) VALUES
		(mauthor, mtitle, mtext, msubtext, time_now, time_now, 0);
-- 	id нового поста
	SELECT id_post INTO id_new_post FROM post as p WHERE mauthor = p.id_author AND mtext = p.text AND p.date_of_creation = time_now;
	IF id_new_post IS NULL THEN
		RETURN FALSE;
	END IF;
-- 	делаем пометку, что пост прикреплен к нужному топику
	INSERT INTO topic_post (id_topic, id_post) VALUES (mtopic, id_new_post);
-- 	Увеличиваем счетчик нужной темы
	UPDATE topic_info SET num_posts = num_posts + 1 WHERE mtopic = id_topic;
-- 	Находим форум, в который мы добавили пост
	SELECT id_forum INTO id_new_forum FROM topic JOIN forum_topic ON (topic.id_topic = forum_topic.id_topic)
		WHERE topic.id_topic = mtopic;
-- 	Обновляем информацию о форуме
	UPDATE forum_info
	SET num_posts = num_posts + 1, last_post_author_id = mauthor, last_post_id = id_new_post, last_post_timestamp = time_now
	WHERE id_forum = id_new_forum;
-- 	Увеличиваем счетчик сообщений пользователю.
	UPDATE user_info SET num_message = num_message + 1 WHERE id_user = mauthor;
	RETURN TRUE;
END;
$$ LANGUAGE plpgsql;
SELECT fn_write_post(5, 21, 'Заголовок', 'Классный сериал!!!', NULL);

-- Посчитать количество сообщений в топике.
CREATE OR REPLACE FUNCTION fn_get_count_topic_msg (id INTEGER)
	RETURNS INTEGER AS $$
DECLARE
	id_count INTEGER;
BEGIN
	SELECT count(*) + 1 INTO id_count FROM topic JOIN topic_post ON (topic.id_topic = topic_post.id_topic) JOIN post ON (topic_post.id_post = post.id_post)
		WHERE topic.id_topic = id;
	RETURN id_count;
END
$$ LANGUAGE plpgsql;
SELECT fn_get_count_topic_msg(4);

-- Посчитать количество сообщений в форуме
CREATE OR REPLACE FUNCTION fn_get_count_forum_msg (id INTEGER)
	RETURNS INTEGER AS $$
DECLARE
	topics forum_topic%ROWTYPE;
	total_amount INTEGER;
BEGIN
	total_amount = 0;
	FOR topics IN SELECT id_topic FROM forum_topic
    WHERE id_forum = id
    LOOP
				total_amount = total_amount + fn_get_count_topic_msg(topics.id_forum);
    END LOOP;
	RETURN total_amount;
END;
$$ LANGUAGE plpgsql;
SELECT fn_get_count_forum_msg(3);

-- Посчитать количество сообщений в категории
CREATE OR REPLACE FUNCTION fn_get_count_category_msg (id INTEGER)
	RETURNS INTEGER AS $$
DECLARE
	forums forum%ROWTYPE;
	total_amount INTEGER;
BEGIN
	total_amount = 0;
	FOR forums IN SELECT id_forum FROM forum
		WHERE id_category = id
		LOOP
			total_amount = total_amount + fn_get_count_forum_msg(forums.id_forum);
		END LOOP;
	RETURN total_amount;
END;
$$ LANGUAGE plpgsql;
SELECT fn_get_count_category_msg(1);

-- Отобразить все форумы в категории
CREATE OR REPLACE FUNCTION fn_get_categories (id INTEGER)
	RETURNS TABLE (
		id_forum INTEGER,
		title VARCHAR(255),
		description TEXT,
		num_posts INTEGER,
		last_post_id INTEGER,
		last_post_author_id INTEGER,
		last_post_timestamp TIMESTAMPTZ
	) AS $$
BEGIN
	RETURN QUERY
		SELECT f.id_forum, f.title, f.description, fi.num_posts, fi.last_post_id, fi.last_post_author_id, fi.last_post_timestamp
			FROM forum as f JOIN forum_info as fi ON f.id_forum = fi.id_forum WHERE id_category = id;
END;
$$ LANGUAGE plpgsql;
SELECT * FROM fn_get_categories(1);


-- Отобразить все топики в форуме, отображая сначала все важные
CREATE OR REPLACE FUNCTION fn_get_topics_by_important (id INTEGER)
	RETURNS TABLE (
		id_topic INTEGER,
		id_author INTEGER,
		title VARCHAR(255),
		text TEXT,
		is_important BOOLEAN,
		is_active BOOLEAN,
		is_approved BOOLEAN,
		date_of_creation TIMESTAMPTZ
	) AS $$
BEGIN
	RETURN QUERY
		SELECT t.id_topic, t.id_author, t.title, t.text, t.is_important, t.is_active, t.is_approved, t.date_of_creation
  		FROM forum_topic as ft JOIN topic as t ON ft.id_topic = t.id_topic
  		WHERE id_forum = id ORDER BY is_important DESC;
END;
$$ LANGUAGE plpgsql;
SELECT * FROM fn_get_topics_by_important(3);


-- Отобразить топик и все посты после по времени создания
CREATE OR REPLACE FUNCTION fn_get_topics_with_posts (id INTEGER)
	RETURNS TABLE (
		id_author INTEGER,
		title VARCHAR(255),
		text TEXT,
		subtext TEXT,
		date_of_creation TIMESTAMPTZ,
		date_last_edit TIMESTAMPTZ,
		rate INTEGER
	) AS $$
BEGIN
	RETURN QUERY
		SELECT * FROM (
  		SELECT t.id_author, t.title, t.text, null, t.date_of_creation as dc, t.date_of_creation, NULL FROM topic as t WHERE t.id_topic = id
    		UNION
  		SELECT p.id_author, p.title, p.text, p.subtext, p.date_of_creation as dc, p.date_last_edit, p.rate
    		FROM post as p JOIN topic_post as tp ON (p.id_post = tp.id_post)
    		WHERE id_topic = id) as l ORDER BY dc;
END;
$$ LANGUAGE plpgsql;
SELECT * FROM fn_get_topics_with_posts(5);

-- Обновить количество сообщений во всех форумах и топиках
CREATE OR REPLACE FUNCTION fn_refresh_num_count_forums_topics()
	RETURNS VOID AS $$
DECLARE
	forums forum%ROWTYPE;
	topics topic%ROWTYPE;
BEGIN
	FOR forums IN SELECT id_forum FROM forum
		LOOP
			UPDATE forum_info
			SET num_posts = fn_get_count_forum_msg(forums.id_forum)
			WHERE forums.id_forum = forum_info.id_forum;
		END LOOP;
	FOR topics IN SELECT id_topic FROM topic
		LOOP
			UPDATE topic_info
			SET num_posts = fn_get_count_topic_msg(topics.id_topic)
			WHERE topics.id_topic = topic_info.id_topic;
		END LOOP;
END;
$$ LANGUAGE plpgsql;
SELECT fn_refresh_num_count_forums_topics();

-- Обновить количество сообщений пользователей
CREATE OR REPLACE FUNCTION fn_refresh_num_count_users()
	RETURNS VOID AS $$
DECLARE
	users "user"%ROWTYPE;
BEGIN
	FOR users IN SELECT id_user FROM "user"
		LOOP
		UPDATE user_info
		SET num_message = (SELECT count(*) FROM post WHERE id_author = users.id_user)
		WHERE users.id_user = user_info.id_user;
		END LOOP;
END;
$$ LANGUAGE plpgsql;
SELECT fn_refresh_num_count_users();

-- Создать топик. Могут все.
CREATE OR REPLACE FUNCTION fn_write_topic(mforum INTEGER,mauthor INTEGER, mtitle VARCHAR(255), mtext TEXT)
	RETURNS BOOLEAN AS $$
DECLARE
	time_now TIMESTAMPTZ;
	id_new_topic INTEGER;
	is_banned_var BOOLEAN;
BEGIN
	time_now = now();
-- 	проверяем, забанен ли пользователь
	SELECT is_banned INTO is_banned_var FROM user_info WHERE id_user = mauthor;
	IF is_banned_var THEN RETURN FALSE; END IF;
-- 	Новый топик
	INSERT INTO topic (id_author, title, text, is_important, is_active, is_approved, date_of_creation)
		VALUES (mauthor, mtitle, mtext, FALSE, TRUE, FALSE, time_now) RETURNING id_topic INTO id_new_topic;
-- 	id нового топика
-- 	делаем пометку, что топик прикреплен к нужному форуму
	INSERT INTO forum_topic (id_forum, id_topic) VALUES (mforum, id_new_topic);
-- 	Добавляем topic_info
	INSERT INTO topic_info (id_topic, rate, num_posts, last_post_author_id, last_post_timestamp)
		VALUES (id_new_topic, 0, 1, mauthor, time_now);
-- 	Увеличиваем счетчик нужного форума
	UPDATE forum_info SET num_posts = num_posts + 1 WHERE mforum = forum_info.id_forum;
-- 	Увеличиваем счетчик сообщений пользователя
	UPDATE user_info SET num_message = num_message + 1
		WHERE mauthor = user_info.id_user;
	RETURN TRUE;
END;
$$ LANGUAGE plpgsql;
SELECT fn_write_topic(7, 21, 'Видеокарты', 'Обсуждаем видеокарты');

-- Создать форум. Могут только администраторы
CREATE OR REPLACE FUNCTION fn_write_forum(mcategory INTEGER, mauthor INTEGER, mtitle VARCHAR(255), mdescription TEXT)
	RETURNS BOOLEAN AS $$
DECLARE
	user_role INTEGER;
	id_new_forum INTEGER;
BEGIN
	SELECT id_role INTO user_role FROM "user" WHERE id_user = mauthor;
	IF NOT (user_role = 1) THEN
		RETURN FALSE;
	END IF;
-- 	Новый форум
	INSERT INTO forum (id_category, title, description) VALUES
		(mcategory, mtitle, mdescription) RETURNING id_forum INTO id_new_forum;
	INSERT INTO forum_info (id_forum, num_posts, last_post_id, last_post_author_id, last_post_timestamp) VALUES
		(id_new_forum, 0, NULL, NULL, NULL);
	RETURN TRUE;
END;
$$ LANGUAGE plpgsql;
SELECT fn_write_forum(2, 1, 'Ваше творчество', 'Стихи, рассказы и прочее творчество, написанное вами');

-- Создать категорию. Могут только администраторы
CREATE OR REPLACE FUNCTION fn_write_category(mauthor INTEGER, mtitle VARCHAR(255))
	RETURNS BOOLEAN AS $$
DECLARE
	user_role INTEGER;
	num INTEGER;
BEGIN
	SELECT id_role INTO user_role FROM "user" WHERE id_user = mauthor;
	IF NOT (user_role = 1) THEN
		RETURN FALSE;
	END IF;
	SELECT count(*) INTO num FROM category WHERE mtitle = title;
	if num = 0 THEN
		INSERT INTO category (title) VALUES (mtitle);
		RETURN TRUE;
	END IF;
	RETURN FALSE;
END;
$$ LANGUAGE plpgsql;
SELECT fn_write_category(2, 'Тестовая комната');

-- Забанить человека. Могут только модераторы и администраторы
CREATE OR REPLACE FUNCTION fn_ban_user(mauthor INTEGER, muser INTEGER)
	RETURNS BOOLEAN AS $$
DECLARE
	user_role INTEGER;
BEGIN
	SELECT id_role INTO user_role FROM "user" WHERE id_user = mauthor;
	IF NOT (user_role = 1 OR user_role = 2) THEN
		RETURN FALSE;
	END IF;
	UPDATE user_info
	SET is_banned = TRUE
	WHERE muser = id_user;
	RETURN TRUE;
END;
$$ LANGUAGE plpgsql;
SELECT fn_ban_user(1, 10);

-- Сменить роль человека. Могут только администраторы
CREATE OR REPLACE FUNCTION fn_change_role_user(mauthor INTEGER, muser INTEGER, mrole INTEGER)
	RETURNS BOOLEAN AS $$
DECLARE
	user_role INTEGER;
BEGIN
	SELECT id_role INTO user_role FROM "user" WHERE id_user = mauthor;
	IF NOT (user_role = 1) THEN
		RETURN FALSE;
	END IF;
	UPDATE "user"
	SET id_role = mrole
	WHERE muser = id_user;
	RETURN TRUE;
END;
$$ LANGUAGE plpgsql;
SELECT fn_change_role_user(1, 9, 2);

-- Удалить категорию. Только администраторы.
CREATE OR REPLACE FUNCTION fn_delete_category(mauthor INTEGER, mcategory INTEGER)
	RETURNS BOOLEAN AS $$
DECLARE
	user_role INTEGER;
	forums forum%ROWTYPE;
	topics topic%ROWTYPE;
	posts post%ROWTYPE;
BEGIN
	SELECT id_role INTO user_role FROM "user" WHERE id_user = mauthor;
	IF NOT (user_role = 1) THEN
		RETURN FALSE;
	END IF;
-- 	Удаляем все посты в категории.
	FOR posts IN SELECT tp.id_post FROM forum_topic as ft JOIN forum ON ft.id_forum = forum.id_forum JOIN topic_post as tp ON ft.id_topic = tp.id_topic
		WHERE id_category = mcategory
	LOOP
		DELETE FROM post WHERE id_post = posts.id_post;
		DELETE FROM topic_post WHERE id_post = posts.id_post;
	END LOOP;
-- 	Удаляем всю информацию о топиках
	FOR topics IN SELECT ft.id_topic FROM forum_topic as ft JOIN forum ON ft.id_forum = forum.id_forum
		WHERE id_category = mcategory
	LOOP
		DELETE FROM topic WHERE id_topic = topics.id_topic;
		DELETE FROM topic_info WHERE id_topic = topics.id_topic;
		DELETE FROM forum_topic WHERE id_topic = topics.id_topic;
	END LOOP;
	FOR forums IN SELECT id_forum FROM forum WHERE id_category = mcategory
		LOOP
			DELETE FROM moderator_forum WHERE id_forum = forums.id_forum;
			DELETE FROM forum WHERE id_forum = forums.id_forum;
			DELETE FROM forum_info WHERE id_forum = forums.id_forum;
		END LOOP;
	DELETE FROM category WHERE id_category = mcategory;
	PERFORM fn_refresh_num_count_forums_topics();
	PERFORM fn_refresh_num_count_users();
	RETURN TRUE;
END;
$$ LANGUAGE plpgsql;
SELECT fn_delete_category(1, 1);

-- Удалить форум. Могут только администраторы
CREATE OR REPLACE FUNCTION fn_delete_forum(mauthor INTEGER, mforum INTEGER)
	RETURNS BOOLEAN AS $$
DECLARE
	user_role INTEGER;
	forums forum%ROWTYPE;
	topics topic%ROWTYPE;
	posts post%ROWTYPE;
BEGIN
	SELECT id_role INTO user_role FROM "user" WHERE id_user = mauthor;
	IF NOT (user_role = 1) THEN
		RETURN FALSE;
	END IF;
-- 	Удаляем все посты в форуме.
	FOR posts IN SELECT tp.id_post FROM forum_topic as ft JOIN forum ON ft.id_forum = forum.id_forum JOIN topic_post as tp ON ft.id_topic = tp.id_topic
		WHERE forum.id_forum = mforum
	LOOP
		DELETE FROM post WHERE id_post = posts.id_post;
		DELETE FROM topic_post WHERE id_post = posts.id_post;
	END LOOP;
-- 	Удаляем всю информацию о топиках
	FOR topics IN SELECT ft.id_topic FROM forum_topic as ft JOIN forum ON ft.id_forum = forum.id_forum
		WHERE forum.id_forum = mforum
	LOOP
		DELETE FROM topic WHERE id_topic = topics.id_topic;
		DELETE FROM topic_info WHERE id_topic = topics.id_topic;
		DELETE FROM forum_topic WHERE id_topic = topics.id_topic;
	END LOOP;
	FOR forums IN SELECT id_forum FROM forum WHERE id_forum = mforum
		LOOP
			DELETE FROM moderator_forum WHERE id_forum = forums.id_forum;
			DELETE FROM forum WHERE id_forum = forums.id_forum;
			DELETE FROM forum_info WHERE id_forum = forums.id_forum;
		END LOOP;
	PERFORM fn_refresh_num_count_forums_topics();
	PERFORM fn_refresh_num_count_users();
	RETURN TRUE;
END;
$$ LANGUAGE plpgsql;
SELECT fn_delete_forum(1, 3);

-- Удалить топик. Могут только модераторы и администраторы.
CREATE OR REPLACE FUNCTION fn_delete_topic(mauthor INTEGER, mtopic INTEGER)
	RETURNS BOOLEAN AS $$
DECLARE
	user_role INTEGER;
	forums forum%ROWTYPE;
	topics topic%ROWTYPE;
	posts post%ROWTYPE;
BEGIN
	SELECT id_role INTO user_role FROM "user" WHERE id_user = mauthor;
	IF NOT (user_role = 1 OR user_role = 2) THEN
		RETURN FALSE;
	END IF;
-- 	Удаляем все посты в категории.
	FOR posts IN SELECT tp.id_post FROM forum_topic as ft JOIN forum ON ft.id_forum = forum.id_forum JOIN topic_post as tp ON ft.id_topic = tp.id_topic
		WHERE tp.id_topic = mtopic
	LOOP
		DELETE FROM post WHERE id_post = posts.id_post;
		DELETE FROM topic_post WHERE id_post = posts.id_post;
	END LOOP;
-- 	Удаляем всю информацию о топиках
	FOR topics IN SELECT ft.id_topic FROM forum_topic as ft JOIN forum ON ft.id_forum = forum.id_forum
		WHERE ft.id_topic = mtopic
	LOOP
		DELETE FROM topic WHERE id_topic = topics.id_topic;
		DELETE FROM topic_info WHERE id_topic = topics.id_topic;
		DELETE FROM forum_topic WHERE id_topic = topics.id_topic;
	END LOOP;
	PERFORM fn_refresh_num_count_forums_topics();
	PERFORM fn_refresh_num_count_users();
	RETURN TRUE;
END;
$$ LANGUAGE plpgsql;
SELECT fn_delete_topic(1, 1);

-- Удалить пост. Могут только модераторы и администраторы
CREATE OR REPLACE FUNCTION fn_delete_post(mauthor INTEGER, mpost INTEGER)
	RETURNS BOOLEAN AS $$
DECLARE
	user_role INTEGER;
	posts post%ROWTYPE;
BEGIN
	SELECT id_role INTO user_role FROM "user" WHERE id_user = mauthor;
	IF NOT (user_role = 1 OR user_role = 2) THEN
		RETURN FALSE;
	END IF;
-- 	Удаляем все посты в категории.
	FOR posts IN SELECT tp.id_post FROM post JOIN topic_post as tp ON post.id_post = tp.id_post
		WHERE tp.id_post = mpost
	LOOP
		DELETE FROM post WHERE id_post = posts.id_post;
		DELETE FROM topic_post WHERE id_post = posts.id_post;
	END LOOP;
	PERFORM fn_refresh_num_count_forums_topics();
	PERFORM fn_refresh_num_count_users();
	RETURN TRUE;
END;
$$ LANGUAGE plpgsql;
SELECT fn_delete_post(1, 7);

-- Назначить модератором. Только администратор
CREATE OR REPLACE FUNCTION fn_create_moderator(mauthor INTEGER, muser INTEGER, mforum INTEGER)
	RETURNS BOOLEAN AS $$
DECLARE
	user_role INTEGER;
	num INTEGER;
BEGIN
	SELECT id_role INTO user_role FROM "user" WHERE id_user = mauthor;
		IF NOT (user_role = 1) THEN
		RETURN FALSE;
	END IF;

	SELECT id_role INTO user_role FROM "user" WHERE id_user = muser;
		IF NOT (user_role = 1 OR user_role = 2) THEN
			RETURN FALSE;
		END IF;

	SELECT count(*) INTO num FROM moderator_forum WHERE muser = id_user AND mforum = id_forum;
	if num <> 0 THEN RETURN FALSE; END IF;

	INSERT INTO moderator_forum (id_forum, id_user) VALUES
		(mforum, muser);
	RETURN TRUE;
END;
$$ LANGUAGE plpgsql;
SELECT fn_create_moderator(1, 5, 3);