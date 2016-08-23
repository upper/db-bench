//go:generate bash -c "sed -e 's/ADAPTER/sqlite/g' -e 's/DRIVER/sqlite/g' ../sqltesting/adapter_benchmark.go.tpl > generated_benchmark_test.go"
package sqlite

import (
	"database/sql"
	"os"

	"upper.io/db.v2/sqlite"
)

const (
	truncateArtist                             = `DELETE FROM "artist"`
	insertHayaoMiyazaki                        = `INSERT INTO "artist" ("name") VALUES('Hayao Miyazaki')`
	insertIntoArtistWithPlaceholderReturningID = `INSERT INTO "artist" ("name") VALUES(?)`
	selectFromArtistWhereName                  = `SELECT * FROM "artist" WHERE "name" = ?`
	updateArtistWhereName                      = `UPDATE "artist" SET "name" = ? WHERE "name" = ?`
	deleteArtistWhereName                      = `DELETE FROM "artist" WHERE "name" = ?`
)

const (
	testTimeZone = "Canada/Eastern"
)

var settings = sqlite.ConnectionURL{
	Database: os.Getenv("DB_NAME"),
}

func tearUp() error {
	sess := mustOpen()
	defer sess.Close()

	batch := []string{
		`PRAGMA foreign_keys=OFF`,

		`BEGIN TRANSACTION`,

		`DROP TABLE IF EXISTS artist`,

		`CREATE TABLE artist (
			id integer primary key,
			name varchar(60)
		)`,

		`DROP TABLE IF EXISTS publication`,

		`CREATE TABLE publication (
			id integer primary key,
			title varchar(80),
			author_id integer
		)`,

		`DROP TABLE IF EXISTS review`,

		`CREATE TABLE review (
			id integer primary key,
			publication_id integer,
			name varchar(80),
			comments text,
			created datetime
		)`,

		`DROP TABLE IF EXISTS data_types`,

		`CREATE TABLE data_types (
			id integer primary key,
		 _uint integer,
		 _uintptr integer,
		 _uint8 integer,
		 _uint16 int,
		 _uint32 int,
		 _uint64 int,
		 _int integer,
		 _int8 integer,
		 _int16 integer,
		 _int32 integer,
		 _int64 integer,
		 _float32 real,
		 _float64 real,
		 _byte integer,
		 _rune integer,
		 _bool integer,
		 _string text,
		 _date datetime,
		 _nildate datetime,
		 _ptrdate datetime,
		 _defaultdate datetime default current_timestamp,
		 _time text
		)`,

		`DROP TABLE IF EXISTS stats_test`,

		`CREATE TABLE stats_test (
			id integer primary key,
			numeric integer,
			value integer
		)`,

		`DROP TABLE IF EXISTS composite_keys`,

		`CREATE TABLE composite_keys (
			code VARCHAR(255) default '',
			user_id VARCHAR(255) default '',
			some_val VARCHAR(255) default '',
			primary key (code, user_id)
		)`,

		`COMMIT`,
	}

	for _, s := range batch {
		driver := sess.Driver().(*sql.DB)
		if _, err := driver.Exec(s); err != nil {
			return err
		}
	}

	return nil
}
