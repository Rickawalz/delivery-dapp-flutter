import { deployContract, verify } from "./helpers";
import hre from "hardhat";
import * as dotenv from "dotenv";
import * as path from "path";

// Load environment variables
dotenv.config({ path: path.join(__dirname, '../../app/.env') });

async function main() {
  console.log("Starting deployment...");

  // Get network configuration
  const network = hre.network.name;
  const rpcUrl = process.env.RPC_URL || "http://localhost:8547";
  console.log(`Deploying to network: ${network}`);
  console.log(`RPC URL: ${rpcUrl}`);

  // Deploy DeliveryToken
  console.log("\nDeploying DeliveryToken...");
  const deliveryToken = await deployContract("DeliveryToken");
  console.log("DeliveryToken deployed to:", deliveryToken.address);

  // Deploy DeliveryNFT
  console.log("\nDeploying DeliveryNFT...");
  const deliveryNFT = await deployContract("DeliveryNFT");
  console.log("DeliveryNFT deployed to:", deliveryNFT.address);

  // Deploy RatingSystem
  console.log("\nDeploying RatingSystem...");
  const ratingSystem = await deployContract("RatingSystem");
  console.log("RatingSystem deployed to:", ratingSystem.address);

  // Deploy StakingManager with DeliveryToken
  console.log("\nDeploying StakingManager...");
  const stakingManager = await deployContract("StakingManager", [deliveryToken.address]);
  console.log("StakingManager deployed to:", stakingManager.address);

  // Deploy DeliverySystem with token address
  console.log("\nDeploying DeliverySystem...");
  const deliverySystem = await deployContract("DeliverySystem", [deliveryToken.address]);
  console.log("DeliverySystem deployed to:", deliverySystem.address);

  // Verify contracts if not on local network
  if (network !== "hardhat" && network !== "localhost") {
    console.log("\nVerifying contracts...");
    await verify(hre, deliveryToken.address);
    await verify(hre, deliveryNFT.address);
    await verify(hre, ratingSystem.address);
    await verify(hre, stakingManager.address, [deliveryToken.address]);
    await verify(hre, deliverySystem.address, [deliveryToken.address]);
  }

  // Export deployment information
  const deploymentInfo = {
    network,
    rpcUrl,
    contracts: {
      DeliveryToken: deliveryToken.address,
      DeliveryNFT: deliveryNFT.address,
      RatingSystem: ratingSystem.address,
      StakingManager: stakingManager.address,
      DeliverySystem: deliverySystem.address,
    },
    timestamp: new Date().toISOString(),
  };

  console.log("\nDeployment completed!");
  console.log("\nDeployment Information:");
  console.log("----------------------");
  console.log(JSON.stringify(deploymentInfo, null, 2));
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  }); 