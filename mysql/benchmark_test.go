//go:generate bash -c "sed -e 's/ADAPTER/mysql/g' -e 's/DRIVER/mysql/g' ../sqltesting/adapter_benchmark.go.tpl > generated_benchmark_test.go"
package mysql

import (
	"database/sql"
	"fmt"
	"os"

	"upper.io/db.v2/mysql"
)

const (
	truncateArtist                             = "TRUNCATE TABLE `artist`"
	insertHayaoMiyazaki                        = "INSERT INTO `artist` (`name`) VALUES('Hayao Miyazaki')"
	insertIntoArtistWithPlaceholderReturningID = "INSERT INTO `artist` (`name`) VALUES(?)"
	selectFromArtistWhereName                  = "SELECT * FROM `artist` WHERE `name` = ?"
	updateArtistWhereName                      = "UPDATE `artist` SET `name` = ? WHERE `name` = ?"
	deleteArtistWhereName                      = "DELETE FROM `artist` WHERE `name` = ?"
)

const (
	testTimeZone = "Canada/Eastern"
)

var settings = mysql.ConnectionURL{
	Database: os.Getenv("DB_NAME"),
	User:     os.Getenv("DB_USERNAME"),
	Password: os.Getenv("DB_PASSWORD"),
	Host:     os.Getenv("DB_HOST") + ":" + os.Getenv("DB_PORT"),
	Options: map[string]string{
		// See https://github.com/go-sql-driver/mysql/issues/9
		"parseTime": "true",
		// Might require you to use mysql_tzinfo_to_sql /usr/share/zoneinfo | mysql -u root -p mysql
		"time_zone": fmt.Sprintf(`"%s"`, testTimeZone),
	},
}

func tearUp() error {
	sess := mustOpen()
	defer sess.Close()

	batch := []string{
		`DROP TABLE IF EXISTS artist`,

		`CREATE TABLE artist (
			id BIGINT(20) UNSIGNED NOT NULL AUTO_INCREMENT,
			PRIMARY KEY(id),
			name VARCHAR(60)
		)`,

		`DROP TABLE IF EXISTS publication`,

		`CREATE TABLE publication (
			id BIGINT(20) UNSIGNED NOT NULL AUTO_INCREMENT,
			PRIMARY KEY(id),
			title VARCHAR(80),
			author_id BIGINT(20)
		)`,

		`DROP TABLE IF EXISTS review`,

		`CREATE TABLE review (
			id BIGINT(20) UNSIGNED NOT NULL AUTO_INCREMENT,
			PRIMARY KEY(id),
			publication_id BIGINT(20),
			name VARCHAR(80),
			comments TEXT,
			created DATETIME NOT NULL
		)`,

		`DROP TABLE IF EXISTS data_types`,

		`CREATE TABLE data_types (
			id BIGINT(20) UNSIGNED NOT NULL AUTO_INCREMENT,
			PRIMARY KEY(id),
			_uint INT(10) UNSIGNED DEFAULT 0,
			_uint8 INT(10) UNSIGNED DEFAULT 0,
			_uint16 INT(10) UNSIGNED DEFAULT 0,
			_uint32 INT(10) UNSIGNED DEFAULT 0,
			_uint64 INT(10) UNSIGNED DEFAULT 0,
			_int INT(10) DEFAULT 0,
			_int8 INT(10) DEFAULT 0,
			_int16 INT(10) DEFAULT 0,
			_int32 INT(10) DEFAULT 0,
			_int64 INT(10) DEFAULT 0,
			_float32 DECIMAL(10,6),
			_float64 DECIMAL(10,6),
			_bool TINYINT(1),
			_string text,
			_date TIMESTAMP NULL,
			_nildate DATETIME NULL,
			_ptrdate DATETIME NULL,
			_defaultdate TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
			_time BIGINT UNSIGNED NOT NULL DEFAULT 0
		)`,

		`DROP TABLE IF EXISTS stats_test`,

		`CREATE TABLE stats_test (
			id BIGINT(20) UNSIGNED NOT NULL AUTO_INCREMENT, PRIMARY KEY(id),
			` + "`numeric`" + ` INT(10),
			` + "`value`" + ` INT(10)
		)`,

		`DROP TABLE IF EXISTS composite_keys`,

		`CREATE TABLE composite_keys (
			code VARCHAR(255) default '',
			user_id VARCHAR(255) default '',
			some_val VARCHAR(255) default '',
			primary key (code, user_id)
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
