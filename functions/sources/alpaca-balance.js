if (!secrets.alpacaKey) {
  throw new Error("Alpaca key is required");
}

if (!secrets.alpacaSecret) {
  throw new Error("Alpaca secret is required");
}

// @TODO: fetch the TSLA balance, when the orders will be fulfilled
const alpacaRequest = Functions.makeHttpRequest({
  url: `https://paper-api.alpaca.markets/v2/account`,
  headers: {
    accept: "application/json",
    "APCA-API-KEY-ID": secrets.alpacaKey,
    "APCA-API-SECRET-KEY": secrets.alpacaSecret,
  },
});

const [response] = await Promise.all([alpacaRequest]);

const portfolioBalance = response.data.portfolio_value;
console.info(`Alpaca balance: $${portfolioBalance}`);

return Functions.encodeUint256(Math.round(portfolioBalance * 1e18));
