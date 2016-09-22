package ADAPTER

import (
	"database/sql"
	"fmt"
	"log"
	"math/rand"
	"os"
	"testing"

	"github.com/gocraft/dbr"
	"upper.io/db.v2"
	"upper.io/db.v2/ADAPTER"
	"upper.io/db.v2/lib/sqlbuilder"
)

const (
	testRows = 1000
)

func TestMain(m *testing.M) {
	if err := tearUp(); err != nil {
		log.Fatal("tearUp", err)
	}

	os.Exit(m.Run())
}

func mustOpen() sqlbuilder.Database {
	sess, err := ADAPTER.Open(settings)
	if err != nil {
		panic(err.Error())
	}
	return sess
}

func updatedArtistN(i int) string {
	return fmt.Sprintf("Updated Artist %d", i%testRows)
}

func artistN(i int) string {
	return fmt.Sprintf("Artist %d", i%testRows)
}

func addFakeRowsAndDisconnect() error {
	sess, err := connectAndAddFakeRows()
	if err != nil {
		return err
	}
	sess.Close()
	return nil
}

func connectAndAddFakeRows() (db.Database, error) {
	sess := mustOpen()

	if err := sess.Collection("artist").Truncate(); err != nil {
		return nil, err
	}

	type valueT struct {
		Name string `db:"name"`
	}

	for i := 0; i < testRows; i++ {
		value := valueT{artistN(i)}
		if _, err := sess.Collection("artist").Insert(value); err != nil {
			return nil, err
		}
	}

	return sess, nil
}

func BenchmarkUpperInsert(b *testing.B) {
	sess := mustOpen()
	defer sess.Close()

	artist := sess.Collection("artist")
	artist.Truncate()

	item := struct {
		Name string `db:"name"`
	}{"Hayao Miyazaki"}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		if _, err := artist.Insert(item); err != nil {
			b.Fatal(err)
		}
	}
}

func BenchmarkUpperInsertVariableArgs(b *testing.B) {
	sess := mustOpen()
	defer sess.Close()

	artist := sess.Collection("artist")
	artist.Truncate()

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		item := struct {
			Name string `db:"name"`
		}{fmt.Sprintf("Hayao Miyazaki %d", rand.Int())}
		if _, err := artist.Insert(item); err != nil {
			b.Fatal(err)
		}
	}
}

func BenchmarkUpperInsertTransaction(b *testing.B) {
	sess := mustOpen()
	defer sess.Close()

	tx, err := sess.NewTx()
	if err != nil {
		b.Fatal(err)
	}
	defer tx.Close()

	artist := tx.Collection("artist")

	if err = artist.Truncate(); err != nil {
		b.Fatal(err)
	}

	item := struct {
		Name string `db:"name"`
	}{"Hayao Miyazaki"}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		if _, err = artist.Insert(item); err != nil {
			b.Fatal(err)
		}
	}

	if err = tx.Commit(); err != nil {
		b.Fatal(err)
	}
}

func BenchmarkUpperInsertTransactionWithMap(b *testing.B) {
	sess := mustOpen()
	defer sess.Close()

	tx, err := sess.NewTx()
	if err != nil {
		b.Fatal(err)
	}
	defer tx.Close()

	artist := tx.Collection("artist")

	if err = artist.Truncate(); err != nil {
		b.Fatal(err)
	}

	item := map[string]string{
		"name": "Hayao Miyazaki",
	}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		if _, err = artist.Insert(item); err != nil {
			b.Fatal(err)
		}
	}

	if err = tx.Commit(); err != nil {
		b.Fatal(err)
	}
}

func BenchmarkUpperFind(b *testing.B) {
	sess, err := connectAndAddFakeRows()
	if err != nil {
		b.Fatal(err)
	}
	defer sess.Close()

	artist := sess.Collection("artist")

	type artistType struct {
		Name string `db:"name"`
	}

	var item artistType

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		res := artist.Find(db.Cond{"name": artistN(i)})
		if err = res.One(&item); err != nil {
			b.Fatal(err)
		}
	}
}

func BenchmarkUpperFindAll(b *testing.B) {
	sess, err := connectAndAddFakeRows()
	if err != nil {
		b.Fatal(err)
	}
	defer sess.Close()

	artist := sess.Collection("artist")

	type artistType struct {
		Name string `db:"name"`
	}

	var items []artistType

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		res := artist.Find(db.Or(
			db.Cond{"name": artistN(i)},
			db.Cond{"name": artistN(i + 1)},
			db.Cond{"name": artistN(i + 2)},
		))
		if err = res.All(&items); err != nil {
			b.Fatal(err)
		}
		if len(items) != 3 {
			b.Fatal("Expecting 3 results.")
		}
	}
}

