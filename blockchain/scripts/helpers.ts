import hre from "hardhat";
import type { Contract } from "ethers";
import * as fs from "fs";
import * as path from "path";

/**
 * Deploy a contract by name with constructor args.
 * Returns the live Contract instance, address, and abi.
 */
export async function deployContract(
  contractName: string,
  args: unknown[] = []
): Promise<{ instance: Contract; address: string; abi: any }> {
  const factory = await hre.ethers.getContractFactory(contractName);
  const contract = await factory.deploy(...args);

  // ethers v6: wait until it's actually deployed
  await contract.waitForDeployment();

  const address = await contract.getAddress();
  const artifact = await hre.artifacts.readArtifact(contractName);

  // Export ABI + address for the frontend, namespaced by network
  await exportAbiAndAddress(contractName, artifact.abi, address);

  return { instance: contract, address, abi: artifact.abi };
}

/**
 * Etherscan-style verification via Hardhat.
 * Assumes your hardhat.config has the appropriate etherscan/apiKey configured.
 */
export async function verify(
  address: string,
  args: unknown[] = []
): Promise<void> {
  try {
    await hre.run("verify:verify", {
      address,
      constructorArguments: args,
    });
  } catch (e) {
    const msg = (e as Error)?.message?.toLowerCase?.() ?? "";
    if (msg.includes("already verified")) {
      console.log("Already verified.");
    } else {
      console.error("Verification failed:", e);
    }
  }
}

/**
 * Writes ABI and contract address files for the Flutter app.
 * - ABI goes to:      app/assets/abi/<ContractName>.json
 * - Addresses go to:  app/assets/config/contracts.<network>.json
 *
 * Using a per-network file prevents overwriting when you switch networks.
 */
async function exportAbiAndAddress(
  contractName: string,
  abi: any,
  address: string
): Promise<void> {
  const network = hre.network.name;
  const chainId = (hre.network.config as any)?.chainId;

  const abiDir = path.join(__dirname, "../../app/assets/abi");
  const configDir = path.join(__dirname, "../../app/assets/config");
  const contractsPath = path.join(configDir, `contracts.${network}.json`);

  // Ensure directories exist
  if (!fs.existsSync(abiDir)) fs.mkdirSync(abiDir, { recursive: true });
  if (!fs.existsSync(configDir)) fs.mkdirSync(configDir, { recursive: true });

  // Write ABI: app/assets/abi/DeliveryToken.json, etc.
  const abiPath = path.join(abiDir, `${contractName}.json`);
  fs.writeFileSync(abiPath, JSON.stringify(abi, null, 2));

  // Merge/update addresses file for this network
  let manifest: {
    network: string;
    chainId?: number;
    updatedAt?: string;
    contracts: Record<string, string>;
  } = { network, chainId, contracts: {} };

  if (fs.existsSync(contractsPath)) {
    try {
      const existing = JSON.parse(fs.readFileSync(contractsPath, "utf8"));
      if (existing && typeof existing === "object") {
        manifest = {
          network: existing.network ?? network,
          chainId: existing.chainId ?? chainId,
          updatedAt: existing.updatedAt,
          contracts: existing.contracts ?? {},
        };
      }
    } catch {
      // If parsing fails, start fresh
      manifest = { network, chainId, contracts: {} };
    }
  }

  manifest.contracts[contractName] = address;
  manifest.updatedAt = new Date().toISOString();

  fs.writeFileSync(contractsPath, JSON.stringify(manifest, null, 2));
  console.log(`Exported ${contractName} ABI to ${abiPath}`);
  console.log(
    `Recorded ${contractName} address (${address}) in ${path.basename(contractsPath)}`
  );
}
