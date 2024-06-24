const { createPromptModule } = require("inquirer");
const { SecretsManager } = require("@chainlink/functions-toolkit");
const { Wallet, providers } = require("ethers");

async function main() {
  const routerAddress = "0xb83E47C2bC239B3bf370bc41e1459A34b41238D0"; // sepolia
  const donID = "fun-ethereum-sepolia-1";
  const gatewayUrls = [
    "https://01.functions-gateway.testnet.chain.link/",
    "https://02.functions-gateway.testnet.chain.link/",
  ];

  const privateKeyPrompt = createPromptModule();
  const { privateKey } = await privateKeyPrompt({
    type: "input",
    name: "privateKey",
    message: "Pls, enter your private key:",
    validate: (answer) => {
      return /^0x[0-9a-fA-F]{64}$/.test(answer);
    },
  });

  const rpcUrl = process.env.SEPOLIA_RPC_URL;

  const secrets = {
    alpacaKey: process.env.ALPACA_API_KEY,
    alpacaSecret: process.env.ALPACA_API_SECRET,
  };

  const provider = new providers.JsonRpcProvider(rpcUrl);
  const wallet = new Wallet(privateKey);
  const signer = wallet.connect(provider);

  const secretsManager = new SecretsManager({
    signer,
    functionsRouterAddress: routerAddress,
    donId: donID,
  });

  await secretsManager.initialize();

  const { encryptedSecrets } = await secretsManager.encryptSecrets(secrets);
  console.info("Encrypted secrets: ", encryptedSecrets);

  const slotIdNumber = 0;
  const expirationTimeMinutes = 3 * 1440; // 3 days

  const uploadResult = await secretsManager.uploadEncryptedSecretsToDON({
    encryptedSecretsHexstring: encryptedSecrets,
    gatewayUrls,
    slotId: slotIdNumber,
    minutesUntilExpiration: expirationTimeMinutes,
  });

  if (!uploadResult.success) {
    throw new Error("Failed to upload secrets to the DON");
  }

  console.info(
    "Secrets uploaded successfully, response from the DON: ",
    uploadResult
  );
  const donHostedSecretsVersion = uploadResult.version;
  console.info("DON hosted secrets version: ", donHostedSecretsVersion);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
