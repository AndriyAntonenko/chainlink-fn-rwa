const fs = require("node:fs");
const path = require("node:path");
const {
  Location,
  ReturnType,
  CodeLanguage,
} = require("@chainlink/functions-toolkit");

const requestConfig = {
  source: fs.readFileSync(
    path.join(__dirname, "../sources/alpaca-balance.js"),
    "utf-8"
  ),
  codeLocation: Location.Inline,
  secrets: {
    alpacaKey: process.env.ALPACA_API_KEY,
    alpacaSecret: process.env.ALPACA_API_SECRET,
  },
  secretsLocation: Location.DONHosted,
  args: [],
  codeLanguage: CodeLanguage.JavaScript,
  expectedReturnType: ReturnType.uint256,
};

module.exports = requestConfig;
