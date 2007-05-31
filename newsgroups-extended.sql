CREATE TABLE newsgroups (
  id INTEGER NOT NULL PRIMARY KEY AUTO_INCREMENT,
  name VARCHAR(255) NOT NULL,
  created_at DATETIME,
  
  INDEX (created_at)
);

CREATE TABLE articles (
  id INTEGER NOT NULL PRIMARY KEY AUTO_INCREMENT,
  source_post INTEGER,
  body LONGTEXT,
  
  INDEX (source_post)
);

CREATE TABLE article_placements (
  id INTEGER NOT NULL PRIMARY KEY AUTO_INCREMENT,
  article_id INTEGER NOT NULL REFERENCES articles(id),
  newsgroup_id INTEGER NOT NULL REFERENCES newsgroups(id),
  placement_id INTEGER NOT NULL,

  INDEX (article_id),
  INDEX (newsgroup_id)
);

CREATE TABLE headers (
  id INTEGER NOT NULL PRIMARY KEY AUTO_INCREMENT,
  article_id INTEGER NOT NULL REFERENCES articles(id),
  name VARCHAR(255) NOT NULL,
  value TEXT NOT NULL,
  
  INDEX (article_id)
);
