import { ethers } from "hardhat";
import * as fs from "fs";
import * as path from "path";
import * as os from "os";
/**
 * Deployment script for Master's Thesis demonstration
 * 
 * Deploys core smart contracts to localhost Hardhat network for academic demonstration.
 * Creates test data for thesis defense live demo.
 * 
 * Usage:
 * Terminal 1: npx hardhat node --hostname 0.0.0.0
 * Terminal 2: npx hardhat run scripts/deploy-thesis.ts --network localhost
 *
 * Env:
 * TIMELOCK_MIN_DELAY      seconds; default 172800 (2 days)
 * HYBRID_COUNCIL_ADDRESS  Safe (or compatible) multisig off localhost.
 *                          Localhost defaults to Hardhat account #1.
 */

interface DeploymentResult {
  network: string;
  contracts: {
    DeliveryToken: string;
    DeliveryTrackingSystem: string;
    BalancedRewardSystem: string;
    SimpleDeliverySystem: string;
    DecentralizationPhase: string;
    RatingSystem: string;
    TimelockController: string;
    RLEGovernor: string;
  };
  timestamp: string;
}

const DEFAULT_TIMELOCK_MIN_DELAY = 2 * 24 * 60 * 60;

function readTimelockMinDelay(): bigint {
  const raw = process.env.TIMELOCK_MIN_DELAY;
  if (raw === undefined || raw.trim() === "") {
    return BigInt(DEFAULT_TIMELOCK_MIN_DELAY);
  }
  if (!/^\d+$/.test(raw.trim())) {
    throw new Error("TIMELOCK_MIN_DELAY must be a non-negative integer number of seconds");
  }
  return BigInt(raw.trim());
}

const SAFE_COUNCIL_ABI = [
  "function getThreshold() view returns (uint256)",
  "function getOwners() view returns (address[])",
];

async function assertSafeCouncil(council: string, deployer: string): Promise<void> {
  const code = await ethers.provider.getCode(council);
  if (code === "0x") {
    throw new Error(
      "HYBRID_COUNCIL_ADDRESS must be a contract, not a plain wallet (EOA)"
    );
  }

  const safe = new ethers.Contract(council, SAFE_COUNCIL_ABI, ethers.provider);
  let threshold: bigint;
  let owners: string[];
  try {
    const rawThreshold = await safe.getThreshold.staticCall();
    const rawOwners = await safe.getOwners.staticCall();
    if (typeof rawThreshold !== "bigint" || !Array.isArray(rawOwners)) {
      throw new Error("unusable Safe response");
    }
    threshold = rawThreshold;
    owners = rawOwners.map((owner: string) => ethers.getAddress(owner));
  } catch {
    throw new Error(
      "Hybrid council must be a Safe (or compatible) multisignature wallet"
    );
  }

  if (threshold < 2n) {
    throw new Error(
      `Hybrid council Safe threshold must be at least 2, got ${threshold.toString()}`
    );
  }
  if (owners.length < 3) {
    throw new Error(
      `Hybrid council Safe must have at least 3 owners, got ${owners.length}`
    );
  }
  const uniqueOwners = new Set(owners.map((owner) => owner.toLowerCase()));
  if (uniqueOwners.size === 1 && uniqueOwners.has(deployer.toLowerCase())) {
    throw new Error("HYBRID_COUNCIL_ADDRESS deployer must not be the only Safe owner");
  }

  console.log("Hybrid council Safe threshold:", threshold.toString());
  console.log("Hybrid council Safe owners:", owners.join(", "));
}