func BenchmarkUpperUpdate(b *testing.B) {
	sess, err := connectAndAddFakeRows()
	if err != nil {
		b.Fatal(err)
	}
	defer sess.Close()

	artist := sess.Collection("artist")

	type artistType struct {
		Name string `db:"name"`
	}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		newValue := artistType{
			Name: updatedArtistN(i),
		}
		res := artist.Find(db.Cond{"name": artistN(i)})
		if err = res.Update(newValue); err != nil {
			b.Fatal(err)
		}
	}
}

// BenchmarkUpperDelete benchmarks
func BenchmarkUpperDelete(b *testing.B) {
	sess, err := connectAndAddFakeRows()
	if err != nil {
		b.Fatal(err)
	}
	defer sess.Close()

	artist := sess.Collection("artist")

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		res := artist.Find(db.Cond{"name": artistN(i)})
		if err = res.Delete(); err != nil {
			b.Fatal(err)
		}
	}
}

// BenchmarkUpperGetCollection
func BenchmarkUpperGetCollection(b *testing.B) {
	sess, err := ADAPTER.Open(settings)
	if err != nil {
		b.Fatal(err)
	}
	defer sess.Close()

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		sess.Collection("artist")
	}
}

func BenchmarkUpperCommitManyTransactions(b *testing.B) {
	sess, err := ADAPTER.Open(settings)
	if err != nil {
		b.Fatal(err)
	}
	defer sess.Close()

	b.ResetTimer()

	for i := 0; i < b.N; i++ {
		var tx sqlbuilder.Tx
		if tx, err = sess.NewTx(); err != nil {
			b.Fatal(err)
		}

		artist := tx.Collection("artist")

		if err = artist.Truncate(); err != nil {
			b.Fatal(err)
		}

		item := struct {
			Name string `db:"name"`
		}{"Hayao Miyazaki"}

		if _, err = artist.Insert(item); err != nil {
			b.Fatal(err)
		}

		if err = tx.Commit(); err != nil {
			b.Fatal(err)
		}

		tx.Close()
	}
}

// BenchmarkUpperRollbackManyTransactions benchmarks
func BenchmarkUpperRollbackManyTransactions(b *testing.B) {
	sess, err := ADAPTER.Open(settings)
	if err != nil {
		b.Fatal(err)
	}
	defer sess.Close()

	b.ResetTimer()

	for i := 0; i < b.N; i++ {
		var tx sqlbuilder.Tx
		if tx, err = sess.NewTx(); err != nil {
			b.Fatal(err)
		}

		artist := tx.Collection("artist")

		if err = artist.Truncate(); err != nil {
			b.Fatal(err)
		}

		item := struct {
			Name string `db:"name"`
		}{"Hayao Miyazaki"}

		if _, err = artist.Insert(item); err != nil {
			b.Fatal(err)
		}

		if err = tx.Rollback(); err != nil {
			b.Fatal(err)
		}

		tx.Close()
	}
}

// BenchmarkSQLInsert benchmarks raw INSERT SQL queries without using prepared
// statements nor arguments.
func BenchmarkSQLInsert(b *testing.B) {
	var err error
	var sess db.Database

	if sess, err = ADAPTER.Open(settings); err != nil {
		b.Fatal(err)
	}

	defer sess.Close()

	driver := sess.Driver().(*sql.DB)

	db, err := beginSQL(driver)
	if err != nil {
		b.Fatal("unable to initialize driver-specific connection:", err)
	}

	if _, err = db.Exec(truncateArtist); err != nil {
		b.Fatal(err)
	}
	if err := doneSQL(db); err != nil {
		b.Fatal("unable to dispose of database-specific connection:", err)
	}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		db, err := beginSQL(driver)
		if err != nil {
			b.Fatal("unable to initialize driver-specific connection:", err)
		}

		if _, err = db.Exec(insertHayaoMiyazaki); err != nil {
			b.Fatal(err)
		}
		if err := doneSQL(db); err != nil {
			b.Fatal("unable to dispose of database-specific connection:", err)
		}
	}
}

func BenchmarkDBRInsert(b *testing.B) {
	var err error

	conn, err := dbr.Open("DRIVER", settings.String(), nil)
	if err != nil {
		b.Fatal(err)
	}

	sess := conn.NewSession(nil)

	defer sess.Close()

	if _, err = sess.Exec(truncateArtist); err != nil {
		b.Fatal(err)
	}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		if _, err = sess.Exec(insertHayaoMiyazaki); err != nil {
			b.Fatal(err)
		}
	}
}

