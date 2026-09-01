import { ethers } from "hardhat";
import * as fs from "fs";
import * as path from "path";
import * as os from "os";
import type { SimpleDeliverySystem } from "../typechain-types";
/**
 * Deployment script for Master's Thesis demonstration
 * 
 * Deploys core smart contracts to localhost Hardhat network for academic demonstration.
 * Creates test data for thesis defense live demo.
 * 
 * Usage:
 * Terminal 1: npx hardhat node --hostname 0.0.0.0
 * Terminal 2: npx hardhat run scripts/deploy-thesis.ts --network localhost
 */

interface DeploymentResult {
  network: string;
  contracts: {
    DeliveryToken: string;
    DeliveryTrackingSystem: string;
    BalancedRewardSystem: string;
    SimpleDeliverySystem: string;
    DecentralizationPhase: string;
  };
  timestamp: string;
}

async function main() {
  console.log("\n🎓 Master's Thesis - Smart Contract Deployment");
  console.log("=============================================\n");

  const [deployer, driver1, driver2, customer1, customer2] = await ethers.getSigners();

  console.log("Deployer address:", deployer.address);
  console.log("Network:", (await ethers.provider.getNetwork()).name);
  console.log("");

  // ========== DEPLOY CONTRACTS ==========

  console.log("📝 Deploying DeliveryToken...");
  const DeliveryToken = await ethers.getContractFactory("DeliveryToken");
  const token = await DeliveryToken.deploy();
  await token.waitForDeployment();
  const tokenAddress = await token.getAddress();
  console.log("✅ DeliveryToken deployed to:", tokenAddress);

  console.log("\n📍 Deploying DeliveryTrackingSystem...");
  const DeliveryTrackingSystem = await ethers.getContractFactory("DeliveryTrackingSystem");
  const tracking = await DeliveryTrackingSystem.deploy();
  await tracking.waitForDeployment();
  const trackingAddress = await tracking.getAddress();
  console.log("✅ DeliveryTrackingSystem deployed to:", trackingAddress);

  console.log("\n💰 Deploying BalancedRewardSystem...");
  const BalancedRewardSystem = await ethers.getContractFactory("BalancedRewardSystem");
  const rewards = await BalancedRewardSystem.deploy(tokenAddress);
  await rewards.waitForDeployment();
  const rewardsAddress = await rewards.getAddress();
  console.log("✅ BalancedRewardSystem deployed to:", rewardsAddress);

  console.log("\n⭐ Deploying RatingSystem...");
  const RatingSystem = await ethers.getContractFactory("RatingSystem");
  const rating = await RatingSystem.deploy();
  await rating.waitForDeployment();
  const ratingAddress = await rating.getAddress();
  console.log("✅ RatingSystem deployed to:", ratingAddress);

  console.log("\n🏛️ Deploying DecentralizationPhase...");
  const DecentralizationPhase = await ethers.getContractFactory("DecentralizationPhase");
  const phase = await DecentralizationPhase.deploy();
  await phase.waitForDeployment();
  const phaseAddress = await phase.getAddress();
  console.log("✅ DecentralizationPhase deployed to:", phaseAddress);

  console.log("\n📦 Deploying SimpleDeliverySystem...");
  const SimpleDeliverySystem = await ethers.getContractFactory("SimpleDeliverySystem");
  const delivery = await SimpleDeliverySystem.deploy(rewardsAddress, trackingAddress, ratingAddress, phaseAddress);
  await delivery.waitForDeployment();
  const deliveryAddress = await delivery.getAddress();
  console.log("✅ SimpleDeliverySystem deployed to:", deliveryAddress);

  // ========== SETUP PERMISSIONS ==========

  console.log("\n🔐 Setting up contract permissions...");

  // Transfer token ownership to reward system
  console.log("  ↳ Transferring DeliveryToken ownership to BalancedRewardSystem...");
  await token.transferOwnership(rewardsAddress);

  // Transfer reward system ownership to delivery system
  console.log("  ↳ Transferring BalancedRewardSystem ownership to SimpleDeliverySystem...");
  await rewards.transferOwnership(deliveryAddress);

  // Transfer tracking system ownership to delivery system
  console.log("  ↳ Transferring DeliveryTrackingSystem ownership to SimpleDeliverySystem...");
  await tracking.transferOwnership(deliveryAddress);

  // Note: RatingSystem doesn't have ownership (no Ownable inheritance)
  console.log("  ↳ RatingSystem has no ownership (public contract)");

  // Transfer decentralization phase ownership to delivery system
  console.log("  ↳ Transferring DecentralizationPhase ownership to SimpleDeliverySystem...");
  await phase.transferOwnership(deliveryAddress);

  console.log("✅ Permissions configured");

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
  
  // ========== AUTO-UPDATE CONTRACT SERVICE ==========
  
  if (localIP !== 'Unknown') {
    console.log("\n🔧 Auto-updating Contract Service...");
    try {
      const contractServicePath = path.join(__dirname, '../../app/lib/services/blockchain/contract_service.dart');
      const rpcUrl = `http://${localIP}:8545`;
      
      // Read the current contract service file
      let contractServiceContent = fs.readFileSync(contractServicePath, 'utf8');
      
      // Replace the HARDHAT_RPC_IP global variable
      const oldPattern = /const String HARDHAT_RPC_IP = '[^']*';/;
      const newPattern = `const String HARDHAT_RPC_IP = '${localIP}';`;
      
      if (oldPattern.test(contractServiceContent)) {
        contractServiceContent = contractServiceContent.replace(oldPattern, newPattern);
        
        // Write the updated content back
        fs.writeFileSync(contractServicePath, contractServiceContent, 'utf8');
        
        console.log(`✅ Contract Service updated with IP: ${localIP}`);
        console.log(`   📍 RPC URL: ${rpcUrl}`);
        console.log(`   📁 File: ${contractServicePath}`);
      } else {
        console.log('⚠️  Could not find HARDHAT_RPC_IP variable in contract service');
        console.log('   Make sure the global variable exists: const String HARDHAT_RPC_IP = \'...\';');
      }
    } catch (error) {
      console.log('❌ Failed to update Contract Service:', error);
    }
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

  const deploymentInfo: DeploymentResult = {
    network: "localhost",
    contracts: {
      DeliveryToken: tokenAddress,
      DeliveryTrackingSystem: trackingAddress,
      BalancedRewardSystem: rewardsAddress,
      SimpleDeliverySystem: deliveryAddress,
      DecentralizationPhase: phaseAddress,
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

  console.log("\n📄 Deployment info saved to:", configPath);
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

