const requestConfig = require("../configs/alpaca-mint-config");
const {
  simulateScript,
  decodeResult,
} = require("@chainlink/functions-toolkit");

async function main() {
  const { responseBytesHexstring, errorString } = await simulateScript(
    requestConfig
  );

  if (responseBytesHexstring) {
    console.info(
      `Response returned by script: ${decodeResult(
        responseBytesHexstring,
        requestConfig.expectedReturnType
      ).toString()}\n`
    );
  }

  if (errorString) {
    console.error(`Error returned by script: ${errorString}\n`);
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