func BenchmarkSQLInsertWithArgs(b *testing.B) {
	var err error
	var sess db.Database

	if sess, err = ADAPTER.Open(settings); err != nil {
		b.Fatal(err)
	}

	defer sess.Close()

	driver := sess.Driver().(*sql.DB)

	db, err := beginSQL(driver)
	if err != nil {
		b.Fatal("unable to initialize driver-specific connection:", err)
	}
	if _, err = db.Exec(truncateArtist); err != nil {
		b.Fatal(err)
	}
	if err := doneSQL(db); err != nil {
		b.Fatal("unable to dispose of database-specific connection:", err)
	}

	args := []interface{}{
		"Hayao Miyazaki",
	}

	var rows *sql.Rows

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		db, err := beginSQL(driver)
		if err != nil {
			b.Fatal("unable to initialize driver-specific connection:", err)
		}
		if rows, err = db.Query(insertIntoArtistWithPlaceholderReturningID, args...); err != nil {
			b.Fatal(err)
		}
		rows.Close()
		if err := doneSQL(db); err != nil {
			b.Fatal("unable to dispose of database-specific connection:", err)
		}
	}
}

func BenchmarkDBRInsertWithArgs(b *testing.B) {
	var err error

	conn, err := dbr.Open("DRIVER", settings.String(), nil)
	if err != nil {
		b.Fatal(err)
	}

	sess := conn.NewSession(nil)

	defer sess.Close()

	if _, err = sess.Exec(truncateArtist); err != nil {
		b.Fatal(err)
	}

	args := []interface{}{
		"Hayao Miyazaki",
	}

	var rows *sql.Rows

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		if rows, err = sess.Query(insertIntoArtistWithPlaceholderReturningID, args...); err != nil {
			b.Fatal(err)
		}
		rows.Close()
	}
}

func BenchmarkSQLPreparedInsertNoArguments(b *testing.B) {
	var err error
	var sess db.Database

	if sess, err = ADAPTER.Open(settings); err != nil {
		b.Fatal(err)
	}

	defer sess.Close()

	driver := sess.Driver().(*sql.DB)

	db, err := beginSQL(driver)
	if err != nil {
		b.Fatal("unable to initialize driver-specific connection:", err)
	}
	if _, err = db.Exec(truncateArtist); err != nil {
		b.Fatal(err)
	}
	if err := doneSQL(db); err != nil {
		b.Fatal("unable to dispose of database-specific connection:", err)
	}

	db, err = beginSQL(driver)
	if err != nil {
		b.Fatal("unable to initialize driver-specific connection:", err)
	}
	stmt, err := db.Prepare(insertHayaoMiyazaki)
	if err != nil {
		b.Fatal(err)
	}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		if _, err = stmt.Exec(); err != nil {
			b.Fatal(err)
		}
	}
	if err := doneSQL(db); err != nil {
		b.Fatal("unable to dispose of database-specific connection:", err)
	}
}

func BenchmarkSQLPreparedInsertWithArguments(b *testing.B) {
	sess := mustOpen()
	defer sess.Close()

	driver := sess.Driver().(*sql.DB)

	db, err := beginSQL(driver)
	if err != nil {
		b.Fatal("unable to initialize driver-specific connection:", err)
	}
	if _, err := db.Exec(truncateArtist); err != nil {
		b.Fatal(err)
	}
	if err := doneSQL(db); err != nil {
		b.Fatal("unable to dispose of database-specific connection:", err)
	}

	db, err = beginSQL(driver)
	if err != nil {
		b.Fatal("unable to initialize driver-specific connection:", err)
	}
	stmt, err := db.Prepare(insertIntoArtistWithPlaceholderReturningID)

	if err != nil {
		b.Fatal(err)
	}

	args := []interface{}{
		"Hayao Miyazaki",
	}

	var rows *sql.Rows

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		if rows, err = stmt.Query(args...); err != nil {
			b.Fatal(err)
		}
		rows.Close()
	}
	if err := doneSQL(db); err != nil {
		b.Fatal("unable to dispose of database-specific connection:", err)
	}
}