async function resolveHybridCouncil(deployer: string, localhostFallback: string): Promise<string> {
  const fromEnv = process.env.HYBRID_COUNCIL_ADDRESS?.trim() ?? "";
  const chainId = (await ethers.provider.getNetwork()).chainId;
  const council = fromEnv !== "" ? fromEnv : chainId === 31337n ? localhostFallback : "";
  if (council === "") {
    throw new Error("HYBRID_COUNCIL_ADDRESS is required when not deploying to localhost");
  }
  if (!ethers.isAddress(council) || council === ethers.ZeroAddress) {
    throw new Error("HYBRID_COUNCIL_ADDRESS must be a non-zero address");
  }
  if (council.toLowerCase() === deployer.toLowerCase()) {
    throw new Error("HYBRID_COUNCIL_ADDRESS must not be the deployer");
  }
  const checksummed = ethers.getAddress(council);
  if (chainId === 31337n) {
    console.log(
      "Hybrid council is a single test account — production deployments must use a multisignature wallet."
    );
    return checksummed;
  }
  await assertSafeCouncil(checksummed, deployer);
  return checksummed;
}

function requireEqual(actual: string, expected: string, label: string) {
  if (actual.toLowerCase() !== expected.toLowerCase()) {
    throw new Error(`${label}: expected ${expected}, got ${actual}`);
  }
}

