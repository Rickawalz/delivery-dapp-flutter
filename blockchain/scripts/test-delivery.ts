import { ethers } from "hardhat";
import * as fs from "fs";
import * as path from "path";

/**
 * Exercises the current SimpleDeliverySystem lifecycle on localhost.
 * The customer creates a delivery and confirms completion. There is no
 * token escrow and no courier accept step.
 */
async function main() {
  const configPath = path.join(__dirname, "../../app/assets/config/contracts.localhost.json");
  const config = JSON.parse(fs.readFileSync(configPath, "utf8"));
  const deliveryAddress = config.contracts.SimpleDeliverySystem as string;
  if (!deliveryAddress) {
    throw new Error("SimpleDeliverySystem address missing from contracts.localhost.json");
  }

  const delivery = await ethers.getContractAt("SimpleDeliverySystem", deliveryAddress);
  const [customer, driver] = await ethers.getSigners();
  const deliveryId = ethers.id(`test-delivery-${Date.now()}`);
  const distanceMeters = 1500;
  const fiatAmountCents = 1500;
  const rating = 5;

  console.log("SimpleDeliverySystem:", deliveryAddress);
  console.log("Customer:", customer.address);
  console.log("Driver:", driver.address);

  console.log("\nCreating delivery...");
  const createTx = await delivery
    .connect(customer)
    .createDelivery(deliveryId, driver.address, distanceMeters, fiatAmountCents);
  const createReceipt = await createTx.wait();
  console.log("Delivery created:", createReceipt?.hash);

  console.log("\nCustomer completing delivery...");
  const completeTx = await delivery.connect(customer).completeDelivery(deliveryId, rating);
  const completeReceipt = await completeTx.wait();
  console.log("Delivery completed:", completeReceipt?.hash);

  const stored = await delivery.getDelivery(deliveryId);
  console.log("Stored delivery:", {
    customer: stored.customer,
    driver: stored.driver,
    distanceMeters: stored.distanceMeters.toString(),
    fiatAmountCents: stored.fiatAmountCents.toString(),
    rating: stored.rating.toString(),
    status: stored.status.toString(),
  });
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
