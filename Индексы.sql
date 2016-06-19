CREATE INDEX IF NOT EXISTS idx_id_user_user ON "user"(id_user);

CREATE INDEX IF NOT EXISTS idx_id_user_user_info ON user_info(id_user);

CREATE INDEX IF NOT EXISTS idx_id_category_category ON category(id_category);

CREATE INDEX IF NOT EXISTS idx_id_forum_forum ON forum(id_forum);
CREATE INDEX IF NOT EXISTS idx_id_category_forum ON forum(id_category);

CREATE INDEX IF NOT EXISTS idx_id_forum_forum_info ON forum_info(id_forum);

CREATE INDEX IF NOT EXISTS idx_id_author_topic ON topic(id_author);
CREATE INDEX IF NOT EXISTS idx_id_topic ON topic(id_topic);

CREATE INDEX IF NOT EXISTS idx_id_topic_topic_info ON topic_info(id_topic);

CREATE INDEX IF NOT EXISTS idx_id_forum_forum_topic ON forum_topic(id_forum);
CREATE INDEX IF NOT EXISTS idx_id_topic_forum_topic ON forum_topic(id_topic);
