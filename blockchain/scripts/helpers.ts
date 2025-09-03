import { HardhatRuntimeEnvironment } from "hardhat/types";
import hre from "hardhat";
import * as fs from 'fs';
import * as path from 'path';

export async function deployContract(
  contractName: string,
  args: any[] = []
) {
  try {
    console.log(`Deploying ${contractName}...`);
    const factory = await hre.ethers.getContractFactory(contractName);
    const contract = await factory.deploy(...args);
    
    // Wait for deployment to be mined
    console.log(`Waiting for ${contractName} deployment...`);
    const deploymentReceipt = await contract.deploymentTransaction()?.wait();
    if (!deploymentReceipt) {
      throw new Error(`Failed to deploy ${contractName}`);
    }
    
    const address = await contract.getAddress();
    console.log(`${contractName} deployed to: ${address}`);
    
    const artifact = await hre.artifacts.readArtifact(contractName);
    
    // Export ABI to Flutter app
    await exportAbi(contractName, artifact.abi, address);
    
    return {
      address,
      abi: artifact.abi,
      instance: contract
    };
  } catch (error) {
    console.error(`Error deploying ${contractName}:`, error);
    throw error;
  }
}

export async function verify(
  hre: HardhatRuntimeEnvironment,
  address: string,
  args: any[] = []
) {
  console.log("Verifying contract...");
  try {
    await hre.run("verify:verify", {
      address: address,
      constructorArguments: args,
    });
  } catch (e) {
    if ((e as Error).message.toLowerCase().includes("already verified")) {
      console.log("Already verified!");
    } else {
      console.error(e);
    }
  }
}

async function exportAbi(contractName: string, abi: any, address: string) {
  // Create directories if they don't exist
  const abiDir = path.join(__dirname, '../../app/assets/abi');
  const configDir = path.join(__dirname, '../../app/assets/config');
  
  if (!fs.existsSync(abiDir)) {
    fs.mkdirSync(abiDir, { recursive: true });
  }
  if (!fs.existsSync(configDir)) {
    fs.mkdirSync(configDir, { recursive: true });
  }

  // Export ABI
  const abiPath = path.join(abiDir, `${contractName}.json`);
  fs.writeFileSync(abiPath, JSON.stringify(abi, null, 2));

  // Export contract address
  const configPath = path.join(configDir, 'contracts.json');
  let config: { [key: string]: string } = {};
  
  if (fs.existsSync(configPath)) {
    config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
  }
  
  config[contractName] = address;
  fs.writeFileSync(configPath, JSON.stringify(config, null, 2));

  console.log(`Exported ${contractName} ABI and address`);
} 