func BenchmarkDBRPreparedInsertWithArguments(b *testing.B) {
	var err error

	conn, err := dbr.Open("DRIVER", settings.String(), nil)
	if err != nil {
		b.Fatal(err)
	}

	sess := conn.NewSession(nil)

	defer sess.Close()

	if _, err = sess.Exec(truncateArtist); err != nil {
		b.Fatal(err)
	}

	stmt, err := sess.Prepare(insertIntoArtistWithPlaceholderReturningID)

	if err != nil {
		b.Fatal(err)
	}

	args := []interface{}{
		"Hayao Miyazaki",
	}

	var rows *sql.Rows

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		if rows, err = stmt.Query(args...); err != nil {
			b.Fatal(err)
		}
		rows.Close()
	}
}

func BenchmarkSQLPreparedInsertWithVariableArgs(b *testing.B) {
	sess := mustOpen()
	defer sess.Close()

	driver := sess.Driver().(*sql.DB)

	db, err := beginSQL(driver)
	if err != nil {
		b.Fatal("unable to initialize driver-specific connection:", err)
	}
	if _, err := db.Exec(truncateArtist); err != nil {
		b.Fatal(err)
	}
	if err := doneSQL(db); err != nil {
		b.Fatal("unable to dispose of database-specific connection:", err)
	}

	db, err = beginSQL(driver)
	if err != nil {
		b.Fatal("unable to initialize driver-specific connection:", err)
	}
	stmt, err := db.Prepare(insertIntoArtistWithPlaceholderReturningID)

	if err != nil {
		b.Fatal(err)
	}

	var rows *sql.Rows

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		args := []interface{}{
			fmt.Sprintf("Hayao Miyazaki %d", rand.Int()),
		}
		if rows, err = stmt.Query(args...); err != nil {
			b.Fatal(err)
		}
		rows.Close()
	}
	if err := doneSQL(db); err != nil {
		b.Fatal("unable to dispose of database-specific connection:", err)
	}
}

func BenchmarkDBRPreparedInsertWithVariableArgs(b *testing.B) {
	var err error

	conn, err := dbr.Open("DRIVER", settings.String(), nil)
	if err != nil {
		b.Fatal(err)
	}

	sess := conn.NewSession(nil)

	defer sess.Close()

	if _, err = sess.Exec(truncateArtist); err != nil {
		b.Fatal(err)
	}

	stmt, err := sess.Prepare(insertIntoArtistWithPlaceholderReturningID)

	if err != nil {
		b.Fatal(err)
	}

	var rows *sql.Rows

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		args := []interface{}{
			fmt.Sprintf("Hayao Miyazaki %d", rand.Int()),
		}
		if rows, err = stmt.Query(args...); err != nil {
			b.Fatal(err)
		}
		rows.Close()
	}
}

func BenchmarkSQLPreparedInsertTransactionWithArgs(b *testing.B) {
	var err error
	var sess db.Database
	var tx *sql.Tx

	if sess, err = ADAPTER.Open(settings); err != nil {
		b.Fatal(err)
	}

	defer sess.Close()

	driver := sess.Driver().(*sql.DB)

	if tx, err = driver.Begin(); err != nil {
		b.Fatal(err)
	}

	if _, err = tx.Exec(truncateArtist); err != nil {
		b.Fatal(err)
	}

	stmt, err := tx.Prepare(insertIntoArtistWithPlaceholderReturningID)
	if err != nil {
		b.Fatal(err)
	}

	args := []interface{}{
		"Hayao Miyazaki",
	}

	var rows *sql.Rows

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		if rows, err = stmt.Query(args...); err != nil {
			b.Fatal(err)
		}
		rows.Close()
	}

	if err = tx.Commit(); err != nil {
		b.Fatal(err)
	}
}

// BenchmarkSQLSelect benchmarks SQL SELECT queries.
func BenchmarkSQLSelect(b *testing.B) {
	var err error
	var sess db.Database

	if sess, err = connectAndAddFakeRows(); err != nil {
		b.Fatal(err)
	}

	defer sess.Close()

	driver := sess.Driver().(*sql.DB)

	var res *sql.Rows

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		db, err := beginSQL(driver)
		if err != nil {
			b.Fatal("unable to initialize driver-specific connection:", err)
		}
		if res, err = db.Query(selectFromArtistWhereName, artistN(i)); err != nil {
			b.Fatal(err)
		}
		res.Close()
		if err := doneSQL(db); err != nil {
			b.Fatal("unable to dispose of database-specific connection:", err)
		}
	}
}

func BenchmarkDBRSelect(b *testing.B) {
	var err error

	if err := addFakeRowsAndDisconnect(); err != nil {
		b.Fatal(err)
	}

	conn, err := dbr.Open("DRIVER", settings.String(), nil)
	if err != nil {
		b.Fatal(err)
	}

	sess := conn.NewSession(nil)

	defer sess.Close()

	var res *sql.Rows

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		if res, err = sess.Query(selectFromArtistWhereName, artistN(i)); err != nil {
			b.Fatal(err)
		}
		res.Close()
	}
}

