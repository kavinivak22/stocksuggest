// netlify/functions/yahoo.js

exports.handler = async function(event, context) {
    const ticker = event.queryStringParameters.ticker;
    if (!ticker) {
        return { statusCode: 400, body: JSON.stringify({ error: 'Ticker is required' }) };
    }

    const url = `https://query1.finance.yahoo.com/v8/finance/chart/${ticker}?range=100d&interval=1d`;

    try {
        const response = await fetch(url, { headers: { 'User-Agent': 'Mozilla/5.0' } });
        if (!response.ok) {
            return { statusCode: response.status, body: response.statusText };
        }
        const data = await response.json();
        return {
            statusCode: 200,
            headers: { "Access-Control-Allow-Origin": "*" },
            body: JSON.stringify(data)
        };
    } catch (e) {
        return { statusCode: 500, body: JSON.stringify({ error: e.message }) };
    }
};