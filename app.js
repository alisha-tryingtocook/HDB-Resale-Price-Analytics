const express = require('express');
const path = require('path');
const db = require('./db');

const app = express();
const PORT = 3000;

app.use(express.static(path.join(__dirname, 'webapppage')));

app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'webapppage', 'index.html'));
});

// query answer
app.get('/avg-price-year', (req, res) => {
//    sql query calculates the average resale price
    const sql = `
    SELECT
    td.year,
    ROUND(AVG(rt.resale_price), 2) as avg_price,
    COUNT(*) as num_transactions
    FROM resale_transactions rt
    JOIN time_dim td ON rt.time_id = td.time_id
    GROUP BY td.year
    ORDER BY td.year;
    `;

    // exacutes the sql query
    db.query(sql, (err, results) => {
        if (err) {
            res.status(500).send('Database error');
            return;
        }
// dynamically build an HTML table using query results
        let html = `
        <h1>Average Resale Price by Year</h1>
        <table border="1">
        <tr>
            <th>Year</th>
            <th>Average Price</th>
            <th>Transaction</th>
            </tr>
            `;
        
        results.forEach(r => {
            html += `
            <tr>
                <td>${r.year}</td>
                <td>${r.avg_price}</td>
                 <td>${r.num_transactions}</td>
                 </tr>
                `;
        });

            html += `
            </table>
            <br><a href="/proxy/3000/">Back to home</a>
            `;
        
            res.send(html);
        });
    });

    app.get('/top-towns', (req, res) => {
        const sql = `
        SELECT
    t.town_name,
    ROUND(AVG(rt.resale_price), 2) as avg_price,
    COUNT(*) as num_transactions
    FROM resale_transactions rt
    JOIN towns t ON rt.town_id = t.town_id
    GROUP BY t.town_name
    ORDER BY avg_price DESC
    LIMIT 10;
`;
        db.query(sql, (err, results) => {
            if (err) {
                res.status(500).send('Database error');
                return;
            }

            let html = `
        <h1>Top 10 Most Expensive Towns</h1>
        <table border="1">
        <tr>
            <th>Year</th>
            <th>Average Price</th>
            <th>Transaction</th>
            </tr>
            `;

            results.forEach(r => {
                html += `
            <tr>
                <td>${r.town_name}</td>
                <td>${r.avg_price}</td>
                 <td>${r.num_transactions}</td>
                 </tr>
                `;
            });

            html += `
            </table>
            <br><a href="/proxy/3000/">Back to home</a>
            `;
            res.send(html);
        });
    });

    // route answers query question
    app.get('/avg-price-flat-type', (req, res) => {
        const sql = `
       SELECT
    ft.flat_type,
    ROUND(AVG(rt.resale_price), 2) as avg_price,
    ROUND(MIN(rt.resale_price), 2) as min_price,
    ROUND(MAX(rt.resale_price), 2) as max_price
FROM resale_transactions rt
JOIN flat_types ft ON rt.flat_type_id = ft.flat_type_id
GROUP BY ft.flat_type
ORDER BY avg_price DESC;
`;
        db.query(sql, (err, results) => {
            if (err) {
                res.status(500).send('Database error');
                return;
            }

            let html = `
        <h1>Average Price by Flat type</h1>
        <table border="1">
        <tr>
            <th>Year</th>
            <th>Average Price</th>
            <th>Transaction</th>
            </tr>
            `;

            results.forEach(r => {
                html += `
            <tr>
                <td>${r.flat_type}</td>
                <td>${r.avg_price}</td>
                 <td>${r.num_transactions}</td>
                 </tr>
                `;
            });

            html += `
            </table>
            <br><a href="/proxy/3000/">Back to home</a>
            `;
            res.send(html);
        });
    });

    // the application listens on port 3000
    app.listen(PORT, () => {
        console.log(`Server running at http://localhost:${PORT}`)
    });