func BenchmarkSQLPreparedSelect(b *testing.B) {
	var err error
	var sess db.Database

	if sess, err = connectAndAddFakeRows(); err != nil {
		b.Fatal(err)
	}
	defer sess.Close()

	driver := sess.Driver().(*sql.DB)

	db, err := beginSQL(driver)
	if err != nil {
		b.Fatal("unable to initialize driver-specific connection:", err)
	}

	stmt, err := db.Prepare(selectFromArtistWhereName)
	if err != nil {
		b.Fatal(err)
	}

	var res *sql.Rows

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		if res, err = stmt.Query(artistN(i)); err != nil {
			b.Fatal(err)
		}
		res.Close()
	}
	if err := doneSQL(db); err != nil {
		b.Fatal("unable to dispose of database-specific connection:", err)
	}
}

func BenchmarkDBRPreparedSelect(b *testing.B) {
	var err error

	if err := addFakeRowsAndDisconnect(); err != nil {
		b.Fatal(err)
	}

	conn, err := dbr.Open("DRIVER", settings.String(), nil)
	if err != nil {
		b.Fatal(err)
	}

	sess := conn.NewSession(nil)

	stmt, err := sess.Prepare(selectFromArtistWhereName)
	if err != nil {
		b.Fatal(err)
	}

	var res *sql.Rows

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		if res, err = stmt.Query(artistN(i)); err != nil {
			b.Fatal(err)
		}
		res.Close()
	}
}

func BenchmarkSQLUpdate(b *testing.B) {
	var err error
	var sess db.Database

	if sess, err = connectAndAddFakeRows(); err != nil {
		b.Fatal(err)
	}

	defer sess.Close()

	driver := sess.Driver().(*sql.DB)

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		db, err := beginSQL(driver)
		if err != nil {
			b.Fatal("unable to initialize driver-specific connection:", err)
		}
		if _, err = db.Exec(updateArtistWhereName, updatedArtistN(i), artistN(i)); err != nil {
			b.Fatal(err)
		}
		if err := doneSQL(db); err != nil {
			b.Fatal("unable to dispose of database-specific connection:", err)
		}
	}
}

func BenchmarkSQLPreparedUpdate(b *testing.B) {
	var err error
	var sess db.Database

	if sess, err = connectAndAddFakeRows(); err != nil {
		b.Fatal(err)
	}

	defer sess.Close()

	driver := sess.Driver().(*sql.DB)

	db, err := beginSQL(driver)
	if err != nil {
		b.Fatal("unable to initialize driver-specific connection:", err)
	}
	stmt, err := db.Prepare(updateArtistWhereName)
	if err != nil {
		b.Fatal(err)
	}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		if _, err = stmt.Exec(updatedArtistN(i), artistN(i)); err != nil {
			b.Fatal(err)
		}
	}
	if err := doneSQL(db); err != nil {
		b.Fatal("unable to dispose of database-specific connection:", err)
	}
}

func BenchmarkSQLDelete(b *testing.B) {
	var err error
	var sess db.Database

	if sess, err = connectAndAddFakeRows(); err != nil {
		b.Fatal(err)
	}

	defer sess.Close()

	driver := sess.Driver().(*sql.DB)

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		db, err := beginSQL(driver)
		if err != nil {
			b.Fatal("unable to initialize driver-specific connection:", err)
		}
		if _, err = db.Exec(deleteArtistWhereName, artistN(i)); err != nil {
			b.Fatal(err)
		}
		if err := doneSQL(db); err != nil {
			b.Fatal("unable to dispose of database-specific connection:", err)
		}
	}
}

func BenchmarkSQLPreparedDelete(b *testing.B) {
	var err error
	var sess db.Database

	if sess, err = connectAndAddFakeRows(); err != nil {
		b.Fatal(err)
	}
	defer sess.Close()

	driver := sess.Driver().(*sql.DB)

	db, err := beginSQL(driver)
	if err != nil {
		b.Fatal("unable to initialize driver-specific connection:", err)
	}
	stmt, err := db.Prepare(deleteArtistWhereName)
	if err != nil {
		b.Fatal(err)
	}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		if _, err = stmt.Exec(artistN(i)); err != nil {
			b.Fatal(err)
		}
	}
	if err := doneSQL(db); err != nil {
		b.Fatal("unable to dispose of database-specific connection:", err)
	}
}