async function main() {
  console.log("\n🎓 Master's Thesis - Smart Contract Deployment");
  console.log("=============================================\n");

  const [deployer, councilAccount, driver1] = await ethers.getSigners();
  const hybridCouncil = await resolveHybridCouncil(deployer.address, councilAccount.address);
  const minDelay = readTimelockMinDelay();

  console.log("Deployer address:", deployer.address);
  console.log("Hybrid council:", hybridCouncil);
  console.log("Timelock min delay (seconds):", minDelay.toString());
  console.log("Network:", (await ethers.provider.getNetwork()).name);
  console.log("");

  console.log("📝 Deploying DeliveryToken...");
  const DeliveryToken = await ethers.getContractFactory("DeliveryToken");
  const token = await DeliveryToken.deploy();
  await token.waitForDeployment();
  const tokenAddress = await token.getAddress();
  console.log("✅ DeliveryToken deployed to:", tokenAddress);

  console.log("\n⏱️ Deploying TimelockController...");
  const TimelockController = await ethers.getContractFactory("TimelockController");
  const timelock = await TimelockController.deploy(minDelay, [], [ethers.ZeroAddress], deployer.address);
  await timelock.waitForDeployment();
  const timelockAddress = await timelock.getAddress();
  console.log("✅ TimelockController deployed to:", timelockAddress);

  console.log("\n🗳️ Deploying RLEGovernor...");
  const RLEGovernor = await ethers.getContractFactory("RLEGovernor");
  const governor = await RLEGovernor.deploy(tokenAddress, timelockAddress, 1, 45818, 0);
  await governor.waitForDeployment();
  const governorAddress = await governor.getAddress();
  console.log("✅ RLEGovernor deployed to:", governorAddress);

  console.log("\n🔐 Granting timelock roles to the governor...");
  const proposerRole = await timelock.PROPOSER_ROLE();
  const cancellerRole = await timelock.CANCELLER_ROLE();
  const adminRole = await timelock.TIMELOCK_ADMIN_ROLE();
  await (await timelock.grantRole(proposerRole, governorAddress)).wait();
  await (await timelock.grantRole(cancellerRole, governorAddress)).wait();
  await (await timelock.renounceRole(adminRole, deployer.address)).wait();
  console.log("✅ Governor can propose and cancel. Deployer renounced TIMELOCK_ADMIN_ROLE.");

  console.log("\n📍 Deploying DeliveryTrackingSystem...");
  const DeliveryTrackingSystem = await ethers.getContractFactory("DeliveryTrackingSystem");
  const tracking = await DeliveryTrackingSystem.deploy();
  await tracking.waitForDeployment();
  const trackingAddress = await tracking.getAddress();
  console.log("✅ DeliveryTrackingSystem deployed to:", trackingAddress);

  console.log("\n⭐ Deploying RatingSystem...");
  const RatingSystem = await ethers.getContractFactory("RatingSystem");
  const rating = await RatingSystem.deploy();
  await rating.waitForDeployment();
  const ratingAddress = await rating.getAddress();
  console.log("✅ RatingSystem deployed to:", ratingAddress);

  console.log("\n💰 Deploying BalancedRewardSystem...");
  const BalancedRewardSystem = await ethers.getContractFactory("BalancedRewardSystem");
  const rewards = await BalancedRewardSystem.deploy(tokenAddress);
  await rewards.waitForDeployment();
  const rewardsAddress = await rewards.getAddress();
  console.log("✅ BalancedRewardSystem deployed to:", rewardsAddress);

  console.log("\n🏛️ Deploying DecentralizationPhase...");
  const DecentralizationPhase = await ethers.getContractFactory("DecentralizationPhase");
  const phase = await DecentralizationPhase.deploy(hybridCouncil, timelockAddress);
  await phase.waitForDeployment();
  const phaseAddress = await phase.getAddress();
  console.log("✅ DecentralizationPhase deployed to:", phaseAddress);

  console.log("\n📦 Deploying SimpleDeliverySystem...");
  const SimpleDeliverySystem = await ethers.getContractFactory("SimpleDeliverySystem");
  const delivery = await SimpleDeliverySystem.deploy(rewardsAddress, trackingAddress, ratingAddress, phaseAddress);
  await delivery.waitForDeployment();
  const deliveryAddress = await delivery.getAddress();
  console.log("✅ SimpleDeliverySystem deployed to:", deliveryAddress);

  console.log("\n🔐 Transferring ownership...");
  await (await token.transferOwnership(rewardsAddress)).wait();
  await (await rewards.transferOwnership(deliveryAddress)).wait();
  await (await tracking.transferOwnership(deliveryAddress)).wait();
  await (await rating.transferOwnership(deliveryAddress)).wait();
  await (await phase.transferOwnership(deliveryAddress)).wait();

  requireEqual(await phase.owner(), deliveryAddress, "phase.owner");
  requireEqual(await rating.owner(), deliveryAddress, "rating.owner");
  requireEqual(await tracking.owner(), deliveryAddress, "tracking.owner");
  requireEqual(await rewards.owner(), deliveryAddress, "rewards.owner");
  requireEqual(await token.owner(), rewardsAddress, "token.owner");
  requireEqual(await phase.currentController(), deployer.address, "phase.currentController");
  requireEqual(await phase.hybridCouncil(), hybridCouncil, "phase.hybridCouncil");
  requireEqual(await phase.daoTimelock(), timelockAddress, "phase.daoTimelock");
  if (!(await timelock.hasRole(proposerRole, governorAddress))) {
    throw new Error("governor is missing PROPOSER_ROLE");
  }
  if (!(await timelock.hasRole(cancellerRole, governorAddress))) {
    throw new Error("governor is missing CANCELLER_ROLE");
  }
  if (await timelock.hasRole(adminRole, deployer.address)) {
    throw new Error("deployer still has TIMELOCK_ADMIN_ROLE");
  }
  console.log("✅ Ownership and timelock roles verified");

  // ========== SKIP TEST DATA CREATION ==========
  
  console.log("\n🧹 Skipping test data creation - starting with clean state");
  console.log("  ✅ Contracts deployed and ready for user-created deliveries");

  // ========== DISPLAY NETWORK INFO ==========
  
  console.log("\n🌐 Network Configuration");
  console.log("========================\n");
  
  // Get local IP address - prioritize eth0 interface
  const interfaces = os.networkInterfaces();
  let localIP = 'Unknown';
  
  console.log('🔍 Debug: Detected network interfaces:');
  for (const [name, addresses] of Object.entries(interfaces)) {
    if (addresses && addresses.length > 0) {
      console.log(`  ${name}:`);
      for (const addr of addresses) {
        console.log(`    - ${addr.address} (${addr.family}, internal: ${addr.internal})`);
      }
    }
  }
  console.log('');
  
  // Priority order: Wi-Fi > eth0 > other real interfaces > WSL interfaces
  const interfacePriority = ['Wi-Fi', 'eth0', 'Ethernet', 'WiFi'];
  
  // First, try priority interfaces
  for (const priorityInterface of interfacePriority) {
    if (interfaces[priorityInterface] && interfaces[priorityInterface].length > 0) {
      console.log(`🎯 Looking for ${priorityInterface} interface...`);
      for (const addr of interfaces[priorityInterface]) {
        if (addr.family === 'IPv4' && !addr.internal) {
          localIP = addr.address;
          console.log(`✅ Found ${priorityInterface} IP: ${localIP}`);
          break;
        }
      }
      if (localIP !== 'Unknown') break;
    }
  }
  
  // If no priority interface found, fall back to other real interfaces
  if (localIP === 'Unknown') {
    console.log('🔄 Falling back to other real interfaces...');
    for (const [name, addresses] of Object.entries(interfaces)) {
      // Skip virtual/WSL interfaces
      if (name.startsWith('docker') || name.startsWith('veth') || name.startsWith('br-') || 
          name.includes('Virtual') || name.includes('Hyper-V') || name.includes('WSL') ||
          name.includes('vEthernet')) {
        console.log(`⏭️ Skipping virtual/WSL interface: ${name}`);
        continue;
      }
      
      if (addresses) {
        for (const addr of addresses) {
          if (addr.family === 'IPv4' && !addr.internal) {
            localIP = addr.address;
            console.log(`✅ Found IP on ${name}: ${localIP}`);
            break;
          }
        }
        if (localIP !== 'Unknown') break;
      }
    }
  }
  
  // Last resort: use any available interface (including WSL)
  if (localIP === 'Unknown') {
    console.log('🆘 Last resort: using any available interface...');
    for (const [name, addresses] of Object.entries(interfaces)) {
      if (addresses) {
        for (const addr of addresses) {
          if (addr.family === 'IPv4' && !addr.internal) {
            localIP = addr.address;
            console.log(`⚠️ Using WSL/virtual interface ${name}: ${localIP}`);
            break;
          }
        }
        if (localIP !== 'Unknown') break;
      }
    }
  }
  
  if (localIP === 'Unknown') {
    console.log('❌ No suitable IP address found');
  }
  
  console.log(`💻 Computer IP is: ${localIP}`);
  console.log(`🔗 RPC URL: http://${localIP}:8545`);
  console.log(`📱 MetaMask Mobile Setup:`);
  console.log(`   - Network Name: Hardhat Local`);
  console.log(`   - RPC URL: http://${localIP}:8545`);
  console.log(`   - Chain ID: 31337`);
  console.log(`   - Currency Symbol: ETH`);
  
  if (localIP !== 'Unknown') {
    const devHostPath = path.join(__dirname, "../../app/assets/config/dev_host.json");
    fs.mkdirSync(path.dirname(devHostPath), { recursive: true });
    fs.writeFileSync(devHostPath, JSON.stringify({ host: localIP }, null, 2) + "\n");
    console.log(`\n✅ Development RPC host saved: ${localIP}`);
    console.log(`   📁 File: ${devHostPath}`);
  }

  // ========== DISPLAY RESULTS FOR THESIS ==========

  console.log("\n📊 Thesis Demonstration Data");
  console.log("============================\n");

  // Get driver 1 stats
  const driver1Stats = await rewards.getDriverStats(driver1.address);
  console.log("Driver 1 Statistics:");
  console.log(`  Total Deliveries: ${driver1Stats[2]}`);
  console.log(`  Total Earned: ${ethers.formatEther(driver1Stats[3])} RLE`);
  console.log(`  Diversity: ${driver1Stats[4]} short, ${driver1Stats[5]} medium, ${driver1Stats[6]} long`);

  // Get network stats
  const networkStats = await rewards.getNetworkStats();
  console.log("\nNetwork Statistics:");
  console.log(`  Total Deliveries Completed: ${networkStats[1]}`);
  console.log(`  Current Token Rate: ${ethers.formatEther(networkStats[0])} RLE per 100 points`);

  // Get platform stats
  const platformStats = await delivery.getPlatformStats();
  console.log("\nPlatform Economics (for RQ2 analysis):");
  console.log(`  Total Deliveries: ${platformStats[0]}`);
  console.log(`  Completed: ${platformStats[1]}`);
  console.log(`  Platform Fees Collected: $${Number(platformStats[2]) / 100} (${platformStats[3]}% fee)`);
  console.log(`  Traditional 30% fee would be: $${(Number(platformStats[2]) / 100) * 15} (comparison for thesis)`);

  // Get decentralization progress
  const progress = await phase.getProgress();
  console.log("\nDecentralization Progress (for RQ2 framework):");
  console.log(`  Current Phase: ${progress[0] === 0n ? "Bootstrap" : progress[0] === 1n ? "Hybrid" : "FullDAO"}`);
  console.log(`  Delivery Progress: ${progress[1]}% of milestone`);
  console.log(`  Driver Progress: ${progress[2]}% of milestone`);
  console.log(`  Can Advance: ${progress[5] ? "Yes" : "Not yet"}`);

  // ========== SAVE DEPLOYMENT INFO ==========

  console.log("\n📍 Deployed addresses");
  console.log("  DeliveryToken:          ", tokenAddress);
  console.log("  TimelockController:     ", timelockAddress);
  console.log("  RLEGovernor:            ", governorAddress);
  console.log("  DeliveryTrackingSystem: ", trackingAddress);
  console.log("  RatingSystem:           ", ratingAddress);
  console.log("  BalancedRewardSystem:   ", rewardsAddress);
  console.log("  DecentralizationPhase:  ", phaseAddress);
  console.log("  SimpleDeliverySystem:   ", deliveryAddress);
  console.log("  Hybrid council:         ", hybridCouncil);

  const deploymentInfo: DeploymentResult = {
    network: "localhost",
    contracts: {
      DeliveryToken: tokenAddress,
      DeliveryTrackingSystem: trackingAddress,
      BalancedRewardSystem: rewardsAddress,
      SimpleDeliverySystem: deliveryAddress,
      DecentralizationPhase: phaseAddress,
      RatingSystem: ratingAddress,
      TimelockController: timelockAddress,
      RLEGovernor: governorAddress,
    },
    timestamp: new Date().toISOString(),
  };

  // Save to file for Flutter app integration
  const configPath = path.join(__dirname, "../../app/assets/config/contracts.localhost.json");
  const configDir = path.dirname(configPath);

  if (!fs.existsSync(configDir)) {
    fs.mkdirSync(configDir, { recursive: true });
  }

  fs.writeFileSync(configPath, JSON.stringify(deploymentInfo, null, 2));

  const abiSource = path.join(
    __dirname,
    "../artifacts/contracts/core/SimpleDeliverySystem.sol/SimpleDeliverySystem.json"
  );
  const abiDest = path.join(__dirname, "../../app/assets/abi/SimpleDeliverySystem.json");
  fs.copyFileSync(abiSource, abiDest);

  const phaseAbiSource = path.join(
    __dirname,
    "../artifacts/contracts/governance/DecentralizationPhase.sol/DecentralizationPhase.json"
  );
  const phaseAbiDest = path.join(__dirname, "../../app/assets/abi/DecentralizationPhase.json");
  fs.copyFileSync(phaseAbiSource, phaseAbiDest);

  console.log("\n📄 Deployment info saved to:", configPath);
  console.log("📄 SimpleDeliverySystem ABI copied to:", abiDest);
  console.log("📄 DecentralizationPhase ABI copied to:", phaseAbiDest);
  console.log("\n✅ Thesis demonstration deployment complete!");
  console.log("\n📚 Ready for:");
  console.log("  - Live thesis defense demo");
  console.log("  - Screenshot capture for thesis document");
  console.log("  - Simulation framework testing");
  console.log("  - Flutter app integration\n");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("\n❌ Deployment failed:");
    console.error(error);
    process.exit(1);
  });

