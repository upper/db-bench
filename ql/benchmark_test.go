//go:generate bash -c "sed -e 's/ADAPTER/ql/g' -e 's/DRIVER/ql/g' ../sqltesting/adapter_benchmark.go.tpl > generated_benchmark_test.go"
package ql

import (
	"database/sql"
	"os"

	"upper.io/db.v2/ql"
)

const (
	truncateArtist                             = `DELETE FROM artist`
	insertHayaoMiyazaki                        = `INSERT INTO artist (name) VALUES("Hayao Miyazaki")`
	insertIntoArtistWithPlaceholderReturningID = `INSERT INTO artist (name) VALUES(?1); SELECT name FROM artist LIMIT 1`
	selectFromArtistWhereName                  = `SELECT * FROM artist WHERE name == ?1`
	updateArtistWhereName                      = `UPDATE artist SET name = ?1 WHERE name == ?2`
	deleteArtistWhereName                      = `DELETE FROM artist WHERE name == ?1`
)

const (
	testTimeZone = "Canada/Eastern"
)

var settings = ql.ConnectionURL{
	Database: os.Getenv("DB_NAME"),
}

func tearUp() error {
	sess := mustOpen()
	defer sess.Close()

	batch := []string{
		`DROP TABLE IF EXISTS artist`,

		`CREATE TABLE artist (
			name string
		)`,

		`DROP TABLE IF EXISTS publication`,

		`CREATE TABLE publication (
			title string,
			author_id int
		)`,

		`DROP TABLE IF EXISTS review`,

		`CREATE TABLE review (
			publication_id int,
			name string,
			comments string,
			created time
		)`,

		`DROP TABLE IF EXISTS data_types`,

		`CREATE TABLE data_types (
			_uint uint,
			_uint8 uint8,
			_uint16 uint16,
			_uint32 uint32,
			_uint64 uint64,
			_int int,
			_int8 int8,
			_int16 int16,
			_int32 int32,
			_int64 int64,
			_float32 float32,
			_float64 float64,
			_bool bool,
			_string string,
			_date time,
			_nildate time,
			_ptrdate time,
			_defaultdate time,
			_time time
		)`,

		`DROP TABLE IF EXISTS stats_test`,

		`CREATE TABLE stats_test (
			id uint,
			numeric int64,
			value int64
		)`,

		`DROP TABLE IF EXISTS composite_keys`,

		`-- Composite keys are currently not supported in QL.
		CREATE TABLE composite_keys (
		-- code string,
		-- user_id string,
			some_val string,
		-- primary key (code, user_id)
		)`,
	}

	driver := sess.Driver().(*sql.DB)
	tx, err := driver.Begin()
	if err != nil {
		return err
	}

	for _, s := range batch {
		if _, err := tx.Exec(s); err != nil {
			return err
		}
	}

	if err := tx.Commit(); err != nil {
		return err
	}

	return nil
}

func beginSQL(d *sql.DB) (*sql.Tx, error) {
	return d.Begin()
}

func doneSQL(t *sql.Tx) error {
	return t.Commit()
}
