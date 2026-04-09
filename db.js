// import mysql2 library
const mysql = require('mysql2');

// create connection to the mysql database
const db = mysql.createConnection({
    host: 'localhost',
    user: 'root',
    password: '',
    database: 'hdb_resale'
});

// establish database connection
// if connection fail, error message is logged
db.connect(err => {
    if (err) {
        console.error('Database connection failed:', err)
        return;
    }
    console.log('Connected to MySQL database');
});

// export the database connection
module.exports = db;