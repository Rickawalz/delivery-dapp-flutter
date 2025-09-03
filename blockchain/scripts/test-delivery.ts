import { ethers } from "hardhat";
import * as dotenv from "dotenv";
import * as path from "path";

interface Delivery {
  id: bigint;
  customer: string;
  courier: string;
  pickupAddress: string;
  deliveryAddress: string;
  price: bigint;
  description: string;
  status: number;
  createdAt: bigint;
  completedAt: bigint;
}

// Load environment variables
dotenv.config({ path: path.join(__dirname, '../../app/.env') });

async function main() {
  // Get the DeliverySystem contract factory and deploy
  const DeliverySystem = await ethers.getContractFactory("DeliverySystem");
  const deliverySystem = await DeliverySystem.attach("0xdc64a140aa3e981100a9beca4e685f962f0cf6c9");

  // Get the DeliveryToken contract
  const DeliveryToken = await ethers.getContractFactory("DeliveryToken");
  const deliveryToken = await DeliveryToken.attach("0x5fbdb2315678afecb367f032d93f642f64180aa3");

  // Get signers
  const [customer, courier] = await ethers.getSigners();

  console.log("Testing delivery creation and management...");
  console.log("Customer address:", customer.address);
  console.log("Courier address:", courier.address);

  // Mint tokens to customer for testing
  const price = ethers.parseEther("0.1");
  console.log("\nMinting tokens to customer...");
  const mintTx = await deliveryToken.mint(customer.address, price);
  await mintTx.wait();
  console.log("Tokens minted!");

  // Approve tokens
  console.log("\nApproving tokens...");
  const approveTx = await deliveryToken.connect(customer).approve(deliverySystem.getAddress(), price);
  await approveTx.wait();
  console.log("Tokens approved!");

  // Create a delivery
  console.log("\nCreating delivery...");
  const createTx = await deliverySystem.connect(customer).createDelivery(
    "123 Pickup St",
    "456 Delivery Ave",
    price,
    "Test delivery"
  );
  
  const receipt = await createTx.wait();
  console.log("Delivery created! Transaction hash:", receipt?.hash);

  // Get the delivery ID from the event
  const deliveryCreatedEvent = receipt?.logs[0];
  const deliveryId = deliveryCreatedEvent?.args?.[0];
  console.log("Delivery ID:", deliveryId);

  // Accept the delivery
  console.log("\nAccepting delivery...");
  const acceptTx = await deliverySystem.connect(courier).acceptDelivery(deliveryId);
  await acceptTx.wait();
  console.log("Delivery accepted!");

  // Get delivery details
  console.log("\nGetting delivery details...");
  const delivery = await deliverySystem.getDelivery(deliveryId);
  console.log("Delivery details:", {
    id: delivery.id.toString(),
    customer: delivery.customer,
    courier: delivery.courier,
    pickupAddress: delivery.pickupAddress,
    deliveryAddress: delivery.deliveryAddress,
    price: ethers.formatEther(delivery.price),
    status: delivery.status
  });

  // Complete the delivery
  console.log("\nCompleting delivery...");
  const completeTx = await deliverySystem.connect(courier).completeDelivery(deliveryId);
  await completeTx.wait();
  console.log("Delivery completed!");

  // Get final delivery details
  console.log("\nGetting final delivery details...");
  const finalDelivery = await deliverySystem.getDelivery(deliveryId);
  console.log("Final delivery details:", {
    id: finalDelivery.id.toString(),
    customer: finalDelivery.customer,
    courier: finalDelivery.courier,
    pickupAddress: finalDelivery.pickupAddress,
    deliveryAddress: finalDelivery.deliveryAddress,
    price: ethers.formatEther(finalDelivery.price),
    status: finalDelivery.status,
    completedAt: new Date(Number(finalDelivery.completedAt) * 1000).toISOString()
  });
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  }); 