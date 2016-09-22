//go:generate bash -c "sed -e 's/ADAPTER/postgresql/g' -e 's/DRIVER/postgres/g' ../benchmark.go.tpl > generated_benchmark_test.go"
package postgresql

import (
	"database/sql"
	"os"

	"upper.io/db.v2/postgresql"
)

const (
	truncateArtist                             = `TRUNCATE TABLE "artist" RESTART IDENTITY`
	insertHayaoMiyazaki                        = `INSERT INTO "artist" ("name") VALUES('Hayao Miyazaki') RETURNING "id"`
	insertIntoArtistWithPlaceholderReturningID = `INSERT INTO "artist" ("name") VALUES($1) RETURNING "id"`
	selectFromArtistWhereName                  = `SELECT * FROM "artist" WHERE "name" = $1`
	updateArtistWhereName                      = `UPDATE "artist" SET "name" = $1 WHERE "name" = $2`
	deleteArtistWhereName                      = `DELETE FROM "artist" WHERE "name" = $1`
)

const (
	testTimeZone = "Canada/Eastern"
)

var settings = postgresql.ConnectionURL{
	Database: os.Getenv("DB_NAME"),
	User:     os.Getenv("DB_USERNAME"),
	Password: os.Getenv("DB_PASSWORD"),
	Host:     os.Getenv("DB_HOST") + ":" + os.Getenv("DB_PORT"),
	Options: map[string]string{
		"timezone": testTimeZone,
	},
}

func tearUp() error {
	sess := mustOpen()
	defer sess.Close()

	batch := []string{
		`DROP TABLE IF EXISTS artist`,

		`CREATE TABLE artist (
			id serial primary key,
			name varchar(60)
		)`,

		`DROP TABLE IF EXISTS publication`,

		`CREATE TABLE publication (
			id serial primary key,
			title varchar(80),
			author_id integer
		)`,

		`DROP TABLE IF EXISTS review`,

		`CREATE TABLE review (
			id serial primary key,
			publication_id integer,
			name varchar(80),
			comments text,
			created timestamp without time zone
		)`,

		`DROP TABLE IF EXISTS data_types`,

		`CREATE TABLE data_types (
			id serial primary key,
			_uint integer,
			_uint8 integer,
			_uint16 integer,
			_uint32 integer,
			_uint64 integer,
			_int integer,
			_int8 integer,
			_int16 integer,
			_int32 integer,
			_int64 integer,
			_float32 numeric(10,6),
			_float64 numeric(10,6),
			_bool boolean,
			_string text,
			_date timestamp with time zone,
			_nildate timestamp without time zone null,
			_ptrdate timestamp without time zone,
			_defaultdate timestamp without time zone DEFAULT now(),
			_time bigint
		)`,

		`DROP TABLE IF EXISTS stats_test`,

		`CREATE TABLE stats_test (
			id serial primary key,
			numeric integer,
			value integer
		)`,

		`DROP TABLE IF EXISTS composite_keys`,

		`CREATE TABLE composite_keys (
			code varchar(255) default '',
			user_id varchar(255) default '',
			some_val varchar(255) default '',
			primary key (code, user_id)
		)`,

		`DROP TABLE IF EXISTS option_types`,

		`CREATE TABLE option_types (
			id serial primary key,
			name varchar(255) default '',
			tags varchar(64)[],
			settings jsonb
		)`,
	}

	for _, s := range batch {
		driver := sess.Driver().(*sql.DB)
		if _, err := driver.Exec(s); err != nil {
			return err
		}
	}

	return nil
}

func beginSQL(d *sql.DB) (*sql.DB, error) {
	return d, nil
}

func doneSQL(t *sql.DB) error {
	return nil
}
